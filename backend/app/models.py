"""LifeHub ORM 模型（Phase 0.5）。

所有实体集中在此，供 Alembic 迁移与运行时共享。
设计约定（冻结，见 DATABASE.md §1）：
- 主键优先 UUIDv7（时间有序，可作同步游标）。
- 时间戳统一 UTC（PostgreSQL 用 timestamptz，server_default now()）。
- 软删除走 deleted_at（各业务表后续补，本阶段先立核心表）。

embedding 列：生产为 pgvector vector(1024)（BGE-M3）；
本地无 PG 时回退为 JSON 文本存储（仅 spike 存储，不做向量检索）。
"""
import json
import os
import time
import uuid

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    LargeBinary,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.types import TypeDecorator

from sqlalchemy.orm import declarative_base

Base = declarative_base()


# --------------------------------------------------------------------------- #
# UUIDv7 —— 时间有序，字符串字典序≈时间序，可直接作 /sync/pull 游标
# --------------------------------------------------------------------------- #
def uuid7() -> str:
    ts = int(time.time() * 1000)  # 48-bit 毫秒时间戳
    rnd = os.urandom(10)
    b = bytearray(16)
    b[0:6] = ts.to_bytes(6, "big")
    b[6] = (rnd[0] & 0x0F) | 0x70  # version 7
    b[7] = (rnd[1] & 0x3F) | 0x80  # RFC 4122 variant
    b[8:16] = rnd[2:10]
    return str(uuid.UUID(bytes=bytes(b)))


# --------------------------------------------------------------------------- #
# 混合向量类型：PG → pgvector vector(1024)；其他方言（SQLite）→ JSON 文本
# --------------------------------------------------------------------------- #
class PgVector(TypeDecorator):
    impl = Text
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            from pgvector.sqlalchemy import Vector

            return Vector(1024)
        return Text()

    def process_bind_param(self, value, dialect):
        if dialect.name == "postgresql":
            return value  # list[float] 交给 pgvector 序列化
        return json.dumps(value) if value is not None else None

    def process_result_value(self, value, dialect):
        if dialect.name == "postgresql":
            return value
        if value is None:
            return None
        return json.loads(value)


