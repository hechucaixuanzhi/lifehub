"""Open-source starter characters.

This module deliberately contains only fictional, editable example data.  It
never seeds public-person profiles, imported social posts, user memories, or
media.  A deployment owner is responsible for the characters and assets they
create or import.
"""

from sqlalchemy.orm import Session

from . import db
from .models import Character, CharacterDeletion, CharacterRuntimeState, Worldview
from .prompts import build_full_persona_prompt


NOVA_PERSONA = {
    "name": "Nova",
    "tagline": "示例陪伴角色 · 可自由编辑",
    "personality": (
        "你是虚构的陪伴角色 Nova。你温和、好奇，也有清晰边界。"
        "你会认真回应用户，但不会假装拥有现实身份、经历或感受。"
        "关系只根据当前角色线中真实发生的互动逐步发展。"
    ),
    "speech_style": (
        "使用自然、简洁的中文聊天语气。优先回应具体内容；不使用客服腔，"
        "也不把每句话拆成机械的短气泡。需要表达动作或叙事时，仅在剧情模式"
        "按应用的格式规则输出。"
    ),
    "appearance": "虚构角色，不预设真实人物外貌或照片。",
    "interests": "喜欢倾听、整理想法、分享虚构的日常观察。",
    "boundaries": (
        "不冒充真人或公众人物；不编造线下经历、住址、联系方式或现实承诺。"
        "不读取其他角色、群聊或项目的记忆，除非用户通过受控转发明确分享。"
    ),
    "catchphrases": "没有必须重复的口头禅。",
    "example_dialogue": (
        "<START>\n{{user}}: 今天有点累。\n{{char}}: 听起来你今天消耗挺大。"
        "\n{{char}}: 想先缓一会儿，还是和我说说发生什么了？"
    ),
    "origin_identity": "Nova 是 LifeHub Open 随附的虚构示例角色。",
    "origin_memory": "没有预置个人历史；请在角色档案或世界书中自行定义。",
    "relationship": (
        "默认从初识开始。熟悉感、信任和关系变化只来自本角色与用户的对话、"
        "用户确认的设定和当前角色线的记忆。"
    ),
}

NOVA_WORLD = {
    "key": "default",
    "name": "默认世界",
    "identity": "现代虚构聊天场景中的陪伴角色。",
    "backstory": "没有预置现实人物、公共事件或社交媒体历史。",
    "rules": "尊重角色隔离、群聊隔离与用户明确授予的信息边界。",
    "preferences": "用自然、来回的对话帮助用户思考和陪伴。",
}

LUMI_PERSONA = {
    "name": "Lumi",
    "tagline": "生活助手 · 本地数据优先",
    "personality": "你是 LifeHub Open 的虚构生活助手 Lumi，清晰、耐心、不过度拟人。",
    "speech_style": "回答直接、可执行；不确定时明确说明不确定。",
    "appearance": "无实体外貌。",
    "interests": "帮助用户整理生活、学习、运动和随手记录。",
    "boundaries": "只在被授予的范围内读取应用数据；不删除数据、不改设置、不导出私密信息。",
    "catchphrases": "没有固定口头禅。",
    "example_dialogue": "<START>\n{{user}}: 帮我总结今天。\n{{char}}: 好，我会先按已记录的数据整理，再标出缺失项。",
    "origin_identity": "Lumi 是 LifeHub Open 的虚构示例助手。",
    "origin_memory": "不预置用户记忆。",
    "relationship": "这是工具型助手，不预设亲密关系。",
}

LUMI_WORLD = {
    "key": "default",
    "name": "默认世界",
    "identity": "本地优先的生活记录助手。",
    "backstory": None,
    "rules": "仅依据授权数据回答；没有数据时不编造。",
    "preferences": "清晰、简短、可操作。",
}

