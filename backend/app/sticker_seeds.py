"""表情包目录（009_stickers）—— 内置打包表情 = 数据。

打包进 APK 的静态表情（assets/stickers/<id>.png），后端只存目录：id=slug=素材文件名，
description 即"见过"的存档描述（预置中文）→ 内置表情永不调 MiMo。
AI 回发标记 [表情:<id>] 解析、历史标签、GET /ai/stickers 下发目录全走本表。

加新表情 = 在此加一行 seed + APK 加同名 PNG + 重启后端（seed_stickers() 幂等 upsert），
前端经 GET /ai/stickers 自动出现，无需改前端代码。
"""
from sqlalchemy.orm import Session

from . import db
from .models import Sticker

# --------------------------------------------------------------------------- #
# 内置表情包（20 个）：description 是给 AI 的中文语义，前端渲染靠 id→本地素材
# --------------------------------------------------------------------------- #
DEFAULT_STICKERS = [
    {"id": "happy",     "name": "开心",   "description": "咧嘴大笑，超开心"},
    {"id": "cry",       "name": "大哭",   "description": "嚎啕大哭，委屈爆发"},
    {"id": "aggrieved", "name": "委屈",   "description": "扁嘴委屈，快哭了"},
    {"id": "angry",     "name": "生气",   "description": "气鼓鼓，别惹我"},
    {"id": "kiss",      "name": "亲亲",   "description": "飞吻亲亲，爱你"},
    {"id": "laugh",     "name": "大笑",   "description": "笑得前仰后合"},
    {"id": "awkward",   "name": "尴尬",   "description": "尴尬挠头，好难为情"},
    {"id": "gnight",    "name": "晚安",   "description": "盖好被子，晚安好梦"},
    {"id": "love",      "name": "爱你",   "description": "比心表白，爱你哟"},
    {"id": "gogogo",    "name": "加油",   "description": "握拳打气，加油冲"},
    {"id": "proud",     "name": "得意",   "description": "叉腰得意，我可太棒了"},
    {"id": "shocked",   "name": "震惊",   "description": "瞪大眼睛，吓一跳"},
    {"id": "confused",  "name": "疑惑",   "description": "歪头问号，一脸懵"},
    {"id": "shy",       "name": "害羞",   "description": "捂脸害羞，脸红了"},
    {"id": "lazy",      "name": "摆烂",   "description": "瘫倒摆烂，不想动"},
    {"id": "yeah",      "name": "耶",     "description": "举双手耶，太好了"},
    {"id": "hungry",    "name": "饿",     "description": "饿到贴肚皮，想吃东西"},
    {"id": "oops",      "name": "坏了",   "description": "捂嘴糟了，闯祸了"},
    {"id": "bye",       "name": "拜拜",   "description": "挥手告别，下次见"},
    {"id": "ok",        "name": "好的",   "description": "比 OK 手势，收到明白"},
]


def seed_stickers() -> None:
    """幂等 upsert：缺行插入、已有行刷新（改描述后重启即生效）。"""
    with db.SessionLocal() as s:
        _seed(s)
        s.commit()


def _seed(s: Session) -> None:
    for c in DEFAULT_STICKERS:
        row = s.get(Sticker, c["id"])
        if row is None:
            s.add(Sticker(**c))
        else:
            for k, v in c.items():
                setattr(row, k, v)
