"""统一错误契约（对齐 API.md §3.2）。

- AI 网关错误 → AIGatewayError → 503 {"error":{"code":"AI_UNAVAILABLE",...}}
- 所有响应错误体统一 `{error:{code,message,retryable}}`
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AIGatewayError(Exception):
    """AI 网关调用失败（未配 Key / provider 异常 / 超时）。

    由 main.py 的 exception_handler 转成 503 AI_UNAVAILABLE。
    """

    def __init__(self, message: str, retryable: bool = True):
        super().__init__(message)
        self.message = message
        self.retryable = retryable


def register_error_handlers(app: FastAPI) -> None:
    """注册统一错误处理器。"""

    @app.exception_handler(AIGatewayError)
    async def _ai_unavailable(_: Request, exc: AIGatewayError):
        return JSONResponse(
            status_code=503,
            content={
                "error": {
                    "code": "AI_UNAVAILABLE",
                    "message": exc.message,
                    "retryable": exc.retryable,
                }
            },
        )
