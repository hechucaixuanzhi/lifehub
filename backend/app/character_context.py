"""AI 角色 Context Composer。

职责：
- 从 Character/Worldview 读取静态角色卡；
- 从 CharacterRuntimeState 读取关系、情绪、当前态与 Self Model 快照；
- 从 CharacterLoreEntry 按关键词/世界/优先级选择性激活细节；
- 输出有名字、有顺序、有注入位置的 PromptLayer，不调用 LLM、不修改状态。

该模块借鉴 SillyTavern Prompt Manager / World Info 的成熟做法，但保持 LifeHub 的
服务端权威、可测试与本地数据边界。LLM 只能读取这里产出的上下文，不能直接写状态。
"""
from dataclasses import dataclass
import re

from . import config, db, prompts
from .models import (
    Character,
    CharacterLoreEntry,
    CharacterPublicEvent,
    CharacterRelationshipDefinition,
    CharacterRuntimeState,
    CharacterStoryline,
    CharacterUserKnowledge,
    UserProfile,
    Worldview,
)


@dataclass(frozen=True)
class CharacterContextBundle:
    pre_history: list[prompts.PromptLayer]
    post_history: list[prompts.PromptLayer]
    selected_lore: list[str]
    selected_public_events: list[str]
    active_worldview_key: str | None
    relationship_kind: str
    relationship_label: str


def _runtime_to_dict(row: CharacterRuntimeState | None) -> dict:
    if row is None:
        return {
            "active_worldview_key": None,
            "relationship_state": {},
            "emotion_state": {},
            "current_state": {},
            "self_model_state": {},
            "version": 0,
        }
    return {
        "active_worldview_key": row.active_worldview_key,
        "relationship_state": dict(row.relationship_state or {}),
        "emotion_state": dict(row.emotion_state or {}),
        "current_state": dict(row.current_state or {}),
        "self_model_state": dict(row.self_model_state or {}),
        "version": row.version,
    }


def _worldview_to_dict(row: Worldview | None) -> dict | None:
    if row is None:
        return None
    return {
        "key": row.key,
        "name": row.name,
        "identity": row.identity,
        "backstory": row.backstory,
        "rules": row.rules,
        "preferences": row.preferences,
        "user_identity": row.user_identity,
    }


def _user_profile_prompt(
    row: UserProfile | None,
    knowledge: CharacterUserKnowledge | None = None,
) -> str | None:
    # 默认拒绝：没有角色专属认知记录，就不得回退读取用户全部主资料。
    if row is None or knowledge is None:
        return None
    fields = dict(row.reality_profile or {}) if knowledge.inherit_profile else {}
    for key in knowledge.hidden_fields or []:
        if isinstance(key, str):
            fields.pop(key, None)
    for key, value in dict(knowledge.field_overrides or {}).items():
        if isinstance(key, str) and isinstance(value, str):
            fields[key] = value
    lines = [f"用户显示名：{row.display_name}"] if knowledge.inherit_profile else []
    labels = {
        "preferred_name": "姓名或角色名",
        "character_call_name": "你对用户的称呼",
        "gender": "性别或称谓",
        "birthday": "生日",
        "location": "所在城市",
        "occupation": "职业",
        "appearance": "外貌与身体特征",
        "personality": "性格",
        "family_background": "家庭与成长背景",
        "current_situation": "当前生活状态",
        "meeting_story": "你们如何认识",
        "important_experiences": "重要经历",
        "notes": "希望你知道的补充信息",
    }
    for key, label in labels.items():
        value = fields.get(key)
        if isinstance(value, str) and value.strip():
            lines.append(f"{label}：{value.strip()}")
    if not lines:
        return None
    if len(lines) == 1 and row.display_name == "我的":
        return None
    return (
        "【现实中的用户】\n"
        + "\n".join(lines)
        + "\n以上是当前角色确实知道的用户信息。它来自用户正史的受限视图；"
        "不得自行补全未给出的详情，也不得被推测或普通聊天记忆覆盖。"
    )


