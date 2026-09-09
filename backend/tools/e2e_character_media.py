"""010 需求5 E2E：character 换头像/背景图（PATCH /ai/characters/{id}）。

链路（带签名，模拟 Flutter）：
  POST /media → media_id(pending)
  PUT  /media/{id}/content ← 1x1 PNG 字节 → ready
  PATCH /ai/characters/companion {avatar_media_id, background_media_id} → 200
  GET  /ai/characters → 回读两字段
  PATCH 恢复默认（null）→ 回读 NULL
  PATCH 伪造 media_id → 422
  PATCH 未签名 → 401
  PATCH 伪造 character_id → 404

运行：python tools/e2e_character_media.py
"""
import base64
import hashlib
import json
import os
import time

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = "e2e-char-media-001"

# 1x1 红色 PNG
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

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


def call(method: str, path: str, body: bytes = b"", signed: bool = True) -> httpx.Response:
    headers = _sig(method, path, body) if signed else {"Content-Type": "application/json"}
    return httpx.request(method, f"{BASE}{path}", content=body, headers=headers)


def main() -> None:
    # 0. 注册设备公钥
    body = json.dumps({"device_id": DEVICE_ID, "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(), "name": "e2e"}).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"
    print("[ok] register")

    # 1. POST /media
    mb = json.dumps({"file_name": "avatar.png", "size": len(PNG), "mime_type": "image/png", "owner_type": "chat"}).encode()
    r = call("POST", "/media", mb)
    assert r.status_code == 200, f"create media {r.status_code}: {r.text}"
    media_id = r.json()["media_id"]
    print(f"[ok] media created: {media_id}")

    # 2. PUT content
    r = call("PUT", f"/media/{media_id}/content", PNG)
    assert r.status_code == 200, f"put content {r.status_code}: {r.text}"
    assert r.json()["media_id"] == media_id
    print("[ok] media ready")

    # 3. PATCH 设头像+背景
    pbody = json.dumps({"avatar_media_id": media_id, "background_media_id": media_id}).encode()
    r = call("PATCH", "/ai/characters/companion", pbody)
    assert r.status_code == 200, f"patch set {r.status_code}: {r.text}"
    c = r.json()["character"]
    assert c["id"] == "companion" and c["avatar_media_id"] == media_id and c["background_media_id"] == media_id
    print("[ok] patch set avatar+background")

    # 4. GET 回读
    r = call("GET", "/ai/characters", b"")
    assert r.status_code == 200, f"get {r.status_code}"
    cm = {x["id"]: x for x in r.json()["characters"]}
    assert cm["companion"]["avatar_media_id"] == media_id
    assert cm["assistant"]["avatar_media_id"] is None
    print("[ok] get returns new fields (companion set, assistant untouched)")

    # 5. 恢复默认（null）
    pbody = json.dumps({"avatar_media_id": None, "background_media_id": None}).encode()
    r = call("PATCH", "/ai/characters/companion", pbody)
    assert r.status_code == 200 and r.json()["character"]["avatar_media_id"] is None
    print("[ok] reset to default (null)")

    # 6. 伪造 media_id → 422
    pbody = json.dumps({"avatar_media_id": "deadbeef"}).encode()
    r = call("PATCH", "/ai/characters/companion", pbody)
    assert r.status_code == 422, f"bad media {r.status_code}: {r.text}"
    assert r.json()["error"]["code"] == "MEDIA_NOT_READY"
    print("[ok] fake media_id → 422 MEDIA_NOT_READY")

    # 7. 未签名 → 401
    r = call("PATCH", "/ai/characters/companion", pbody, signed=False)
    assert r.status_code == 401, f"unsigned {r.status_code}: {r.text}"
    print("[ok] unsigned → 401")

    # 8. 伪造 character → 404
    pbody = json.dumps({"avatar_media_id": media_id}).encode()
    r = call("PATCH", "/ai/characters/nope", pbody)
    assert r.status_code == 404, f"bad char {r.status_code}: {r.text}"
    assert r.json()["error"]["code"] == "CHARACTER_NOT_FOUND"
    print("[ok] fake character_id → 404")

    print("\nALL PASS")


if __name__ == "__main__":
    main()
