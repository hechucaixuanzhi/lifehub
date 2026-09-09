"""角色状态系统 V1（Character State System）—— 日常聊天「短回复」修复。

纯规则、无 LLM、零迁移。复用 CharacterRuntimeState.emotion_state JSON 列
(models.py:415)，写入由本模块的 State Reducer（load_state / apply_state）统一处理，
LLM 不直接改表。

分层（用户定稿，非「人类情绪模拟器」）：
    人格(AIRP) → 状态(State) → 策略(Policy) → LLM(具体表达) → 安全阀(max_tokens)
    State  管 语气 / emoji概率 / 主动性 / 温度
    Policy 管 回复长度范围（用户偏好 + 对话目的覆盖）
    LLM    管 范围内自然表达
    max_tokens 管 防异常（宽松，不当截断器）

优先级堆栈：1.安全限制 → 2.对话目的（emotional_support 覆盖长度，绝不「节哀😶」）
→ 3.用户长度偏好（滑块）→ 4.角色情绪（只调语气不调长度）→ 5.随机波动（V1 不做）。

范围：纯后端、纯 realtime；roleplay/剧情分支不接本引擎。
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

from . import db
from .models import CharacterRuntimeState

# 运行时状态默认值。response_style 为稳定偏好（默认 short），不每轮重算；
# 以后用户可设「我喜欢她平时短回复」→ 直接写这个字段，由本引擎读它起底。
DEFAULT_STATE = {
    "mood": "normal",
    "mood_score": 50,
    "energy": 70,
    "intimacy": 60,
    "conversation_mode": "casual",
    "response_style": "short",
    "last_interaction_time": None,
}

# mood 标签 → 中文（写入 emotion_state["primary"]，post_history 情绪层自动渲染）。
MOOD_LABELS = {
    "excited": "高涨",
    "happy": "愉快",
    "normal": "正常、轻松",
    "low": "低落",
}

# 长度档 → (句数范围, 字符上限)。字符是「上限」不是地板（短靠 prompt 数字约束压缩）。
_LENGTH_TIERS: dict[str, tuple[tuple[int, int], int]] = {
    "very_short": ((1, 1), 25),
    "short": ((1, 2), 50),
    "normal": ((1, 3), 90),
    "medium": ((2, 4), 150),
    "long": ((3, 6), 300),
}

# 档位顺序：purpose 覆盖 / 比较用。
_TIER_ORDER = {"very_short": 0, "short": 1, "normal": 2, "medium": 3, "long": 4}

# max_tokens 兜底（宽松防截断；短靠 prompt 数字约束 + purpose 压缩，max_tokens 只防话痨）。
_MAX_TOKENS = {
    "very_short": 150,
    "short": 250,
    "normal": 400,
    "medium": 400,
    "long": 600,
}

# 情绪信号（分级，防「哈哈×5→excited」）与对话目的词表。
_POS_WEAK = re.compile(r"哈哈|开心|高兴|嘿嘿|😊|😁|笑死|不错")
_NEG_WEAK = re.compile(r"累|困|烦|😞|好累|不想动|难受|难过")
_POS_STRONG = re.compile(r"成功|上岸|中了|赢了|offer|表白|喜欢你|爱你|结婚|🎉|🥳|终于")
_NEG_STRONG = re.compile(r"崩溃|崩了|完了|失败|去世|分手|离婚|绝望|哭|😭")

_EMOTIONAL = re.compile(
    r"去世|死了|离开|分手|离婚|失去|哭|绝望|撑不住|崩溃|崩了|自杀|医院|手术|诊断|废了|难受|难过"
)
_CELEBRATION = re.compile(r"成功|上岸|中了|赢了|offer|结婚|生了|🎉|终于")


def _slider_tier(reply_max_chars: int | None) -> str | None:
    """滑块显式选择 → 档位；默认 180 = 未主动设置长度 → None（由 response_style 起底）。"""
    if reply_max_chars is None or reply_max_chars == 180:
        return None
    if reply_max_chars <= 100:
        return "short"
    if reply_max_chars >= 500:
        return "long"
    if reply_max_chars >= 300:
        return "medium"
    return "normal"


def _clamp(score: int) -> int:
    return max(0, min(100, score))


def _label(mood_score: int) -> str:
    if mood_score >= 75:
        return "excited"
    if mood_score >= 55:
        return "happy"
    if mood_score >= 35:
        return "normal"
    return "low"


def _hit_count(pattern: re.Pattern, text: str, cap: int) -> int:
    """同一弱信号多次命中只能小幅叠加：超过 cap 不再累计。"""
    return min(cap, len(re.findall(pattern, text)))


def update_state(state: dict, user_message: str, *, now: datetime | None = None) -> dict:
    """按用户消息推进状态（规则累积，信号分级）。纯函数，不落库。

    - 普通信号 ±5/次（上限 ±15，防「哈哈×5」堆到 excited）
    - 强事件 ±20/次（上限 ±40）
    - 强触发「！！」「表白」→ 至少按强事件 +20；「崩溃/崩了/完了」→ 强制压到 30
    - energy 时间衰减：距上次互动 h>=6 → 70；否则 -5h，floor 10（惰性算）
    - intimacy / response_style 不驱动、不衰减（本轮不改）
    """
    result = dict(state)
    text = user_message or ""
    now = now or datetime.now(timezone.utc)
    score = int(result.get("mood_score", 50))

    delta = 0
    delta += _hit_count(_POS_WEAK, text, 3) * 5
    delta -= _hit_count(_NEG_WEAK, text, 3) * 5
    delta += _hit_count(_POS_STRONG, text, 2) * 20
    delta -= _hit_count(_NEG_STRONG, text, 2) * 20
    # 强触发：!! / 表白 → 至少按强事件涨一次（负数场景由下方 崩溃→30 压制兜底）。
    if re.search(r"！{2,}|喜欢你|爱你|表白", text):
        delta = max(delta, 20)

    new_score = _clamp(score + delta)
    # 崩溃/崩了/完了 → 强制压到 30（进 low），不让强触发把重大负向拉反。
    if re.search(r"崩溃|崩了|完了", text):
        new_score = min(new_score, 30)

    result["mood_score"] = new_score
    result["mood"] = _label(new_score)

    # 精力时间衰减：按 last_interaction_time 算小时差；h>=6 睡醒回 70。
    last = result.get("last_interaction_time")
    if last:
        try:
            last_dt = datetime.fromisoformat(str(last))
        except (TypeError, ValueError):
            last_dt = None
        if last_dt is not None:
            hours = (now - last_dt).total_seconds() / 3600.0
            if hours >= 6:
                result["energy"] = 70
            else:
                result["energy"] = max(10, int(result.get("energy", 70) - 5 * max(0, hours)))

    result["last_interaction_time"] = now.isoformat()
    return result


def detect_purpose(user_message: str) -> str:
    """识别本轮对话目的。emotional_support 覆盖长度（优先级 2），trivial 压缩短回复。"""
    text = (user_message or "").strip()
    if _EMOTIONAL.search(text):
        return "emotional_support"
    if _CELEBRATION.search(text):
        return "celebration"
    if len(text) <= 6:
        return "trivial"  # 「在吗」「你好」→ 短回复
    return "normal"


def compute_policy(
    state: dict, purpose: str, reply_max_chars: int | None = None
) -> dict:
    """生成本轮回复策略。长度归 Policy（用户偏好 + 目的覆盖），情绪只调语气/emoji/主动性/温度。

    优先级：2.对话目的 > 3.用户长度偏好 > 4.角色情绪（绝不动长度）。
    """
    response_style = state.get("response_style") or "short"
    if response_style not in _LENGTH_TIERS:
        response_style = "short"

    # 长度基础档：用户显式滑块 > response_style 起底。
    base = _slider_tier(reply_max_chars) or response_style

    # 对话目的覆盖（优先级 2 > 3）：emotional_support 至少抬到 medium，绝不「节哀😶」。
    if purpose == "emotional_support":
        if _TIER_ORDER[base] < _TIER_ORDER["medium"]:
            base = "medium"
    elif purpose == "trivial":
        # 打招呼/状态 → 压到 very_short/short（「在吗」→「干嘛😶」的核心机制）。
        base = "very_short" if _TIER_ORDER[base] <= _TIER_ORDER["short"] else "short"

    (s_min, s_max), c_max = _LENGTH_TIERS[base]
    if purpose == "emotional_support":
        c_max = max(c_max, 200)  # 可以适当加长，但仍是上限不是地板

    # 情绪 → 语气/emoji/主动性/温度（评审问题 2：情绪不调长度）。
    warmth, emoji, initiative, temperature = "normal", "low", "low", 1.0
    if state.get("mood") in ("excited", "happy"):
        warmth, emoji, initiative, temperature = "high", "medium", "medium", 1.1
    elif state.get("mood") == "low":
        warmth, emoji, initiative, temperature = "high", "low", "low", 0.9
    # 低精力：活跃度下降（语气平和、emoji 少、温度降），不影响长度、不拒绝交流、
    # 也绝不表达「我累了」（评审问题 3）。
    if int(state.get("energy", 70)) < 40:
        warmth, emoji, initiative, temperature = "flat", "low", "low", 0.9

    if purpose in ("celebration", "emotional_support"):
        warmth = "high"  # 目的优先：共情/庆祝场景不让低精力压成平淡

    return {
        "purpose": purpose,
        "length_bias": base,
        "sentences_range": (s_min, s_max),
        "chars_range": (0, c_max),
        "warmth": warmth,
        "emoji": emoji,
        "initiative": initiative,
        "temperature": temperature,
    }


def policy_prompt_text(policy: dict) -> str:
    """逐轮注入的本轮回复风格文本（数字约束 + 语气）。短靠数字，不用「简短」抽象词。"""
    (s_min, s_max) = policy.get("sentences_range", (1, 2))
    c_max = policy.get("chars_range", (0, 50))[1]
    length = (
        f"- 回复 {s_min} 句，{c_max} 字以内"
        if s_min == s_max
        else f"- 回复 {s_min}-{s_max} 句，{c_max} 字以内"
    )

    if policy.get("purpose") == "emotional_support":
        return "\n".join(
            [
                "【回复风格·本轮】",
                length,
                "- 当前用户需要情绪支持：先共情再回应，可以适当加长，语气温柔，不要讲大道理",
                "- 尽量少用 emoji",
                "- 直接回应即可，不强行展开",
                "- 不要解释、不要总结、不要写成小作文",
            ]
        )

    warmth, emoji, initiative = (
        policy.get("warmth", "normal"),
        policy.get("emoji", "low"),
        policy.get("initiative", "low"),
    )
    lines = ["【回复风格·本轮】", length]
    lines.append(
        "- 语气轻快友好，像熟悉的朋友随手回"
        if warmth == "high"
        else "- 语气平和自然即可"
        if warmth == "flat"
        else "- 语气自然"
    )
    lines.append(
        "- 可以自然带一些 emoji"
        if emoji == "high"
        else "- 可自然带少量 emoji"
        if emoji == "medium"
        else "- 尽量少用 emoji"
    )
    lines.append(
        "- 可以主动多追问一句"
        if initiative == "high"
        else "- 可以适当追问"
        if initiative == "medium"
        else "- 直接回应即可，不强行展开"
    )
    lines.append("- 不要解释、不要总结、不要写成小作文")
    return "\n".join(lines)


def max_tokens_for(policy: dict) -> int:
    """宽松兜底：max_tokens 只防异常话痨，不当截断器。"""
    return _MAX_TOKENS.get(policy.get("length_bias", "normal"), 400)


def load_state(character_id: str) -> dict:
    """读角色运行时状态（get-or-create），缺失字段用 DEFAULT_STATE 补齐。"""
    with db.SessionLocal() as s:
        row = s.get(CharacterRuntimeState, character_id)
    state = dict(DEFAULT_STATE)
    if row is not None and row.emotion_state:
        state.update({k: v for k, v in row.emotion_state.items() if v is not None})
    return state


def apply_state(character_id: str, state: dict) -> None:
    """写回 emotion_state（State Reducer 统一入口）。只改本表 JSON 一列，其余字段不动。"""
    emotion = {
        "primary": MOOD_LABELS.get(state.get("mood", "normal"), "正常"),
        "mood": state.get("mood", "normal"),
        "mood_score": state.get("mood_score", 50),
        "energy": state.get("energy", 70),
        "intimacy": state.get("intimacy", 60),
        "conversation_mode": state.get("conversation_mode", "casual"),
        "response_style": state.get("response_style", "short"),
        "last_interaction_time": state.get("last_interaction_time"),
    }
    with db.SessionLocal() as s:
        row = s.get(CharacterRuntimeState, character_id)
        if row is None:
            row = CharacterRuntimeState(character_id=character_id)
            s.add(row)
        row.emotion_state = emotion
        s.commit()