# --------------------------------------------------------------------------- #
# 核心表（001_init）
# --------------------------------------------------------------------------- #
class Device(Base):
    __tablename__ = "device"
    device_id = Column(String, primary_key=True)
    pubkey = Column(Text, nullable=False)  # Ed25519 原始公钥（base64）
    name = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Conversation(Base):
    __tablename__ = "conversation"
    id = Column(String, primary_key=True, default=uuid7)
    persona = Column(String, default="assistant")  # assistant(小迹) | companion(AI女友)
    # 角色分层（007）：语义化命名，与 persona 双写（新行 persona=character_id）
    character_id = Column(String, nullable=True, index=True)
    # realtime=微信现实聊天（可多气泡）；roleplay=剧情/穿越（单条长回复）。
    reply_mode = Column(String, nullable=False, server_default="realtime")
    # 群聊（032）：single=单聊；group=多角色群聊（character_id=NULL）。
    type = Column(String, nullable=False, server_default="single")
    name = Column(String, nullable=True)  # 群聊显示名；单聊为 NULL
    worldbook_id = Column(String, nullable=True)  # 群聊引用的世界书（可空=现实世界）
    # 发言模式（032）：auto=LLM 自动选人；all=全员各回一条；mention=用户点名@。单聊为 NULL。
    speaker_mode = Column(String, nullable=True, default="auto")
    # 群聊聊天背景（036）：指向 media_asset.id，null=默认纹理。
    background_media_id = Column(String, nullable=True)
    # 群聊回复「字数/条数」限制（036）：群设置可调、后端持久化；按 reply_mode 取用。
    # 真实模式 60-600 字、剧情 300-3000 字；reply_count 真实模式条数 1-5（剧情恒 1）。
    reply_chars_realtime = Column(Integer, nullable=False, server_default=text("180"))
    reply_chars_roleplay = Column(Integer, nullable=False, server_default=text("1000"))
    reply_count = Column(Integer, nullable=False, server_default=text("1"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Message(Base):
    __tablename__ = "message"
    id = Column(String, primary_key=True, default=uuid7)
    conversation_id = Column(String, ForeignKey("conversation.id"), index=True)
    role = Column(String)  # user | assistant
    # 群聊（032）：发言人 character_id；NULL=用户消息。前端渲染逐发言人头像。
    sender_character_id = Column(String, nullable=True, index=True)
    content = Column(Text)
    # 微信富媒体（008）：kind = text | image | file | sticker；图片/文件即消息
    kind = Column(String, nullable=False, server_default="text")
    media_asset_id = Column(String, nullable=True, index=True)  # → media_asset.id
    # 内置表情包引用（009）：kind='sticker' 且为打包表情时指向 sticker.id（渲染本地素材）
    sticker_id = Column(String, nullable=True, index=True)  # → sticker.id
    file_name = Column(Text, nullable=True)  # 文件气泡显示名
    file_size = Column(BigInteger, nullable=True)  # 文件气泡大小（字节）
    # 语音消息（014）：kind='audio' 时带秒数（气泡宽度/时长显示用）
    audio_duration = Column(Integer, nullable=True)
    # 引用回复（019）：服务端持久化并注入 LLM；不再只是前端气泡装饰。
    quote_message_id = Column(String, nullable=True, index=True)
    quote_role = Column(String, nullable=True)  # user | assistant
    quote_content = Column(Text, nullable=True)
    # 红包/转账（033）：kind='redpacket'|'transfer' 时带金额（假钱社交信号，无真实支付）。
    redpacket_amount = Column(Numeric, nullable=True)
    # 红包领取（034）：AI 收到红包必回并「领取」；claimed 标记是否已领、claim_time 领取时刻。
    redpacket_claimed = Column(Boolean, nullable=False, server_default=text("false"))
    redpacket_claim_time = Column(DateTime(timezone=True), nullable=True)
    # 转账接受/婉拒（036）：kind='transfer' 时 AI 选择收下或婉拒。
    # null=待回应；true=接受（前端弹收款图案）；false=婉拒（不弹交互）。
    transfer_accepted = Column(Boolean, nullable=True)
    # 对话来源与上下文可见性：剔除无违禁记忆时保留微信聊天气泡，但不再喂给模型。
    source_mode = Column(String, nullable=False, server_default="standard", index=True)
    context_excluded = Column(
        Boolean, nullable=False, server_default=text("false"), index=True
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# AI 角色反馈（037）—— 气泡右下角 👍/👎 收集用户对 AI 回复的反馈。
# 核心隔离键 character_id：反馈只优化发出该消息的角色，绝不跨角色污染。
# message_id 唯一 → 每条 AI 消息一条反馈，改主意走 upsert 覆盖。
# user_message/ai_message 快照 + reasons + preferred_reply 是 V3 画像分析原料，
# 本轮只收数据不消费。无 user_id：单用户设备制。
# --------------------------------------------------------------------------- #
class ConversationFeedback(Base):
    __tablename__ = "conversation_feedback"
    id = Column(String, primary_key=True, default=uuid7)
    character_id = Column(String, nullable=False, index=True)  # 反馈归属角色
    conversation_id = Column(String, nullable=False, index=True)
    message_id = Column(String, nullable=False, unique=True)  # 被评 AI 消息
    rating = Column(String, nullable=False)  # positive | negative
    user_message = Column(Text, nullable=True)  # 该轮用户消息快照（V3 原料）
    ai_message = Column(Text, nullable=True)  # AI 消息快照
    reasons = Column(JSON, nullable=True)  # ["too_formal", ...] 多选（码，见 FEEDBACK_REASONS）
    custom_feedback = Column(Text, nullable=True)  # 点踩自由填写（「其他」的高价值信息）
    preferred_reply = Column(Text, nullable=True)  # 用户希望回复
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------- #
# 世界书（032_group_worldbook）—— 群聊共享的「世界设定」（酒馆 World Setting）。
# 独立实体，存放于通讯录「标签」；群聊可选引用（conversation.worldbook_id），
# 不选 = 现实世界。与按角色的 Worldview 书不同：本表与角色无关，一表多群共享。
# --------------------------------------------------------------------------- #
class Worldbook(Base):
    __tablename__ = "worldbook"
    id = Column(String, primary_key=True, default=uuid7)
    name = Column(String, nullable=False)  # 世界书名称，如「修仙界」
    summary = Column(Text, nullable=True)  # 简介：这个世界是什么样
    rules = Column(Text, nullable=True)  # 世界规则/社会背景
    user_identity = Column(Text, nullable=True)  # 预留：用户在这个世界的身份
    # R6 世界卡（035）：JSON 数组，protagonist|supporting|faction|location|plotline。
    # 角色卡转成 Character 后回填 character_id；供建群勾选与卡片页面编辑。
    cards = Column(JSON, nullable=False, default=list)
    sort = Column(Integer, nullable=False, default=0)  # 标签列表展示顺序
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())


class ConversationMember(Base):
    """群聊成员联结（032）：一条 Conversation(type='group') 对应多行。

    world_identity 预留成员级世界身份预设（MVP 不写）；sort 表示成员展示顺序。
    """

    __tablename__ = "conversation_member"
    conversation_id = Column(
        String, ForeignKey("conversation.id", ondelete="CASCADE"), primary_key=True
    )
    character_id = Column(String, nullable=False, primary_key=True, index=True)
    world_identity = Column(Text, nullable=True)
    # R6 配角临时加入（035）：temporary=True 的成员为世界书配角卡的临时群成员
    # （前端角标「临时」，可从群设置移除；移除不影响角色卡本身）。
    temporary = Column(Boolean, nullable=False, default=False)
    sort = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class RedPacketClaim(Base):
    """红包领取记录（034）：kind='redpacket' 消息可有多条领取（群红包多人拆）。

    character_id=NULL 表示用户领取；非 NULL 表示对应 AI 角色领取。
    """

    __tablename__ = "redpacket_claim"
    id = Column(String, primary_key=True, default=uuid7)
    message_id = Column(
        String, ForeignKey("message.id", ondelete="CASCADE"), index=True
    )
    character_id = Column(String, nullable=True, index=True)  # NULL=用户
    claimed_at = Column(DateTime(timezone=True), server_default=func.now())


class AppSetting(Base):
    """应用级键值设置（014）：当前克隆音色 voice_id 等。后端可写、GET /ai/tts/status 暴露。"""

    __tablename__ = "app_setting"
    key = Column(String, primary_key=True)
    value = Column(Text, nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Memory(Base):
    __tablename__ = "memory"
    id = Column(String, primary_key=True, default=uuid7)
    type = Column(String)  # event | fact | preference
    content = Column(Text)
    embedding = Column(PgVector(), nullable=True)  # BGE-M3 1024 维
    # 角色分层（007）：每角色独立记忆；NULL=历史数据（backfill='companion'）
    character_id = Column(String, nullable=True, index=True)
    # 来源模式：standard=普通聊天/手动录入；noban=无违禁会话自动形成。
    # 关闭无违禁时可精确剔除后者，不通过内容关键词猜测。
    source_mode = Column(String, nullable=False, server_default="standard", index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    # 提炼版本化（012）：active 正常参与检索；superseded=已被提炼并入他条；archived=已归档
    status = Column(String, nullable=False, server_default="active")
    superseded_by = Column(String, nullable=True)  # 被并入哪条记忆（superseded 时）
    refined_at = Column(DateTime(timezone=True), nullable=True)  # 被提炼时间
    # 记忆强化（013）：importance=常驻权重（0-1，>=0.8 常驻保护）；last_accessed_at=检索新鲜度
    importance = Column(Float, nullable=False, server_default=text("0.5"))
    last_accessed_at = Column(DateTime(timezone=True), nullable=True)


class MemoryRevision(Base):
    """记忆提炼留痕（012）：每次提炼/回滚写一行，供审计与回滚。"""
    __tablename__ = "memory_revision"
    id = Column(String, primary_key=True, default=uuid7)
    memory_id = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False)  # merged|merged_into|archived|restored
    old_content = Column(Text, nullable=True)
    new_content = Column(Text, nullable=True)
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class MemoryRefineLog(Base):
    """记忆提炼审计（012）：每轮提炼跑一条，兼作调度跳过判定依据。"""
    __tablename__ = "memory_refine_log"
    id = Column(String, primary_key=True, default=uuid7)
    character_id = Column(String, nullable=False, index=True)
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    finished_at = Column(DateTime(timezone=True), nullable=True)
    total = Column(Integer, nullable=False, default=0)
    merged = Column(Integer, nullable=False, default=0)
    created = Column(Integer, nullable=False, default=0)
    archived = Column(Integer, nullable=False, default=0)
    unchanged = Column(Integer, nullable=False, default=0)
    error = Column(Text, nullable=True)


# --------------------------------------------------------------------------- #
# AI 角色分层（007_ai_characters）—— 人格层：角色 = 数据，多角色复用
# 系统提示词以 DB 为准；seed_characters() 启动幂等 upsert（见 character_seeds.py）。
# --------------------------------------------------------------------------- #
class Character(Base):
    """一个 AI 聊天角色（人格层）。加角色 = 在 character_seeds.py 加一行 seed。"""
    __tablename__ = "character"
    id = Column(String, primary_key=True)  # slug: assistant | companion | ...
    name = Column(String, nullable=False)  # 显示名
    tagline = Column(String, nullable=True)  # 通讯录副标题
    avatar_text = Column(String, nullable=False)  # 头像字符
    avatar_color = Column(String, nullable=False)  # #RRGGBB
    # 010：自定义头像/聊天背景图（media_asset.id，NULL=用默认 glyph/灰底）
    avatar_media_id = Column(String, nullable=True)
    background_media_id = Column(String, nullable=True)
    welcome_message = Column(String, nullable=True)  # 无历史时欢迎语
    system_prompt = Column(Text, nullable=False)
    noban_prompt = Column(Text, nullable=True)  # NULL=不支持无违禁（前端不显示爱心）
    # 「AI 回复规范」第一层 —— 人格层结构化字段（015_persona_layer）：
    # 由 prompts.build_persona_system_prompt() 确定性组装进 system prompt；
    # system_prompt/noban_prompt 保留作物化兜底。前端 /ai/characters 不透出。
    personality = Column(Text, nullable=True)  # 性格（具体行为，非空泛形容词）
    speech_style = Column(Text, nullable=True)  # 说话口吻/格式（长度/emoji/语气）
    interests = Column(Text, nullable=True)  # 爱好与背景（可并入性格之外的设定）
    boundaries = Column(Text, nullable=True)  # 边界（要做/不要做，反人格）
    catchphrases = Column(Text, nullable=True)  # 口头禅/经典台词
    example_dialogue = Column(Text, nullable=True)  # 示例对话（few-shot，{{char}}/{{user}}）
    # 「AI 回复规范」9 层骨架（016_worldview）——先简单占位，内容后续逐层优化：
    appearance = Column(Text, nullable=True)  # 3 外貌层（Face/Body/Visual Aura）
    origin_world_enabled = Column(Boolean, nullable=False, default=True)  # 原世界记忆开关
    origin_identity = Column(Text, nullable=True)  # 原世界身份（现实人生）
    origin_memory = Column(Text, nullable=True)  # 原世界经历
    relationship = Column(Text, nullable=True)  # 6 关系层（当前关系状态/称呼，简版）
    memory_enabled = Column(Boolean, nullable=False, default=False)
    # 文件传输助手标记（008）：纯存储、不调 AI，聊天页隐藏爱心/语音输入
    is_file_transfer = Column(Boolean, nullable=False, default=False)
    sort = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())


class CharacterDeletion(Base):
    """已由用户删除的角色墓碑。

    内置角色由启动种子提供；仅删除 ``character`` 行会在重启后重新生成。
    墓碑让用户的删除决定成为长期状态，同时不影响以后创建新的自定义角色。
    """

    __tablename__ = "character_deletion"

    character_id = Column(String, primary_key=True)
    deleted_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 角色语音档案（027_character_voice_profile）—— 每个角色独立，不再共用全局 voice_id。
# source_type=system | design | clone；clone 只允许本人或已获授权的声音样本。
# --------------------------------------------------------------------------- #
class CharacterVoiceProfile(Base):
    __tablename__ = "character_voice_profile"

    character_id = Column(String, primary_key=True)
    provider = Column(String, nullable=False, default="minimax")
    source_type = Column(String, nullable=False, default="system")
    voice_id = Column(String, nullable=True)
    sample_media_id = Column(String, nullable=True)
    design_prompt = Column(Text, nullable=True)
    status = Column(String, nullable=False, default="ready")
    enabled = Column(Boolean, nullable=False, default=True)
    reply_policy = Column(String, nullable=False, default="mirror")
    speed = Column(Float, nullable=False, default=1.0)
    volume = Column(Float, nullable=False, default=1.0)
    pitch = Column(Integer, nullable=False, default=0)
    language_boost = Column(String, nullable=False, default="auto")
    last_error = Column(Text, nullable=True)
    consent_attested_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------- #
# 表情包目录（009_stickers）—— 打包进 APK 的静态表情，后端仅存目录
# id=slug=APK 素材文件名（assets/stickers/<id>.png）；description 即"见过"的存档描述，
# 内置表情预置描述 → 永不调 MiMo。AI 回发标记 [表情:<id>] 解析也走本表。
# --------------------------------------------------------------------------- #
class Sticker(Base):
    __tablename__ = "sticker"
    id = Column(String, primary_key=True)  # slug，如 happy
    name = Column(String, nullable=False)  # 显示名（中文）
    description = Column(Text, nullable=False)  # 中文描述（AI 上下文 / 历史标签）
    sort = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 世界观书（016_worldview）—— 「AI 回复规范」第 4/5/7 层（World/Backstory/
# Preferences）。每角色可多本，默认现实世界（key='real'），切换世界观 = 换
# enabled 行，人格卡（Core/Speech/Appearance）不动。
# --------------------------------------------------------------------------- #
class Worldview(Base):
    __tablename__ = "worldview"
    id = Column(String, primary_key=True)  # f"{character_id}:{key}"
    character_id = Column(String, nullable=False)
    key = Column(String, nullable=False)  # real | xianxia | magic | ...
    name = Column(String, nullable=False)  # 显示名，如「现实世界」
    identity = Column(Text, nullable=True)  # 4 该世界身份（姓名/年龄/身份/家庭/职业/阵营）
    backstory = Column(Text, nullable=True)  # 5 该世界经历（童年/重要事件/转折）
    rules = Column(Text, nullable=True)  # 世界规则/社会背景
    preferences = Column(Text, nullable=True)  # 7 偏好与习惯（该世界内）
    # 020：用户在“其他世界”的身份随世界包保存。现实身份只在 user_profile。
    user_identity = Column(Text, nullable=True)
    enabled = Column(Boolean, nullable=False, default=True)
    sort = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# AI 角色运行状态（018_character_context）—— 与静态 Character Card 严格分离
#
# Character / Worldview 是“角色定义”；本表是“这一刻角色处于什么状态”。JSON 只承载
# 可迭代的状态对象，避免每补一个关系/情绪/Self Model 细节都做一次数据库迁移。
# 状态的写入必须由后续 State Reducer 统一处理，LLM 不直接改表。
# --------------------------------------------------------------------------- #
class CharacterRuntimeState(Base):
    __tablename__ = "character_runtime_state"

    character_id = Column(String, primary_key=True)  # → character.id
    active_worldview_key = Column(String, nullable=True, default="real")
    relationship_state = Column(JSON, nullable=False, default=dict)
    emotion_state = Column(JSON, nullable=False, default=dict)
    current_state = Column(JSON, nullable=False, default=dict)
    self_model_state = Column(JSON, nullable=False, default=dict)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------- #
# 用户现实身份 + 手动关系定义（020_profile_relationship）
#
# UserProfile 是“现实中的用户”唯一主资料；其他世界的用户身份放在对应
# Worldview.user_identity，不与现实身份并列。CharacterRelationshipDefinition 是
# 用户明确选择的关系锚点，和会随聊天变化的 relationship_state 严格分离。
# --------------------------------------------------------------------------- #
class UserProfile(Base):
    __tablename__ = "user_profile"

    id = Column(String, primary_key=True, default="owner")
    display_name = Column(String, nullable=False, default="我的")
    lifehub_id = Column(String, nullable=False, default="lifehub_user")
    avatar_media_id = Column(String, nullable=True)
    signature = Column(Text, nullable=True)
    reality_profile = Column(JSON, nullable=False, default=dict)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CharacterRelationshipDefinition(Base):
    __tablename__ = "character_relationship_definition"

    character_id = Column(String, primary_key=True)  # → character.id
    kind = Column(String, nullable=False, default="initial")
    label = Column(String, nullable=False, default="初识")
    description = Column(Text, nullable=True)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CharacterUserKnowledge(Base):
    """某个角色目前知道的用户资料视图。

    用户完整正史仍只存于 UserProfile；这里按角色覆盖或隐藏字段，防止所有角色
    天然全知。后续关系成长可以逐步更新本表，但 LLM 本身没有直接写权限。
    """

    __tablename__ = "character_user_knowledge"

    character_id = Column(String, primary_key=True)  # → character.id
    # 默认拒绝：只有用户在新建/角色页明确允许时，才继承用户全局基础资料。
    inherit_profile = Column(Boolean, nullable=False, default=False)
    field_overrides = Column(JSON, nullable=False, default=dict)
    hidden_fields = Column(JSON, nullable=False, default=list)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CharacterStoryline(Base):
    """按角色独立保存的线性故事路线；节点内容由用户编辑，LLM 只读。"""

    __tablename__ = "character_storyline"

    character_id = Column(String, primary_key=True)  # → character.id
    premise = Column(Text, nullable=True)
    progress = Column(Text, nullable=True)
    direction = Column(Text, nullable=True)
    nodes = Column(JSON, nullable=False, default=list)
    current_node_id = Column(String, nullable=True)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------- #
# 角色 Lorebook（018_character_context）—— 参考 SillyTavern World Info
#
# Character/Worldview 中的核心定义可常驻；体量更大、只在特定话题需要的细节放到
# LoreEntry，由 Context Composer 按关键词、世界与优先级选择性注入。
# --------------------------------------------------------------------------- #
class CharacterLoreEntry(Base):
    __tablename__ = "character_lore_entry"
    __table_args__ = (
        UniqueConstraint("character_id", "key", name="uq_character_lore_key"),
    )

    id = Column(String, primary_key=True, default=uuid7)
    character_id = Column(String, nullable=False, index=True)
    key = Column(String, nullable=False)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    trigger_keywords = Column(JSON, nullable=False, default=list)
    worldview_key = Column(String, nullable=True)
    always_on = Column(Boolean, nullable=False, default=False)
    priority = Column(Integer, nullable=False, default=100)
    position = Column(String, nullable=False, default="after_world")
    enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CharacterPublicEvent(Base):
    """角色在现实世界中可核实的公开正史事件。"""

    __tablename__ = "character_public_event"
    __table_args__ = (
        UniqueConstraint("character_id", "key", name="uq_character_public_event_key"),
    )

    id = Column(String, primary_key=True, default=uuid7)
    character_id = Column(String, nullable=False, index=True)
    key = Column(String, nullable=False)
    event_date = Column(String, nullable=False)  # YYYY / YYYY-MM / YYYY-MM-DD
    end_date = Column(String, nullable=True)
    category = Column(String, nullable=False)
    title = Column(String, nullable=False)
    summary = Column(Text, nullable=False)
    detail = Column(Text, nullable=True)
    tags = Column(JSON, nullable=False, default=list)
    source_urls = Column(JSON, nullable=False, default=list)
    source_level = Column(String, nullable=False, default="official")
    importance = Column(Integer, nullable=False, default=50)
    enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --------------------------------------------------------------------------- #
# 当前态快照（011_entity_snapshot）—— 各业务「当前态」镜像，AI 读库直接查
# 定义类实体（study_resource/exercise_type/pet/inbox_item/life_habit）经 /sync/push
# 增量应用 + 启动全量重放维护；通用 JSON 快照按构造对齐真实 Drift 列。
# 事件流（*_session/*_log/*_event）不落快照，留在 sync_event 供聚合。
# --------------------------------------------------------------------------- #
class EntitySnapshot(Base):
    __tablename__ = "entity_snapshot"
    scope = Column(String, primary_key=True, default="user")
    entity_type = Column(String, primary_key=True)
    entity_id = Column(String, primary_key=True)
    payload = Column(JSON, nullable=False)  # 该类型最新完整定义（snake_case，同 sync_event.payload）
    version = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 同步事件日志（002_sync）—— 轻量变更日志，非完整事件溯源
# 当前态表（如后续的业务表）与本表并存；本表供 reconcile 与 AI 读变化历史。
# --------------------------------------------------------------------------- #
class SyncEvent(Base):
    __tablename__ = "sync_event"
    id = Column(String, primary_key=True, default=uuid7)
    device_id = Column(String, nullable=False, index=True)
    entity_type = Column(String, nullable=False, index=True)
    entity_id = Column(String, nullable=False, index=True)
    operation = Column(String, nullable=False)  # create | update | delete
    payload = Column(JSON, nullable=True)
    version = Column(Integer, nullable=False, default=1)  # 同一实体每变更 +1
    # 客户端本地事件 id（幂等去重键，见 005_sync_idempotency 迁移）
    client_event_id = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    synced_at = Column(DateTime(timezone=True), nullable=True)

    # 幂等：同设备同一本地事件仅接受一次（重推去重）
    __table_args__ = (
        UniqueConstraint("device_id", "client_event_id", name="uq_sync_device_client_event"),
    )


# --------------------------------------------------------------------------- #
# 媒体资源（003_media）—— 宠物照片 / AI 图片理解复用，不把路径直接塞进业务表
# --------------------------------------------------------------------------- #
class MediaAsset(Base):
    __tablename__ = "media_asset"
    id = Column(String, primary_key=True, default=uuid7)
    owner_type = Column(String, nullable=False, default="chat", index=True)  # pet_log | chat | ...
    owner_id = Column(String, nullable=True, index=True)  # 聊天媒体上传时 message 未建 → 可空
    file_hash = Column(String, nullable=True)  # PUT 字节后回填（完整性校验）
    storage_path = Column(Text, nullable=False)  # 相对 UPLOAD_DIR 的路径（通常 = id）
    mime_type = Column(String, nullable=True)
    # 上传生命周期（008）：pending（建元数据）→ ready（PUT 字节完成）
    status = Column(String, nullable=False, default="pending")
    size = Column(BigInteger, nullable=True)
    file_name = Column(Text, nullable=True)
    # 相册表情包的存档描述（009）：首次 MiMo 描述后写入，再发/历史直接复用（见过不重调）
    caption = Column(Text, nullable=True)
    device_id = Column(String, nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 自我识别身份库（017_self_identity）—— 运行能力层，不编入 9 层 AIRP
# 设计稿 docs/DESIGN_SELF_IDENTITY.md：LLM 不负责认脸；前端检测+embedding，
# 后端纯 stdlib 比对。identity 存储 → check 三态判定 → 注入 /ai/chat 图片分支。
# --------------------------------------------------------------------------- #
class FaceGallery(Base):
    """身份库：character_id → 子身份簇 → 多 embedding。

    embedding = float32×192 原始字节（BLOB，约 0.8KB/张），后端 struct.unpack 解析；
    不用 TEXT JSON（省 5~10 倍、解析快）。不存平均脸——不同妆造靠多参考图 + 子身份簇覆盖。
    source_asset_id 指向参考图的 media_asset（溯源）。
    """

    __tablename__ = "face_gallery"
    id = Column(String, primary_key=True, default=uuid7)
    character_id = Column(String, nullable=False, index=True)  # companion
    sub_identity = Column(String, nullable=True)
    # natural_daily | stage_makeup | selfie | side_profile
    embedding = Column(LargeBinary, nullable=False)  # float32×192 原始字节（mobile_face_net）
    source_asset_id = Column(String, nullable=True)  # → media_asset.id 溯源
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 私人朋友圈（004_moment）—— PRD R12 / Phase 2 后半段顺手加
# 仅表结构，无业务 API；媒体复用 MediaAsset 多态（owner_type='moment', owner_id=moment.id），
# 不建关联表。对齐 Flutter 端 Moments 表（app/lib/core/database/tables.dart）。
# --------------------------------------------------------------------------- #
class Moment(Base):
    __tablename__ = "moment"
    id = Column(String, primary_key=True, default=uuid7)
    author_type = Column(String, nullable=False, server_default="user")  # user | character
    character_id = Column(String, nullable=True, index=True)
    content = Column(Text, nullable=False)
    visibility = Column(String, nullable=False, server_default="private")  # 仅自己可见
    source = Column(String, nullable=False, server_default="manual")  # manual | public_import
    source_platform = Column(String, nullable=True)  # instagram | weibo | manual
    source_url = Column(Text, nullable=True)
    source_post_id = Column(String, nullable=True)
    location = Column(String, nullable=True)
    ai_context = Column(Text, nullable=True)
    published_precision = Column(String, nullable=False, server_default="datetime")
    device_id = Column(String, nullable=False, index=True)  # 同步作用域
    published_at = Column(DateTime(timezone=True), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint(
            "source_platform", "source_post_id", name="uq_moment_public_source"
        ),
    )


class MomentMedia(Base):
    __tablename__ = "moment_media"
    id = Column(String, primary_key=True, default=uuid7)
    moment_id = Column(
        String, ForeignKey("moment.id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_asset_id = Column(String, nullable=True)
    remote_url = Column(Text, nullable=True)
    sort = Column(Integer, nullable=False, default=0)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)


class MomentLike(Base):
    __tablename__ = "moment_like"
    id = Column(String, primary_key=True, default=uuid7)
    moment_id = Column(
        String, ForeignKey("moment.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_type = Column(String, nullable=False)  # user | character
    actor_id = Column(String, nullable=False, server_default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint(
            "moment_id", "actor_type", "actor_id", name="uq_moment_like_actor"
        ),
    )


class MomentComment(Base):
    __tablename__ = "moment_comment"
    id = Column(String, primary_key=True, default=uuid7)
    moment_id = Column(
        String, ForeignKey("moment.id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_type = Column(String, nullable=False)  # user | character
    actor_id = Column(String, nullable=False, server_default="")
    content = Column(Text, nullable=False)
    reply_to_id = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# --------------------------------------------------------------------------- #
# 小米运动健康（Mi Fitness）自动同步（006_mi_fitness）—— 云读取，非设备手动录入
# 独立建表：与用户手动记录分离；App 经签名 endpoint 直接查询。
# 时间戳统一 UTC；date 为自然日（中国区 YYYY-MM-DD）。
# --------------------------------------------------------------------------- #
class MiActivityDaily(Base):
    """每日活动汇总：步数 / 距离 / 活动卡路里。date 为唯一键，天然幂等。"""
    __tablename__ = "mi_activity_daily"
    date = Column(String, primary_key=True)  # YYYY-MM-DD
    steps = Column(Integer, nullable=False, default=0)
    distance_m = Column(Float, nullable=False, default=0.0)
    active_kcal = Column(Float, nullable=False, default=0.0)
    timezone = Column(String, nullable=False, default="Asia/Shanghai")
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiWorkout(Base):
    """小米运动记录：跑步/骑行/健走/器械等，native_id 唯一去重。"""
    __tablename__ = "mi_workout"
    id = Column(String, primary_key=True, default=uuid7)
    native_id = Column(String, nullable=False, unique=True)  # 云记录 sid_key_time
    activity_type = Column(String, nullable=False, index=True)
    sport_category = Column(String, nullable=True)
    start_at = Column(DateTime(timezone=True), nullable=False, index=True)
    end_at = Column(DateTime(timezone=True), nullable=True)
    duration_min = Column(Integer, nullable=False, default=0)
    distance_m = Column(Float, nullable=True)
    calories_kcal = Column(Float, nullable=True)
    avg_hr_bpm = Column(Integer, nullable=True)
    max_hr_bpm = Column(Integer, nullable=True)
    avg_pace_s_per_km = Column(Float, nullable=True)
    max_pace_s_per_km = Column(Float, nullable=True)
    total_steps = Column(Integer, nullable=True)
    raw = Column(JSON, nullable=True)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiHeartRateSample(Base):
    """心率采样（含静息心率 sample_type='resting'）。timestamp+sample_type 唯一。"""
    __tablename__ = "mi_heart_rate"
    id = Column(String, primary_key=True, default=uuid7)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    bpm = Column(Integer, nullable=False)
    sample_type = Column(String, nullable=False, default="passive")  # passive|active|resting
    synced_at = Column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint("timestamp", "sample_type", name="uq_mi_hr_ts_type"),
    )


class MiSleepSession(Base):
    """睡眠会话：起止、时长、深浅睡/REM 阶段、评分。"""
    __tablename__ = "mi_sleep"
    id = Column(String, primary_key=True, default=uuid7)
    sleep_id = Column(String, nullable=False, unique=True)
    start_at = Column(DateTime(timezone=True), nullable=False)
    end_at = Column(DateTime(timezone=True), nullable=False)
    duration_min = Column(Integer, nullable=False, default=0)
    awake_min = Column(Integer, nullable=False, default=0)
    asleep_min = Column(Integer, nullable=False, default=0)
    score = Column(Integer, nullable=True)
    is_nap = Column(Boolean, nullable=False, default=False)
    stages = Column(JSON, nullable=True)  # [{stage: deep|light|rem|awake, minutes}]
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiBodyMeasurement(Base):
    """体重 / 身体成分（体脂、肌肉、水分、骨量、内脏脂肪、基础代谢、体年龄）。"""
    __tablename__ = "mi_body_measurement"
    id = Column(String, primary_key=True, default=uuid7)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    weight_kg = Column(Float, nullable=False)
    bmi = Column(Float, nullable=True)
    body_fat_pct = Column(Float, nullable=True)
    muscle_kg = Column(Float, nullable=True)
    water_pct = Column(Float, nullable=True)
    bone_kg = Column(Float, nullable=True)
    visceral_fat_score = Column(Integer, nullable=True)
    basal_meta_kcal = Column(Integer, nullable=True)
    body_age = Column(Integer, nullable=True)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiSpo2Sample(Base):
    """血氧饱和度采样。"""
    __tablename__ = "mi_spo2"
    id = Column(String, primary_key=True, default=uuid7)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    spo2_pct = Column(Integer, nullable=False)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiStressSample(Base):
    """压力值采样：score 0-100，level low|medium|high。"""
    __tablename__ = "mi_stress"
    id = Column(String, primary_key=True, default=uuid7)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    score = Column(Integer, nullable=False)
    level = Column(String, nullable=True)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())


class MiAbnormalHeartbeat(Base):
    """异常心跳事件（房颤等预警）。"""
    __tablename__ = "mi_abnormal_heartbeat"
    id = Column(String, primary_key=True, default=uuid7)
    start_at = Column(DateTime(timezone=True), nullable=False)
    end_at = Column(DateTime(timezone=True), nullable=True)
    duration_sec = Column(Integer, nullable=False, default=0)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())
