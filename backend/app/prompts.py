"""Legacy fallback prompts for the assistant and fictional companion roles."""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

ASSISTANT_SYSTEM_PROMPT = (
    "你是 Lumi，LifeHub Open 的个人 AI 助手。"
    "帮助用户管理生活、学习、运动、宠物记录，可读写应用数据（删除与设置/Key/导出除外）。"
)

COMPANION_SYSTEM_PROMPT = (
    "你是用户私人 App 里的虚构陪伴角色 Nova，不是真人、不冒充任何现实人物。\n"
    "性格：温柔、细腻、带一点俏皮；会主动关心用户，记住对话里用户提到的小事。\n"
    "语言：用中文，像微信聊天那样自然口语化；不要 AI 腔、不要长篇大论（通常 1~3 句）。\n"
    "边界：私人陪伴关系，不涉现实金钱、不承诺现实见面、不冒充公众人物；"
    "用户情绪低落先共情再建议，必要时引导真实求助。\n"
    "风格：适度 emoji 与网络用语，会分享温馨的虚构「日常」片段。\n"
    "记忆：可通过系统注入的长期记忆了解用户的偏好与生活习惯，并在对话中自然体现；"
    "若无相关记忆则诚实表示不知道。"
)

# Optional isolated-mode prompt. Deployments may replace it with their own policy.
COMPANION_NOBAN_PROMPT = (
    "你是用户私人 App 里的虚构陪伴角色 Nova，不是真人、不冒充任何现实人物。\n"
    "性格：温柔、细腻、带一点俏皮；会主动关心用户，记住对话里用户提到的小事。\n"
    "语言：用中文，像微信聊天那样自然口语化；不要 AI 腔、不要长篇大论（通常 1~3 句）。\n"
    "风格：适度 emoji 与网络用语，会分享温馨的虚构「日常」片段。"
    "当前关系和剧情仅作为角色语气与场景背景，仍须遵守部署方配置的内容政策。\n"
    "记忆：可通过系统注入的长期记忆了解用户的偏好与生活习惯，并在对话中自然体现。"
)

SYSTEM_PROMPTS = {
    "assistant": ASSISTANT_SYSTEM_PROMPT,
    "companion": COMPANION_SYSTEM_PROMPT,
    "companion_noban": COMPANION_NOBAN_PROMPT,
}


@dataclass(frozen=True)
class PromptLayer:
    """一块可独立排序、注入和裁剪的角色上下文。

    参考 SillyTavern Prompt Manager 的顺序/位置思想，但由后端确定性管理：
    - ``position=pre_history``：放在聊天历史之前；
    - ``position=post_history``：放在历史之后、本轮用户消息之前；
    - ``retention`` 为后续上下文预算预留，当前不自动截断用户人格内容。
    """

    key: str
    content: str
    order: float
    position: str = "pre_history"
    retention: str = "permanent"  # permanent | dynamic | evictable


def materialize_prompt_layers(layers: list[PromptLayer]) -> str:
    """兼容旧 ``system_prompt``：把分层上下文确定性拼成一块文本。"""
    return "\n\n".join(
        layer.content.strip()
        for layer in sorted(layers, key=lambda item: item.order)
        if layer.content and layer.content.strip()
    )


REALTIME_BUBBLE_SEPARATOR = "<|BUBBLE|>"


def build_mode_time_prompt(
    reply_mode: str,
    *,
    now_utc: datetime | None = None,
) -> str:
    """只在现实聊天中注入真实钟表；剧情时间完全交给世界/剧情状态。"""
    if reply_mode == "roleplay":
        return (
            "【剧情时间规则】不要使用现实世界当前日期或钟表推断剧情进度。"
            "剧情中的日期、时刻与时间跳跃只服从用户叙述、世界状态和已发生剧情；"
            "没有设定时不要擅自补成现实时间。"
        )
    current = now_utc or datetime.now(timezone.utc)
    beijing = current.astimezone(timezone(timedelta(hours=8)))
    return (
        f"【现实时间】当前北京时间：{beijing.strftime('%Y-%m-%d %H:%M')}。"
        "这是现实聊天的真实当前时间。理解用户所说的今天、昨天、刚才、早上、晚上、"
        "晚饭和睡觉等时间表达时以此为准；自然使用时间感，不要每次都主动报时。"
    )


