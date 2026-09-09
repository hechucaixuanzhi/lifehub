"""Shared FastAPI request authentication dependencies.

Keeping signature verification outside ``main`` lets feature routers depend on
the same gate without importing the application object or creating cycles.
"""

from fastapi import HTTPException, Request

from . import auth, config, rate_limit


def unauthorized(code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={"error": {"code": code, "message": message, "retryable": False}},
    )


async def require_signature(request: Request) -> None:
    """Verify the device signature unless local spike mode disables auth."""
    if config.SKIP_AUTH:
        return
    device_id = request.headers.get("X-Device-Id")
    timestamp = request.headers.get("X-Timestamp")
    signature = request.headers.get("X-Signature")
    if not (device_id and timestamp and signature):
        raise unauthorized("SIGNATURE_INVALID", "缺少签名头")
    if not auth.is_timestamp_fresh(timestamp):
        raise unauthorized("TIMESTAMP_EXPIRED", "时间戳超窗（重放防护）")
    if not rate_limit.check_rate_limit(f"{device_id}:{request.url.path}"):
        raise HTTPException(
            status_code=429,
            detail={
                "error": {
                    "code": "RATE_LIMITED",
                    "message": "请求过于频繁",
                    "retryable": True,
                }
            },
        )
    body = await request.body()
    if not auth.verify_signature(
        device_id,
        timestamp,
        signature,
        request.method,
        request.url.path,
        body,
    ):
        raise unauthorized("SIGNATURE_INVALID", "验签失败")