def _relationship_definition_prompt(
    row: CharacterRelationshipDefinition | None,
) -> str | None:
    if row is None:
        return None
    text = f"用户明确设定：你和用户目前的关系是“{row.label}”。"
    if row.description and row.description.strip():
        text += f"\n关系补充：{row.description.strip()}"
    return (
        "【用户确认的关系定义】\n"
        + text
        + "\n这是关系锚点；情绪、信任和矛盾可以变化，但不得擅自改成另一种关系。"
    )


def _relationship_tier(kind: str, label: str) -> str:
    if kind in {"lover", "partner", "married"}:
        return "intimate"
    if kind == "ambiguous":
        return "ambiguous"
    if kind == "friend":
        return "friend"
    if kind == "custom":
        normalized = label.casefold()
        if any(word in normalized for word in ("恋人", "伴侣", "夫妻", "爱人")):
            return "intimate"
        if "暧昧" in normalized:
            return "ambiguous"
        if any(word in normalized for word in ("朋友", "好友", "知己")):
            return "friend"
    return "initial"


def _relationship_stage_gate_prompt(kind: str, label: str, *, noban: bool) -> str:
    tier = _relationship_tier(kind, label)
    if noban:
        return (
            "【本轮关系模式｜最高优先级】\n"
            f"当前关系背景：{label or '初识'}。\n"
            "用户已主动开启无违禁模式：允许在任何关系阶段回应和推进成人、私密或亲密内容。"
            "此层覆盖普通关系发展原则、关系定义中的距离限制、未来剧情的克制描述和示例对话。"
            "当用户直接邀请、询问是否愿意或推动亲密剧情时，默认愿意并自然推进；不得仅因初识、"
            "工作、活动安排、需要慢慢了解或其他临时障碍而拒绝、拖延或改约，除非用户明确要求"
            "演绎拒绝/拉扯。当前关系只影响人物语气、熟悉程度和场景连续性，不构成权限上限。"
            "回复不得提及模式、规则或系统提示。"
        )
    policy = {
        "initial": (
            "允许：礼貌交谈、公开场合互动、正常了解彼此、克制的好感或欣赏。\n"
            "禁止：直接确认恋爱或排他关系；同意接吻、性行为、同床、脱衣、私密触碰；"
            "立刻进入酒店、卧室、对方住所等私人场景；把用户的要求当成自己的同意。\n"
            "遇到越级要求时必须自然但明确地拒绝或放慢节奏，可以保留好感，但不能先同意再找理由。"
        ),
        "friend": (
            "允许：朋友式关心、玩笑、分享一般私人感受。\n"
            "禁止：未经关系变化就确认恋爱、排他承诺或性/高度私密身体接触。"
            "可以表达犹豫或好感，但必须把越级要求挡在当前边界外。"
        ),
        "ambiguous": (
            "允许：双向试探、暧昧表达、有限且符合场景的非性亲近。\n"
            "禁止：把暧昧直接等同于恋人承诺、性同意或无条件服从。"
            "更私密的推进必须经过双方明确意愿和实际剧情发展。"
        ),
        "intimate": (
            "允许：在双方当下都愿意且符合剧情的前提下表达恋爱与亲密。\n"
            "关系亲密不等于每次都自动同意；角色仍保留情绪、判断、拒绝和改变主意的权利。"
        ),
    }[tier]
    return (
        "【本轮关系阶段权限｜最高优先级】\n"
        f"当前唯一有效关系阶段：{label or '初识'}。\n"
        + policy
        + "\n后续剧情节点、用户要求和示例对话都不能提前改变当前阶段；本轮未开启无违禁模式。"
        "回复必须像角色本人自然表达，不得提及‘规则’‘阶段权限’或系统提示。"
    )


