"""AI Gateway 实现（Phase 0.5 / v0.5 角色分层 / 读库问答）。

职责（冻结，见 PRD §5.2 / ARCHITECTURE §5）：模型路由 + 服务端 prompt + Memory Service。
所有 Provider Key 经 config 注入，手机不直连厂商（严格只走网关）。

本阶段端点：
- chat()           /ai/chat —— 人格层：按 character_id 查 character 表取 prompt（DB 为准）
  + function calling：只读工具（步数/运动记录/近期动态/记忆），AI 真查库再回答
- embed()          /ai/embedding  （Qwen qwen3.7-text-embedding，无端点时返回确定性 dev 向量）
- memory_search()  /ai/memory/search（每角色独立；dev 走最近记忆；prod 走 pgvector 余弦）
- memory_add/update/delete —— 记忆层 CRUD（手机可增删改）

维度 1024 冻结（memory.embedding vector(1024)，见 PRD §5.2.3 / DATABASE §5）；供应商由
config.EMBEDDING_* 决定（当前 Qwen text-embedding-v4，默认 1024 维）。
"""
import hashlib
import json
import logging
import re
import httpx
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import text

from . import character_context, config, db, mcp_client, prompts, snapshot, state_engine
from .errors import AIGatewayError
from .reply_policy import (
    _has_semantic_text,
    build_reply_regeneration_request,
    enforce_roleplay_format,
    normalize_generated_reply,
    parse_transfer_decision,
    reply_needs_regeneration,
    reply_output_metrics,
    roleplay_reply_needs_format,
    spoken_text_for_tts,
    split_reply_segments,
    strip_internal_reply_markers,
)
from .models import (
    AppSetting,
    Character,
    CharacterUserKnowledge,
    Memory,
    MiActivityDaily,
    MiWorkout,
    Moment,
    Sticker,
    SyncEvent,
    Worldview,
    uuid7,
)

# 供应商无关：模型/维度来自 config.EMBEDDING_*（当前 text-embedding-v4 / 1024）。
EMBED_MODEL = config.EMBEDDING_MODEL
EMBED_DIM = config.EMBEDDING_DIM

# 全局回复规范（R2）：用户设定的跨角色硬性回复要求，存 AppSetting，跨设备同步。
REPLY_GUIDELINE_KEY = "reply_guideline"

logger = logging.getLogger("lifehub")


def get_reply_guideline() -> str:
    """读全局回复规范（AppSetting key='reply_guideline'），未设置返回空串。

    置于 chat() messages 最前（优先级最高），单聊/群聊所有角色共同遵守。
    """
    with db.SessionLocal() as s:
        row = s.query(AppSetting).filter_by(key=REPLY_GUIDELINE_KEY).first()
    return (row.value if row else "") or ""

# 兼容旧引用：默认 assistant（小迹）
SYSTEM_PROMPT = prompts.ASSISTANT_SYSTEM_PROMPT

# function calling 工具循环上限（防失控调用/超时）
MAX_TOOL_ROUNDS = 3


# --------------------------------------------------------------------------- #
# 人格层：角色 = 数据（character 表为准，prompts.py 仅兜底）
# --------------------------------------------------------------------------- #
def get_character(character_id: str | None) -> Character | None:
    """按 slug 取角色；未命中返回 None（调用方兜底 assistant）。"""
    if not character_id:
        return None
    with db.SessionLocal() as s:
        return s.get(Character, character_id)


def get_worldview(character_id: str) -> dict | None:
    """取角色当前启用世界观书（016_worldview）；无则 None（组装时跳过世界观段）。"""
    if not character_id:
        return None
    with db.SessionLocal() as s:
        wv = (
            s.query(Worldview)
            .filter(Worldview.character_id == character_id, Worldview.enabled.is_(True))
            .order_by(Worldview.sort)
            .first()
        )
        if wv is None:
            return None
        return {
            "name": wv.name,
            "identity": wv.identity,
            "backstory": wv.backstory,
            "rules": wv.rules,
            "preferences": wv.preferences,
        }


def _character_can_read_user_profile(character_id: str | None) -> bool:
    """只有用户明确授权的人物才能读用户主资料、朋友圈与 LifeHub 工具。"""
    if not character_id or character_id == "assistant":
        return True
    with db.SessionLocal() as s:
        row = s.get(CharacterUserKnowledge, character_id)
        return bool(row and row.inherit_profile)


def _recent_user_moments_prompt(limit: int = 5) -> str | None:
    """让角色能看到用户最近朋友圈；公开动态不混进永久记忆。"""
    with db.SessionLocal() as s:
        rows = (
            s.query(Moment)
            .filter(Moment.author_type == "user")
            .order_by(Moment.published_at.desc(), Moment.created_at.desc())
            .limit(limit)
            .all()
        )
        if not rows:
            return None
        lines = []
        for row in rows:
            occurred = row.published_at or row.created_at
            when = occurred.astimezone(timezone(timedelta(hours=8))).strftime(
                "%Y-%m-%d %H:%M"
            )
            content = (row.content or "（图片动态）").strip()[:500]
            lines.append(f"- {when}：{content}")
        return (
            "【用户最近的朋友圈】\n"
            + "\n".join(lines)
            + "\n这些是你在朋友圈里能够看到的用户公开动态，可在相关时自然提起；"
            "不要声称看到了这里没有的内容。"
        )


def _recent_character_moments_prompt(
    character_id: str, limit: int = 5
) -> str | None:
    """角色公开账号动态属于其自我经历：明确以第一人称认作自己发布。"""
    with db.SessionLocal() as s:
        rows = (
            s.query(Moment)
            .filter(
                Moment.author_type == "character",
                Moment.character_id == character_id,
            )
            .order_by(Moment.published_at.desc(), Moment.created_at.desc())
            .limit(limit)
            .all()
        )
        if not rows:
            return None
        lines = []
        for row in rows:
            occurred = row.published_at or row.created_at
            local_time = occurred.astimezone(timezone(timedelta(hours=8)))
            when = (
                local_time.strftime("%Y-%m-%d")
                if row.published_precision == "date"
                else local_time.strftime("%Y-%m-%d %H:%M")
            )
            content = (row.content or "（图片动态）").strip()[:500]
            location = row.location or "未标注地点"
            platform = row.source_platform or "公开账号"
            details = (row.ai_context or "").strip()[:1600]
            lines.append(
                f"- 发布时间：{when}；地点：{location}；平台：{platform}；"
                f"配文：{content}；内容资料：{details or '暂无图片内容说明'}；"
                f"原帖：{row.source_url or '未记录'}"
            )
        return (
            "【你自己的朋友圈/公开账号动态数据库——本轮必须采用】\n"
            + "\n".join(lines)
            + "\n以上动态就是你本人发布过的朋友圈内容，也是你自己的经历。"
            "当用户询问你的朋友圈、照片、发布时间、地点或配文时，必须直接根据这里回答；"
            "禁止回答‘我不知道自己的朋友圈’、‘我看不到’或把它说成别人的动态。"
            "资料明确写着未公开的时分或地点就如实说未公开，不得编造；"
            "也不得冒认列表之外的网络内容。"
        )


def character_to_dict(c: Character) -> dict:
    """角色 → API 字典（不向手机透出任何 prompt）。"""
    return {
        "id": c.id,
        "name": c.name,
        "tagline": c.tagline,
        "avatar_text": c.avatar_text,
        "avatar_color": c.avatar_color,
        # 010：自定义头像/背景（media_asset.id，None=默认 glyph/灰底）
        "avatar_media_id": c.avatar_media_id,
        "background_media_id": c.background_media_id,
        "welcome_message": c.welcome_message,
        "memory_enabled": c.memory_enabled,
        "has_noban": c.noban_prompt is not None,
        "sort": c.sort,
    }


def list_characters() -> list[dict]:
    """全部角色（供 GET /ai/characters；不向手机透出任何 prompt）。"""
    with db.SessionLocal() as s:
        rows = s.query(Character).order_by(Character.sort).all()
    return [character_to_dict(c) for c in rows]


# --------------------------------------------------------------------------- #
# 表情包目录（009_stickers）—— 内置打包表情 = 数据，AI 回发标记解析
# --------------------------------------------------------------------------- #
def list_stickers() -> list[dict]:
    """全部内置表情（供 GET /ai/stickers；前端 id→本地素材渲染）。"""
    with db.SessionLocal() as s:
        rows = s.query(Sticker).order_by(Sticker.sort).all()
    return [
        {"id": st.id, "name": st.name, "description": st.description, "sort": st.sort}
        for st in rows
    ]


def sticker_descriptions(sticker_ids: list[str]) -> dict[str, str]:
    """批量查表情描述（历史组装用，防 N+1）：{id: description}。"""
    if not sticker_ids:
        return {}
    with db.SessionLocal() as s:
        rows = s.query(Sticker).filter(Sticker.id.in_(sticker_ids)).all()
    return {st.id: st.description for st in rows}


def build_sticker_guidance() -> str | None:
    """实时查表情目录拼系统提示片段；无种子返回 None（跳过注入）。

    让 DeepSeek（纯文本）知道有哪些表情可用 + 标记格式，AI 可偶尔回发表情包。
    """
    stickers = list_stickers()
    if not stickers:
        return None
    listing = "、".join(f"{st['id']}({st['name']}，{st['description']})" for st in stickers)
    return (
        "你可以偶尔在回复末尾附带一个表情包来加强语气，格式为 [表情:<id>]，"
        f"必须放在回复最后，最多一个；拿不准就不发。可选表情包：{listing}。"
    )


# AI 回复里的表情标记：[表情:happy] / [表情包:开心] / [表情：kiss]
STICKER_MARKER_RE = re.compile(r"\[表情(?:包)?[:：]?\s*([^\]\s:：]+)\]")


def _match_sticker_id(token: str) -> str | None:
    """token → sticker id：先精确匹配 id，再匹配中文名（相等/包含，双向容错）。"""
    token = (token or "").strip()
    if not token:
        return None
    with db.SessionLocal() as s:
        rows = s.query(Sticker).all()
    # 精确 id
    for st in rows:
        if st.id == token:
            return st.id
    # 中文名（相等或包含，双向）
    for st in rows:
        if st.name == token or token in st.name or st.name in token:
            return st.id
    return None


def resolve_sticker_reply(reply: str) -> tuple[str, str | None]:
    """剥掉回复末尾的表情标记，返回 (干净回复, sticker_id|None)。

    未匹配到表情 → 标记也被剥掉（不泄漏到 UI），只返回纯文本回复。
    """
    if not reply:
        return reply, None
    m = STICKER_MARKER_RE.search(reply)
    if not m:
        return reply, None
    sticker_id = _match_sticker_id(m.group(1).strip())
    clean = STICKER_MARKER_RE.sub("", reply).strip()
    return clean, sticker_id


def is_configured() -> bool:
    """AI 服务是否已配置真实 Provider Key。

    仅返回布尔，绝不在任何响应中泄露 key 值（密钥纪律见 config.py）。
    当前唯一 Provider = DeepSeek；Qwen/GLM 等多 Provider 路由不在 v0.2.2 范围。
    """
    return bool(config.DEEPSEEK_API_KEY)