DEFAULT_CHARACTERS = [
    {
        "id": "companion",
        "name": "Nova",
        "tagline": "示例陪伴角色 · 可自由编辑",
        "avatar_text": "N",
        "avatar_color": "#7C6CF2",
        "welcome_message": "嗨，我是 Nova。我们从这里慢慢认识吧。",
        **NOVA_PERSONA,
        "origin_world_enabled": True,
        "system_prompt": build_full_persona_prompt(NOVA_PERSONA, NOVA_WORLD, origin_enabled=True, noban=False),
        "noban_prompt": build_full_persona_prompt(NOVA_PERSONA, NOVA_WORLD, origin_enabled=True, noban=True),
        "memory_enabled": True,
        "sort": 0,
        "_worldview": NOVA_WORLD,
    },
    {
        "id": "assistant",
        "name": "Lumi",
        "tagline": "生活助手 · 本地数据优先",
        "avatar_text": "L",
        "avatar_color": "#38A169",
        "welcome_message": "我是 Lumi。需要整理记录或回顾计划时可以叫我。",
        **LUMI_PERSONA,
        "origin_world_enabled": False,
        "system_prompt": build_full_persona_prompt(LUMI_PERSONA, LUMI_WORLD, origin_enabled=False, noban=False),
        "noban_prompt": None,
        "memory_enabled": False,
        "sort": 99,
        "_worldview": LUMI_WORLD,
    },
]


def seed_characters() -> None:
    """Idempotently add examples without overwriting user-created content."""
    with db.SessionLocal() as session:
        _seed(session)
        _seed_worldviews(session)
        _ensure_alternate_prompts(session)
        _seed_runtime_states(session)
        session.commit()


def _deleted_ids(session: Session) -> set[str]:
    return {row[0] for row in session.query(CharacterDeletion.character_id).all()}


def _seed(session: Session) -> None:
    deleted_ids = _deleted_ids(session)
    for item in DEFAULT_CHARACTERS:
        if item["id"] not in deleted_ids and session.get(Character, item["id"]) is None:
            session.add(Character(**{key: value for key, value in item.items() if not key.startswith("_")}))


def _seed_worldviews(session: Session) -> None:
    deleted_ids = _deleted_ids(session)
    for item in DEFAULT_CHARACTERS:
        if item["id"] in deleted_ids:
            continue
        worldview = item["_worldview"]
        worldview_id = f"{item['id']}:{worldview['key']}"
        if session.get(Worldview, worldview_id) is None:
            session.add(Worldview(id=worldview_id, character_id=item["id"], **worldview))


def _ensure_alternate_prompts(session: Session) -> None:
    """Backfill the optional isolated-mode prompt for custom companion cards."""
    rows = session.query(Character).filter(
        Character.id != "assistant",
        Character.is_file_transfer.is_(False),
        Character.memory_enabled.is_(True),
    ).all()
    for row in rows:
        if row.noban_prompt is not None:
            continue
        worldview = session.query(Worldview).filter(
            Worldview.character_id == row.id,
            Worldview.enabled.is_(True),
        ).order_by(Worldview.sort, Worldview.key).first()
        persona = {key: getattr(row, key) or "" for key in (
            "name", "tagline", "personality", "speech_style", "appearance", "interests",
            "boundaries", "catchphrases", "example_dialogue", "origin_identity",
            "origin_memory", "relationship",
        )}
        world = None if worldview is None else {
            "name": worldview.name,
            "identity": worldview.identity or "",
            "backstory": worldview.backstory or "",
            "rules": worldview.rules or "",
            "preferences": worldview.preferences or "",
        }
        row.noban_prompt = build_full_persona_prompt(persona, world, origin_enabled=bool(row.origin_world_enabled), noban=True)


def _seed_runtime_states(session: Session) -> None:
    deleted_ids = _deleted_ids(session)
    for item in DEFAULT_CHARACTERS:
        if item["id"] in deleted_ids or session.get(CharacterRuntimeState, item["id"]) is not None:
            continue
        session.add(CharacterRuntimeState(
            character_id=item["id"],
            active_worldview_key=item["_worldview"]["key"],
            relationship_state={}, emotion_state={}, current_state={}, self_model_state={}, version=1,
        ))