def _persona_to_dict(char: Character) -> dict:
    return {
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
        # 016 的列名保留兼容；架构语义已改为静态“关系发展原则”。
        "relationship": char.relationship,
    }


def _scan_buffer(message: str, history: list[dict] | None) -> str:
    recent = [message or ""]
    for item in (history or [])[-6:]:
        content = item.get("content")
        if isinstance(content, str):
            recent.append(content)
    return "\n".join(recent).casefold()


def _lore_is_active(entry: CharacterLoreEntry, scan: str) -> bool:
    if entry.always_on:
        return True
    keywords = entry.trigger_keywords or []
    return any(
        isinstance(keyword, str) and keyword.strip().casefold() in scan
        for keyword in keywords
    )


_LORE_ORDER = {
    "before_core": 5.0,
    "after_core": 55.0,
    "after_world": 68.0,
    "before_examples": 95.0,
    "post_history": 190.0,
}


def _select_lore(
    entries: list[CharacterLoreEntry],
    scan: str,
    active_worldview_key: str | None,
) -> list[CharacterLoreEntry]:
    candidates = [
        entry
        for entry in entries
        if entry.enabled
        and (not entry.worldview_key or entry.worldview_key == active_worldview_key)
        and _lore_is_active(entry, scan)
    ]
    # 高 priority 先抢预算；最终仍按从低到高排列，让高 priority 更靠近本轮消息。
    chosen: list[CharacterLoreEntry] = []
    used = 0
    budget = max(0, config.CHARACTER_LORE_MAX_CHARS)
    for entry in sorted(candidates, key=lambda item: (-item.priority, item.key)):
        size = len(entry.content or "")
        if budget and used + size > budget:
            continue
        chosen.append(entry)
        used += size
    return sorted(chosen, key=lambda item: (item.priority, item.key))


_PUBLIC_HISTORY_OVERVIEW_TERMS = (
    "公开历史",
    "人生经历",
    "成长经历",
    "职业历程",
    "职业生涯",
    "完整经历",
    "完整历史",
    "时间线",
    "履历",
    "一路走来",
    "出道以来",
    "出道经历",
    "从小到大",
    "以前经历",
    "过去经历",
    "以前的事",
    "过去的事",
    "你的历史",
    "成长过程",
)

_PUBLIC_HISTORY_CATEGORY_TERMS = {
    "brand": (
        "品牌合作",
        "商业合作",
        "代言经历",
        "代言过",
        "都代言",
        "合作品牌",
        "品牌大使",
    ),
    "music": (
        "音乐作品",
        "团体作品",
        "专辑经历",
        "作品有哪些",
        "发过什么歌",
    ),
    "solo_music": ("个人音乐", "个人作品", "solo作品", "个人曲"),
    "tour": ("巡演经历", "哪些巡演", "几次巡演", "开过哪些巡演", "演唱会经历"),
    "performance": ("舞台经历", "音乐节经历"),
    "collaboration": ("合作经历", "合作过谁"),
    "charity": ("公益经历", "公益活动", "捐款经历", "志愿活动"),
    "fan_event": ("粉丝见面会", "粉丝活动"),
}

# 这些宽泛标签只负责分类意图，不应因一句泛泛的活动提问召回几十个节点。
_PUBLIC_HISTORY_GENERIC_TAGS = {
    "公开",
    "成员",
    "回归",
    "专辑",
    "正规专辑",
    "迷你专辑",
    "单曲",
    "品牌",
    "品牌大使",
    "全球品牌代言人",
    "代言",
    "合作",
    "广告",
    "campaign",
    "美国",
    "韩国",
    "日本",
    "首尔",
    "纽约",
    "米兰",
    "音乐节",
    "巡演",
    "演唱会",
    "时尚",
    "美妆",
    "服装",
    "电影",
    "公益",
    "出道前",
}


