"""011 任务3 E2E：AI 读库补全 —— 问当前态，断言 LLM 走新工具且回答含快照名字。

运行：python tools/e2e_ai_readlib.py （需已注册设备；无签名要求由脚本处理）
验证点：/ai/chat 对「我现在有哪些学习资源/宠物/习惯完成得怎么样」的答复应包含
快照种子里的真实名字（跑步/喝水/睡眠/英语/日语/小七 等），证明 query_* 工具
被触发且名字经 list_snapshots 解析成功。
"""
import base64
import hashlib
import json
import os
import sys
import time

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = f"e2e-readlib-{int(time.time())}"
CHARACTER_ID = "assistant"

# 快照种子里的真实名字（任一命中即证明名字解析成功）
KNOWN_NAMES = ["跑步", "喝水", "睡眠", "英语", "日语", "阅读", "小七", "晒太阳"]

_priv = Ed25519PrivateKey.generate()


def _sig(method: str, path: str, body: bytes) -> dict:
    ts = str(int(time.time() * 1000))
    msg = f"{method}|{path}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    return {
        "X-Device-Id": DEVICE_ID,
        "X-Timestamp": ts,
        "X-Signature": base64.b64encode(_priv.sign(msg)).decode(),
        "Content-Type": "application/json",
    }


def call(method: str, path: str, body: bytes = b"", timeout: float = 15) -> httpx.Response:
    return httpx.request(method, f"{BASE}{path}", content=body, headers=_sig(method, path, body),
                         timeout=timeout)


def main() -> None:
    body = json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e readlib",
    }).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"

    q = "我现在有哪些学习资源、宠物？习惯完成得怎么样？"
    body = json.dumps({
        "message": q,
        "character_id": CHARACTER_ID,
        "conversation_id": f"e2e-readlib-{int(time.time())}",
    }).encode()
    r = call("POST", "/ai/chat", body, timeout=120)
    assert r.status_code == 200, f"chat {r.status_code}: {r.text[:300]}"
    data = r.json()
    reply = str(data.get("reply") or data.get("message") or data.get("content") or data)
    print("\n=== LLM 答复 ===\n", reply[:800])
    hits = [n for n in KNOWN_NAMES if n in reply]
    print("\n命中名字:", hits or "（无）")
    assert hits, f"答复未包含任何快照名字（工具可能未触发或名字未解析）：{reply[:300]}"
    print("[ok] AI 读库：工具触发且名字解析成功")


if __name__ == "__main__":
    main()
