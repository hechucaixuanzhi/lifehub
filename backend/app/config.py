"""Spike 0.1 配置：从 .env 读取（python-dotenv）。

安全纪律（冻结，见 API.md §密钥纪律）：
- 所有 Provider Key 仅此文件经环境变量加载，绝不存在代码 / PRD / docs / git。
- 手机端永不持有任何 Provider Key（只持设备私钥）。
"""
import os

from dotenv import load_dotenv

load_dotenv()

# AI Provider Keys（仅服务端）
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
QWEN_API_KEY = os.getenv("QWEN_API_KEY", "")
GLM_API_KEY = os.getenv("GLM_API_KEY", "")
KIMI_API_KEY = os.getenv("KIMI_API_KEY", "")
MINIMAX_API_KEY = os.getenv("MINIMAX_API_KEY", "")
MIMO_API_KEY = os.getenv("MIMO_API_KEY", "")  # 小米 MiMo 平台（识图）

# 语音 TTS（AI 语音消息，S1）：MiniMax 克隆音色。国内基址 api.minimaxi.com；
# 克隆全 API（上传样本 → voice_clone → t2a_v2），无需火山那种控制台槽位购买。
MINIMAX_BASE_URL = os.getenv("MINIMAX_BASE_URL", "https://api.minimaxi.com")
MINIMAX_TTS_MODEL = os.getenv("MINIMAX_TTS_MODEL", "speech-02-hd")
# 全局开关：key 缺失 / 主动关闭时 AI 回复静默降级纯文字
MINIMAX_TTS_ENABLED = os.getenv("MINIMAX_TTS_ENABLED", "false").lower() == "true"
# 单次合成文本上限（超长截断，控制成本与延迟；微信语音上限约 60s，中文 ≈3-4 字/s）
MAX_TTS_CHARS = int(os.getenv("MAX_TTS_CHARS", "240"))
# 默认音色（克隆放缓：先用 MiniMax 内置女声；克隆音色存在时自动优先）
MINIMAX_TTS_VOICE = os.getenv("MINIMAX_TTS_VOICE", "female-shaonv")
VOLCENGINE_TTS_KEY = os.getenv("VOLCENGINE_TTS_KEY", "")
# Embedding（记忆向量化）—— 供应商无关命名，换 provider 只改这几个值，不动业务代码。
# 契约：OpenAI 兼容 /v1/embeddings（POST {input, model} → data[0].embedding）。
# 当前：Qwen text-embedding-v4（默认 1024 维，与 memory.embedding vector(1024) 一致）。
EMBEDDING_ENDPOINT = os.getenv("EMBEDDING_ENDPOINT", "")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "qwen3.7-text-embedding")
EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1024"))
EMBEDDING_API_KEY = os.getenv("EMBEDDING_API_KEY", "")

# 数据库
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./spike.db")

# 认证：仅 Spike 本地开发可跳过验签；默认 false（安全默认），dev 显式设 true
SKIP_AUTH = os.getenv("SKIP_AUTH", "false").lower() == "true"

# 媒体上传（微信富媒体 008）：文件落 UPLOAD_DIR（容器内相对路径），compose bind mount 到宿主
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "uploads")
MAX_MEDIA_SIZE = int(os.getenv("MAX_MEDIA_SIZE", str(50 * 1024 * 1024)))  # 50MB 上限

# 小米 MiMo 视觉（MIMO_API_KEY 已在上方声明）—— AI 看图描述图片内容
# 官方 OpenAI 兼容端点：https://api.xiaomimimo.com/v1；识图仅 mimo-v2.5 支持（全模态）
MIMO_VISION_URL = os.getenv(
    "MIMO_VISION_URL",
    "https://api.xiaomimimo.com/v1/chat/completions",
)
MIMO_VISION_MODEL = os.getenv("MIMO_VISION_MODEL", "mimo-v2.5")

# 小米运动健康（Mi Fitness）自动同步（v0.4-4）
# 凭据从 https://account.xiaomi.com 登录后 Cookie 中获取（userId / passToken），
# 存家庭服务器 .env，绝不进 git。region=cn 时走 https://hlth.io.mi.com（国内健康云）。
MI_FITNESS_USER_ID = os.getenv("MI_FITNESS_USER_ID", "")
MI_FITNESS_PASS_TOKEN = os.getenv("MI_FITNESS_PASS_TOKEN", "")
MI_FITNESS_REGION = os.getenv("MI_FITNESS_REGION", "cn")
MI_FITNESS_SYNC_ENABLED = os.getenv("MI_FITNESS_SYNC_ENABLED", "false").lower() == "true"
# 每日自动增量同步时刻（UTC 小时；中国时间=+8）。避开整点，1 点 UTC=9 点北京。
MI_FITNESS_SYNC_HOUR = int(os.getenv("MI_FITNESS_SYNC_HOUR", "1"))

# 记忆 AI 提炼（012）：每日自动合并近重复记忆的时刻（UTC 小时；18 点 UTC=北京 02:00，趁睡觉整理）
MEMORY_REFINE_HOUR = int(os.getenv("MEMORY_REFINE_HOUR", "18"))

# MCP 客户端（WS4）：外部 MCP 服务器清单路径（容器内）+ 工具列表缓存 TTL
MCP_SERVERS_PATH = os.getenv("MCP_SERVERS_PATH", "/app/mcp_servers.json")
MCP_TTL_SECONDS = int(os.getenv("MCP_TTL_SECONDS", "60"))

# AI 角色 Lorebook：单轮按需注入的内容上限（字符，非 token）。核心人格不受此预算裁剪；
# 仅限制 character_lore_entry，防后续细节无限挤占聊天历史。
CHARACTER_LORE_MAX_CHARS = int(os.getenv("CHARACTER_LORE_MAX_CHARS", "6000"))

# 角色公开正史：稳定人生摘要常驻角色卡，具体事件仅在相关话题被召回。
# 单独设预算，避免“问一个品牌”时挤掉近期聊天、共同记忆和当前关系。
CHARACTER_PUBLIC_HISTORY_MAX_CHARS = int(
    os.getenv("CHARACTER_PUBLIC_HISTORY_MAX_CHARS", "7000")
)

# 微信式聊天上下文：保留更多最近消息，但给历史单独设字符预算，避免长会话无限挤占
# 角色核心。当前消息不计入 history，由网关只注入一次。
AI_CHAT_HISTORY_MAX_MESSAGES = int(os.getenv("AI_CHAT_HISTORY_MAX_MESSAGES", "40"))
AI_CHAT_HISTORY_MAX_CHARS = int(os.getenv("AI_CHAT_HISTORY_MAX_CHARS", "16000"))

# 初版 AI 表情包回发默认停用。用户仍可发送表情；这里只控制角色是否用
# ``[表情:<id>]`` 敷衍回复。
AI_STICKER_REPLIES_ENABLED = os.getenv(
    "AI_STICKER_REPLIES_ENABLED", "false"
).lower() == "true"

# Dormant life/study/exercise modules: preserve code and existing data.
LIFE_TRACKING_ENABLED = os.getenv("LIFE_TRACKING_ENABLED", "false").lower() == "true"