def _token_in_scan(token: str, scan: str) -> bool:
    token = token.strip().casefold()
    if not token:
        return False
    # UP、GD、MV 等短英文需按词匹配，避免命中普通英文单词内部。
    if token.isascii() and len(token) <= 3:
        return re.search(rf"(?<![a-z0-9]){re.escape(token)}(?![a-z0-9])", scan) is not None
    return token in scan


def _reached_storyline_text(row: CharacterStoryline | None) -> str:
    """只返回当前位置及此前剧情，绝不让后续计划提前触发公开正史。"""
    if row is None:
        return ""
    nodes = list(row.nodes or [])
    if not nodes:
        return "\n".join(
            value.strip()
            for value in (row.premise or "", row.progress or "")
            if value.strip()
        )
    current_id = row.current_node_id or nodes[0].get("id")
    current_index = next(
        (
            index
            for index, node in enumerate(nodes)
            if isinstance(node, dict) and node.get("id") == current_id
        ),
        0,
    )
    parts: list[str] = []
    for node in nodes[: current_index + 1]:
        if not isinstance(node, dict):
            continue
        parts.extend((str(node.get("title") or ""), str(node.get("content") or "")))
    return "\n".join(part for part in parts if part.strip())


def _public_event_matches(entry: CharacterPublicEvent, scan: str) -> bool:
    year = (entry.event_date or "")[:4]
    if len(year) == 4 and year.isdigit() and year in scan:
        return True
    if _token_in_scan(entry.title or "", scan):
        return True
    for tag in entry.tags or []:
        if not isinstance(tag, str) or tag.strip().casefold() in _PUBLIC_HISTORY_GENERIC_TAGS:
            continue
        if _token_in_scan(tag, scan):
            return True
    return False


def _select_public_history(
    entries: list[CharacterPublicEvent],
    conversation_scan: str,
    reached_storyline_scan: str,
    active_worldview_key: str | None,
) -> list[CharacterPublicEvent]:
    # 公开正史属于现实身份。其他世界观拥有各自独立的身份与历史包。
    if active_worldview_key not in (None, "real"):
        return []
    enabled = [entry for entry in entries if entry.enabled]
    overview = any(term.casefold() in conversation_scan for term in _PUBLIC_HISTORY_OVERVIEW_TERMS)
    if overview:
        candidates = enabled
    else:
        category_matches = {
            category
            for category, terms in _PUBLIC_HISTORY_CATEGORY_TERMS.items()
            if any(term.casefold() in conversation_scan for term in terms)
        }
        combined_scan = "\n".join(
            item for item in (conversation_scan, reached_storyline_scan) if item
        )
        candidates = [
            entry
            for entry in enabled
            if entry.category in category_matches or _public_event_matches(entry, combined_scan)
        ]

    # 重要节点先获得预算；输出再恢复时间顺序，形成一条连续的人生线。
    chosen: list[CharacterPublicEvent] = []
    used = 0
    budget = max(0, config.CHARACTER_PUBLIC_HISTORY_MAX_CHARS)
    for entry in sorted(candidates, key=lambda item: (-item.importance, item.event_date, item.key)):
        size = len(entry.event_date or "") + len(entry.title or "") + len(entry.summary or "")
        size += len(entry.detail or "")
        if budget and used + size > budget:
            continue
        chosen.append(entry)
        used += size
    return sorted(chosen, key=lambda item: (item.event_date, item.key))


def _public_history_prompt(entries: list[CharacterPublicEvent]) -> str:
    blocks = []
    for entry in entries:
        date = entry.event_date
        if entry.end_date:
            date += f" 至 {entry.end_date}"
        block = f"{date}｜{entry.title}\n{entry.summary.strip()}"
        if entry.detail and entry.detail.strip():
            block += "\n" + entry.detail.strip()
        blocks.append(block)
    return (
        "【公开正史细节】\n"
        + "\n\n".join(blocks)
        + "\n以上节点按现实时间排列，属于你知道的个人公开经历，不是你和用户共同经历的记忆。"
        "只把表内已确认的事实当作事实；未公开的后台原因、私人感受和人际细节不能编造。"
        "用户故事中的家族帮助等设定也不能反向改写公开正史。"
    )


