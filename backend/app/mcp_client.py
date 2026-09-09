"""MCP 客户端（WS4）：纯标准库消费外部 MCP 服务器的 stdio 工具。

协议（已核实）：
- stdio 传输 = 换行分隔 JSON-RPC 2.0，每行一个 JSON 对象、\\n 结尾，无 Content-Length。
- 服务器 stdout 只允许协议输出（日志一律走 stderr），否则客户端跳过畸形行不崩。
- 握手：initialize(protocolVersion=2024-11-05) → notifications/initialized(无 id 通知)
  → tools/list → tools/call。

健壮性（不崩 chat）：
- 服务器退出/EOF/写管道失败 → 标记 offline；pending 调用立即返错误。
- 畸形行、未知无 id 消息 → 记录日志后忽略。
- 每次调用有超时（REQUEST_TIMEOUT=15s）；工具注册表 60s TTL 缓存，减少握手开销。
- 服务器子进程用 daemon 线程读 stdout，stderr 单独 drain（防止日志写满阻塞）。

命名约定：聊天工具名 = mcp__{server}__{tool}，ai_gateway._execute_tool 按前缀分发。
"""
import json
import logging
import os
import queue
import re
import subprocess
import threading
import time

from . import config

logger = logging.getLogger("lifehub")

PROTOCOL_VERSION = "2024-11-05"
HANDSHAKE_TIMEOUT = 10  # 握手 / tools/list 上限（秒）
REQUEST_TIMEOUT = 15  # 单次 tools/call 上限（秒）
RETRY_COOLDOWN = 20  # 服务器离线后的重连冷却（秒）：崩溃/被杀后自动自愈


class MCPError(Exception):
    """MCP 客户端异常（服务器离线/超时/远端报错），message 可直接给 AI。"""


def _clean_schema(schema):
    """把任意 inputSchema 清洗成 OpenAI 函数子集（剥 $schema/$id/$defs/examples 等）。"""
    if not isinstance(schema, dict):
        return {"type": "object", "properties": {}}
    out = {}
    for k in ("type", "properties", "required", "enum", "items", "description",
              "minimum", "maximum", "format", "const"):
        if k in schema:
            v = schema[k]
            if k == "properties" and isinstance(v, dict):
                out[k] = {
                    pk: _clean_schema(pv) if isinstance(pv, dict) else pv
                    for pk, pv in v.items()
                }
            else:
                out[k] = v
    if "type" not in out:
        out["type"] = "object"
    if "properties" not in out:
        out["properties"] = {}
    return out