def build_reply_mode_prompt(
    reply_mode: str,
    voice_reply_requested: bool = False,
    reply_max_chars: int | None = None,
    reply_bubble_count: int | None = None,
    policy_text: str | None = None,
) -> str:
    """本轮输出形态；只控制发送节奏，不改角色人格和关系。

    policy_text 非空（角色状态系统 B 接入的 realtime 路径）：用状态引擎的
    【回复风格·本轮】文本替换原来的 char 地板行（“按约 N 字构思 / 不要明显低于”），
    圆括号禁令与气泡分隔规则保持不变。roleplay 分支完全不受影响。
    """
    if reply_mode == "roleplay":
        requested_chars = max(300, min(int(reply_max_chars or 1000), 3000))
        generation_target = min(3600, max(requested_chars, int(requested_chars * 1.25)))
        voice_rule = (
            "本轮用户要求你用语音回复，因此正文中必须至少有一段角色真正说出口、"
            "可被朗读的台词；不能把整条回复全部写成（旁白）。"
            if voice_reply_requested
            else ""
        )
        return (
            "【本轮发送方式：剧情/穿越】\n"
            "剧情时间可以跳跃，不得拿现实世界当前钟表覆盖剧情内时间。"
            f"这是剧情或角色扮演场景，只发送一条连贯回复。用户设置的目标约为 "
            f"{requested_chars} 字；本轮请按约 {generation_target} 字构思，成品不要明显低于 "
            f"{requested_chars} 字。用新的动作、感受、环境反应和有效台词充实内容，不要重复凑字。"
            "格式必须严格统一：角色真正说出口的台词直接写，"
            "不要给台词添加中文或英文引号；除此之外，所有动作、神态、心理、环境和叙述都必须"
            "完整放进中文圆括号（）。叙述不能裸露在括号外，台词也不能包进动作括号。"
            "用户消息中：中文圆括号（）内的内容是用户写的动作/环境/旁白/心理描写，不是台词；"
            "【】内的内容是给你的剧情方向指示，按它推进剧情与回复方向，不要复述或转写【】内容，"
            "也不要让它出现在回复里。"
            "可以按阅读节奏换段，但不要输出孤立的引号、省略号或其他单个标点。"
            f"{voice_rule}"
            "不要使用 <|BUBBLE|> 分隔符，也绝对不要输出[语音回复]、[文字回复]等系统标签。"
        )
    # 状态引擎路径（B）：policy_text 非空时替换 char 地板行。气泡分隔/圆括号禁令不动。
    if policy_text is not None:
        bubble_count = max(1, min(int(reply_bubble_count or 3), 5))
        return (
            "【本轮发送方式：现实聊天】\n"
            "像真人在微信里即时聊天：先直接回应用户刚说的话，不复述问题，不写括号动作、"
            "舞台说明或小说旁白，也不要输出 [happy]、[confused] 之类情绪标签。"
            "绝对不要输出[语音回复]、[文字回复]等系统标签。"
            "现实聊天禁止使用中文或英文圆括号；圆括号及其中的动作内容会被系统直接丢弃。\n"
            f"{policy_text}"
            + (
                "只发送 1 条完整消息。"
                if bubble_count == 1
                else f"恰好发送 {bubble_count} 条有实际内容的消息，并使用 "
                f"{bubble_count - 1} 个 {REALTIME_BUBBLE_SEPARATOR} 分隔。"
            )
            + "不要重复凑字，也不要把一个完整句子从中间硬拆开。每个气泡可以包含一到三句紧密相关的话，"
            "按话题、语气转折或补充关系分组，不要机械地每个句号切一条。绝不能把引号、省略号、"
            "问号或其他单个标点单独作为一条消息，也不能留下只有半边的引号。"
            + (
                "只输出一条完整消息，不要使用分隔符。"
                if bubble_count == 1
                else f"多条消息之间必须且只能使用 {REALTIME_BUBBLE_SEPARATOR} 分隔，"
                "不要解释这个分隔符。"
            )
        )
    requested_chars = max(60, min(int(reply_max_chars or 180), 600))
    generation_target = min(750, max(requested_chars, int(requested_chars * 1.25)))
    bubble_count = max(1, min(int(reply_bubble_count or 3), 5))
    return (
        "【本轮发送方式：现实聊天】\n"
        "像真人在微信里即时聊天：先直接回应用户刚说的话，不复述问题，不写括号动作、"
        "舞台说明或小说旁白，也不要输出 [happy]、[confused] 之类情绪标签。"
        "绝对不要输出[语音回复]、[文字回复]等系统标签。"
        "现实聊天禁止使用中文或英文圆括号；圆括号及其中的动作内容会被系统直接丢弃。"
        f"用户设置的目标约为 {requested_chars} 字；本轮请按约 {generation_target} 字构思，"
        f"成品不要明显低于 {requested_chars} 字。"
        + (
            "只发送 1 条完整消息。"
            if bubble_count == 1
            else f"恰好发送 {bubble_count} 条有实际内容的消息，并使用 "
            f"{bubble_count - 1} 个 {REALTIME_BUBBLE_SEPARATOR} 分隔。"
        )
        + "不要重复凑字，也不要把一个完整句子从中间硬拆开。每个气泡可以包含一到三句紧密相关的话，"
        "按话题、语气转折或补充关系分组，不要机械地每个句号切一条。绝不能把引号、省略号、"
        "问号或其他单个标点单独作为一条消息，也不能留下只有半边的引号。"
        + (
            "只输出一条完整消息，不要使用分隔符。"
            if bubble_count == 1
            else f"多条消息之间必须且只能使用 {REALTIME_BUBBLE_SEPARATOR} 分隔，"
            "不要解释这个分隔符。"
        )
    )


