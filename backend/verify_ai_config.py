"""Development-only configuration check for the provider routing branch."""
import os
import sys

# 在 import config 之前注入 dummy key，证明"配置存在→走真实调用分支"
os.environ["DEEPSEEK_API_KEY"] = "test-key"
os.environ.setdefault("SKIP_AUTH", "true")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import ai_gateway  # noqa: E402

print("is_configured() =", ai_gateway.is_configured())
assert ai_gateway.is_configured() is True, "dummy key 应判定为已配置"

reply = ai_gateway.chat("ping")
print("chat() 返回前 50 字:", repr(reply[:50]))
is_dev_placeholder = reply.startswith("[开发模式")
print("仍是开发占位文本?", is_dev_placeholder)
assert not is_dev_placeholder, "存在 key 时不应再返回开发占位，应进入真实调用分支"
print("OK: 配置存在时 chat() 已切到真实 DeepSeek 调用分支（dummy key 被拒属预期）")
