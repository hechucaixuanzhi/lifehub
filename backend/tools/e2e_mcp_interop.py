"""WS4 E2E：纯 stdlib MCP 客户端 × 官方 FastMCP SDK 服务器互通。

运行（容器内，测试期 pip 允许）：
  pip install mcp fastmcp
  docker exec lifehub-backend python tools/e2e_mcp_interop.py

验证点：
  A. 握手 initialize → notifications/initialized → tools/list 协议互通
  B. tools/list 见到 add / get_text（inputSchema 可读）
  C. tools/call add(2,40) → 42；get_text → hello-from-fastmcp
  D. 服务器进程退出 → call 干净报 MCPError（离线标记，不挂死）
"""
import sys
import time

sys.path.insert(0, "/app")
from app.mcp_client import MCPServer, MCPError  # noqa: E402


def check(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def main() -> None:
    srv = MCPServer("fastmcp", "python", ["/app/tools/fastmcp_test_server.py"])
    try:
        print("===== A. 握手 + tools/list =====")
        srv.ensure_started()
        tools = srv.list_tools()
        names = [t["name"] for t in tools]
        check("add" in names and "get_text" in names, f"tools/list 见到 add/get_text（{names}）")
        add_tool = next(t for t in tools if t["name"] == "add")
        check(isinstance(add_tool.get("inputSchema"), dict), "add 的 inputSchema 为对象 schema")

        print("===== B. tools/call =====")
        res = srv.call_tool("add", {"a": 2, "b": 40})
        text = "".join(c.get("text", "") for c in (res.get("content") or []))
        check("42" in text, f"add(2,40)=42（{text!r}）")
        res = srv.call_tool("get_text", {})
        text = "".join(c.get("text", "") for c in (res.get("content") or []))
        check("hello-from-fastmcp" in text, f"get_text 返回固定文本（{text!r}）")

        print("===== C. 服务器退出 → 离线干净报错 =====")
        srv.proc.terminate()
        for _ in range(40):  # 等 read_loop 感知 EOF → offline
            if srv.offline:
                break
            time.sleep(0.1)
        check(srv.offline, "服务器退出后已标记 offline")
        try:
            srv.call_tool("add", {"a": 1, "b": 2})
            raise AssertionError("[FAIL] 服务器退出后应报错")
        except MCPError as exc:
            check(True, f"离线后干净报错: {exc}")

        print("\nALL PASS")
    finally:
        srv.shutdown(terminate=True)


if __name__ == "__main__":
    main()