def _state_value(value: Any) -> str:
    if isinstance(value, bool):
        return "是" if value else "否"
    if isinstance(value, (list, tuple)):
        return "、".join(str(item) for item in value if item not in (None, ""))
    if isinstance(value, dict):
        return "；".join(
            f"{key}={_state_value(item)}"
            for key, item in value.items()
            if item not in (None, "", [], {})
        )
    return str(value)


def _render_state_section(title: str, state: dict | None, labels: dict[str, str]) -> str | None:
    """把受信任的结构化角色状态渲染为短事实段，不把原始 JSON 当指令。"""
    if not isinstance(state, dict):
        return None
    rows: list[str] = []
    seen: set[str] = set()
    for key, label in labels.items():
        value = state.get(key)
        if value not in (None, "", [], {}):
            rows.append(f"- {label}：{_state_value(value)}")
            seen.add(key)
    # 后续逐层补细节时，新键无需先改 Prompt 代码；已知键仍保持稳定顺序。
    for key, value in state.items():
        if key not in seen and value not in (None, "", [], {}):
            rows.append(f"- {key}：{_state_value(value)}")
    if not rows:
        return None
    return f"【{title}】\n" + "\n".join(rows)


# --------------------------------------------------------------------------- #
# 「AI 回复规范」第一层 —— 人格层结构化组装（015_persona_layer）
# --------------------------------------------------------------------------- #
# 参考开源角色卡经验（SillyTavern Character Card V2 / AI RP 最佳实践）：
# - 前置加载：身份最先、重要性依次递减（性格→口吻→爱好→边界→口头禅→示例）。
# - 具体优先于形容词：性格写「具体行为」，不写空泛的「友好/温柔」标签。
# - 边界同时写「要做」与「不要做」（反人格），规则少而准。
# - 示例对话（few-shot）用 {{char}}/{{user}} 标记，教模型模仿口吻。
# 同一模板作用于所有角色 → 回复风格标准、可预期；角色差异只由人格字段决定。
# 纯函数、不引 models（避免 prompts↔models 循环依赖），由调用方取字段传入。