class MCPServer:
    """一个 stdio MCP 服务器子进程的客户端句柄（懒启动 + 断线标记）。"""

    def __init__(self, name: str, command: str, args: list[str] | None = None,
                 env: dict | None = None):
        self.name = name
        self.command = command
        self.args = list(args or [])
        self.env = env or {}
        self.offline = False
        self.proc: subprocess.Popen | None = None
        self._next_id = 1
        self._pending: dict[int, queue.Queue] = {}
        self._lock = threading.Lock()
        self._start_lock = threading.Lock()
        self._offline_since: float | None = None  # 断线时刻（monotonic），用于冷却重连

    # ------------------------------------------------------------------ #
    def _spawn(self) -> None:
        full_env = dict(os.environ)
        full_env.update(self.env)
        self.proc = subprocess.Popen(
            [self.command, *self.args],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True, encoding="utf-8", errors="replace",
            bufsize=1, env=full_env,
        )
        # 服务器日志走 stderr：后台 drain，防止 stderr 写满把服务器阻塞
        threading.Thread(target=self._drain_stderr, daemon=True).start()
        threading.Thread(target=self._read_loop, daemon=True).start()

    def _drain_stderr(self) -> None:
        try:
            for line in self.proc.stderr:
                line = line.rstrip()
                if line:
                    logger.info("[mcp %s] %s", self.name, line[:300])
        except Exception:
            pass

    def _read_loop(self) -> None:
        try:
            while True:
                line = self.proc.stdout.readline()
                if not line:  # EOF → 服务器退出
                    self._mark_offline("服务器退出")
                    return
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    logger.warning("[mcp %s] 忽略畸形行: %r", self.name, line[:120])
                    continue
                if msg.get("id") is not None:
                    self._resolve(msg)
                # 其余（notifications/initialized 等无 id 消息）忽略
        except Exception:
            self._mark_offline("读取循环异常")

    def _resolve(self, msg: dict) -> None:
        with self._lock:
            q = self._pending.pop(msg.get("id"), None)
        if q is not None:
            q.put(msg)

    def _mark_offline(self, reason: str) -> None:
        if self.offline:
            return
        self.offline = True
        self._offline_since = time.monotonic()
        logger.warning("[mcp %s] 离线: %s", self.name, reason)
        with self._lock:
            pending = list(self._pending.values())
            self._pending.clear()
        err = {"error": {"code": -32000, "message": f"MCP 服务器 {self.name} 离线（{reason}）"}}
        for q in pending:
            q.put(err)

    def _request(self, method: str, params: dict | None = None,
                 timeout: float = REQUEST_TIMEOUT) -> dict:
        if self.offline or self.proc is None or self.proc.poll() is not None:
            raise MCPError(f"MCP 服务器 {self.name} 离线")
        with self._lock:
            req_id = self._next_id
            self._next_id += 1
            q: queue.Queue = queue.Queue(maxsize=1)
            self._pending[req_id] = q
        msg = {"jsonrpc": "2.0", "id": req_id, "method": method}
        if params is not None:
            msg["params"] = params
        try:
            self.proc.stdin.write(json.dumps(msg) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, ValueError, OSError):
            self._mark_offline("写管道失败")
            raise MCPError(f"MCP 服务器 {self.name} 离线（写管道失败）") from None
        try:
            resp = q.get(timeout=timeout)
        except queue.Empty:
            raise MCPError(f"MCP 服务器 {self.name} 响应超时（{timeout:.0f}s）") from None
        if resp.get("error"):
            raise MCPError(f"{resp['error'].get('message', resp['error'])}")
        return resp.get("result") or {}

    # ------------------------------------------------------------------ #
    def ensure_started(self) -> None:
        """懒启动 + 握手（幂等；失败标记 offline 并抛错，绝不静默）。

        离线后 RETRY_COOLDOWN 内拒绝；冷却过后尝试自愈重连（服务器崩溃/被杀可恢复）。
        """
        with self._start_lock:
            if self.offline:
                if (self._offline_since is not None
                        and time.monotonic() - self._offline_since < RETRY_COOLDOWN):
                    raise MCPError(f"MCP 服务器 {self.name} 离线")
                # 冷却期已过 → 自愈重连
                self.offline = False
                self._offline_since = None
            if self.proc is not None and self.proc.poll() is None:
                return
            self._spawn()
            try:
                self._request("initialize", {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {"name": "lifehub", "version": "1.0"},
                }, timeout=HANDSHAKE_TIMEOUT)
                self._notify("notifications/initialized", {})
            except Exception as exc:
                self._mark_offline(f"握手失败: {exc}")
                self.shutdown(terminate=True)
                raise MCPError(f"MCP 服务器 {self.name} 握手失败: {exc}") from None

    def _notify(self, method: str, params: dict | None = None) -> None:
        if self.proc is None or self.proc.poll() is not None:
            return
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        try:
            self.proc.stdin.write(json.dumps(msg) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, ValueError, OSError):
            self._mark_offline("写管道失败")

    def list_tools(self, timeout: float = HANDSHAKE_TIMEOUT) -> list[dict]:
        self.ensure_started()
        result = self._request("tools/list", timeout=timeout)
        tools = result.get("tools") or []
        return [t for t in tools if isinstance(t, dict) and isinstance(t.get("name"), str)]

    def call_tool(self, tool: str, arguments: dict | None = None,
                  timeout: float = REQUEST_TIMEOUT) -> dict:
        self.ensure_started()
        return self._request("tools/call", {
            "name": tool,
            "arguments": arguments or {},
        }, timeout=timeout)

    def shutdown(self, terminate: bool = False) -> None:
        if self.proc is None:
            return
        try:
            if self.proc.poll() is None:
                self._notify("notifications/exit" if terminate else "notifications/exit", {})
                try:
                    self.proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    self.proc.terminate()
                    try:
                        self.proc.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        self.proc.kill()
        except Exception:
            pass
        self.offline = True
        self.proc = None


