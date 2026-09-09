"""Phase 0.5 链路验证脚本：模拟 Flutter 端 Device Key Pair 全流程。

流程：
  1. 生成本地 Ed25519 密钥对（私钥=手机 secure_storage，公钥=报送服务端）
  2. POST /auth/register 注册设备公钥
  3. 对以下需签名端点依次签名调用：
       POST /ai/chat          聊天
       POST /ai/embedding     BGE-M3 向量化
       POST /ai/memory/search Memory 检索
       POST /sync/push        上传变更
       GET  /sync/pull        拉取增量
  4. 打印各端点回复

运行（先起服务：uvicorn app.main:app --reload）：
  python tools/gen_keys.py
  LIFEHUB_BASE=http://127.0.0.1:8001 python tools/gen_keys.py
"""
import base64
import hashlib
import json
import os
import time

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = "spike-device-001"


def _signed_post(priv, path: str, payload: dict) -> tuple[int, dict]:
    method = "POST"
    body = json.dumps(payload).encode()
    ts = str(int(time.time() * 1000))
    signing = f"{method}|{path}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    sig = base64.b64encode(priv.sign(signing)).decode()
    r = httpx.post(
        f"{BASE}{path}",
        content=body,
        headers={
            "Content-Type": "application/json",
            "X-Device-Id": DEVICE_ID,
            "X-Timestamp": ts,
            "X-Signature": sig,
        },
    )
    return r.status_code, r.json()


def _signed_get(priv, path: str) -> tuple[int, dict]:
    method = "GET"
    ts = str(int(time.time() * 1000))
    # GET 无 body，body 哈希 = sha256(b"")
    signing = f"{method}|{path}|{hashlib.sha256(b'').hexdigest()}|{ts}".encode()
    sig = base64.b64encode(priv.sign(signing)).decode()
    r = httpx.get(
        f"{BASE}{path}",
        headers={"X-Device-Id": DEVICE_ID, "X-Timestamp": ts, "X-Signature": sig},
    )
    return r.status_code, r.json()


def main() -> None:
    priv = Ed25519PrivateKey.generate()
    pub_b64 = base64.b64encode(priv.public_key().public_bytes_raw()).decode()

    r = httpx.post(f"{BASE}/auth/register", json={"device_id": DEVICE_ID, "pubkey": pub_b64, "name": "spike"})
    print("register       ->", r.status_code, r.json())

    code, data = _signed_post(priv, "/ai/chat", {"message": "你好"})
    print("ai/chat        ->", code, data)

    code, data = _signed_post(priv, "/ai/embedding", {"text": "我喜欢川端康成"})
    print("ai/embedding   ->", code, {"model": data.get("model"), "dim": data.get("dim")})

    code, data = _signed_post(priv, "/ai/memory/search", {"query": "川端康成", "limit": 3})
    print("ai/memory/search->", code, {"results": len(data.get("results", []))})

    code, data = _signed_post(
        priv,
        "/sync/push",
        {
            "events": [
                {"entity_type": "life_event", "entity_id": "evt-1", "operation": "create", "payload": {"mood": "ok"}},
                {"entity_type": "life_event", "entity_id": "evt-2", "operation": "create", "payload": {"note": "x"}},
            ]
        },
    )
    print("sync/push      ->", code, data)

    code, data = _signed_get(priv, "/sync/pull")
    print("sync/pull      ->", code, {"events": len(data.get("events", [])), "next_cursor": data.get("next_cursor")})


if __name__ == "__main__":
    main()