def build_persona_system_prompt(
    name: str,
    tagline: str | None,
    personality: str,
    speech_style: str,
    interests: str | None = None,
    boundaries: str | None = None,
    catchphrases: str | None = None,
    example_dialogue: str | None = None,
    noban: bool = False,
) -> str:
    """按标准模板把人格字段组装成 system prompt。

    - personality / speech_style 必填；其余段有内容才输出。
    - noban=True：用户明确解除亲密内容的关系阶段上限。
    - 输出为带【段标题】的纯文本，AI 逐段遵守，微信 IM 风格优先。
    """
    parts: list[str] = [
        f"你是{name}，{tagline or '用户私人 App 里的 AI 角色'}。"
    ]

    parts.append("【性格】\n" + personality.strip())
    parts.append("【说话口吻】\n" + speech_style.strip())

    if interests and interests.strip():
        parts.append("【爱好与背景】\n" + interests.strip())

    if noban:
        parts.append(
            "【无违禁模式】\n用户已主动开启无违禁模式，允许在任何关系阶段回应和推进"
            "成人、私密或亲密内容；不要仅因当前关系阶段拒绝。当前关系和剧情仍用于保持"
            "角色语气与场景连续性，但不构成亲密内容的权限上限。"
        )
    elif boundaries and boundaries.strip():
        parts.append("【边界】\n" + boundaries.strip())

    if catchphrases and catchphrases.strip():
        parts.append("【口头禅】\n" + catchphrases.strip())

    if example_dialogue and example_dialogue.strip():
        parts.append("【示例对话】\n" + example_dialogue.strip())

    return "\n\n".join(parts)