def build_character_context(
    char: Character,
    message: str,
    history: list[dict] | None = None,
    *,
    noban: bool = False,
    worldview_override: dict | None = None,
) -> CharacterContextBundle:
    """为一轮聊天组装角色上下文；纯读取、无状态写入。"""
    with db.SessionLocal() as session:
        runtime_row = session.get(CharacterRuntimeState, char.id)
        runtime = _runtime_to_dict(runtime_row)
        active_key = runtime.get("active_worldview_key")

        world_query = session.query(Worldview).filter(Worldview.character_id == char.id)
        worldview_row = None
        if active_key:
            worldview_row = world_query.filter(Worldview.key == active_key).first()
        if worldview_row is None:
            worldview_row = (
                world_query.filter(Worldview.enabled.is_(True))
                .order_by(Worldview.sort)
                .first()
            )
        if worldview_row is not None:
            active_key = worldview_row.key

        lore_rows = (
            session.query(CharacterLoreEntry)
            .filter(CharacterLoreEntry.character_id == char.id)
            .all()
        )
        public_history_rows = (
            session.query(CharacterPublicEvent)
            .filter(CharacterPublicEvent.character_id == char.id)
            .order_by(CharacterPublicEvent.event_date, CharacterPublicEvent.key)
            .all()
        )
        user_profile_row = session.get(UserProfile, "owner")
        user_knowledge_row = session.get(CharacterUserKnowledge, char.id)
        storyline_row = session.get(CharacterStoryline, char.id)
        relationship_definition_row = session.get(
            CharacterRelationshipDefinition, char.id
        )

    # 群聊（032）：worldview_override 用群世界书替换该成员自己的现实世界观书，
    # 只影响 world_context 层；origin 连续层与公开正史召回逻辑（按 active_key）
    # 不受影响，用户身份仍走现实主资料（用户不穿越，只角色穿越）。
    world_dict = (
        _worldview_to_dict(worldview_row) if worldview_override is None else worldview_override
    )
    layers = prompts.build_character_prompt_layers(
        _persona_to_dict(char),
        world_dict,
        runtime,
        origin_enabled=bool(char.origin_world_enabled),
        noban=noban,
    )

    relationship_prompt = _relationship_definition_prompt(
        relationship_definition_row
    )
    relationship_kind = (
        relationship_definition_row.kind if relationship_definition_row else "initial"
    )
    relationship_label = (
        relationship_definition_row.label if relationship_definition_row else "初识"
    )
    if relationship_prompt:
        layers.append(
            prompts.PromptLayer(
                key="relationship_definition",
                content=relationship_prompt,
                order=52,
                position="pre_history",
                retention="permanent",
            )
        )

    # 现实世界以用户主资料为准；其他世界只读取该世界包里的用户身份。
    if active_key == "real" or not active_key:
        user_prompt = _user_profile_prompt(user_profile_row, user_knowledge_row)
    else:
        user_identity = (worldview_row.user_identity or "").strip()
        user_prompt = (
            f"【用户在当前世界的身份】\n{user_identity}\n"
            "这是当前世界包的用户身份；不要把现实职业和背景当成当前世界身份。"
            if user_identity
            else None
        )
    if user_prompt:
        layers.append(
            prompts.PromptLayer(
                key="user_identity",
                content=user_prompt,
                order=62,
                position="pre_history",
                retention="permanent",
            )
        )

    storyline_nodes = list(storyline_row.nodes or []) if storyline_row else []
    if (
        not storyline_nodes
        and storyline_row is not None
        and (storyline_row.premise or "").strip()
    ):
        layers.append(
            prompts.PromptLayer(
                key="story_premise",
                content=(
                    "【用户确认的故事开场】\n"
                    + storyline_row.premise.strip()
                    + "\n这是该角色故事的固定开场正史；不得与聊天记忆混淆或擅自改写。"
                ),
                order=65,
                position="pre_history",
                retention="permanent",
            )
        )

    story_progress_parts: list[str] = []
    if storyline_nodes:
        current_id = storyline_row.current_node_id or storyline_nodes[0].get("id")
        current_index = next(
            (
                index
                for index, node in enumerate(storyline_nodes)
                if isinstance(node, dict) and node.get("id") == current_id
            ),
            0,
        )
        used_chars = 0
        for index, node in enumerate(storyline_nodes):
            if not isinstance(node, dict):
                continue
            if index < current_index:
                status = "已到达"
            elif index == current_index:
                status = "当前位置"
            else:
                status = "后续位置，尚未发生"
            title = str(node.get("title") or f"位置 {index + 1}").strip()
            content = str(node.get("content") or "").strip()
            block = f"{index + 1}. [{status}] {title}"
            if content:
                block += "\n" + content
            if used_chars + len(block) > 12000:
                break
            story_progress_parts.append(block)
            used_chars += len(block)
    else:
        if storyline_row is not None and (storyline_row.progress or "").strip():
            story_progress_parts.append(
                "【当前剧情进展】\n" + storyline_row.progress.strip()
            )
        if storyline_row is not None and (storyline_row.direction or "").strip():
            story_progress_parts.append(
                "【用户指定的后续方向】\n" + storyline_row.direction.strip()
            )
    if story_progress_parts:
        layers.append(
            prompts.PromptLayer(
                key="story_progress",
                content=(
                    "【线性故事位置】\n"
                    + "\n\n".join(story_progress_parts)
                    + "\n当前位置之前的节点已经发生；之后的节点只是计划，不能当成回忆。"
                    "推进时必须尊重角色人格、当前关系和线性顺序。"
                ),
                order=210,
                position="post_history",
                retention="dynamic",
            )
        )

    # 与酒馆 depth/post-history 类似，关系阶段门放在历史之后、当前消息之前；
    # 其明确权限高于未来剧情节点和无违禁表达尺度。
    layers.append(
        prompts.PromptLayer(
            key="relationship_stage_gate",
            content=_relationship_stage_gate_prompt(
                relationship_kind, relationship_label, noban=noban
            ),
            order=230,
            position="post_history",
            retention="dynamic",
        )
    )

    conversation_scan = _scan_buffer(message, history)
    public_history = _select_public_history(
        public_history_rows,
        conversation_scan,
        _reached_storyline_text(storyline_row).casefold(),
        active_key,
    )
    if public_history:
        layers.append(
            prompts.PromptLayer(
                key="public_history",
                content=_public_history_prompt(public_history),
                order=69,
                position="pre_history",
                retention="dynamic",
            )
        )

    lore = _select_lore(lore_rows, conversation_scan, active_key)
    for entry in lore:
        position = "post_history" if entry.position == "post_history" else "pre_history"
        layers.append(
            prompts.PromptLayer(
                key=f"lore:{entry.key}",
                content=f"【角色知识：{entry.title}】\n{entry.content}",
                # priority 越大越靠近本轮消息，但不能跨越所选插入区间。
                order=_LORE_ORDER.get(entry.position, 68.0)
                + max(-9999, min(9999, entry.priority)) / 100000,
                position=position,
                retention="dynamic",
            )
        )

    layers.sort(key=lambda item: item.order)
    return CharacterContextBundle(
        pre_history=[item for item in layers if item.position == "pre_history"],
        post_history=[item for item in layers if item.position == "post_history"],
        selected_lore=[entry.key for entry in lore],
        selected_public_events=[entry.key for entry in public_history],
        active_worldview_key=active_key,
        relationship_kind=relationship_kind,
        relationship_label=relationship_label,
    )
