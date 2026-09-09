"""Device Key Pair 验签（类 SSH，冻结，见 API.md §1）。

- 手机本地生成 Ed25519 密钥对，私钥存 secure_storage，公钥经 /auth/register 报送。
- 每次请求用私钥对 `method|path|sha256(body)|timestamp` 签名，放 X-Signature 头。
- 服务端用注册公钥验签；时间戳 ±5min 防重放。
"""
import base64
import hashlib

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

from . import db

_REPLAY_WINDOW_MS = 5 * 60 * 1000


def get_device(device_id: str) -> db.Device | None:
    with db.SessionLocal() as s:
        return s.get(db.Device, device_id)


def register_device(device_id: str, pubkey_b64: str, name: str | None = None) -> str:
    with db.SessionLocal() as s:
        s.merge(db.Device(device_id=device_id, pubkey=pubkey_b64, name=name))
        s.commit()
    return device_id


def _signing_message(method: str, path: str, body: bytes, timestamp: str) -> bytes:
    body_hash = hashlib.sha256(body).hexdigest()
    return f"{method}|{path}|{body_hash}|{timestamp}".encode()


def verify_signature(
    device_id: str,
    timestamp: str,
    signature_b64: str,
    method: str,
    path: str,
    body: bytes,
) -> bool:
    with db.SessionLocal() as s:
        dev = s.get(db.Device, device_id)
    if dev is None:
        return False
    try:
        pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(dev.pubkey))
        pub.verify(base64.b64decode(signature_b64), _signing_message(method, path, body, timestamp))
        return True
    except (InvalidSignature, ValueError, Exception):
        return False


def is_timestamp_fresh(timestamp_ms: str) -> bool:
    try:
        ts = int(timestamp_ms)
    except (TypeError, ValueError):
        return False
    import time

    return abs(int(time.time() * 1000) - ts) <= _REPLAY_WINDOW_MS