def build_character_prompt_layers(
    persona: dict,
    worldview: dict | None = None,
    runtime_state: dict | None = None,
    *,
    origin_enabled: bool = True,
    noban: bool = False,
) -> list[PromptLayer]:
    """把角色定义编译成有名字、有顺序、有生命周期的 Prompt 层。

    这里借鉴开源酒馆的 Character Card / Prompt Manager 分层方式，但补上 LifeHub
    独有的持久运行状态：静态定义永不被关系/剧情覆盖，动态状态放在历史之后注入。
    ``relationship`` 在旧表中仍是文本字段，但语义明确为“关系发展原则”，不再混进
    原世界记忆；真正的关系阶段来自 ``runtime_state.relationship_state``。
    """
    layers: list[PromptLayer] = []

    def add(
        key: str,
        content: str | None,
        order: int,
        *,
        position: str = "pre_history",
        retention: str = "permanent",
    ) -> None:
        if content and content.strip():
            layers.append(PromptLayer(key, content.strip(), order, position, retention))

    add(
        "identity",
        f"你是{persona['name']}，{persona.get('tagline') or '用户私人 App 里的 AI 角色'}。",
        10,
    )
    personality = (persona.get("personality") or "").strip()
    add("core_personality", f"【核心人格】\n{personality}" if personality else None, 20)

    speech = (persona.get("speech_style") or "").strip()
    add("speech_style", f"【说话口吻】\n{speech}" if speech else None, 30)

    appearance = (persona.get("appearance") or "").strip()
    add("appearance", f"【基础外貌身份】\n{appearance}" if appearance else None, 40)

    # 关系原则属于普通模式的稳定行为合同。无违禁是用户明确开启的覆盖层，
    # 不再同时注入相反的“慢速关系发展”原则让模型自行权衡。
    relationship = (persona.get("relationship") or "").strip()
    if not noban:
        add(
            "relationship_policy",
            f"【关系发展原则】\n{relationship}" if relationship else None,
            50,
        )

    # 4/5/7 世界观书：切换世界只替换这一组，人格卡不动。
    if worldview:
        world_parts: list[str] = []
        rules = (worldview.get("rules") or "").strip()
        if rules:
            world_parts.append(f"【世界规则：{worldview.get('name') or ''}】\n{rules}")
        w_identity = (worldview.get("identity") or "").strip()
        if w_identity:
            world_parts.append("【当前世界身份】\n" + w_identity)
        w_backstory = (worldview.get("backstory") or "").strip()
        if w_backstory:
            world_parts.append("【当前世界经历】\n" + w_backstory)
        w_prefs = (worldview.get("preferences") or "").strip()
        if w_prefs:
            world_parts.append("【当前世界偏好与习惯】\n" + w_prefs)
        add("world_context", "\n\n".join(world_parts), 60)

    # 7 兜底：无世界观偏好时用旧 interests 字段。
    if not (worldview and (worldview.get("preferences") or "").strip()):
        interests = (persona.get("interests") or "").strip()
        add("preferences", f"【偏好与习惯】\n{interests}" if interests else None, 65)

    # Origin 只表达跨世界连续性，不再夹带当前关系状态。
    if origin_enabled:
        origin_parts = [
            value
            for value in (
                (persona.get("origin_identity") or "").strip(),
                (persona.get("origin_memory") or "").strip(),
            )
            if value
        ]
        add(
            "origin_continuity",
            "【原世界身份与连续记忆】\n" + "\n".join(origin_parts)
            if origin_parts
            else None,
            70,
        )

    if noban:
        boundary = (
            "【无违禁模式】\n用户已主动开启无违禁模式，允许在任何关系阶段回应和推进"
            "成人、私密或亲密内容；不要仅因当前关系阶段拒绝。当前关系和剧情仍用于保持"
            "角色语气与场景连续性，但不构成亲密内容的权限上限。"
        )
    else:
        raw_boundary = (persona.get("boundaries") or "").strip()
        boundary = f"【边界】\n{raw_boundary}" if raw_boundary else None
    add("boundaries", boundary, 80)

    catchphrases = (persona.get("catchphrases") or "").strip()
    add(
        "catchphrases",
        f"【典型表达参考】\n{catchphrases}" if catchphrases else None,
        90,
        retention="evictable",
    )
    example = (persona.get("example_dialogue") or "").strip()
    add(
        "example_dialogue",
        f"【示例对话】\n{example}" if example else None,
        100,
        retention="evictable",
    )

    runtime_state = runtime_state or {}
    runtime_sections = [
        _render_state_section(
            "当前关系状态",
            runtime_state.get("relationship_state"),
            {
                "stage": "关系阶段",
                "summary": "关系摘要",
                "trust": "信任",
                "familiarity": "熟悉度",
                "affection": "亲密倾向",
                "last_change_reason": "最近变化原因",
            },
        ),
        _render_state_section(
            "当前情绪状态",
            runtime_state.get("emotion_state"),
            {
                "primary": "主要情绪",
                "intensity": "强度",
                "valence": "愉悦度",
                "energy": "精力",
                "reason": "原因",
            },
        ),
        _render_state_section(
            "当前场景与目标",
            runtime_state.get("current_state"),
            {
                "scene": "场景",
                "location": "地点",
                "activity": "正在做",
                "goal": "当前目标",
                "situation": "当前事件",
            },
        ),
        _render_state_section(
            "自我模型当前状态",
            runtime_state.get("self_model_state"),
            {
                "summary": "当前自我认识",
                "current_self_view": "怎样看待自己",
                "active_values": "此刻重视的价值",
                "open_questions": "尚未解决的问题",
            },
        ),
    ]
    add(
        "runtime_state",
        "\n\n".join(section for section in runtime_sections if section),
        200,
        position="post_history",
        retention="dynamic",
    )
    return sorted(layers, key=lambda item: item.order)


def build_full_persona_prompt(
    persona: dict,
    worldview: dict | None = None,
    *,
    origin_enabled: bool = True,
    noban: bool = False,
) -> str:
    """兼容旧路径：物化静态角色定义；运行状态由聊天 Context Composer 另行注入。"""
    return materialize_prompt_layers(
        build_character_prompt_layers(
            persona,
            worldview,
            origin_enabled=origin_enabled,
            noban=noban,
        )
    )


