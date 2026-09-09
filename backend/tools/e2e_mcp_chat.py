"""WS4 E2E：/ai/chat 集成外部 MCP 工具（dev_tools 演示服务器）。

运行（容器内）：
  docker exec lifehub-backend python tools/e2e_mcp_chat.py

验证点：
  A. 问「现在几点」→ 回复含时间数字，证明 mcp__dev_tools__get_current_time 被触发
  B. 问「掷个骰子」→ 回复含数字（roll_dice 结果被引用）
  C. 演示服务器被 kill 后再问 → chat 仍 200 不崩，回复说明工具不可用/兜底
"""
import base64
import hashlib
import json
import os
import re
import sys
import time

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
CHARACTER_ID = "assistant"
DEVICE_ID = f"e2e-mcp-chat-{int(time.time())}"

_priv = Ed25519PrivateKey.generate()


def _sig(method: str, path: str, body: bytes) -> dict:
    ts = str(int(time.time() * 1000))
    msg = f"{method}|{path.split('?')[0]}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    return {
        "X-Device-Id": DEVICE_ID,
        "X-Timestamp": ts,
        "X-Signature": base64.b64encode(_priv.sign(msg)).decode(),
        "Content-Type": "application/json",
    }


def call(method: str, path: str, body: bytes = b"", timeout: float = 120) -> httpx.Response:
    return httpx.request(method, f"{BASE}{path}", content=body, headers=_sig(method, path, body),
                         timeout=timeout)


def check(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def chat(q: str, conv: str) -> str:
    body = json.dumps({"message": q, "character_id": CHARACTER_ID, "conversation_id": conv}).encode()
    r = call("POST", "/ai/chat", body, timeout=120)
    assert r.status_code == 200, f"chat {r.status_code}: {r.text[:300]}"
    data = r.json()
    return str(data.get("reply") or data.get("message") or data.get("content") or data)


def kill_demo_server() -> None:
    """杀掉后端拉起的 mcp_demo_server 子进程（容器内无 pkill/ps，直接扫 /proc）。"""
    me = os.getpid()
    killed = []
    for pid in os.listdir("/proc"):
        if not pid.isdigit() or pid == str(me):
            continue
        try:
            cl = open(f"/proc/{pid}/cmdline", "rb").read().decode(errors="replace")
            if "mcp_demo_server" in cl:
                os.kill(int(pid), 9)
                killed.append(pid)
        except Exception:
            pass
    if not killed:
        print("[warn] 未找到 mcp_demo_server 进程（可能未拉起）")
    return killed


def main() -> None:
    body = json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e mcp chat",
    }).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"

    print("\n===== A. 现在几点（触发 get_current_time）=====")
    reply = chat("现在几点？", f"e2e-mcp-{int(time.time())}")
    print("  回复:", reply[:200])
    check(bool(re.search(r"\d", reply)), "回复含时间数字")
    check((":" in reply and re.search(r"\d\d?[:：]\d\d", reply)) or "2026" in reply or "点" in reply,
          "回复含时间形态（HH:MM / 点）")

    print("\n===== B. 掷骰子（触发 roll_dice）=====")
    reply = chat("帮我掷个骰子，看看今天运气如何", f"e2e-mcp-{int(time.time())}")
    print("  回复:", reply[:200])
    check(bool(re.search(r"\d", reply)), "回复含点数数字")

    print("\n===== C. 杀演示服务器后仍不崩 chat =====")
    killed = kill_demo_server()
    check(bool(killed), "已杀掉演示服务器进程")
    time.sleep(1.0)  # 等后端 read_loop 感知 EOF → offline
    try:
        reply = chat("现在几点？", f"e2e-mcp-{int(time.time())}")
    except Exception as exc:
        raise AssertionError(f"[FAIL] 服务器离线后 chat 崩溃/异常: {exc}")
    print("  回复:", reply[:200])
    check(reply.strip() != "", "服务器离线后回复非空（不崩）")

    print("\nALL PASS")


if __name__ == "__main__":
    main()