class MCPRegistry:
    """模块级单例：按 mcp_servers.json 管理服务器，工具列表 60s TTL 缓存。"""

    def __init__(self, path: str | None = None, ttl: float = 60.0):
        self.path = path or config.MCP_SERVERS_PATH
        self.ttl = ttl
        self._servers: dict[str, MCPServer] = {}
        self._tools_cache: list[dict] | None = None
        self._tools_fetched_at = 0.0
        self._lock = threading.Lock()

    # ------------------------------------------------------------------ #
    def _load_config(self) -> list[dict]:
        if not self.path or not os.path.exists(self.path):
            return []
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
            return data.get("servers") or []
        except (OSError, ValueError) as exc:
            logger.warning("[mcp] 读取 %s 失败: %s", self.path, exc)
            return []

    def _ensure_servers(self) -> None:
        for cfg in self._load_config():
            if not cfg.get("enabled", True):
                continue
            name = str(cfg.get("name", "")).strip()
            if not re.match(r"^[A-Za-z0-9_]+$", name) or "__" in name:
                logger.warning("[mcp] 跳过非法服务器名: %r", name)
                continue
            command = cfg.get("command")
            if not command:
                continue
            if name not in self._servers:
                self._servers[name] = MCPServer(
                    name, command, cfg.get("args") or [], cfg.get("env") or {})

    def shutdown_all(self) -> None:
        for srv in self._servers.values():
            srv.shutdown(terminate=True)

    # ------------------------------------------------------------------ #
    def get_tools_cached(self, ttl: float | None = None) -> list[dict]:
        """返回 [{server, tool}] 最新快照；失败服务器跳过，缓存内仍保留其旧工具。"""
        now = time.monotonic()
        ttl = ttl or self.ttl
        with self._lock:
            self._ensure_servers()
            if self._tools_cache is not None and now - self._tools_fetched_at < ttl:
                return self._tools_cache
            all_tools: list[dict] = []
            for srv in self._servers.values():
                try:
                    tools = srv.list_tools()
                except Exception as exc:
                    logger.warning("[mcp] %s 工具获取失败: %s", srv.name, exc)
                    tools = []
                all_tools.extend({"server": srv.name, "tool": t} for t in tools)
            self._tools_cache = all_tools
            self._tools_fetched_at = now
            return all_tools

    def call_tool(self, server: str, tool: str, arguments: dict | None = None) -> dict:
        with self._lock:
            srv = self._servers.get(server)
        if srv is None:
            raise MCPError(f"未知 MCP 服务器: {server}")
        return srv.call_tool(tool, arguments)

    def to_openai_tools(self, ttl: float | None = None) -> list[dict]:
        """把注册表工具转成 OpenAI function schema，命名 mcp__{server}__{tool}。"""
        out = []
        for item in self.get_tools_cached(ttl=ttl):
            t = item["tool"]
            desc = str(t.get("description") or f"外部 MCP 工具 {item['server']}.{t['name']}")
            desc = desc[:400]
            out.append({
                "type": "function",
                "function": {
                    "name": f"mcp__{item['server']}__{t['name']}",
                    "description": desc,
                    "parameters": _clean_schema(t.get("inputSchema") or {}),
                },
            })
        return out


# 模块级单例：ai_gateway 直接 import 使用；进程退出时回收子进程
import atexit

registry = MCPRegistry()
atexit.register(registry.shutdown_all)