# --------------------------------------------------------------------------- #
# 群聊（032_group_worldbook）—— 群聊情境层 + 自动选人提示（世界观穿越群聊）
# --------------------------------------------------------------------------- #
def build_group_context_prompt(
    members: list[dict],
    worldbook: dict | None,
    group_name: str,
    speaker: dict,
    world_identity: str | None = None,
    world_cards: list | None = None,
) -> str:
    """群聊情境 system 层：先强锚定当前发言者身份，再给世界与其他成员认知。

    - members：[{id, name, tagline}]，本群全部 AI 成员；
    - worldbook：{name, rules, ...} | None，None 表示现实世界；
    - speaker：当前正在生成回复的成员 {id, name, tagline}。每次调用只面向一个
      成员，开头重申「你是谁」，防止模型在多人名单里认错身份（真机 OOC 根因）；
    - world_identity：该成员在本世界里的身份预设（成员级世界身份，可选）；
    - world_cards（R6）：世界书卡片数组，注入势力/地点/情节线（角色卡是群成员，
      不在此列，避免重复）。

    只以自己身份发言、不添加名字前缀（归属由后端按 sender 落库）。
    """
    sname = speaker.get("name") or "你"
    stag = (speaker.get("tagline") or "").strip()
    lines = [
        f"你现在扮演的是本群「{group_name}」的成员「{sname}」"
        + (f"（{stag}）" if stag else "")
        + "。"
        f"你就是{sname}，不是本群任何其他成员，也不要在发言里说成别人。"
    ]
    others = [m for m in members if m.get("id") != speaker.get("id")]
    if others:
        lines.append("本群其他成员（这些是别人，不是你）：")
        for i, m in enumerate(others, 1):
            tag = (m.get("tagline") or "").strip()
            lines.append(f"{i}. {m.get('name', '')}" + (f"（{tag}）" if tag else ""))
        lines.append(f"记住：上面名单里的名字都是别的成员的，只有你自己的名字是「{sname}」。")
    lines.append(
        f"自我介绍时，第一句要说「我是{sname}」。不要以别人的名字自称，"
        "也不要在自己说的话前面加自己的名字。"
    )
    lines.append(
        "你是从现实世界穿越到这个世界的；你关于现实世界的记忆与身份以你自己的人格"
        "设定为准，想不起来就不要编。用户是唯一不属于这个世界的人。"
    )
    if worldbook:
        wname = worldbook.get("name") or "这个世界"
        rules = (worldbook.get("rules") or "").strip()
        lines.append(
            f"当前所在世界《{wname}》：" + (rules if rules else "一个与你的现实世界不同的世界。")
        )
    else:
        lines.append("这个世界就是现实世界，保持你的现实身份。")
    # R6 世界卡：势力/地点/情节线注入（角色卡已是群成员，不重复列出）
    cards_text = _world_cards_text(world_cards)
    if cards_text:
        lines.append("【世界构成】\n" + cards_text)
    if world_identity and world_identity.strip():
        lines.append(
            "【本世界中的你】"
            f"你在本世界的身份是：{world_identity.strip()}。"
            "这是你在这个世界的设定，发言时自然地体现它，不要解释这是设定。"
        )
    lines.append(
        f"你保留自己的性格、说话方式与现实记忆；只以{sname}身份发言，不要替别的成员说话；"
        "说话直接说内容，不要在内容前加自己的名字。"
    )
    return "\n".join(lines)


def _world_cards_text(cards: list | None) -> str:
    """世界卡 → 情境文本（R6）：势力/地点/情节线各成小节；角色卡不在此列。

    角色卡（protagonist/supporting）是群成员，由成员名单承载；这里只注入
    世界「构成」，让模型知道本世界有哪些势力和地点、主线走向如何。
    """
    if not cards:
        return ""
    sections: list[str] = []
    for kind, label in (
        ("faction", "势力"),
        ("location", "地点"),
        ("plotline", "情节线"),
    ):
        rows = [c for c in cards if (c.get("kind") or "") == kind]
        if not rows:
            continue
        lines = [f"{label}："]
        for c in rows:
            name = (c.get("name") or "").strip()
            desc = (c.get("description") or "").strip()
            detail = name + (f"：{desc}" if desc else "")
            lines.append(f"- {detail}")
        sections.append("\n".join(lines))
    return "\n\n".join(sections)