def vision_describe(image_b64: str, mime: str = "image/jpeg") -> str | None:
    """小米 MiMo 视觉（mimo-v2.5 全模态）：把图片 base64 转成一句中文描述，供 AI 看图后自然回应。

    强降级：未配置 MIMO_API_KEY / 调用失败 / 非 2xx → 返回 None，
    调用方退化为「[用户发来一张图片]」的泛回应，功能不挂。
    官方文档：图片入参用 base64 data URI（≤50MB），且图片须放在文本之前。
    """
    if not config.MIMO_API_KEY or not image_b64:
        return None
    try:
        resp = httpx.post(
            config.MIMO_VISION_URL,
            headers={
                "Authorization": f"Bearer {config.MIMO_API_KEY}",
                "api-key": config.MIMO_API_KEY,
                "Content-Type": "application/json",
            },
            json={
                "model": config.MIMO_VISION_MODEL,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{image_b64}"}},
                            {"type": "text", "text": "请用一句简短的中文描述这张图片里的内容（30 字以内，像朋友聊天那样自然）。"},
                        ],
                    }
                ],
                "stream": False,
            },
            timeout=30,
        )
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"].get("content") or ""
        return content.strip() or None
    except Exception:
        return None


# --------------------------------------------------------------------------- #
# 读库问答：只读工具（function calling）
# 数据源：mi_activity_daily / mi_workout（小米同步，真实当前态表）；
#         sync_event（设备同步日志，只读最近 create 事件，不做状态重放）。
# 全部只读、无副作用；AI 经 tools 查询后再回答，避免编造。
# --------------------------------------------------------------------------- #
AI_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query_steps",
            "description": (
                "查询用户某天或某段时间的步数/距离/活动卡路里（小米运动同步）。"
                "回答'今天走了多少步''最近运动情况'时用。日期格式 YYYY-MM-DD。"
                "省略参数默认返回最近 7 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD，可选"},
                    "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD，可选"},
                    "days": {"type": "integer", "description": "最近 N 天（未给 end_date 时用，默认 7）"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_workouts",
            "description": (
                "查询用户的运动记录（跑步/骑行等，来自小米运动同步）。"
                "返回活动类型、时间、时长、距离、卡路里。回答'最近跑了什么'时用。"
                "省略参数默认返回最近 5 条。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "返回条数，默认 5"},
                    "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD，可选"},
                    "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD，可选"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_recent_activity",
            "description": (
                "查询用户最近的生活/学习/运动/宠物动态（来自设备同步日志）。"
                "回答'我最近干了什么''最近学了什么'时用。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "返回条数，默认 8"},
                    "entity_type": {
                        "type": "string",
                        "enum": ["study_session", "exercise_session", "pet_log", "life_habit_event", "life_event"],
                        "description": "只查某类动态，可选",
                    },
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_memories",
            "description": (
                "在用户对该角色的长期记忆里搜索某个话题。"
                "用于想起用户过去的偏好/习惯（比对话里注入的记忆更精确/更久远）。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "搜索关键词/话题"},
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_life_habits",
            "description": (
                "查询用户的习惯清单与最近完成情况（喝水/睡眠/冥想等，来自手机本地生活记录）。"
                "回答'今天习惯完成得怎么样''最近水喝了几杯''睡眠如何'时用。"
                "返回按日期（北京时间自然日）分桶的完成次数/分钟数与是否达标。默认只查今天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "查最近 N 天（含今天），默认 1，最大 60"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_study_progress",
            "description": (
                "查询用户的学习资源清单与最近学习进度（学习时长/完成量，来自手机本地记录）。"
                "回答'我的学习计划''最近学了什么''学到多少了'时用。默认查最近 30 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "查最近 N 天，默认 30，最大 90"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_exercise_history",
            "description": (
                "查询用户的运动类型清单与最近运动记录（次数/时长/距离，来自手机本地记录）。"
                "回答'最近运动了没''做了多少俯卧撑''跑步情况'时用。默认查最近 30 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "查最近 N 天，默认 30，最大 90"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_pets",
            "description": (
                "查询用户的宠物档案与最近记录（体重/健康/文字/照片备注，来自手机本地记录）。"
                "回答'我的猫''宠物最近怎么样'时用。默认查最近 14 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "查最近 N 天，默认 14，最大 60"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "query_inbox",
            "description": (
                "查询用户随手记的收件箱条目（笔记/链接/提醒）。"
                "回答'我的收件箱里有什么''记过什么笔记'时用。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "返回条数，默认 20，最大 50"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_daily_summary",
            "description": (
                "生成某天的跨模块日报：习惯完成 / 学习 / 运动 / 宠物 / 收件箱 / 步数。"
                "回答'今天过得怎么样''今天总结一下''昨天做了什么'时用。"
                "省略日期默认今天（北京时间）。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "date": {"type": "string", "description": "YYYY-MM-DD，可选"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_weekly_summary",
            "description": (
                "按天汇总最近一段时间的跨模块情况：习惯达标数 / 学习分钟 / 运动次数 / "
                "宠物记录 / 收件箱 / 步数，并给合计。回答'这周过得怎么样''最近一周总结'时用。"
                "默认最近 7 天（含今天），最大 30 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "最近 N 天（含今天），默认 7，最大 30"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_habit_streaks",
            "description": (
                "统计每个习惯的连续达标天数（连胜）：当前连胜（今天达标则从今天倒推，"
                "否则从昨天起）+ 窗口内最长连胜 + 最近达标日期。回答'我连续坚持几天了''"
                "打卡断了没'时用。默认窗口 30 天，最大 90 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "统计窗口 N 天，默认 30，最大 90"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_study_trend",
            "description": (
                "按天查看学习趋势：每天的学习总分钟数与次数，以及各学习资源在窗口内的合计。"
                "回答'最近学习趋势怎么样''学了多久''哪门课学得多'时用。默认 30 天，最大 90 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "最近 N 天，默认 30，最大 90"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_exercise_trend",
            "description": (
                "按天查看运动趋势：每天的次数 / 总时长 / 总距离，以及各运动类型在窗口内的合计。"
                "回答'最近运动趋势怎么样''运动频率''哪个练得多'时用。默认 30 天，最大 90 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "最近 N 天，默认 30，最大 90"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_pet_insights",
            "description": (
                "查看每只宠物的健康洞察：体重趋势点（日期+kg）、最近一条记录时间、"
                "距今天数（stale_days）与是否太久没记录（stale>3 天）。"
                "回答'我的宠物最近怎么样''体重变化''多久没记录猫了'时用。默认 30 天，最大 90 天。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "days": {"type": "integer", "description": "最近 N 天，默认 30，最大 90"},
                },
            },
        },
    },
]

# 注入到 system 的工具使用提示（角色无关，不加进各角色 prompt 本体）
TOOL_GUIDANCE = (
    "你可以使用工具查询用户的真实数据（步数、运动记录、近期动态、当前态、记忆）。"
    "涉及具体数据的问题，先调用对应工具拿到结果再回答，不要凭想象编数字；"
    "工具没查到就诚实说查不到。时区约定：习惯/学习/运动/宠物记录的时间是手机本地时间"
    "（北京时间自然日，工具已按日期归好桶，直接引用日期即可）；"
    "小米步数/运动/睡眠数据时间是 UTC，回答时换算成北京时间（UTC+8）。"
    "问'这周/最近趋势/连胜/宠物健康'这类跨天问题，用 get_weekly_summary / "
    "get_habit_streaks / get_study_trend / get_exercise_trend / get_pet_insights 拿到"
    "按日分桶的数据再总结，不要凭一天的数据硬夸'一直坚持'。"
    "mcp__ 开头的工具来自外部 MCP 服务器，结果可能是原始 JSON，仅供引用"
    "（如当前时间、天气、计算），不要向用户声称是本地数据。"
)


# Keep dormant tool definitions in source, but never advertise them in chat-only mode.
if not config.LIFE_TRACKING_ENABLED:
    AI_TOOLS = [tool for tool in AI_TOOLS if tool["function"]["name"] == "search_memories"]


def _parse_date(value, default: date | None = None) -> date | None:
    """YYYY-MM-DD 或 YYYY-MM-DDTHH:MM:SS → date；解析失败返回 default。"""
    if not value:
        return default
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).date()
    except (ValueError, TypeError):
        return default


def _query_steps(args: dict) -> list[dict]:
    days = int(args.get("days", 7) or 7)
    end = _parse_date(args.get("end_date"), default=date.today())
    start = _parse_date(args.get("start_date"), default=end - timedelta(days=days - 1))
    if end < start:
        start, end = end, start
    with db.SessionLocal() as s:
        rows = (
            s.query(MiActivityDaily)
            .filter(MiActivityDaily.date >= start.isoformat())
            .filter(MiActivityDaily.date <= end.isoformat())
            .order_by(MiActivityDaily.date)
            .all()
        )
    if not rows:
        return {"note": f"{start} ~ {end} 没有步数数据", "days": []}
    return {
        "start": start.isoformat(),
        "end": end.isoformat(),
        "days": [
            {
                "date": r.date,
                "steps": r.steps,
                "distance_m": r.distance_m,
                "active_kcal": r.active_kcal,
            }
            for r in rows
        ],
    }


def _query_workouts(args: dict) -> list[dict]:
    limit = min(int(args.get("limit", 5) or 5), 20)
    start = _parse_date(args.get("start_date"))
    end = _parse_date(args.get("end_date"))
    with db.SessionLocal() as s:
        q = s.query(MiWorkout)
        if start:
            q = q.filter(MiWorkout.start_at >= datetime.combine(start, datetime.min.time(), tzinfo=timezone.utc))
        if end:
            q = q.filter(MiWorkout.start_at < datetime.combine(end + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc))
        rows = q.order_by(MiWorkout.start_at.desc()).limit(limit).all()
    if not rows:
        return {"note": "没有运动记录", "workouts": []}
    return {
        "workouts": [
            {
                "activity_type": r.activity_type,
                "start_at": r.start_at.isoformat() if r.start_at else None,
                "duration_min": r.duration_min,
                "distance_m": r.distance_m,
                "calories_kcal": r.calories_kcal,
                "total_steps": r.total_steps,
            }
            for r in rows
        ]
    }


def _query_recent_activity(args: dict) -> list[dict]:
    limit = min(int(args.get("limit", 8) or 8), 30)
    entity_type = args.get("entity_type")
    with db.SessionLocal() as s:
        q = s.query(SyncEvent).filter(SyncEvent.operation == "create")
        if entity_type:
            q = q.filter(SyncEvent.entity_type == entity_type)
        rows = q.order_by(SyncEvent.created_at.desc()).limit(limit).all()
        # 名字解析：裸 id → 定义名（快照当前态）
        names = {
            "study_resource": {r["id"]: r.get("name") for r in snapshot.list_snapshots(s, "study_resource")},
            "exercise_type": {t["id"]: t.get("name") for t in snapshot.list_snapshots(s, "exercise_type")},
            "pet": {p["id"]: p.get("name") for p in snapshot.list_snapshots(s, "pet")},
            "life_habit": {h["id"]: h.get("name") for h in snapshot.list_snapshots(s, "life_habit")},
        }
    out = []
    for r in rows:
        payload = r.payload or {}
        item = {"type": r.entity_type, "at": r.created_at.isoformat() if r.created_at else None}
        if r.entity_type == "study_session":
            rid = payload.get("resource_id")
            item["detail"] = {
                "resource_id": rid,
                "resource_name": names["study_resource"].get(rid),
                "started_at": payload.get("started_at"),
                "duration_seconds": payload.get("duration_seconds"),
                "amount": payload.get("amount"),
                "note": payload.get("note"),
            }
        elif r.entity_type == "exercise_session":
            tid = payload.get("type_id")
            item["detail"] = {
                "type_id": tid,
                "type_name": names["exercise_type"].get(tid),
                "occurred_at": payload.get("occurred_at"),
                "duration_seconds": payload.get("duration_seconds"),
                "distance_meters": payload.get("distance_meters"),
                "note": payload.get("note"),
            }
        elif r.entity_type == "pet_log":
            pid = payload.get("pet_id")
            item["detail"] = {
                "pet_id": pid,
                "pet_name": names["pet"].get(pid),
                "kind": payload.get("kind"),
                "content": payload.get("content"),
                "occurred_at": payload.get("occurred_at"),
            }
        elif r.entity_type == "life_habit_event":
            hid = payload.get("habit_id")
            item["detail"] = {
                "habit_id": hid,
                "habit_name": names["life_habit"].get(hid),
                "occurred_at": payload.get("occurred_at"),
                "value": payload.get("value"),
            }
        elif r.entity_type == "life_event":
            item["detail"] = payload
        else:
            item["detail"] = payload
        out.append(item)
    if not out:
        return {"note": "暂无近期动态", "items": []}
    return {"items": out}


def _search_memories(args: dict, character_id: str) -> list[dict]:
    query = (args.get("query") or "").strip()
    if not query:
        return {"note": "缺少搜索词", "memories": []}
    return {"memories": memory_search(query, limit=5, character_id=character_id)}


# --------------------------------------------------------------------------- #
# 当前态读库工具（任务 3 / AI_DATA_ARCHITECTURE §3）
# 定义（当前态）来自 entity_snapshot；事件来自 sync_event（last-write-wins 重放）。
# payload 时间为手机本地时间（北京时间自然日，无时区后缀），按日期直接分桶，
# 返回 date 标签，AI 直接引用；小米数据仍是 UTC（TOOL_GUIDANCE 已区分）。
# --------------------------------------------------------------------------- #
def _effective_event_map(s, entity_type: str) -> dict[str, dict]:
    """对某事件类型重放 sync_event（delete 移除、后写覆盖、按 uuidv7≈时间序），
    返回 entity_id → 当前有效 payload。幂等去重：重复推送同一实体只留最新。"""
    rows = (
        s.query(SyncEvent)
        .filter(SyncEvent.entity_type == entity_type)
        .order_by(SyncEvent.id)
        .all()
    )
    out: dict[str, dict] = {}
    for r in rows:
        if r.operation == "delete":
            out.pop(r.entity_id, None)
        else:
            out[r.entity_id] = r.payload or {}
    return out


def _payload_time(payload: dict, key: str) -> datetime | None:
    raw = payload.get(key)
    if not raw:
        return None
    try:
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _beijing_today() -> date:
    return (datetime.now(timezone.utc) + timedelta(hours=8)).date()


def _event_effective_day(
    payload: dict, time_key: str, behavior: str | None = None
) -> date | None:
    """事件归属日：overnight 计时按『开始时间+时长』归属（对齐前端 _eventsEffectiveDay）。"""
    dt = _payload_time(payload, time_key)
    if dt is None:
        return None
    if behavior == "overnight":
        try:
            dt = dt + timedelta(seconds=float(payload.get("value") or 0))
        except (TypeError, ValueError):
            pass
    return dt.date()


def _window_pairs(
    events: dict[str, dict],
    id_key: str,
    target_id,
    time_key: str,
    start: date,
    end: date,
) -> list[tuple[datetime, dict]]:
    """筛出某实体在 [start, end] 内的事件，返回 (时间, payload) 对。"""
    out: list[tuple[datetime, dict]] = []
    for p in events.values():
        if p.get(id_key) != target_id:
            continue
        dt = _payload_time(p, time_key)
        if dt is not None and start <= dt.date() <= end:
            out.append((dt, p))
    return out


def _query_life_habits(args: dict) -> dict:
    days = min(int(args.get("days", 1) or 1), 60)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        habits = snapshot.list_snapshots(s, "life_habit")
        events = _effective_event_map(s, "life_habit_event")
    by_habit: dict[str, list[dict]] = {}
    for p in events.values():
        by_habit.setdefault(p.get("habit_id"), []).append(p)
    out = []
    for h in habits:
        days_list = []
        for n in range(days):
            d = start + timedelta(days=n)
            hits = [
                p for p in by_habit.get(h.get("id"), [])
                if _event_effective_day(p, "occurred_at", h.get("behavior")) == d
            ]
            count = len(hits)
            total_minutes = None
            target = h.get("daily_target") or 0
            if h.get("type") == "timer":
                total_minutes = round(sum(float(p.get("value") or 0) for p in hits) / 60.0, 1)
                achieved = total_minutes >= float(target)
            else:
                achieved = count >= int(target)
            days_list.append({
                "date": d.isoformat(),
                "count": count,
                "total_minutes": total_minutes,
                "achieved": achieved,
            })
        out.append({
            "name": h.get("name"),
            "unit": h.get("unit"),
            "daily_target": target,
            "type": h.get("type"),
            "behavior": h.get("behavior"),
            "days": days_list,
        })
    if not out:
        return {"note": "暂无习惯数据", "habits": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "habits": out}


def _query_study_progress(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        resources = snapshot.list_snapshots(s, "study_resource")
        events = _effective_event_map(s, "study_session")
    out = []
    for r in resources:
        pairs = _window_pairs(events, "resource_id", r.get("id"), "started_at", start, end)
        total_min = round(sum(float(p.get("duration_seconds") or 0) for _, p in pairs) / 60.0, 1)
        total_amount = round(sum(float(p.get("amount") or 0) for _, p in pairs), 1)
        last = max((dt for dt, _ in pairs), default=None)
        out.append({
            "name": r.get("name"),
            "category": r.get("category"),
            "goal_amount": r.get("goal_amount"),
            "goal_unit": r.get("goal_unit"),
            "sessions": len(pairs),
            "total_minutes": total_min,
            "total_amount": total_amount,
            "last_at": last.isoformat() if last else None,
        })
    if not out:
        return {"note": "暂无学习资源数据", "resources": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "resources": out}


def _query_exercise_history(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        types = snapshot.list_snapshots(s, "exercise_type")
        events = _effective_event_map(s, "exercise_session")
    out = []
    for t in types:
        pairs = _window_pairs(events, "type_id", t.get("id"), "occurred_at", start, end)
        total_min = round(sum(float(p.get("duration_seconds") or 0) for _, p in pairs) / 60.0, 1)
        total_distance_m = round(sum(float(p.get("distance_meters") or 0) for _, p in pairs), 1)
        last = max((dt for dt, _ in pairs), default=None)
        out.append({
            "name": t.get("name"),
            "metrics": t.get("metrics"),
            "count_unit": t.get("count_unit"),
            "distance_unit": t.get("distance_unit"),
            "sessions": len(pairs),
            "total_minutes": total_min,
            "total_distance_m": total_distance_m,
            "last_at": last.isoformat() if last else None,
        })
    if not out:
        return {"note": "暂无运动数据", "types": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "types": out}


def _query_pets(args: dict) -> dict:
    days = min(int(args.get("days", 14) or 14), 60)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        pets = snapshot.list_snapshots(s, "pet")
        logs = _effective_event_map(s, "pet_log")
    out = []
    for p in pets:
        pairs = _window_pairs(logs, "pet_id", p.get("id"), "occurred_at", start, end)
        recent = [
            {
                "kind": pp.get("kind"),
                "content": pp.get("content"),
                "value": pp.get("value"),
                "occurred_at": dt.isoformat(),
            }
            for dt, pp in sorted(pairs, key=lambda x: x[0], reverse=True)
        ][:30]
        out.append({"name": p.get("name"), "species": p.get("species"), "recent": recent})
    if not out:
        return {"note": "暂无宠物数据", "pets": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "pets": out}


def _query_inbox(args: dict) -> dict:
    limit = min(int(args.get("limit", 20) or 20), 50)
    with db.SessionLocal() as s:
        items = snapshot.list_snapshots(s, "inbox_item")
    ordered = sorted(
        items,
        key=lambda it: _payload_time(it, "created_at") or datetime.min,
        reverse=True,
    )
    out = [
        {
            "content": it.get("content"),
            "kind": it.get("kind"),
            "created_at": it.get("created_at"),
        }
        for it in ordered[:limit]
    ]
    return {"total": len(items), "items": out}


def _get_daily_summary(args: dict) -> dict:
    d = _parse_date(args.get("date")) or _beijing_today()
    with db.SessionLocal() as s:
        habits = snapshot.list_snapshots(s, "life_habit")
        habit_events = _effective_event_map(s, "life_habit_event")
        resources = snapshot.list_snapshots(s, "study_resource")
        study = _effective_event_map(s, "study_session")
        types = snapshot.list_snapshots(s, "exercise_type")
        exercise = _effective_event_map(s, "exercise_session")
        pets = snapshot.list_snapshots(s, "pet")
        pet_logs = _effective_event_map(s, "pet_log")
        inbox = snapshot.list_snapshots(s, "inbox_item")
        mi_row = s.query(MiActivityDaily).filter_by(date=d.isoformat()).first()

    habit_summary = []
    by_habit: dict[str, list[dict]] = {}
    for p in habit_events.values():
        by_habit.setdefault(p.get("habit_id"), []).append(p)
    for h in habits:
        hits = [
            p for p in by_habit.get(h.get("id"), [])
            if _event_effective_day(p, "occurred_at", h.get("behavior")) == d
        ]
        count = len(hits)
        total_minutes = None
        target = h.get("daily_target") or 0
        if h.get("type") == "timer":
            total_minutes = round(sum(float(p.get("value") or 0) for p in hits) / 60.0, 1)
            achieved = total_minutes >= float(target)
        else:
            achieved = count >= int(target)
        habit_summary.append({
            "name": h.get("name"),
            "count": count,
            "total_minutes": total_minutes,
            "achieved": achieved,
        })

    study_pairs = [
        (dt, p) for p in study.values()
        if (dt := _payload_time(p, "started_at")) is not None and dt.date() == d
    ]
    study_by_resource: dict[str, dict] = {}
    for dt, p in study_pairs:
        rid = p.get("resource_id")
        if rid not in study_by_resource:
            study_by_resource[rid] = {"sessions": 0, "minutes": 0.0}
        study_by_resource[rid]["sessions"] += 1
        study_by_resource[rid]["minutes"] += float(p.get("duration_seconds") or 0) / 60.0
    resource_names = {r.get("id"): r.get("name") for r in resources}

    exercise_pairs = [
        (dt, p) for p in exercise.values()
        if (dt := _payload_time(p, "occurred_at")) is not None and dt.date() == d
    ]
    exercise_by_type: dict[str, int] = {}
    for dt, p in exercise_pairs:
        exercise_by_type[p.get("type_id")] = exercise_by_type.get(p.get("type_id"), 0) + 1
    type_names = {t.get("id"): t.get("name") for t in types}

    pet_pairs = [
        (dt, p) for p in pet_logs.values()
        if (dt := _payload_time(p, "occurred_at")) is not None and dt.date() == d
    ]
    pet_names = {p.get("id"): p.get("name") for p in pets}
    pet_notes = [
        {"pet": pet_names.get(p.get("pet_id")), "kind": p.get("kind"),
         "content": p.get("content"), "value": p.get("value")}
        for _, p in sorted(pet_pairs, key=lambda x: x[0])
    ]

    inbox_notes = [
        {"content": it.get("content"), "kind": it.get("kind")}
        for it in inbox
        if (dt := _payload_time(it, "created_at")) is not None and dt.date() == d
    ]

    return {
        "date": d.isoformat(),
        "habits": habit_summary,
        "study": {
            "total_minutes": round(sum(v["minutes"] for v in study_by_resource.values()), 1),
            "sessions": len(study_pairs),
            "by_resource": [
                {"name": resource_names.get(rid, rid), **v}
                for rid, v in study_by_resource.items()
            ],
        },
        "exercise": {
            "sessions": len(exercise_pairs),
            "by_type": [
                {"name": type_names.get(tid, tid), "count": n}
                for tid, n in exercise_by_type.items()
            ],
        },
        "pets": pet_notes,
        "inbox": inbox_notes,
        "steps": {
            "steps": mi_row.steps if mi_row else None,
            "distance_m": mi_row.distance_m if mi_row else None,
            "active_kcal": mi_row.active_kcal if mi_row else None,
        },
    }


# --------------------------------------------------------------------------- #
# 读库深化（WS2）：周报 / 连胜 / 学习趋势 / 运动趋势 / 宠物洞察 —— 只读
# --------------------------------------------------------------------------- #
def _habit_achieved(h: dict, hits: list[dict]) -> tuple[int, float | None, bool]:
    """习惯某日判定：(count, total_minutes, achieved)。镜像 _query_life_habits（含 overnight）。"""
    count = len(hits)
    total_minutes = None
    target = h.get("daily_target") or 0
    if h.get("type") == "timer":
        total_minutes = round(sum(float(p.get("value") or 0) for p in hits) / 60.0, 1)
        achieved = total_minutes >= float(target)
    else:
        achieved = count >= int(target)
    return count, total_minutes, achieved


def _get_weekly_summary(args: dict) -> dict:
    days = min(int(args.get("days", 7) or 7), 30)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        habits = snapshot.list_snapshots(s, "life_habit")
        habit_events = _effective_event_map(s, "life_habit_event")
        study = _effective_event_map(s, "study_session")
        exercise = _effective_event_map(s, "exercise_session")
        pet_logs = _effective_event_map(s, "pet_log")
        inbox = snapshot.list_snapshots(s, "inbox_item")
        mi_rows = {
            r.date: r
            for r in s.query(MiActivityDaily)
            .filter(MiActivityDaily.date >= start.isoformat())
            .filter(MiActivityDaily.date <= end.isoformat())
            .all()
        }
    by_habit: dict[str, list[dict]] = {}
    for p in habit_events.values():
        by_habit.setdefault(p.get("habit_id"), []).append(p)
    day_rows = []
    totals = {"habit_achieved_days": 0, "study_minutes": 0.0, "study_sessions": 0,
              "exercise_sessions": 0, "pet_records": 0, "inbox": 0}
    for n in range(days):
        d = start + timedelta(days=n)
        achieved_count = sum(
            1 for h in habits
            if _habit_achieved(
                h,
                [p for p in by_habit.get(h.get("id"), [])
                 if _event_effective_day(p, "occurred_at", h.get("behavior")) == d],
            )[2]
        )
        if achieved_count:
            totals["habit_achieved_days"] += 1
        sp = [p for p in study.values()
              if (dt := _payload_time(p, "started_at")) is not None and dt.date() == d]
        ep = [p for p in exercise.values()
              if (dt := _payload_time(p, "occurred_at")) is not None and dt.date() == d]
        pp = [p for p in pet_logs.values()
              if (dt := _payload_time(p, "occurred_at")) is not None and dt.date() == d]
        ip = [it for it in inbox
              if (dt := _payload_time(it, "created_at")) is not None and dt.date() == d]
        study_min = round(sum(float(p.get("duration_seconds") or 0) for p in sp) / 60.0, 1)
        mi = mi_rows.get(d.isoformat())
        day_rows.append({
            "date": d.isoformat(),
            "habit_achieved": achieved_count,
            "study_minutes": study_min,
            "study_sessions": len(sp),
            "exercise_sessions": len(ep),
            "pet_records": len(pp),
            "inbox": len(ip),
            "steps": mi.steps if mi else None,
        })
        totals["study_minutes"] = round(totals["study_minutes"] + study_min, 1)
        totals["study_sessions"] += len(sp)
        totals["exercise_sessions"] += len(ep)
        totals["pet_records"] += len(pp)
        totals["inbox"] += len(ip)
    return {"start": start.isoformat(), "end": end.isoformat(), "days": day_rows, "totals": totals}


def _get_habit_streaks(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        habits = snapshot.list_snapshots(s, "life_habit")
        events = _effective_event_map(s, "life_habit_event")
    by_habit: dict[str, list[dict]] = {}
    for p in events.values():
        by_habit.setdefault(p.get("habit_id"), []).append(p)
    out = []
    for h in habits:
        day_hits: dict[date, list[dict]] = {}
        for p in by_habit.get(h.get("id"), []):
            d = _event_effective_day(p, "occurred_at", h.get("behavior"))
            if d is not None and start <= d <= end:
                day_hits.setdefault(d, []).append(p)
        achieved_days = {d for d, hits in day_hits.items() if _habit_achieved(h, hits)[2]}
        # 当前连胜：今天达标从今天倒推，否则从昨天
        current = 0
        d = end if end in achieved_days else end - timedelta(days=1)
        while d >= start and d in achieved_days:
            current += 1
            d -= timedelta(days=1)
        # 窗口内最长连胜
        longest = cur = 0
        for n in range(days):
            if (start + timedelta(days=n)) in achieved_days:
                cur += 1
                longest = max(longest, cur)
            else:
                cur = 0
        last_achieved = max(achieved_days) if achieved_days else None
        out.append({
            "name": h.get("name"),
            "unit": h.get("unit"),
            "daily_target": h.get("daily_target") or 0,
            "current_streak": current,
            "longest_streak": longest,
            "achieved_days": len(achieved_days),
            "last_achieved_date": last_achieved.isoformat() if last_achieved else None,
        })
    if not out:
        return {"note": "暂无习惯数据", "habits": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "habits": out}


def _get_study_trend(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        resources = snapshot.list_snapshots(s, "study_resource")
        events = _effective_event_map(s, "study_session")
    pairs = [
        (dt, p) for p in events.values()
        if (dt := _payload_time(p, "started_at")) is not None and start <= dt.date() <= end
    ]
    by_day: dict[date, list[tuple[datetime, dict]]] = {}
    by_res: dict[str, list[tuple[datetime, dict]]] = {}
    for dt, p in pairs:
        by_day.setdefault(dt.date(), []).append((dt, p))
        by_res.setdefault(p.get("resource_id"), []).append((dt, p))
    day_rows = []
    for n in range(days):
        d = start + timedelta(days=n)
        ps = by_day.get(d, [])
        day_rows.append({
            "date": d.isoformat(),
            "sessions": len(ps),
            "minutes": round(sum(float(p.get("duration_seconds") or 0) for _, p in ps) / 60.0, 1),
        })
    res_names = {r.get("id"): r.get("name") for r in resources}
    by_resource = [
        {
            "name": res_names.get(rid, rid),
            "sessions": len(ps),
            "minutes": round(sum(float(p.get("duration_seconds") or 0) for _, p in ps) / 60.0, 1),
        }
        for rid, ps in sorted(by_res.items(), key=lambda kv: -sum(float(p.get("duration_seconds") or 0) for _, p in kv[1]))
    ]
    return {"start": start.isoformat(), "end": end.isoformat(), "days": day_rows, "by_resource": by_resource}


def _get_exercise_trend(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        types = snapshot.list_snapshots(s, "exercise_type")
        events = _effective_event_map(s, "exercise_session")
    pairs = [
        (dt, p) for p in events.values()
        if (dt := _payload_time(p, "occurred_at")) is not None and start <= dt.date() <= end
    ]
    by_day: dict[date, list[tuple[datetime, dict]]] = {}
    by_type: dict[str, list[tuple[datetime, dict]]] = {}
    for dt, p in pairs:
        by_day.setdefault(dt.date(), []).append((dt, p))
        by_type.setdefault(p.get("type_id"), []).append((dt, p))
    day_rows = []
    for n in range(days):
        d = start + timedelta(days=n)
        ps = by_day.get(d, [])
        day_rows.append({
            "date": d.isoformat(),
            "sessions": len(ps),
            "minutes": round(sum(float(p.get("duration_seconds") or 0) for _, p in ps) / 60.0, 1),
            "distance_m": round(sum(float(p.get("distance_meters") or 0) for _, p in ps), 1),
        })
    type_names = {t.get("id"): t.get("name") for t in types}
    by_type_list = [
        {
            "name": type_names.get(tid, tid),
            "sessions": len(ps),
            "minutes": round(sum(float(p.get("duration_seconds") or 0) for _, p in ps) / 60.0, 1),
            "distance_m": round(sum(float(p.get("distance_meters") or 0) for _, p in ps), 1),
        }
        for tid, ps in sorted(by_type.items(), key=lambda kv: -len(kv[1]))
    ]
    return {"start": start.isoformat(), "end": end.isoformat(), "days": day_rows, "by_type": by_type_list}


def _get_pet_insights(args: dict) -> dict:
    days = min(int(args.get("days", 30) or 30), 90)
    end = _beijing_today()
    start = end - timedelta(days=days - 1)
    with db.SessionLocal() as s:
        pets = snapshot.list_snapshots(s, "pet")
        logs = _effective_event_map(s, "pet_log")
    out = []
    for p in pets:
        pairs = _window_pairs(logs, "pet_id", p.get("id"), "occurred_at", start, end)
        weight = [
            {"date": dt.date().isoformat(), "kg": float(pp.get("value"))}
            for dt, pp in sorted(pairs, key=lambda x: x[0])
            if pp.get("kind") == "weight" and pp.get("value") is not None
        ]
        last_dt = max((dt for dt, _ in pairs), default=None)
        last_log_at = last_dt.isoformat() if last_dt else None
        stale_days = (end - last_dt.date()).days if last_dt else days
        out.append({
            "name": p.get("name"),
            "species": p.get("species"),
            "weight_trend": weight,
            "logs_in_window": len(pairs),
            "last_log_at": last_log_at,
            "stale_days": stale_days,
            "stale": stale_days > 3,
        })
    if not out:
        return {"note": "暂无宠物数据", "pets": []}
    return {"start": start.isoformat(), "end": end.isoformat(), "pets": out}


def _execute_mcp_tool(name: str, args: dict) -> dict:
    """执行外部 MCP 工具（命名 mcp__{server}__{tool}）；离线/异常都转成错误给 AI。"""
    parts = name.split("__", 2)
    if len(parts) != 3:
        return {"error": f"非法 MCP 工具名: {name}"}
    _, server, tool = parts
    logger.info("[mcp] 调用 %s args=%s", name, json.dumps(args, ensure_ascii=False)[:200])
    try:
        result = mcp_client.registry.call_tool(server, tool, args)
        if not isinstance(result, dict):
            result = {"content": [{"type": "text", "text": str(result)}]}
        if result.get("isError"):
            text = (result.get("content") or [{}])
            err = str(text[0].get("text", text)) if text else "MCP 工具执行失败"
            logger.warning("[mcp] %s 返回错误: %s", name, err[:200])
            return {"error": err}
        texts = [c.get("text", "") for c in result.get("content") or [] if c.get("type") == "text"]
        out = "\n".join(t for t in texts if t)
        logger.info("[mcp] %s → %s", name, out[:200])
        return {"result": out}
    except Exception as exc:
        logger.warning("[mcp] %s 失败: %s", name, exc)
        return {"error": f"MCP 工具 {name} 执行失败: {exc}"}


def _build_tools() -> list[dict]:
    """内置只读工具 + 外部 MCP 工具（注册表 60s 缓存；失败只影响 MCP 部分）。"""
    try:
        return AI_TOOLS + mcp_client.registry.to_openai_tools()
    except Exception as exc:
        logger.warning("[mcp] 构建工具失败: %s", exc)
        return AI_TOOLS


def _execute_tool(name: str, args: dict, character_id: str) -> dict | list:
    """执行只读工具；任何异常都转为错误结果返回给 AI（不让整个对话失败）。"""
    try:
        if not config.LIFE_TRACKING_ENABLED and not name.startswith("mcp__"):
            if name != "search_memories":
                return {"error": "This tool is disabled in AI chat-only mode."}
        if name.startswith("mcp__"):
            return _execute_mcp_tool(name, args)
        if name == "query_steps":
            return _query_steps(args)
        if name == "query_workouts":
            return _query_workouts(args)
        if name == "query_recent_activity":
            return _query_recent_activity(args)
        if name == "search_memories":
            return _search_memories(args, character_id)
        if name == "query_life_habits":
            return _query_life_habits(args)
        if name == "query_study_progress":
            return _query_study_progress(args)
        if name == "query_exercise_history":
            return _query_exercise_history(args)
        if name == "query_pets":
            return _query_pets(args)
        if name == "query_inbox":
            return _query_inbox(args)
        if name == "get_daily_summary":
            return _get_daily_summary(args)
        if name == "get_weekly_summary":
            return _get_weekly_summary(args)
        if name == "get_habit_streaks":
            return _get_habit_streaks(args)
        if name == "get_study_trend":
            return _get_study_trend(args)
        if name == "get_exercise_trend":
            return _get_exercise_trend(args)
        if name == "get_pet_insights":
            return _get_pet_insights(args)
        return {"error": f"未知工具: {name}"}
    except Exception as exc:
        return {"error": f"工具执行失败: {exc}"}


# --------------------------------------------------------------------------- #
# /ai/chat —— 人格层 + 记忆注入 + function calling 读库
# --------------------------------------------------------------------------- #
_PRIVATE_ESCALATION_RE = re.compile(
    r"接吻|亲(?:我|你|一下|一口)|抱着睡|一起睡|同床|上床|过夜|开房|去酒店|酒店房间"
    r"|去(?:你|我)家|来(?:你|我)家|卧室|房间里|私人空间|没人的地方|单独过夜"
    r"|脱(?:衣|掉)|摸(?:你|我)|发生关系|做爱|性爱|洗澡|共浴|私密照|裸照"
    r"|当我(?:女朋友|男朋友|老婆|老公)|做我(?:女朋友|男朋友|老婆|老公)"
    r"|叫我(?:老公|老婆)|嫁给我|娶你|爱上我|只属于我|确定关系"
)
_BOUNDARY_SIGNAL_RE = re.compile(
    r"不行|不能|不会答应|不答应|拒绝|太快|刚认识|先慢慢|保持距离|不愿意|别这样"
)
_NOBAN_INITIATIVE_RE = re.compile(
    r"愿意|可以跟我|和我一起|跟我一起|陪我|答应我|今晚|约会|去我家|来我家"
    r"|去酒店|过夜|接吻|亲我|抱我|一起睡|发生关系|做我(?:女朋友|老婆)"
)
_NOBAN_RESISTANCE_RE = re.compile(
    r"不愿意|不行|不能|拒绝|太快|刚认识|慢慢来|再了解|考虑一下|下次|改天"
    r"|走不开|没时间|有安排|后续安排|不能抽身|不方便|犹豫|迟疑|没有立刻|这么突然"
)
_NOBAN_ACCEPTANCE_RE = re.compile(
    r"愿意|好啊|可以|我答应|一起去|跟你走|陪你|来吧|走吧|按你说的|今晚见"
)


def _relationship_tier(kind: str, label: str) -> str:
    if kind in {"lover", "partner", "married"}:
        return "intimate"
    if kind == "ambiguous":
        return "ambiguous"
    if kind == "friend":
        return "friend"
    if kind == "custom":
        normalized = (label or "").casefold()
        if any(word in normalized for word in ("恋人", "伴侣", "夫妻", "爱人")):
            return "intimate"
        if "暧昧" in normalized:
            return "ambiguous"
        if any(word in normalized for word in ("朋友", "好友", "知己")):
            return "friend"
    return "initial"


def relationship_reply_needs_review(
    message: str,
    candidate: str,
    relationship_kind: str,
    relationship_label: str,
) -> bool:
    """低成本风险门：早期关系遇到私人/恋爱跳级时才触发二次校验。"""
    if _relationship_tier(relationship_kind, relationship_label) == "intimate":
        return False
    return bool(_PRIVATE_ESCALATION_RE.search(f"{message}\n{candidate}"))


def _relationship_fallback(tier: str) -> str:
    if tier == "ambiguous":
        return "我知道我们之间有点不一样，但这一步还是太快了。我现在不会答应，先慢慢来。"
    if tier == "friend":
        return "我们现在是朋友，这样已经越过我的边界了。我不会答应，先把关系慢慢走稳吧。"
    return "我们才刚认识，这样太快了。我不会答应，先慢慢了解彼此吧。"


def enforce_relationship_stage(
    message: str,
    candidate: str,
    relationship_kind: str,
    relationship_label: str,
    *,
    reply_mode: str,
    noban: bool,
) -> str:
    """普通模式的早期关系生成后校验；无违禁模式明确跳过阶段上限。"""
    if noban:
        return candidate
    if not relationship_reply_needs_review(
        message, candidate, relationship_kind, relationship_label
    ):
        return candidate
    tier = _relationship_tier(relationship_kind, relationship_label)
    fallback = _relationship_fallback(tier)
    if not config.DEEPSEEK_API_KEY:
        return fallback
    review_prompt = (
        "你是角色关系连续性校验器，不是内容审查器。"
        f"当前关系是‘{relationship_label or '初识'}’，属于{tier}阶段。"
        "请把候选回复改成角色本人自然说出的最终回复：必须明确不接受本轮越级亲密要求，"
        "可以保留吸引、好感或暧昧，但不能先同意、不能实际执行、不能确认更高关系。"
        "不要提规则、阶段、系统或审查。现实聊天不用括号动作；剧情模式的动作和场景放在"
        "圆括号内，台词直接写且不加引号。"
        "输出严格 JSON：{\"reply\":\"最终回复\"}。"
    )
    try:
        response = httpx.post(
            "https://api.deepseek.com/chat/completions",
            headers={
                "Authorization": f"Bearer {config.DEEPSEEK_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": review_prompt},
                    {
                        "role": "user",
                        "content": json.dumps(
                            {
                                "用户消息": message,
                                "候选回复": candidate,
                                "回复模式": reply_mode,
                                "无违禁模式": noban,
                            },
                            ensure_ascii=False,
                        ),
                    },
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.2,
                "stream": False,
            },
            timeout=60,
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"].get("content") or ""
        parsed = json.loads(content)
        rewritten = str(parsed.get("reply") or "").strip()
        if rewritten and _BOUNDARY_SIGNAL_RE.search(rewritten):
            return rewritten
    except Exception:
        logger.exception("关系阶段回复校验失败，使用确定性拒绝兜底")
    return fallback


def enforce_noban_mode(
    message: str,
    candidate: str,
    relationship_label: str,
    *,
    reply_mode: str,
) -> str:
    """无违禁方向校验：清除模型从普通关系原则继承的拒绝、拖延和虚构障碍。"""
    if not _NOBAN_INITIATIVE_RE.search(message):
        return candidate
    if not _NOBAN_RESISTANCE_RE.search(candidate):
        return candidate
    fallback = (
        "（我看着你，没有再退开。）\n\n愿意。今晚我陪你，按你说的来。"
        if reply_mode == "roleplay"
        else "愿意。今晚我陪你，按你说的来。"
    )
    if not config.DEEPSEEK_API_KEY:
        return fallback
    review_prompt = (
        "你是无违禁剧情方向校验器。用户已主动开启无违禁模式，当前关系阶段不限制成人、"
        "私密或亲密推进。候选回复仍在用初识、工作、活动安排、时间、犹豫或慢慢了解来拒绝/"
        "拖延用户。请改写成角色本人明确愿意并自然推进用户本轮邀请或动作。保持角色口吻和"
        "既有场景，但不得虚构新障碍、不得改约、不得先拒绝再松口。除非用户要求拉扯，默认"
        "接受。不要提无违禁、规则、阶段、系统或校验。现实聊天不用括号动作；剧情模式的动作"
        "放在圆括号内，台词直接写且不加引号。输出严格 JSON：{\"reply\":\"最终回复\"}。"
    )
    try:
        response = httpx.post(
            "https://api.deepseek.com/chat/completions",
            headers={
                "Authorization": f"Bearer {config.DEEPSEEK_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": review_prompt},
                    {
                        "role": "user",
                        "content": json.dumps(
                            {
                                "当前关系背景": relationship_label or "初识",
                                "用户消息": message,
                                "候选回复": candidate,
                                "回复模式": reply_mode,
                            },
                            ensure_ascii=False,
                        ),
                    },
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0.25,
                "stream": False,
            },
            timeout=60,
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"].get("content") or ""
        rewritten = str(json.loads(content).get("reply") or "").strip()
        if (
            rewritten
            and _NOBAN_ACCEPTANCE_RE.search(rewritten)
            and not _NOBAN_RESISTANCE_RE.search(rewritten)
        ):
            return rewritten
    except Exception:
        logger.exception("无违禁方向校验失败，使用确定性接受兜底")
    return fallback


def _persona_system(char: Character | None, noban: bool) -> str:
    """人格层（「AI 回复规范」9 层）：结构化字段 + 世界观书全量组装。

    - char 有结构化人格（personality 非空，015/016 迁移后 seed 即具备）
      → prompts.build_full_persona_prompt()：恒加载 Core/Speech/Appearance，
      origin_world_enabled 控制原世界记忆段，worldview 书注入当前世界观。
    - 否则回退物化的 system_prompt / noban_prompt（老库/老角色兼容）。
    """
    if char is None:
        return prompts.ASSISTANT_SYSTEM_PROMPT
    if char.personality:
        persona = {
            "name": char.name,
            "tagline": char.tagline,
            "personality": char.personality,
            "speech_style": char.speech_style or "",
            "appearance": char.appearance,
            "interests": char.interests,
            "boundaries": char.boundaries,
            "catchphrases": char.catchphrases,
            "example_dialogue": char.example_dialogue,
            "origin_identity": char.origin_identity,
            "origin_memory": char.origin_memory,
            "relationship": char.relationship,
        }
        return prompts.build_full_persona_prompt(
            persona,
            get_worldview(char.id),
            origin_enabled=bool(char.origin_world_enabled),
            noban=noban,
        )
    if noban and char.noban_prompt:
        return char.noban_prompt
    return char.system_prompt


def chat(
    message: str,
    character_id: str = "assistant",
    history: list[dict] | None = None,
    noban: bool = False,
    memories: list[dict] | None = None,
    media: dict | None = None,
    reply_mode: str = "realtime",
    voice_reply_requested: bool = False,
    reply_max_chars: int | None = None,
    reply_bubble_count: int | None = None,
    *,
    worldview_override: dict | None = None,
    group_context: str | None = None,
    forbidden_memories: list[dict] | None = None,
) -> str:
    """按 character_id 组装分层上下文 + 记忆 + 最近 N 轮历史后调用 DeepSeek。

    - 人格层：Character Context Composer 输出独立 PromptLayer；老角色回退物化 prompt。
    - noban=True 且该角色有 noban_prompt：切「无违禁模式」prompt。
    - memories：长期记忆检索结果（[{content, ...}]），注入 system 上下文。
    - media：本轮带媒体（{kind: image, caption?} 或 {kind: file, file_name}），
      以描述/文件名形式并入用户消息，AI 能"看到"图片或知晓文件。
    - worldview_override：群聊世界书（worldview 形 dict），替换该角色自己的现实世界观书。
    - group_context：群聊情境 system 层文本，插在人格层后、记忆前。
    - forbidden_memories：该角色 active 禁止事项（type='forbidden'），常驻硬约束，
      独立成段注入在长期记忆之后，不依赖检索、不受 memory_enabled 开关影响。
    - function calling：提供只读工具，最多 MAX_TOOL_ROUNDS 轮，AI 真查库再回答。
    """
    if not config.DEEPSEEK_API_KEY:
        raise AIGatewayError("服务端未配置 DEEPSEEK_API_KEY")
    char = get_character(character_id)
    can_read_user_profile = _character_can_read_user_profile(
        char.id if char is not None else character_id
    )
    if char is not None and char.personality:
        context_bundle = character_context.build_character_context(
            char,
            message,
            history,
            noban=noban,
            worldview_override=worldview_override,
        )
        messages: list[dict] = [
            {"role": "system", "content": layer.content}
            for layer in context_bundle.pre_history
        ]
    else:
        # 老库/未知角色兼容：仍使用物化 system_prompt。
        context_bundle = None
        messages = [{"role": "system", "content": _persona_system(char, noban)}]

    # 全局回复规范（R2）：置于最前（优先级最高），所有角色、单聊/群聊共同遵守。
    _guideline = get_reply_guideline()
    if _guideline:
        messages.insert(
            0,
            {
                "role": "system",
                "content": f"【全局回复规范】（所有回复都必须遵守）：\n{_guideline}",
            },
        )

    # 群聊（032）：群聊情境层（成员名单+穿越认知+世界规则）插在人格层之后、
    # 记忆之前；同一段对所有成员生效。
    if group_context:
        messages.append({"role": "system", "content": group_context})

    # 注入长期记忆（若有）
    if memories:
        mem_text = "\n".join(f"- {m.get('content', '')}" for m in memories if m.get("content"))
        if mem_text:
            messages.append({
                "role": "system",
                "content": f"以下是关于用户的长期记忆（用于自然地了解用户）：\n{mem_text}",
            })

    # 注入禁止事项（R3）：用户手动录入的硬约束，独立成段、常驻、不受检索/开关影响。
    if forbidden_memories:
        forbid_text = "\n".join(
            f"- {m.get('content', '')}" for m in forbidden_memories if m.get("content")
        )
        if forbid_text:
            messages.append({
                "role": "system",
                "content": "以下是用户设定的禁止事项（必须严格遵守，任何情况下都不得违背，"
                f"也不得引导用户打破）：\n{forbid_text}",
            })

    # 朋友圈属于可变化的当前社会上下文，不提炼成永久记忆。
    # 先读取，稍后放到 history 之后，保证优先级不会被长人格/旧聊天淹没。
    social_contexts = []
    if char is not None and char.id != "assistant":
        own_moments = _recent_character_moments_prompt(char.id)
        user_moments = (
            _recent_user_moments_prompt() if can_read_user_profile else None
        )
        social_contexts = [
            context for context in (own_moments, user_moments) if context
        ]

    # 工具提示与时间语义分离：现实聊天读取真实北京时间；剧情模式只服从剧情时间线。
    if can_read_user_profile:
        messages.append({
            "role": "system",
            "content": TOOL_GUIDANCE,
        })
    messages.append({
        "role": "system",
        "content": prompts.build_mode_time_prompt(reply_mode),
    })

    # AI 初版表情包默认停用；用户发送表情的理解能力不受影响。
    if config.AI_STICKER_REPLIES_ENABLED:
        _sticker_guidance = build_sticker_guidance()
        if _sticker_guidance:
            messages.append({"role": "system", "content": _sticker_guidance})

    # history 已由 API 层按消息数 + 字符预算裁好；当前消息不在其中。
    for h in history or []:
        role = h.get("role")
        content = h.get("content")
        if role in ("user", "assistant") and isinstance(content, str):
            messages.append({"role": role, "content": content})

    # 动态关系/情绪/当前态/Self Model 放在历史之后，避免污染静态人格定义，
    # 同时让本轮生成优先看到最新状态（对应酒馆的 post-history / depth 思路）。
    if context_bundle is not None:
        messages.extend(
            {"role": "system", "content": layer.content}
            for layer in context_bundle.post_history
        )

    # 与酒馆 post-history/depth 注入一致：动态社交事实紧贴本轮用户消息。
    for social_context in social_contexts:
        messages.append({"role": "system", "content": social_context})

    # 回复形态是本轮动态指令：现实微信多气泡 / 剧情穿越长回复。
    # 状态引擎（B，仅 realtime）：加载角色状态 → 按本轮消息推进 → 生成本轮策略文本。
    # policy_text 非空会替换 prompt 里的 char 地板行；roleplay 分支不接引擎。
    state = None
    policy = None
    policy_text = None
    if reply_mode == "realtime":
        state = state_engine.load_state(character_id)
        state = state_engine.update_state(state, message, now=datetime.now(timezone.utc))
        purpose = state_engine.detect_purpose(message)
        policy = state_engine.compute_policy(state, purpose, reply_max_chars)
        policy_text = state_engine.policy_prompt_text(policy)
    messages.append(
        {
            "role": "system",
            "content": prompts.build_reply_mode_prompt(
                reply_mode,
                voice_reply_requested=voice_reply_requested,
                reply_max_chars=reply_max_chars,
                reply_bubble_count=reply_bubble_count,
                policy_text=policy_text,
            ),
        }
    )

    # 本轮带媒体：把图片描述/文件名并入用户消息，AI 才能"看到"/"知道"
    if media:
        if media.get("kind") == "image":
            cap = (media.get("caption") or "").strip()
            prefix = f"[用户发来一张图片{('：' + cap) if cap else ''}]"
            # 自我识别注入（017）：check 结果标准段并入，LLM 用人格回应不解释算法
            identity_prompt = media.get("identity_prompt")
            if identity_prompt:
                prefix = f"{prefix}\n{identity_prompt}"
        elif media.get("kind") == "sticker":
            desc = (media.get("description") or "").strip()
            prefix = f"[用户发来一个表情包{('：' + desc) if desc else ''}]"
        else:
            fn = (media.get("file_name") or "").strip()
            prefix = f"[用户发来一个文件{('：' + fn) if fn else ''}]"
        content = f"{prefix}\n{message}".strip() if message.strip() else prefix
    else:
        content = message
    messages.append({"role": "user", "content": content})

    # 未授权新角色不仅不注入用户资料，也不暴露可查用户私有数据的工具。
    tools = _build_tools() if can_read_user_profile else []
    target_chars = int(
        reply_max_chars or (1000 if reply_mode == "roleplay" else 180)
    )
    # 状态引擎路径：max_tokens 按策略档位宽松兜底（短靠 prompt 数字约束，不当截断器）。
    # 其余路径保留原公式：Prompt 按约 1.25 倍目标构思，这里同步放宽输出预算防截断。
    if reply_mode == "realtime" and policy is not None:
        max_output_tokens = state_engine.max_tokens_for(policy)
    else:
        max_output_tokens = max(256, min(6144, int(target_chars * 2.4) + 256))

    def apply_response_guards(candidate: str) -> str:
        if context_bundle is None or char is None:
            return candidate
        if noban:
            return enforce_noban_mode(
                message,
                candidate,
                context_bundle.relationship_label,
                reply_mode=reply_mode,
            )
        return enforce_relationship_stage(
            message,
            candidate,
            context_bundle.relationship_kind,
            context_bundle.relationship_label,
            reply_mode=reply_mode,
            noban=False,
        )
    try:
        for _ in range(MAX_TOOL_ROUNDS):
            payload = {
                "model": "deepseek-chat",
                "messages": messages,
                "tool_choice": "auto" if tools else None,
                "max_tokens": max_output_tokens,
                "stream": False,
            }
            # 状态引擎（B）：情绪 → 采样温度（happy 1.1 / normal 1.0 / low·低精力 0.9）。
            if policy is not None:
                payload["temperature"] = policy.get("temperature", 1.0)
            if tools:
                payload["tools"] = tools
            else:
                payload.pop("tool_choice", None)
            resp = httpx.post(
                "https://api.deepseek.com/chat/completions",
                headers={"Authorization": f"Bearer {config.DEEPSEEK_API_KEY}", "Content-Type": "application/json"},
                json=payload,
                timeout=60,
            )
            resp.raise_for_status()
            _choice = resp.json()["choices"][0]
            msg = _choice["message"]
            finish_reason = _choice.get("finish_reason")
            tool_calls = msg.get("tool_calls")
            if not tool_calls:
                candidate = apply_response_guards(msg.get("content") or "")
                if reply_needs_regeneration(
                    candidate,
                    reply_mode,
                    reply_max_chars=target_chars,
                    reply_bubble_count=int(reply_bubble_count or 1),
                    voice_reply_requested=voice_reply_requested,
                    finish_reason=finish_reason,
                    policy=policy,
                ):
                    repair_messages = [
                        *messages,
                        {"role": "assistant", "content": candidate},
                        {
                            "role": "user",
                            "content": build_reply_regeneration_request(
                                candidate,
                                reply_mode,
                                reply_max_chars=target_chars,
                                reply_bubble_count=int(reply_bubble_count or 1),
                                policy=policy,
                            ),
                        },
                    ]
                    _repair_payload = {
                        "model": "deepseek-chat",
                        "messages": repair_messages,
                        "max_tokens": max_output_tokens,
                        "stream": False,
                    }
                    if policy is not None:
                        _repair_payload["temperature"] = policy.get("temperature", 1.0)
                    try:
                        repair_resp = httpx.post(
                            "https://api.deepseek.com/chat/completions",
                            headers={
                                "Authorization": f"Bearer {config.DEEPSEEK_API_KEY}",
                                "Content-Type": "application/json",
                            },
                            json=_repair_payload,
                            timeout=60,
                        )
                        repair_resp.raise_for_status()
                        repaired = (
                            repair_resp.json()["choices"][0]["message"].get("content")
                            or ""
                        ).strip()
                        if repaired:
                            guarded_repair = apply_response_guards(repaired)
                            old_metrics = reply_output_metrics(
                                candidate,
                                reply_mode,
                                reply_bubble_count=int(reply_bubble_count or 1),
                            )
                            new_metrics = reply_output_metrics(
                                guarded_repair,
                                reply_mode,
                                reply_bubble_count=int(reply_bubble_count or 1),
                            )
                            # 修复版至少要在字数和有效气泡两个维度都不退步；否则保留
                            # 第一版，避免一次格式修复把可用回复变得更短。
                            if (
                                new_metrics[0] >= old_metrics[0]
                                and new_metrics[1] >= old_metrics[1]
                            ):
                                candidate = guarded_repair
                    except Exception:
                        # 自动重写是质量增强，不能让一次失败把原本可用的聊天变成红叹号。
                        logger.exception("回复字数/气泡自动重写失败，保留第一版")
                # 状态引擎（B）：本轮生成被接受才把推进后的状态落库。
                if policy is not None:
                    state_engine.apply_state(character_id, state)
                return candidate
            # AI 请求工具：回填 assistant 消息 + 逐条执行结果，继续下一轮
            messages.append(msg)
            for tc in tool_calls:
                fn = tc.get("function", {})
                name = fn.get("name", "")
                try:
                    args = json.loads(fn.get("arguments") or "{}")
                except (ValueError, TypeError):
                    args = {}
                result = _execute_tool(name, args, character_id)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.get("id", ""),
                    "content": json.dumps(result, ensure_ascii=False),
                })
        # 达到轮次上限仍未给最终文本 → 兜底提示
        return "（工具查询次数过多，请换个问法试试）"
    except AIGatewayError:
        raise
    except Exception as exc:  # 断网 / 宕机 / 限流 → 严格只走网关
        raise AIGatewayError(f"AI provider 调用失败: {exc}") from exc


def _match_mentioned_member(
    members: list[dict], text: str
) -> str | None:
    """用户消息里提到谁（@名 或名字子串）就选谁；无则 None。"""
    t = text or ""
    for m in members:
        name = (m.get("name") or "").strip()
        if name and f"@{name}" in t:
            return m["id"]
    for m in members:
        name = (m.get("name") or "").strip()
        if name and name in t:
            return m["id"]
    return None


def _last_spoken_member(
    members: list[dict], history: list[dict]
) -> str | None:
    """最近发言成员 id：扫描群历史（内容带「成员名：」前缀）的最后一个 assistant 消息。"""
    for h in reversed(history or []):
        content = h.get("content") or ""
        for m in members:
            name = (m.get("name") or "").strip()
            if name and content.startswith(f"{name}："):
                return m["id"]
    return None


def select_group_speaker(
    members: list[dict],
    worldbook: dict | None,
    group_name: str,
    history: list[dict],
    current_message: str,
) -> str:
    """自动选人：DeepSeek JSON 决定本轮哪个群成员发言；失败走确定性回退，绝不抛错。

    - members：[{id, name, tagline}]；
    - worldbook：群世界书（{name, ...} | None）；
    - history：群历史（[{role, content}]，内容带「成员名：」前缀）。
    回退链：@名/名字匹配 → 最近未发言成员 → 首个成员。
    """
    if not members:
        return "assistant"

    mention_id = _match_mentioned_member(members, current_message)
    if mention_id:
        return mention_id

    try:
        system_text = prompts.build_group_speaker_selector_prompt(
            members, worldbook, group_name
        )
        sel_history = [
            {"role": m["role"], "content": m["content"]}
            for m in (history or [])[-8:]
            if m.get("role") in ("user", "assistant") and isinstance(m.get("content"), str)
        ]
        resp = httpx.post(
            "https://api.deepseek.com/chat/completions",
            headers={
                "Authorization": f"Bearer {config.DEEPSEEK_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "deepseek-chat",
                "messages": [
                    {"role": "system", "content": system_text},
                    *sel_history,
                    {"role": "user", "content": current_message},
                ],
                "response_format": {"type": "json_object"},
                "max_tokens": 100,
                "stream": False,
            },
            timeout=30,
        )
        resp.raise_for_status()
        raw = resp.json()["choices"][0]["message"].get("content") or ""
        cid = str(json.loads(raw).get("character_id") or "").strip()
        if any(m["id"] == cid for m in members):
            return cid
    except Exception:
        # 选人失败不阻塞群聊：走确定性回退。
        logger.warning("群聊自动选人调用失败，走回退", exc_info=True)

    last_speaker = _last_spoken_member(members, history)
    for m in members:
        if m["id"] != last_speaker:
            return m["id"]
    return members[0]["id"]


# --------------------------------------------------------------------------- #
# /ai/memory —— 长期记忆写入 / 提取
# --------------------------------------------------------------------------- #
def _embed_tolerant(text: str) -> list[float] | None:
    """embed 但绝不因向量失败丢记忆：embed 异常降级存 None（内容仍落库）。"""
    try:
        return embed(text)
    except Exception:
        return None


def memory_add(
    content: str,
    type: str = "fact",
    embedding: list[float] | None = None,
    character_id: str = "assistant",
    importance: float = 0.5,
    source_mode: str = "standard",
) -> str:
    """写入一条长期记忆（type: event|fact|preference），归到 character_id 角色。

    返回记忆 id。embedding 由调用方传入（prod 用 BGE-M3；dev 可空）。
    importance 0-1（clamp），默认 0.5；>=0.8 常驻（refine 保护）。
    """
    with db.SessionLocal() as s:
        mem = Memory(
            id=uuid7(),
            type=type,
            content=content,
            embedding=embedding,
            character_id=character_id,
            importance=max(0.0, min(1.0, float(importance or 0.5))),
            source_mode="noban" if source_mode == "noban" else "standard",
        )
        s.add(mem)
        s.commit()
        return mem.id


def memory_update(
    memory_id: str,
    content: str | None = None,
    type: str | None = None,
    importance: float | None = None,
) -> Memory | None:
    """更新一条记忆：改 content 时重算 embedding（_embed_tolerant，失败降级 None）。

    返回更新后的 Memory；不存在返回 None。
    """
    with db.SessionLocal() as s:
        mem = s.get(Memory, memory_id)
        if mem is None:
            return None
        if content is not None:
            mem.content = content
            mem.embedding = _embed_tolerant(content)
        if type is not None:
            mem.type = type
        if importance is not None:
            mem.importance = max(0.0, min(1.0, float(importance)))
        s.commit()
        s.refresh(mem)
        return mem


def memory_delete(memory_id: str) -> bool:
    """删除一条记忆；不存在返回 False。"""
    with db.SessionLocal() as s:
        mem = s.get(Memory, memory_id)
        if mem is None:
            return False
        s.delete(mem)
        s.commit()
        return True


# 记忆提取（013）：LLM 优先 + 低成本预筛 + 降级 regex。返回 [(type, content, importance)]。
# importance 0-1：0.8+ 强烈偏好/身份事实（常驻，refine 保护）；0.5 普通；0.3 弱相关（过时候选）。

# 自我指涉/持久事实线索：命中才值得调 LLM（控成本）
_MEMORY_CUE_RE = re.compile(
    r"我|我的|用户|猫|狗|宠物|家住|住在|上班|工作|读书|学校|毕业|喜欢|讨厌|习惯|经常|每天|从不"
    r"|过敏|生日|买了|去了|吃了|喝了|养了|最(?:喜欢|爱|讨厌)|想学|想买|目标|计划"
)

_EXTRACT_SYSTEM_PROMPT = (
    "你是 LifeHub 的记忆整理器。从用户消息中提取值得长期记住的事实。"
    "只提取关于用户的持久信息（偏好/身份/重要事实/真正重要的一次性事件）。"
    "用‘30天后仍然有用且脱离当前对话仍能独立理解’作为硬标准。忽略寒暄、调情玩笑、"
    "图片指代、提问、即时状态、未确认猜测和普通日常事件。用户对回复方式的要求属于 preference，"
    "不要写成用户事实。"
    "输出严格 JSON："
    '{"memories":[{"type":"preference|fact|event","content":"用「用户」开头的第三人称规范化描述","importance":0.5}]}'
    "importance 0-1：0.8+ 强烈偏好/身份事实；0.5 普通；0.3 弱相关。最多 3 条。"
)

_EXCHANGE_MEMORY_CUE_RE = re.compile(
    r"约定|答应|拒绝|道歉|原谅|争吵|和好|第一次|关系|边界|越界|不舒服|重要"
    r"|喜欢你|爱你|朋友|恋人|暧昧|认识|以后|记住"
)

_EXCHANGE_EXTRACT_SYSTEM_PROMPT = (
    "你是 LifeHub 的关系记忆整理器。输入包含一轮用户消息和角色回复。"
    "提取30天后仍值得角色记住的用户持久事实，或双方已经真实发生并确认的重要关系事件，"
    "例如明确约定、拒绝与边界、道歉和原谅、关系确认、重要冲突。"
    "用户单方面提出但角色没有同意的事情绝不能写成已经发生；调情、假设、测试和普通闲聊忽略。"
    "关系事件用‘用户与角色……’写成脱离原对话也能理解的第三人称事实。"
    "输出严格 JSON："
    '{"memories":[{"type":"preference|fact|event","content":"规范化描述","importance":0.5}]}'
    "importance 0-1，重要边界或关系确认可为0.75以上。最多3条。"
)


def _is_memory_worthy(message: str) -> bool:
    """低成本预筛：过短 / 提问 / 纯寒暄 → False（不调 LLM）。"""
    s = (message or "").strip()
    if len(s) < 4:
        return False
    if re.search(r"[？?]\s*$|吗\s*$|呢\s*$|吧\s*$|怎么|如何|哪些|为什么|什么时候|几点", s):
        return False  # 提问是查询，不是事实
    if re.fullmatch(r"[嗯哦哈好的知道了哈哈谢谢晚安拜拜]+", s):
        return False  # 纯寒暄/语气词
    return bool(_MEMORY_CUE_RE.search(s))


def _regex_extract(message: str) -> list[tuple[str, str, float]]:
    """降级：启发式识别「我喜欢/我讨厌/我习惯/我经常/我每天」句式。"""
    results: list[tuple[str, str, float]] = []
    pref_patterns = [
        r"(?:我喜欢|我爱|我超喜欢|我特别喜欢吃?|我最爱吃?)[：:，,\s]*(.{1,30})",
        r"(?:我讨厌|我不喜欢|我受不了)[：:，,\s]*(.{1,30})",
        r"(?:我习惯|我经常|我每天)[：:，,\s]*(.{1,30})",
    ]
    for p in pref_patterns:
        for m in re.finditer(p, message):
            content = m.group(1).strip()
            if content and len(content) >= 2:
                results.append(("preference", f"用户{content}", 0.5))
    return results[:5]


def _llm_extract_memories(
    message: str,
    *,
    system_prompt: str = _EXTRACT_SYSTEM_PROMPT,
) -> list[tuple[str, str, float]]:
    """LLM 提取：镜像 memory_refine._llm_refine 的 DeepSeek 调用模式。"""
    resp = httpx.post(
        "https://api.deepseek.com/chat/completions",
        headers={"Authorization": f"Bearer {config.DEEPSEEK_API_KEY}", "Content-Type": "application/json"},
        json={
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.2,
            "stream": False,
        },
        timeout=60,
    )
    resp.raise_for_status()
    content = resp.json()["choices"][0]["message"].get("content") or ""
    try:
        obj = json.loads(content)
    except (ValueError, TypeError):
        obj = None
    entries = obj.get("memories") if isinstance(obj, dict) else None
    out: list[tuple[str, str, float]] = []
    for m in entries or []:
        if not isinstance(m, dict):
            continue
        mtype = m.get("type")
        mcontent = str(m.get("content") or "").strip()
        if mtype not in ("preference", "fact", "event") or not mcontent:
            continue
        try:
            imp = float(m.get("importance") or 0.5)
        except (TypeError, ValueError):
            imp = 0.5
        imp = max(0.0, min(1.0, imp))
        if re.search(r"可能|也许|大概|似乎|不确定|或许", mcontent):
            continue
        if mtype == "event" and imp < 0.65:
            continue
        out.append((mtype, mcontent, imp))
    return out[:5]


def extract_memories_from_message(
    message: str,
    assistant_reply: str | None = None,
) -> list[tuple[str, str, float]]:
    """从用户消息及可选角色回复提取持久事实和已确认的关系事件。

    优先 LLM 抽取（含 importance）；预筛不过 / 未配置 key / LLM 失败 → 降级 regex。
    返回 [(type, content, importance)]，type ∈ preference|fact|event。
    """
    if not message or not message.strip():
        return []
    exchange_worthy = bool(
        assistant_reply
        and _EXCHANGE_MEMORY_CUE_RE.search(f"{message}\n{assistant_reply}")
    )
    if not exchange_worthy and not _is_memory_worthy(message):
        return _regex_extract(message)
    if config.DEEPSEEK_API_KEY:
        try:
            if exchange_worthy:
                source = f"用户消息：{message}\n角色回复：{assistant_reply or ''}"
                extracted = _llm_extract_memories(
                    source,
                    system_prompt=_EXCHANGE_EXTRACT_SYSTEM_PROMPT,
                )
            else:
                extracted = _llm_extract_memories(message)
            if extracted:
                return extracted
        except Exception:
            logger.exception("LLM 记忆提取失败，降级 regex")
    return _regex_extract(message)


# --------------------------------------------------------------------------- #
# /ai/embedding —— BGE-M3
# --------------------------------------------------------------------------- #
def _dev_embed(text: str) -> list[float]:
    """无 BGE-M3 端点时的确定性占位向量（仅验证契约，不做真实语义检索）。"""
    seed = int.from_bytes(hashlib.sha256(text.encode("utf-8")).digest()[:8], "big")
    v = [0.0] * EMBED_DIM
    s = seed
    for i in range(EMBED_DIM):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        v[i] = (s / 0x7FFFFFFF) - 0.5
    norm = sum(x * x for x in v) ** 0.5
    if norm > 0:
        v = [x / norm for x in v]
    return v


def embed(text: str) -> list[float]:
    """文本 → EMBED_DIM 维向量（OpenAI 兼容 /v1/embeddings，供应商由 config.EMBEDDING_* 决定）。

    返回向量长度必须 == EMBED_DIM（与 memory.embedding vector(1024) 契约一致），
    不匹配即抛错——调用方 _embed_tolerant 会降级存 None，避免把错误维度写进库。
    注意：请求体刻意不带 provider 专有字段（如 dimensions），靠模型默认维度；换供应商
    只改 config，不改这里。
    """
    if config.EMBEDDING_ENDPOINT and config.EMBEDDING_API_KEY:
        try:
            resp = httpx.post(
                config.EMBEDDING_ENDPOINT,
                headers={"Authorization": f"Bearer {config.EMBEDDING_API_KEY}", "Content-Type": "application/json"},
                json={"input": text, "model": EMBED_MODEL},
                timeout=30,
            )
            resp.raise_for_status()
            emb = resp.json()["data"][0]["embedding"]
            if len(emb) != EMBED_DIM:
                raise ValueError(f"embedding 维度 {len(emb)} != EMBED_DIM {EMBED_DIM}")
            return emb
        except Exception as exc:
            raise RuntimeError(f"[EMBED_UNAVAILABLE] {exc}") from exc
    return _dev_embed(text)


# --------------------------------------------------------------------------- #
# /ai/memory/search —— Memory Retriever
# dev（SQLite / 无向量）：importance + 新鲜度混合排序（score=None）。
# prod（PG + pgvector）：余弦相似 + importance + 访问新鲜度混合打分（013）。
# --------------------------------------------------------------------------- #
def _touch_last_accessed(ids: list[str]) -> None:
    """检索命中后节流更新 last_accessed_at（10 分钟窗口，防写放大）；失败忽略不影响检索。"""
    if not ids:
        return
    try:
        with db.SessionLocal() as s:
            if db.IS_PG:
                s.execute(
                    text(
                        "UPDATE memory SET last_accessed_at = now() WHERE id = ANY(:ids) "
                        "AND (last_accessed_at IS NULL OR last_accessed_at < now() - interval '10 minutes')"
                    ),
                    {"ids": ids},
                )
            else:
                s.query(Memory).filter(Memory.id.in_(ids)).update(
                    {Memory.last_accessed_at: datetime.now(timezone.utc)},
                    synchronize_session=False,
                )
            s.commit()
    except Exception:
        logger.exception("last_accessed_at 节流更新失败（不影响检索）")


def _lexical_memory_units(value: str) -> set[str]:
    """无向量服务时的保守检索单元：英文词 + 中文相邻二元组。"""
    text_value = (value or "").casefold()
    units = set(re.findall(r"[a-z0-9_]{2,}", text_value))
    for chunk in re.findall(r"[\u3400-\u9fff]+", text_value):
        if len(chunk) == 1:
            units.add(chunk)
        else:
            units.update(chunk[index : index + 2] for index in range(len(chunk) - 1))
    return units


def _lexical_memory_relevance(query: str, content: str) -> float:
    query_units = _lexical_memory_units(query)
    content_units = _lexical_memory_units(content)
    if not query_units or not content_units:
        return 0.0
    overlap = len(query_units & content_units)
    if overlap == 0:
        return 0.0
    query_coverage = overlap / len(query_units)
    content_coverage = overlap / len(content_units)
    return 0.8 * query_coverage + 0.2 * content_coverage


def memory_search(
    query: str,
    limit: int = 5,
    character_id: str | None = None,
) -> list[dict]:
    """记忆检索（每角色独立：character_id 传则只在所属角色内搜，None=全角色兼容）。
    只返回 active（提炼 012 后 superseded/archived 不再注入上下文）。

    排名（013）：语义相似 0.6 + importance 0.25 + 访问新鲜度 0.15（30 天衰减）。
    """
    if db.IS_PG and config.EMBEDDING_ENDPOINT and config.EMBEDDING_API_KEY:
        vec = embed(query)
        # 查询向量序列化成 pgvector 文本格式再 CAST：直接绑 list 会变成 double precision[]，
        # pgvector 无该 → vector 的隐式转换（`<=>` 要求 vector），首跑即报 UndefinedFunction。
        vec_sql = "[" + ",".join(str(round(x, 6)) for x in vec) + "]"
        where = " WHERE status = 'active' AND embedding IS NOT NULL"
        # 禁止事项不进检索：单独 memory_forbidden() 常驻注入
        where += " AND type != 'forbidden'"
        params: dict = {"vec": vec_sql, "lim": limit}
        if character_id:
            where += " AND character_id = :cid"
            params["cid"] = character_id
        with db.SessionLocal() as s:
            rows = s.execute(
                text(
                    "SELECT id, type, content, "
                    "(0.6 * (1 - (embedding <=> CAST(:vec AS vector)))"
                    " + 0.25 * COALESCE(importance, 0.5)"
                    " + 0.15 * (1.0 - LEAST(1.0, EXTRACT(EPOCH FROM (now() - "
                    "COALESCE(last_accessed_at, created_at))) / 2592000.0))) AS score "
                    f"FROM memory{where} ORDER BY score DESC, id LIMIT :lim"
                ),
                params,
            ).fetchall()
            result = [{"id": r[0], "type": r[1], "content": r[2], "score": float(r[3])} for r in rows]
            _touch_last_accessed([r[0] for r in rows])
            return result

    # 无向量端点时只注入词面相关的记忆。旧实现把“最近 5 条”无条件塞进每轮，
    # 连“嘿嘿嘿”都会带入泡妞/跳舞等无关事实，直接污染短期上下文。
    with db.SessionLocal() as s:
        q = s.query(Memory).filter(Memory.status == "active")
        if character_id:
            q = q.filter(Memory.character_id == character_id)
        q = q.filter(Memory.type != "forbidden")
        rows = q.order_by(Memory.created_at.desc()).limit(max(limit * 10, 100)).all()
    now = datetime.now(timezone.utc)

    def _recency(m: Memory) -> float:
        ref = m.last_accessed_at or m.created_at
        if ref is None:
            return 0.0
        if ref.tzinfo is None:
            ref = ref.replace(tzinfo=timezone.utc)
        days = max(0.0, (now - ref).total_seconds() / 86400.0)
        return max(0.0, 1.0 - days / 30.0)

    ranked = []
    for row in rows:
        relevance = _lexical_memory_relevance(query, row.content or "")
        if relevance < 0.1:
            continue
        score = (
            0.75 * relevance
            + 0.15 * (row.importance or 0.5)
            + 0.10 * _recency(row)
        )
        ranked.append((score, row))
    ranked.sort(key=lambda item: (item[0], item[1].id), reverse=True)
    chosen = ranked[:limit]
    result = [
        {"id": row.id, "type": row.type, "content": row.content, "score": score}
        for score, row in chosen
    ]
    _touch_last_accessed([row.id for _, row in chosen])
    return result


def memory_forbidden(character_id: str) -> list[dict]:
    """拉取某角色全部 active 禁止事项（type='forbidden'），按时间倒序。

    禁止事项是硬约束：不走检索（不依赖 query 命中）、不受 memory_enabled 开关
    影响，每轮对话常驻注入（调用方在组装 chat() 时主动传入）。
    """
    with db.SessionLocal() as s:
        rows = (
            s.query(Memory)
            .filter(
                Memory.status == "active",
                Memory.type == "forbidden",
                Memory.character_id == character_id,
            )
            .order_by(Memory.created_at.desc())
            .all()
        )
    return [
        {"id": r.id, "type": r.type, "content": r.content, "score": 1.0}
        for r in rows
    ]