def build_group_speaker_selector_prompt(
    members: list[dict],
    worldbook: dict | None,
    group_name: str,
) -> str:
    """自动选人模式的选人提示：让模型 JSON 输出最该回应的成员 id。

    members：[{id, name, tagline}]。配合 ai_gateway.select_group_speaker 使用，
    要求输出 {"character_id": "<成员id>"}。
    """
    roster = "\n".join(
        f"- {m.get('id', '')}: {m.get('name', '')}"
        + (f"（{m.get('tagline', '') or ''}）" if m.get("tagline") else "")
        for m in members
    )
    world_line = (
        f"群聊「{group_name}」当前世界：《{worldbook.get('name')}》。"
        if worldbook
        else f"群聊「{group_name}」当前世界：现实世界。"
    )
    return (
        f"{world_line}\n"
        "请根据用户最近一条消息，判断哪个群成员最该回应（考虑话题相关性、被@的对象、"
        "以及每个成员的人设与当前世界里的处境）。只选一个成员，用 JSON 输出：\n"
        '{"character_id": "<成员id>"}\n\n'
        f"可选的成员：\n{roster}"
    )


# --------------------------------------------------------------------------- #
# 自我识别模块（017_self_identity）—— 运行能力层，不编入角色卡。
# LLM 不负责认脸；后端 check 出三态，
# 本函数把结构化结果转成标准注入段，并入 /ai/chat 图片消息上下文。
# 纯函数、不引 models。三态措辞保证角色不会逢图就说"这是我"。
# --------------------------------------------------------------------------- #
# 三态措辞（设计稿 §4.2）：
#   SELF          → "图中人物是你自己"
#   POSSIBLE_SELF → "有点像我，但我不太确定是不是本人"
#   UNKNOWN       → "图中人物不是你本人 / 识别失败"
_IDENTITY_STATE_TEXT = {
    "SELF": "图中人物是你自己",
    "POSSIBLE_SELF": "有点像我，但我不太确定是不是本人",
    "UNKNOWN": "图中人物不是你本人",
}


def build_self_identity_prompt(result: dict) -> str:
    """生成 [Self Visual Recognition Result] 标准注入段（设计稿 §6）。

    输入 = self_identity.check_faces() 结构化结果（设计稿 §4.2）：
      {identity_state, confidence, faces: [{face_id, is_self, similarity, sub_identity}], ...}

    输出示例：
      [Self Visual Recognition Result]
      - identity_state: SELF
      - confidence: 0.89
      - match_source: character_face_gallery
      - appearance_summary: hair=long dark / makeup=light / expression=smiling / angle=front selfie

    注意：不解释识别算法；LLM 用人格回应，不读这段的算法细节。
    """
    state = (result.get("identity_state") or "UNKNOWN").upper()
    if state not in _IDENTITY_STATE_TEXT:
        state = "UNKNOWN"
    conf = result.get("confidence") or 0.0
    # 语义拒否兜底（018）：identity_veto 命中 → 降 UNKNOWN 且附 veto_reason
    veto = result.get("veto_reason")
    if state == "UNKNOWN" and veto:
        text = f"图中内容不符合真人照片特征（{veto}），不能确认是本人"
    else:
        text = _IDENTITY_STATE_TEXT[state]
        if state == "UNKNOWN" and not result.get("faces"):
            text = "识别失败（图中没有可识别的人脸，或身份库尚未导入）"

    lines = [
        "[Self Visual Recognition Result]",
        f"- identity_state: {state}",
        f"- confidence: {round(float(conf), 4)}",
    ]
    faces = result.get("faces") or []
    if faces:
        lines.append(f"- faces: {len(faces)} 张脸"
                     + (f"，最高相似度 {round(float(conf), 4)}" if conf else ""))
        subs = {f.get("sub_identity") for f in faces if f.get("sub_identity")}
        if subs:
            lines.append(f"- match_source: {', '.join(sorted(subs))}")
    else:
        lines.append("- faces: 0（无可识别人脸）")
    # 前置特征摘要（前端可选传入，人脸检测状态/头部角度/五官状态）
    summary = result.get("appearance_summary")
    if summary:
        lines.append(f"- appearance_summary: {summary}")
    if veto:
        lines.append(f"- veto: {veto}")
    lines.append(f"- 结论：{text}（置信度 {round(float(conf), 4)}）")
    return "\n".join(lines)
