"""LifeHub Backend — Phase 0.5（云端能力骨架）。

端点（冻结，见 API.md）：
  GET  /health                 存活探针
  POST /auth/register          设备公钥注册（一次性，免签）
  POST /ai/chat                聊天（需签名）→ {"reply": "..."}
  POST /ai/embedding           Qwen qwen3.7-text-embedding 向量化（需签名）→ {"embedding": [...], "model": "..."}
  POST /ai/memory/search       Memory 检索（需签名）→ {"results": [...]}
  POST /sync/push              手机上传变更（需签名）→ {"accepted": N, "conflicts": []}
  GET  /sync/pull?cursor=...   拉取增量（需签名）→ {"events": [...], "next_cursor": "..."}
"""
import copy
import difflib
import hashlib
import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy import func, or_

from . import (
    ai_gateway,
    auth,
    character_seeds,
    chat_common,
    config,
    db,
    errors,
    group_chat,
    memory_refine,
    mi_fitness_sync,
    prompts,
    public_moment_seeds,
    rate_limit,
    snapshot,
    sticker_seeds,
    timeline,
    tts_minimax,
)
from .routers.feedback import (
    FEEDBACK_REASONS,
    _feedback_confidence,
    feedback_list,
    feedback_stats,
    feedback_submit,
    router as feedback_router,
)
from .routers.memory import (
    character_noban_memories_delete,
    memory_clear,
    memory_create,
    memory_delete,
    memory_list,
    memory_patch,
    memory_refine_endpoint,
    memory_revisions_endpoint,
    memory_rollback_endpoint,
    memory_search,
    memory_stats_endpoint,
    router as memory_router,
)
from .routers.reply_guideline import (
    reply_guideline_get,
    reply_guideline_put,
    router as reply_guideline_router,
)
from .routers.self_identity import (
    router as self_identity_router,
    self_identity_calibrate,
    self_identity_check,
    self_identity_gallery,
    self_identity_gallery_clear,
    self_identity_import,
    self_identity_status,
)
from .security import require_signature, unauthorized as _unauthorized
from .models import (
    Character,
    CharacterDeletion,
    CharacterLoreEntry,
    CharacterPublicEvent,
    CharacterRelationshipDefinition,
    CharacterRuntimeState,
    CharacterStoryline,
    CharacterUserKnowledge,
    CharacterVoiceProfile,
    Conversation,
    ConversationMember,
    FaceGallery,
    MediaAsset,
    Memory,
    MemoryRefineLog,
    MemoryRevision,
    Message,
    Moment,
    MomentComment,
    MomentLike,
    MomentMedia,
    RedPacketClaim,
    MiActivityDaily,
    MiWorkout,
    SyncEvent,
    UserProfile,
    Worldbook,
    Worldview,
    uuid7,
)

app = FastAPI(title="LifeHub Backend Phase 0.5")
errors.register_error_handlers(app)
app.include_router(feedback_router)
app.include_router(memory_router)
app.include_router(reply_guideline_router)
app.include_router(self_identity_router)


# 显式配置 lifehub 日志：uvicorn 默认只配自身 logger，根 logger 无 handler 会丢 INFO。
# 固定 INFO → stderr（docker logs 可见），供 MCP 调用审计等排障。
_logger = logging.getLogger("lifehub")
if not _logger.handlers:
    _logger.addHandler(logging.StreamHandler())
_logger.setLevel(logging.INFO)
_logger.propagate = False


@app.on_event("startup")
def _startup() -> None:
    db.init_db()
    character_seeds.seed_characters()  # 只补内置默认；用户在手机改写的角色卡永不覆盖
    with db.SessionLocal() as session:
        public_moment_seeds.seed_public_moments(session)
        session.commit()
    sticker_seeds.seed_stickers()  # 表情包目录（009）：幂等 upsert
    if config.LIFE_TRACKING_ENABLED:
        mi_fitness_sync.start_scheduler()
    try:
        if config.LIFE_TRACKING_ENABLED:
            snapshot.ensure_snapshot()  # 当前态镜像：reconcile（事件权威）+ seed（补默认）
    except Exception:
        import logging
        logging.getLogger("lifehub").exception("snapshot ensure failed")
    memory_refine.start_scheduler()  # 记忆提炼（每日自动，见 memory_refine.py）


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "db": "postgres" if db.IS_PG else "sqlite(fallback)"}


@app.post("/auth/register")
async def register(request: Request) -> dict:
    body = await request.json()
    device_id = body.get("device_id", "")
    if not device_id:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "缺少 device_id", "retryable": False}},
        )
    # 限流：注册 5 req/min（公网暴露于 Tunnel，防滥用）
    if not rate_limit.check_rate_limit(f"register:{device_id}", max_requests=5):
        raise HTTPException(
            status_code=429,
            detail={"error": {"code": "RATE_LIMITED", "message": "注册过于频繁", "retryable": True}},
        )
    # 已存在设备：须携带有效签名（用已注册公钥）才允许覆盖（密钥轮换）；否则 409
    existing = auth.get_device(device_id)
    if existing is not None and not config.SKIP_AUTH:
        timestamp = request.headers.get("X-Timestamp", "")
        signature = request.headers.get("X-Signature", "")
        body_bytes = await request.body()
        ok = auth.verify_signature(
            device_id, timestamp, signature, request.method, request.url.path, body_bytes
        )
        if not ok:
            raise HTTPException(
                status_code=409,
                detail={"error": {"code": "DEVICE_EXISTS", "message": "设备已注册，需签名覆盖", "retryable": False}},
            )
    auth.register_device(device_id, body["pubkey"], body.get("name"))
    return {"device_id": device_id, "status": "registered"}


# --------------------------------------------------------------------------- #
# AI Gateway
# --------------------------------------------------------------------------- #
@app.post("/ai/health")
async def ai_health(_: None = Depends(require_signature)) -> dict:
    """AI 服务健康/配置探针：返回是否已配置真实 Key（不泄露 key 本身）。

    手机端 AI 设置页用此端点显示状态 + 测试连接，无需也不可能拿到 Key。
    """
    return {
        "configured": ai_gateway.is_configured(),
        "provider": "deepseek",
        "model": "deepseek-chat",
    }


def _preview_content(msg: Message) -> str:
    """主页/会话列表预览文本：媒体消息转短标签。"""
    content = msg.content or ""
    if msg.kind == "image":
        content = f"[图片] {content}".strip() if content else "[图片]"
    elif msg.kind == "sticker":
        content = "[表情包]"
    elif msg.kind == "file":
        content = msg.file_name or "[文件]"
    elif msg.kind == "audio":
        content = "[语音]"
    elif msg.kind == "redpacket":
        content = "[红包]"
    elif msg.kind == "transfer":
        content = "[转账]"
    return content


@app.post("/ai/chat")
async def ai_chat(request: Request, _: None = Depends(require_signature)) -> dict:
    body = await request.json()
    message = body.get("message", "")
    # 角色分层：character_id 优先，兼容老 APK 的 persona 别名
    character_id = body.get("character_id") or body.get("persona") or "assistant"
    conversation_id = body.get("conversation_id")
    noban = bool(body.get("noban", False))
    message_source_mode = "noban" if noban else "standard"
    requested_reply_mode = body.get("reply_mode")
    if requested_reply_mode not in ("realtime", "roleplay"):
        requested_reply_mode = None
    try:
        requested_reply_max_chars = int(body.get("reply_max_chars"))
    except (TypeError, ValueError):
        requested_reply_max_chars = None
    try:
        requested_reply_bubble_count = int(body.get("reply_bubble_count"))
    except (TypeError, ValueError):
        requested_reply_bubble_count = None
    quote_body = body.get("quote") if isinstance(body.get("quote"), dict) else {}
    # 微信富媒体（008/009）：kind = text | image | file | sticker；纯文本不关联媒体
    media_kind = body.get("kind") or "text"
    media_asset_id = body.get("media_asset_id") if media_kind != "text" else None
    force_voice_reply = body.get("force_voice_reply")
    has_explicit_voice_choice = isinstance(force_voice_reply, bool)
    voice_reply_requested = media_kind == "audio" or force_voice_reply is True
    # 内置表情包（009）：kind='sticker' + sticker_id → 目录描述（不调 MiMo）
    sticker_id = body.get("sticker_id") if media_kind == "sticker" else None
    # 语音消息（014）：kind='audio' 带音频秒数（content=本地 ASR 转写文字）
    audio_duration = None
    if media_kind == "audio":
        try:
            audio_duration = int(body.get("audio_duration") or 0) or None
        except (TypeError, ValueError):
            audio_duration = None
    # 红包/转账（033）：kind='redpacket'|'transfer' 带金额（content=留言，假钱）
    redpacket_amount = None
    if media_kind in ("redpacket", "transfer"):
        try:
            redpacket_amount = float(body.get("redpacket_amount"))
        except (TypeError, ValueError):
            redpacket_amount = None

    char = ai_gateway.get_character(character_id)
    memory_enabled = bool(char and char.memory_enabled)

    # 媒体上下文：图片 → MiMo 瞬时描述；文件 → 文件名；表情包 → 存档/目录描述。
    # 抽到 chat_common.resolve_media_context（单聊/群聊共用），含自我识别注入。
    media_ctx, media_file_name, media_file_size = chat_common.resolve_media_context(
        media_kind, media_asset_id, sticker_id, body.get("self_identity")
    )

    quote_message_id: str | None = None
    quote_role: str | None = None
    quote_content: str | None = None
    with db.SessionLocal() as s:
        # 会话持久化：无 conversation_id 则新建（按 character_id，persona 双写兼容）；
        # 否则复用（老会话补 backfill character_id）
        if not conversation_id:
            conv = Conversation(
                id=uuid7(),
                persona=character_id,
                character_id=character_id,
                reply_mode=requested_reply_mode or "realtime",
            )
            s.add(conv)
        else:
            conv = s.get(Conversation, conversation_id)
            if conv is None:
                conv = Conversation(
                    id=uuid7(),
                    persona=character_id,
                    character_id=character_id,
                    reply_mode=requested_reply_mode or "realtime",
                )
                s.add(conv)
            elif conv.character_id is None:
                conv.character_id = character_id
            conversation_id = conv.id

        if requested_reply_mode:
            conv.reply_mode = requested_reply_mode
        reply_mode = conv.reply_mode or "realtime"
        # 验收批3③：剧情模式把用户【...】提取为剧情方向指示（早提取——在记忆提取与
        # 消息落库之前，元指令不进记忆/历史/红包附言；（）旁白原样保留）。
        message, user_directive = chat_common.extract_user_directives(
            message, roleplay=reply_mode == "roleplay"
        )
        if reply_mode == "roleplay":
            reply_max_chars = max(
                300, min(requested_reply_max_chars or 1000, 3000)
            )
            reply_bubble_count = 1
        else:
            reply_max_chars = max(
                60, min(requested_reply_max_chars or 180, 600)
            )
            reply_bubble_count = max(
                1, min(requested_reply_bubble_count or 3, 5)
            )

        # 引用优先按服务端 message_id 回查并确认属于当前会话；本地乐观消息还没有
        # 服务端 id 时，接受客户端正文兜底，但限制长度和角色枚举。
        raw_quote_id = str(quote_body.get("message_id") or "").strip()
        if raw_quote_id and not raw_quote_id.startswith("local-"):
            quoted = s.get(Message, raw_quote_id)
            if quoted is not None and quoted.conversation_id == conv.id:
                quote_message_id = quoted.id
                quote_role = quoted.role
                quote_content = chat_common.reference_text(quoted)
        if not quote_content:
            fallback_quote = str(quote_body.get("content") or "").strip()[:4000]
            if fallback_quote:
                quote_message_id = raw_quote_id or None
                raw_quote_role = quote_body.get("role")
                quote_role = (
                    raw_quote_role
                    if raw_quote_role in ("user", "assistant")
                    else None
                )
                quote_content = fallback_quote

        # 当前用户消息尚未落表，先取它之前的历史；避免本轮在 history 和末尾重复两次。
        # 群聊与私人聊天完全隔离：单聊只读本会话历史，不并入任何群聊或其他单聊。
        history = chat_common.build_history(chat_common.recent_history_rows(s, conv.id))

        # 落 user message（图片/文件/表情包带媒体字段；content 保留用户文字，可为空）
        user_row = Message(
            conversation_id=conv.id,
            role="user",
            content=message,
            kind=media_kind,
            media_asset_id=media_asset_id,
            sticker_id=sticker_id,
            file_name=media_file_name,
            file_size=media_file_size,
            audio_duration=audio_duration,
            quote_message_id=quote_message_id,
            quote_role=quote_role,
            quote_content=quote_content,
            source_mode=message_source_mode,
            redpacket_amount=redpacket_amount,
        )
        s.add(user_row)
        s.flush()
        user_message_payload = {
            "id": user_row.id,
            "role": "user",
            "kind": user_row.kind or "text",
            "content": user_row.content or "",
            "media_asset_id": user_row.media_asset_id,
            "sticker_id": user_row.sticker_id,
            "file_name": user_row.file_name,
            "file_size": user_row.file_size,
            "audio_duration": user_row.audio_duration,
            "quote_message_id": user_row.quote_message_id,
            "quote_role": user_row.quote_role,
            "quote_content": user_row.quote_content,
            "redpacket_amount": user_row.redpacket_amount,
            "redpacket_claimed": bool(user_row.redpacket_claimed),
            "redpacket_claim_time": (
                user_row.redpacket_claim_time.isoformat()
                if user_row.redpacket_claim_time
                else None
            ),
            "created_at": user_row.created_at.isoformat(),
        }
        s.commit()

    # 长期记忆：仅 memory_enabled 角色检索注入（按角色隔离）
    memories = []
    if memory_enabled:
        try:
            memories = ai_gateway.memory_search(message, limit=5, character_id=character_id)
        except Exception:
            memories = []
    message_for_ai = chat_common.current_message_with_quote(message, quote_role, quote_content)
    # 红包/转账（033）：本轮消息以社交信号描述注入（假钱，AI 仅感知收到）。
    if media_kind == "redpacket":
        _amt = chat_common.redpacket_amount_text(redpacket_amount)
        message_for_ai = (
            f"用户发来红包：金额{_amt}元，留言：{message}"
            if message
            else f"用户发来红包：金额{_amt}元"
        )
        # R4：红包必回——以收到并致谢的口吻回应，至少说一句谢谢。
        message_for_ai += "（你收到了这个红包，请以收下并致谢的口吻回应，至少说一句谢谢。）"
    elif media_kind == "transfer":
        _amt = chat_common.redpacket_amount_text(redpacket_amount)
        message_for_ai = (
            f"用户转账{_amt}元，附言：{message}"
            if message
            else f"用户转账{_amt}元"
        )
        # 验收批2：转账可收可拒——模型决定，回复最前面写 [接受]/[婉拒] 标记。
        message_for_ai += (
            "（你收到了这笔转账，可以决定收下或婉拒：若收下，在回复最前面写 [接受]；"
            "若婉拒，写 [婉拒]。然后按你的选择自然回复，拒绝时礼貌说明理由。）"
        )
    # 验收批3③：用户【】方向指示晚注入——红包/转账分支会整体替换 message_for_ai，
    # 故在其后统一拼到最终 message_for_ai 前；只进本轮模型输入，不进 history。
    if user_directive:
        message_for_ai = f"【用户指示：{user_directive}】\n{message_for_ai}"
    _logger.info(
        "ai_chat_mode character=%s conversation=%s noban=%s reply_mode=%s "
        "reply_max_chars=%s reply_bubble_count=%s",
        character_id,
        conv.id,
        noban,
        reply_mode,
        reply_max_chars,
        reply_bubble_count,
    )
    reply = ai_gateway.chat(
        message_for_ai,
        character_id=character_id,
        history=history,
        noban=noban,
        memories=memories,
        media=media_ctx,
        reply_mode=reply_mode,
        voice_reply_requested=voice_reply_requested,
        reply_max_chars=reply_max_chars,
        reply_bubble_count=reply_bubble_count,
        forbidden_memories=ai_gateway.memory_forbidden(character_id),
    )
    reply = ai_gateway.normalize_generated_reply(reply or "", reply_mode)
    # 转账收/拒（验收批2）：解析 [接受]/[婉拒] 前缀标记，剥离后继续走常规拆条。
    transfer_accepted = None
    if media_kind == "transfer":
        transfer_accepted, reply = ai_gateway.parse_transfer_decision(reply)

    # 记忆提取（013）：仅 memory_enabled 角色；LLM 优先 + 降级 regex；补算 embedding；
    # 幂等：精确匹配 + 近重复（difflib ≥0.95，防 LLM 措辞漂移）都跳过
    if memory_enabled and message.strip():
        for mtype, content, importance in ai_gateway.extract_memories_from_message(
            message, reply
        ):
            with db.SessionLocal() as s:
                dup = (
                    s.query(ai_gateway.Memory.id)
                    .filter_by(
                        type=mtype,
                        content=content,
                        character_id=character_id,
                        source_mode=message_source_mode,
                    )
                    .first()
                )
                if dup is not None:
                    continue
                near = (
                    s.query(ai_gateway.Memory.content)
                    .filter(
                        ai_gateway.Memory.character_id == character_id,
                        ai_gateway.Memory.source_mode == message_source_mode,
                    )
                    .order_by(ai_gateway.Memory.created_at.desc())
                    .limit(100)
                    .all()
                )
                if any(
                    difflib.SequenceMatcher(None, content, c[0]).ratio() >= 0.95
                    for c in near
                ):
                    continue
                ai_gateway.memory_add(
                    content,
                    type=mtype,
                    embedding=ai_gateway._embed_tolerant(content),
                    character_id=character_id,
                    importance=importance,
                    source_mode=message_source_mode,
                )

    # 无论开关是否启用都剥掉模型遗留标记；默认不再把标记解析成表情气泡。
    reply, parsed_sticker_id = ai_gateway.resolve_sticker_reply(reply or "")
    ai_sticker_id = (
        parsed_sticker_id if config.AI_STICKER_REPLIES_ENABLED else None
    )
    reply_segments = ai_gateway.split_reply_segments(
        reply,
        reply_mode,
        require_spoken=voice_reply_requested,
        reply_bubble_count=reply_bubble_count,
    )
    combined_reply = "\n".join(reply_segments)
    # R4 红包必回：AI 完全空回复（模型拒答）→ 兜底致谢，红包/转账必须有回应。
    # 转账若标记为婉拒，兜底也按婉拒口吻（与决定一致）。
    if (
        media_kind in ("redpacket", "transfer")
        and not combined_reply.strip()
        and not ai_sticker_id
    ):
        if media_kind == "transfer" and transfer_accepted is False:
            fallback_line = "这钱就不收了，心意领了～"
        else:
            fallback_line = (
                "谢谢你的红包！" if media_kind == "redpacket" else "收到你的转账啦，谢谢～"
            )
        combined_reply = fallback_line
        reply_segments = [fallback_line]
    spoken_reply = ai_gateway.spoken_text_for_tts(combined_reply, reply_mode)
    if voice_reply_requested and reply_mode == "roleplay" and not spoken_reply:
        # 硬兜底：绿色按钮/用户语音要求本轮必须落语音消息。即使 Provider
        # 极端情况下只生成动作，也只追加最短台词，绝不把动作或环境拿去朗读。
        fallback_line = "嗯，我在。"
        combined_reply = (
            f"{combined_reply}\n\n{fallback_line}" if combined_reply else fallback_line
        )
        reply_segments = [combined_reply]
        spoken_reply = "嗯，我在。"

    # 语音回复（014）：仅当本条消息是语音（kind='audio'）才合成 AI 语音回复，
    # 且已配置默认女声/克隆音色。语音↔语音，文字聊天不阻塞 TTS（保速度）。
    # 任何 TTS 异常静默降级纯文字（语音是锦上添花，不能阻断聊天）。
    voice_profile = tts_minimax.get_profile(character_id)
    voice_policy = voice_profile.get("reply_policy", "mirror")
    explicit_voice_request = any(
        token in message for token in ("发语音", "语音说", "听听你的声音", "用声音说")
    )
    occasional_hit = (
        int(hashlib.sha256(f"{conv.id}:{user_row.id}".encode()).hexdigest()[:8], 16)
        % 100
        < 12
    )
    # 新客户端的输入框小话筒对“文字消息”拥有最终决定权：开=语音，关=文字。
    # 用户发来的本身就是语音时始终语音回复，不受按钮/旧策略影响。
    # 未携带该字段的旧客户端继续兼容角色语音策略。
    wants_voice_for_text = (
        force_voice_reply
        if has_explicit_voice_choice
        else (
            voice_policy == "always"
            or explicit_voice_request
            or (voice_policy == "sometimes" and occasional_hit)
        )
    )
    tts_reply = (
        voice_profile.get("enabled", True)
        and spoken_reply
        and not ai_sticker_id
        and (
            media_kind == "audio"
            or (
                wants_voice_for_text
                and (has_explicit_voice_choice or voice_policy != "off")
            )
        )
    )
    audio_media_id, audio_dur = (
        _maybe_tts(character_id, spoken_reply) if tts_reply else (None, None)
    )
    _logger.info(
        "ai_voice_result character=%s conversation=%s requested=%s explicit=%s "
        "media_kind=%s reply_mode=%s spoken_chars=%s generated=%s",
        character_id,
        conv.id,
        voice_reply_requested,
        has_explicit_voice_choice,
        media_kind,
        reply_mode,
        len(spoken_reply),
        bool(audio_media_id),
    )

    reply_messages: list[dict] = []
    if combined_reply or ai_sticker_id:
        with db.SessionLocal() as s:
            base_time = datetime.now(timezone.utc)
            if ai_sticker_id:
                rows = [
                    Message(
                        conversation_id=conv.id,
                        role="assistant",
                        content=combined_reply,
                        kind="sticker",
                        sticker_id=ai_sticker_id,
                        source_mode=message_source_mode,
                        created_at=base_time,
                    )
                ]
            elif audio_media_id:
                # 现实聊天：一个微信语音气泡即可。
                # 剧情/穿越：完整剧情仍以文字显示，随后附一条只朗读引号台词的语音；
                # 语音副本排除出后续 LLM 历史，避免和上一条完整剧情重复注入。
                rows = []
                if reply_mode == "roleplay":
                    rows.append(
                        Message(
                            conversation_id=conv.id,
                            role="assistant",
                            content=combined_reply,
                            kind="text",
                            source_mode=message_source_mode,
                            created_at=base_time,
                        )
                    )
                rows.append(
                    Message(
                        conversation_id=conv.id,
                        role="assistant",
                        content=spoken_reply,
                        kind="audio",
                        media_asset_id=audio_media_id,
                        audio_duration=audio_dur,
                        source_mode=message_source_mode,
                        context_excluded=reply_mode == "roleplay",
                        created_at=base_time
                        + (timedelta(milliseconds=1) if reply_mode == "roleplay" else timedelta()),
                    )
                )
            else:
                rows = [
                    Message(
                        conversation_id=conv.id,
                        role="assistant",
                        content=segment,
                        kind="text",
                        source_mode=message_source_mode,
                        created_at=base_time + timedelta(milliseconds=index),
                    )
                    for index, segment in enumerate(reply_segments)
                ]
            s.add_all(rows)
            s.flush()
            reply_messages = [
                {
                    "id": row.id,
                    "content": row.content or "",
                    "kind": row.kind,
                    "media_asset_id": row.media_asset_id,
                    "sticker_id": row.sticker_id,
                    "audio_duration": row.audio_duration,
                    "created_at": row.created_at.isoformat(),
                }
                for row in rows
            ]
            s.commit()

    # R4 领取落库：红包/转账且 AI 有回应 → 标记已领取（首次），AI 领取记录一条。
    if media_kind in ("redpacket", "transfer") and (
        combined_reply.strip() or ai_sticker_id
    ):
        with db.SessionLocal() as s:
            ur = s.get(Message, user_row.id)
            if ur is not None:
                # 转账收/拒（验收批2）：决定落库（不明→默认接受，与旧行为一致）
                if media_kind == "transfer" and ur.transfer_accepted is None:
                    ur.transfer_accepted = (
                        bool(transfer_accepted)
                        if transfer_accepted is not None
                        else True
                    )
                exists = (
                    s.query(RedPacketClaim.id)
                    .filter_by(message_id=ur.id, character_id=character_id)
                    .first()
                )
                if exists is None:
                    if not ur.redpacket_claimed:
                        ur.redpacket_claimed = True
                        ur.redpacket_claim_time = datetime.now(timezone.utc)
                    s.add(
                        RedPacketClaim(message_id=ur.id, character_id=character_id)
                    )
                    s.commit()

    # 转账收/拒：AI 回应后决定已知，回填本轮 user_message（前端即时上屏）
    if media_kind == "transfer":
        user_message_payload["transfer_accepted"] = (
            bool(transfer_accepted) if transfer_accepted is not None else True
        )

    resp = {
        "reply": combined_reply,
        "replies": reply_messages,
        "reply_mode": reply_mode,
        "reply_max_chars": reply_max_chars,
        "reply_bubble_count": reply_bubble_count,
        "conversation_id": conv.id,
        "user_message": user_message_payload,
    }
    if ai_sticker_id:
        resp["sticker_id"] = ai_sticker_id
    if audio_media_id:
        resp["audio_media_id"] = audio_media_id
        resp["audio_duration"] = audio_dur
    return resp


# --------------------------------------------------------------------------- #
# 世界书（032_group_worldbook）—— 通讯录「标签」里的独立世界设定实体。
# 群聊可选引用（conversation.worldbook_id）；不选 = 现实世界。
# --------------------------------------------------------------------------- #
_CARD_KINDS = ("protagonist", "supporting", "faction", "location", "plotline")


def _card_serialize(card: dict) -> dict:
    return {
        "id": card.get("id"),
        "kind": card.get("kind", ""),
        "name": card.get("name", ""),
        "description": card.get("description", ""),
        "avatar_text": card.get("avatar_text", ""),
        "avatar_color": card.get("avatar_color", ""),
        # 角色卡（protagonist/supporting）转成 Character 后回填；非角色卡恒 None。
        "character_id": card.get("character_id"),
        "role_rank": card.get("role_rank"),  # 角色卡：地位/辈分
        # 情节线卡：剧情推进字段
        "premise": card.get("premise"),
        "progress": card.get("progress"),
        "direction": card.get("direction"),
        "nodes": card.get("nodes") or [],
        "created_at": card.get("created_at"),
        "updated_at": card.get("updated_at"),
    }


def _find_worldbook_card(wb: Worldbook, card_id: str) -> dict | None:
    for c in wb.cards or []:
        if c.get("id") == card_id:
            return c
    return None


def _card_color(card_id: str) -> str:
    palette = (
        "#E7A5B5",
        "#86B6D8",
        "#9BC69B",
        "#C5A6D8",
        "#D8B486",
        "#83BDB5",
    )
    return palette[sum(card_id.encode("utf-8")) % len(palette)]


def _worldbook_serialize(wb: Worldbook | None) -> dict | None:
    if wb is None:
        return None
    return {
        "id": wb.id,
        "name": wb.name,
        "summary": wb.summary or "",
        "rules": wb.rules or "",
        "cards": [_card_serialize(c) for c in (wb.cards or [])],
        "sort": wb.sort or 0,
        "created_at": wb.created_at.isoformat() if wb.created_at else None,
        "updated_at": wb.updated_at.isoformat() if wb.updated_at else None,
    }


@app.get("/worldbooks")
async def worldbooks_list(_: None = Depends(require_signature)) -> dict:
    with db.SessionLocal() as s:
        rows = s.query(Worldbook).order_by(Worldbook.sort, Worldbook.created_at).all()
    return {"worldbooks": [_worldbook_serialize(w) for w in rows]}


@app.post("/worldbooks")
async def worldbook_create(request: Request, _: None = Depends(require_signature)) -> dict:
    body = await request.json()
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "WORLDBOOK_NO_NAME", "message": "世界书名称不能为空", "retryable": False}},
        )
    with db.SessionLocal() as s:
        wb = Worldbook(
            id=uuid7(),
            name=name[:40],
            summary=(body.get("summary") or "").strip() or None,
            rules=(body.get("rules") or "").strip() or None,
            sort=int(body.get("sort") or 0),
        )
        s.add(wb)
        s.commit()
        payload = _worldbook_serialize(wb)
    return {"worldbook": payload}


@app.patch("/worldbooks/{worldbook_id}")
async def worldbook_patch(
    worldbook_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        if "name" in body:
            name = (body.get("name") or "").strip()
            if not name:
                raise HTTPException(
                    status_code=422,
                    detail={"error": {"code": "WORLDBOOK_NO_NAME", "message": "世界书名称不能为空", "retryable": False}},
                )
            wb.name = name[:40]
        if "summary" in body:
            wb.summary = (body.get("summary") or "").strip() or None
        if "rules" in body:
            wb.rules = (body.get("rules") or "").strip() or None
        if "sort" in body:
            wb.sort = int(body.get("sort") or 0)
        s.commit()
        payload = _worldbook_serialize(wb)
    return {"worldbook": payload}


@app.delete("/worldbooks/{worldbook_id}")
async def worldbook_delete(
    worldbook_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        # 引用该世界书的群置为「现实世界」（worldbook_id=NULL），不连带删群。
        s.query(Conversation).filter(Conversation.worldbook_id == worldbook_id).update(
            {Conversation.worldbook_id: None}, synchronize_session=False
        )
        s.delete(wb)
        s.commit()
    return {"ok": True}


# --------------------------------------------------------------------------- #
# 世界书卡片（R6，035）—— 卡片 CRUD + 主角卡入群 / 配角卡临时入群。
# 卡片存于 worldbook.cards JSON；kind = protagonist | supporting | faction |
# location | plotline。角色卡（protagonist/supporting）可转成 Character 入群。
# --------------------------------------------------------------------------- #
def _card_field(body: dict, key: str, max_length: int) -> str:
    v = body.get(key)
    return (v.strip() if isinstance(v, str) else "")[:max_length]


def _card_plot_fields(body: dict, card: dict) -> None:
    """情节线卡专属字段（premise/progress/direction/nodes）；其他卡忽略。"""
    if "premise" in body:
        card["premise"] = _card_field(body, "premise", 4000) or None
    if "progress" in body:
        card["progress"] = _card_field(body, "progress", 4000) or None
    if "direction" in body:
        card["direction"] = _card_field(body, "direction", 4000) or None
    if "nodes" in body and isinstance(body.get("nodes"), list):
        card["nodes"] = [
            {
                "id": str(n.get("id", ""))[:80] if isinstance(n, dict) else "",
                "title": (n.get("title") or "")[:80] if isinstance(n, dict) else "",
                "content": (n.get("content") or "")[:4000] if isinstance(n, dict) else "",
            }
            for n in body["nodes"][:200]
            if isinstance(n, dict)
        ]


@app.post("/worldbooks/{worldbook_id}/cards")
async def worldbook_card_create(
    worldbook_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    kind = (body.get("kind") or "").strip()
    if kind not in _CARD_KINDS:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "CARD_BAD_KIND", "message": "卡片类型必须是 protagonist/supporting/faction/location/plotline", "retryable": False}},
        )
    name = _card_field(body, "name", 80)
    if not name:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "CARD_NO_NAME", "message": "卡片名称不能为空", "retryable": False}},
        )
    now = datetime.now(timezone.utc).isoformat()
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        card = {
            "id": uuid7(),
            "kind": kind,
            "name": name,
            "description": _card_field(body, "description", 4000),
            "avatar_text": _card_field(body, "avatar_text", 8) or name[0],
            "avatar_color": _card_field(body, "avatar_color", 7) or "#86B6D8",
            "character_id": None,
            "role_rank": (
                _card_field(body, "role_rank", 60) or None
                if kind in ("protagonist", "supporting")
                else None
            ),
            "premise": None,
            "progress": None,
            "direction": None,
            "nodes": [],
            "created_at": now,
            "updated_at": now,
        }
        _card_plot_fields(body, card)
        # JSON 列脏写：必须 deepcopy 新结构再重挂（同一对象/浅拷贝重挂不触发 dirty）
        cards = copy.deepcopy(wb.cards or [])
        cards.append(card)
        wb.cards = cards
        s.commit()
        return {"card": _card_serialize(card)}


@app.patch("/worldbooks/{worldbook_id}/cards/{card_id}")
async def worldbook_card_patch(
    worldbook_id: str,
    card_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    now = datetime.now(timezone.utc).isoformat()
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        # JSON 列脏写：必须 deepcopy 新结构再重挂（原 dict 原地改 + 重挂同一/浅拷贝列表不落库）
        cards = copy.deepcopy(wb.cards or [])
        card = next((c for c in cards if c.get("id") == card_id), None)
        if card is None:
            raise HTTPException(status_code=404, detail="card not found")
        if "kind" in body and body.get("kind") in _CARD_KINDS:
            card["kind"] = body.get("kind")
        if "name" in body:
            nm = _card_field(body, "name", 80)
            if not nm:
                raise HTTPException(
                    status_code=422,
                    detail={"error": {"code": "CARD_NO_NAME", "message": "卡片名称不能为空", "retryable": False}},
                )
            card["name"] = nm
        if "description" in body:
            card["description"] = _card_field(body, "description", 4000)
        if "avatar_text" in body:
            card["avatar_text"] = _card_field(body, "avatar_text", 8) or card["name"][0]
        if "avatar_color" in body:
            card["avatar_color"] = _card_field(body, "avatar_color", 7) or card.get("avatar_color", "")
        if "role_rank" in body and card["kind"] in ("protagonist", "supporting"):
            card["role_rank"] = _card_field(body, "role_rank", 60) or None
        _card_plot_fields(body, card)
        card["updated_at"] = now
        wb.cards = cards
        s.commit()
        return {"card": _card_serialize(card)}


@app.delete("/worldbooks/{worldbook_id}/cards/{card_id}")
async def worldbook_card_delete(
    worldbook_id: str,
    card_id: str,
    _: None = Depends(require_signature),
) -> dict:
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        cards = [c for c in (wb.cards or []) if c.get("id") != card_id]
        wb.cards = cards
        s.commit()
    return {"ok": True}


def _card_join_group(worldbook_id: str, card_id: str, group_id: str, temporary: bool) -> dict:
    """世界书角色卡入群（R6）：无 character_id 先转 Character 回填，再挂 ConversationMember。

    temporary=True：配角临时加入（群设置可移除，角标「临时」）；
    temporary=False：主角永久加入。
    """
    if not group_id:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "GROUP_ID_REQUIRED", "message": "缺少 group_id", "retryable": False}},
        )
    now = datetime.now(timezone.utc).isoformat()
    with db.SessionLocal() as s:
        wb = s.get(Worldbook, worldbook_id)
        if wb is None:
            raise HTTPException(status_code=404, detail="worldbook not found")
        # JSON 列脏写：deepcopy 新结构，回填 character_id 后重挂才落库
        cards = copy.deepcopy(wb.cards or [])
        card = next((c for c in cards if c.get("id") == card_id), None)
        if card is None:
            raise HTTPException(status_code=404, detail="card not found")
        if card["kind"] not in ("protagonist", "supporting"):
            raise HTTPException(
                status_code=422,
                detail={"error": {"code": "CARD_NOT_CHARACTER", "message": "只有角色卡可以加入群聊", "retryable": False}},
            )
        conv = s.get(Conversation, group_id)
        if conv is None or conv.type != "group":
            raise HTTPException(status_code=404, detail="group not found")
        character_id = card.get("character_id")
        if not character_id:
            character_id = f"world_{uuid7()}"
            _build_character_record(
                s,
                character_id=character_id,
                name=card["name"],
                tagline=card.get("role_rank"),
                origin_identity=card.get("description") or "",
                memory_enabled=True,
            )
            card["character_id"] = character_id
            card["updated_at"] = now
            wb.cards = cards
        existing = (
            s.query(ConversationMember)
            .filter(
                ConversationMember.conversation_id == group_id,
                ConversationMember.character_id == character_id,
            )
            .one_or_none()
        )
        if existing is None:
            max_sort = (
                s.query(func.max(ConversationMember.sort))
                .filter(ConversationMember.conversation_id == group_id)
                .scalar()
                or 0
            )
            s.add(
                ConversationMember(
                    conversation_id=group_id,
                    character_id=character_id,
                    temporary=temporary,
                    sort=max_sort + 1,
                )
            )
        elif existing.temporary and not temporary:
            # 配角临时成员后主角入群 → 升级为永久成员
            existing.temporary = False
        s.commit()
    return {"character_id": character_id, "temporary": temporary}


@app.post("/worldbooks/{worldbook_id}/cards/{card_id}/join_group")
async def worldbook_card_join_group(
    worldbook_id: str,
    card_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    return _card_join_group(
        worldbook_id, card_id, (body.get("group_id") or "").strip(), temporary=False
    )


@app.post("/worldbooks/{worldbook_id}/cards/{card_id}/temporary_join")
async def worldbook_card_temporary_join(
    worldbook_id: str,
    card_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    return _card_join_group(
        worldbook_id, card_id, (body.get("group_id") or "").strip(), temporary=True
    )


# --------------------------------------------------------------------------- #
# 群聊（032_group_worldbook）—— 复用 Conversation(type='group') + ConversationMember。
# 群 id = conversation_id；群消息按 sender_character_id 逐发言人落库。
# --------------------------------------------------------------------------- #
def _group_member_serialize(
    c: Character,
    world_identity: str | None = None,
    temporary: bool = False,
) -> dict:
    return {
        "id": c.id,
        "name": c.name,
        "avatar_text": c.avatar_text,
        "avatar_color": c.avatar_color,
        "tagline": c.tagline,
        "world_identity": world_identity,  # 成员级世界身份预设（#2，无则 null）
        "temporary": temporary,  # R6 配角临时成员（前端角标「临时」）
    }


def _group_payload(
    conv: Conversation,
    members: list[Character],
    wb: Worldbook | None,
    world_identity_map: dict[str, str] | None = None,
    temporary_map: dict[str, bool] | None = None,
) -> dict:
    world_identity_map = world_identity_map or {}
    # R6：{character_id: temporary}。未传时补一次查询（读操作，低频率）。
    if temporary_map is None:
        with db.SessionLocal() as s:
            temporary_map = {
                r.character_id: bool(r.temporary)
                for r in s.query(ConversationMember)
                .filter(ConversationMember.conversation_id == conv.id)
                .all()
            }
    return {
        "id": conv.id,
        "name": conv.name or "群聊",
        "members": [
            _group_member_serialize(
                c,
                world_identity_map.get(c.id) or None,
                temporary_map.get(c.id, False),
            )
            for c in members
        ],
        "member_count": len(members),
        "worldbook_id": conv.worldbook_id,
        "worldbook": _worldbook_serialize(wb),
        "speaker_mode": conv.speaker_mode or "auto",
        "reply_mode": conv.reply_mode or "realtime",
        "background_media_id": conv.background_media_id,
        "reply_chars_realtime": conv.reply_chars_realtime or 180,
        "reply_chars_roleplay": conv.reply_chars_roleplay or 1000,
        "reply_count": conv.reply_count or 1,
        "created_at": conv.created_at.isoformat() if conv.created_at else None,
    }


@app.post("/ai/groups")
async def group_create(request: Request, _: None = Depends(require_signature)) -> dict:
    body = await request.json()
    raw_member_ids = body.get("member_ids")
    if not isinstance(raw_member_ids, list) or not raw_member_ids:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "GROUP_NO_MEMBERS", "message": "群成员不能为空", "retryable": False}},
        )
    name = (body.get("name") or "").strip()[:30] or "群聊"
    worldbook_id = body.get("worldbook_id")
    speaker_mode = body.get("speaker_mode") or "auto"
    if speaker_mode not in ("auto", "all", "mention"):
        speaker_mode = "auto"
    with db.SessionLocal() as s:
        members = []
        for cid in raw_member_ids:
            c = s.get(Character, str(cid))
            if c is None:
                raise HTTPException(
                    status_code=422,
                    detail={"error": {"code": "GROUP_MEMBER_MISSING", "message": f"成员不存在: {cid}", "retryable": False}},
                )
            members.append(c)
        wb = s.get(Worldbook, worldbook_id) if worldbook_id else None
        if worldbook_id and wb is None:
            raise HTTPException(
                status_code=422,
                detail={"error": {"code": "WORLDBOOK_MISSING", "message": "世界书不存在", "retryable": False}},
            )
        # R6 世界书主角卡：与 member_ids 合并。卡片转 Character 后入群（永久成员）。
        card_ids = body.get("card_ids") if isinstance(body.get("card_ids"), list) else []
        if card_ids:
            if wb is None:
                raise HTTPException(
                    status_code=422,
                    detail={"error": {"code": "CARD_NEED_WORLDBOOK", "message": "勾选世界书卡片需要先选择世界书", "retryable": False}},
                )
            # JSON 列脏写：deepcopy 新结构再重挂（回填 character_id 后重挂才落库）
            wb_cards = copy.deepcopy(wb.cards or [])
            for card_id in card_ids:
                card = next(
                    (c for c in wb_cards if c.get("id") == str(card_id)), None
                )
                if card is None:
                    raise HTTPException(
                        status_code=422,
                        detail={"error": {"code": "CARD_MISSING", "message": f"世界书卡片不存在: {card_id}", "retryable": False}},
                    )
                if card["kind"] != "protagonist":
                    raise HTTPException(
                        status_code=422,
                        detail={"error": {"code": "CARD_NOT_PROTAGONIST", "message": "建群勾选仅支持主角卡（配角用「临时加入现有群」）", "retryable": False}},
                    )
                cid = card.get("character_id")
                if not cid:
                    cid = f"world_{uuid7()}"
                    _build_character_record(
                        s,
                        character_id=cid,
                        name=card["name"],
                        tagline=card.get("role_rank"),
                        origin_identity=card.get("description") or "",
                        memory_enabled=True,
                    )
                    card["character_id"] = cid
                    card["updated_at"] = datetime.now(timezone.utc).isoformat()
                c = s.get(Character, cid)
                if c is None:
                    raise HTTPException(
                        status_code=422,
                        detail={"error": {"code": "GROUP_MEMBER_MISSING", "message": f"角色不存在: {cid}", "retryable": False}},
                    )
                members.append(c)
            wb.cards = wb_cards  # 显式重挂（角色卡回填 character_id）
        # 去重（成员 + 卡片可能指向同一角色）
        seen = set()
        unique_members = []
        for c in members:
            if c.id not in seen:
                seen.add(c.id)
                unique_members.append(c)
        members = unique_members
        conv = Conversation(
            id=uuid7(),
            persona="group",
            character_id=None,
            type="group",
            name=name,
            worldbook_id=worldbook_id,
            speaker_mode=speaker_mode,
            reply_mode="realtime",
        )
        s.add(conv)
        for i, c in enumerate(members):
            s.add(ConversationMember(conversation_id=conv.id, character_id=c.id, sort=i))
        s.commit()
        # 新群成员身份预设全空；卡片入群的角色卡非临时（永久成员）。
        payload = _group_payload(conv, members, wb, {}, temporary_map={})
        conversation_id = conv.id
    return {"group": payload, "conversation_id": conversation_id}


@app.get("/ai/groups")
async def groups_list(_: None = Depends(require_signature)) -> dict:
    """群列表（含最近一条消息预览）。"""
    with db.SessionLocal() as s:
        convs = (
            s.query(Conversation)
            .filter(Conversation.type == "group")
            .order_by(Conversation.created_at.desc())
            .all()
        )
        conv_ids = [c.id for c in convs]
        last_msgs: dict[str, Message] = {}
        if conv_ids:
            rows = (
                s.query(Message)
                .filter(Message.conversation_id.in_(conv_ids))
                .order_by(Message.created_at.desc(), Message.id.desc())
                .all()
            )
            for m in rows:
                if m.conversation_id not in last_msgs:
                    last_msgs[m.conversation_id] = m
    groups = []
    for conv in convs:
        with db.SessionLocal() as s:
            members = group_chat.get_group_members(s, conv.id)
        last = last_msgs.get(conv.id)
        sender_name = None
        if last and last.sender_character_id:
            sender_name = next(
                (c.name for c in members if c.id == last.sender_character_id), None
            )
        groups.append(
            {
                "id": conv.id,
                "name": conv.name or "群聊",
                "member_count": len(members),
                "member_ids": [c.id for c in members],
                "worldbook_id": conv.worldbook_id,
                "speaker_mode": conv.speaker_mode or "auto",
                "reply_mode": conv.reply_mode or "realtime",
                "last_content": _preview_content(last) if last else None,
                "last_sender_name": sender_name,
                "last_kind": (last.kind or "text") if last else None,
                "last_at": last.created_at.isoformat() if last and last.created_at else None,
            }
        )
    return {"groups": groups}


@app.get("/ai/groups/{conversation_id}")
async def group_get(
    conversation_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        conv = s.get(Conversation, conversation_id)
        if conv is None or conv.type != "group":
            raise HTTPException(status_code=404, detail="group not found")
        members = group_chat.get_group_members(s, conversation_id)
        wb = s.get(Worldbook, conv.worldbook_id) if conv.worldbook_id else None
        world_identity_map = group_chat.get_group_member_world_identities(
            s, conversation_id
        )
    return {"group": _group_payload(conv, members, wb, world_identity_map)}


@app.patch("/ai/groups/{conversation_id}")
async def group_patch(
    conversation_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    with db.SessionLocal() as s:
        conv = s.get(Conversation, conversation_id)
        if conv is None or conv.type != "group":
            raise HTTPException(status_code=404, detail="group not found")
        if "name" in body:
            new_name = (body.get("name") or "").strip()[:30]
            if new_name:
                conv.name = new_name
        if "worldbook_id" in body:
            wb_id = body.get("worldbook_id")
            if wb_id and s.get(Worldbook, wb_id) is None:
                raise HTTPException(
                    status_code=422,
                    detail={"error": {"code": "WORLDBOOK_MISSING", "message": "世界书不存在", "retryable": False}},
                )
            conv.worldbook_id = wb_id or None  # null/空 → 切回现实世界
        if "speaker_mode" in body:
            mode = body.get("speaker_mode")
            if mode in ("auto", "all", "mention"):
                conv.speaker_mode = mode
        if "reply_mode" in body:
            rm = body.get("reply_mode")
            if rm in ("realtime", "roleplay"):
                conv.reply_mode = rm
        # 群聊背景（036）：显式 null/空 → 恢复默认纹理；非空必须指向已就绪媒体。
        if "background_media_id" in body:
            bg = body.get("background_media_id")
            if bg:
                _validate_asset_or_422(s, bg)
            conv.background_media_id = bg or None
        # 群聊回复字数/条数（036）：clamp 后落库，group_chat 生成时取用。
        if "reply_chars_realtime" in body:
            conv.reply_chars_realtime = max(
                60, min(int(body.get("reply_chars_realtime") or 180), 600)
            )
        if "reply_chars_roleplay" in body:
            conv.reply_chars_roleplay = max(
                300, min(int(body.get("reply_chars_roleplay") or 1000), 3000)
            )
        if "reply_count" in body:
            conv.reply_count = max(1, min(int(body.get("reply_count") or 1), 5))
        existing = {
            r.character_id
            for r in s.query(ConversationMember)
            .filter(ConversationMember.conversation_id == conversation_id)
            .all()
        }
        sort_base = len(existing)
        for cid in body.get("add_member_ids") or []:
            cid = str(cid)
            if cid in existing or s.get(Character, cid) is None:
                continue
            s.add(
                ConversationMember(
                    conversation_id=conversation_id, character_id=cid, sort=sort_base
                )
            )
            sort_base += 1
        remove_ids = [str(x) for x in (body.get("remove_member_ids") or [])]
        if remove_ids:
            s.query(ConversationMember).filter(
                ConversationMember.conversation_id == conversation_id,
                ConversationMember.character_id.in_(remove_ids),
            ).delete(synchronize_session=False)
        # 成员级世界身份预设（#2）：{character_id: str|null} → 写入/清空对应行。
        mwi = body.get("member_world_identities")
        if isinstance(mwi, dict):
            for cid, val in mwi.items():
                row = (
                    s.query(ConversationMember)
                    .filter(
                        ConversationMember.conversation_id == conversation_id,
                        ConversationMember.character_id == str(cid),
                    )
                    .one_or_none()
                )
                if row is None:
                    continue
                row.world_identity = (
                    (val or "").strip()[:2000] if isinstance(val, str) else ""
                )
        members = group_chat.get_group_members(s, conversation_id)
        if not members:
            # 成员全移除 → 群失去存在意义，整体清空。
            s.query(Message).filter(Message.conversation_id == conversation_id).delete(
                synchronize_session=False
            )
            s.query(ConversationMember).filter(
                ConversationMember.conversation_id == conversation_id
            ).delete(synchronize_session=False)
            s.query(Conversation).filter(Conversation.id == conversation_id).delete(
                synchronize_session=False
            )
            s.commit()
            return {"ok": True, "deleted": True}
        wb = s.get(Worldbook, conv.worldbook_id) if conv.worldbook_id else None
        world_identity_map = group_chat.get_group_member_world_identities(
            s, conversation_id
        )
        s.commit()
        payload = _group_payload(conv, members, wb, world_identity_map)
    return {"group": payload}


@app.delete("/ai/groups/{conversation_id}")
async def group_delete(
    conversation_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        conv = s.get(Conversation, conversation_id)
        if conv is None or conv.type != "group":
            raise HTTPException(status_code=404, detail="group not found")
        s.query(Message).filter(Message.conversation_id == conversation_id).delete(
            synchronize_session=False
        )
        s.query(ConversationMember).filter(
            ConversationMember.conversation_id == conversation_id
        ).delete(synchronize_session=False)
        s.delete(conv)
        s.commit()
    return {"ok": True}


def _parse_group_chat_body(body: dict) -> dict:
    """解析群聊请求体 → group_chat_flow / group_chat_flow_events 的 kwargs。"""
    message = body.get("message", "")
    conversation_id = body.get("conversation_id")
    if not conversation_id:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "GROUP_MISSING_ID", "message": "缺少 conversation_id", "retryable": False}},
        )
    media_kind = body.get("kind") or "text"
    media_asset_id = body.get("media_asset_id") if media_kind != "text" else None
    sticker_id = body.get("sticker_id") if media_kind == "sticker" else None
    audio_duration = None
    if media_kind == "audio":
        try:
            audio_duration = int(body.get("audio_duration") or 0) or None
        except (TypeError, ValueError):
            audio_duration = None
    redpacket_amount = None
    if media_kind in ("redpacket", "transfer"):
        try:
            redpacket_amount = float(body.get("redpacket_amount"))
        except (TypeError, ValueError):
            redpacket_amount = None
    requested_reply_mode = body.get("reply_mode")
    if requested_reply_mode not in ("realtime", "roleplay"):
        requested_reply_mode = None
    try:
        requested_reply_max_chars = int(body.get("reply_max_chars"))
    except (TypeError, ValueError):
        requested_reply_max_chars = None
    mention_character_id = body.get("mention_character_id")
    # 无违禁：群聊与单聊同语义，仅对支持无违禁（noban_prompt 非空）的成员生效。
    noban = bool(body.get("noban"))
    message_source_mode = "noban" if noban else "standard"

    # 媒体上下文：与单聊同一套逻辑（chat_common，含自我识别注入）。
    media_ctx, media_file_name, media_file_size = chat_common.resolve_media_context(
        media_kind, media_asset_id, sticker_id, body.get("self_identity")
    )

    # 引用：服务端 message_id 优先，客户端正文兜底（与 ai_chat 同一套规则）。
    quote_body = body.get("quote") if isinstance(body.get("quote"), dict) else {}
    quote_message_id = quote_role = quote_content = None
    raw_quote_id = str(quote_body.get("message_id") or "").strip()
    if raw_quote_id and not raw_quote_id.startswith("local-"):
        with db.SessionLocal() as s:
            quoted = s.get(Message, raw_quote_id)
            if quoted is not None and quoted.conversation_id == conversation_id:
                quote_message_id = quoted.id
                quote_role = quoted.role
                quote_content = chat_common.reference_text(quoted)
    if not quote_content:
        fallback_quote = str(quote_body.get("content") or "").strip()[:4000]
        if fallback_quote:
            quote_message_id = raw_quote_id or None
            raw_quote_role = quote_body.get("role")
            quote_role = (
                raw_quote_role if raw_quote_role in ("user", "assistant") else None
            )
            quote_content = fallback_quote

    return dict(
        conversation_id=conversation_id,
        message=message,
        media_ctx=media_ctx,
        media_file_name=media_file_name,
        media_file_size=media_file_size,
        media_kind=media_kind,
        media_asset_id=media_asset_id,
        sticker_id=sticker_id,
        audio_duration=audio_duration,
        redpacket_amount=redpacket_amount,
        quote_message_id=quote_message_id,
        quote_role=quote_role,
        quote_content=quote_content,
        mention_character_id=mention_character_id,
        requested_reply_mode=requested_reply_mode,
        requested_reply_max_chars=requested_reply_max_chars,
        message_source_mode=message_source_mode,
        noban=noban,
    )


@app.post("/ai/group_chat")
async def ai_group_chat(request: Request, _: None = Depends(require_signature)) -> dict:
    """群聊一轮（非流式）：落用户消息 → 按群发言模式定成员 → 逐成员全量生成落库。

    响应 {replies, user_message, conversation_id, speaker_mode, reply_mode}。
    """
    body = await request.json()
    return group_chat.group_chat_flow(**_parse_group_chat_body(body))


@app.post("/ai/group_chat/stream")
async def ai_group_chat_stream(
    request: Request, _: None = Depends(require_signature)
) -> StreamingResponse:
    """群聊流式（#4）：SSE 逐条产出 reply（persist-as-you-go），done 收尾。

    - 事件：reply → done（或 error）；user_message 事件跳过（前端已本地展示）。
    - Starlette 对 sync generator 走 threadpool，阻塞的 chat() 不卡事件循环。
    """
    body = await request.json()
    kwargs = _parse_group_chat_body(body)
    # 预检在 200 前完成：校验类错误返回正确状态码，而非空 SSE 流。
    group_chat.ensure_group_ready(kwargs["conversation_id"])

    def gen():
        for event in group_chat.group_chat_flow_events(**kwargs):
            etype = event["type"]
            if etype == "user_message":
                continue  # 前端已乐观展示用户消息，不需要重放
            data = {k: v for k, v in event.items() if k != "type"}
            yield f"event: {etype}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        gen(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@app.get("/ai/characters")
async def ai_characters(_: None = Depends(require_signature)) -> dict:
    """角色列表（人格层）。不透出任何 prompt；has_noban 供前端显示爱心 toggle。"""
    return {"characters": ai_gateway.list_characters()}


def _build_character_record(
    s,
    *,
    character_id: str,
    name: str,
    tagline: str | None = None,
    origin_identity: str = "",
    origin_memory: str = "",
    memory_enabled: bool = True,
    sort: int | None = None,
    welcome_message: str | None = None,
    inherit_user_profile: bool = False,
) -> Character:
    """创建 Character + 关联五表（Worldview/RuntimeState/Relationship/UserKnowledge/Storyline）。

    供 ai_character_create（用户自建）与 R6 世界书主角卡转角色（join_group / 建群勾选）
    复用：两路创建的角色结构与默认人格完全一致。调用方负责 commit。
    """
    if sort is None:
        sort = int(
            s.query(func.max(Character.sort))
            .filter(
                Character.id != "assistant",
                Character.is_file_transfer.is_(False),
            )
            .scalar()
            or 0
        ) + 1
    persona = _default_custom_persona(name, tagline or "", origin_identity)
    worldview = {
        "key": "real",
        "name": "现实世界",
        "identity": origin_identity,
        "backstory": origin_memory,
        "rules": "现实世界，遵循现实逻辑；未填写的经历和私人信息不得擅自编造。",
        "preferences": "",
    }
    character = Character(
        id=character_id,
        name=name,
        tagline=tagline or None,
        avatar_text=name[0],
        avatar_color=_custom_character_color(character_id),
        welcome_message=welcome_message or f"嗨，我是{name}。很高兴认识你～",
        system_prompt=prompts.build_full_persona_prompt(
            persona, worldview, origin_enabled=True, noban=False
        ),
        noban_prompt=prompts.build_full_persona_prompt(
            persona, worldview, origin_enabled=True, noban=True
        ),
        personality=persona["personality"],
        speech_style=persona["speech_style"],
        interests=persona["interests"],
        boundaries=persona["boundaries"],
        catchphrases=persona["catchphrases"],
        example_dialogue=persona["example_dialogue"],
        appearance=persona["appearance"],
        origin_world_enabled=True,
        origin_identity=origin_identity,
        origin_memory=origin_memory,
        relationship=persona["relationship"],
        memory_enabled=memory_enabled,
        is_file_transfer=False,
        sort=sort,
    )
    s.add(character)
    s.add(
        Worldview(
            id=f"{character_id}:real",
            character_id=character_id,
            **worldview,
            enabled=True,
            sort=0,
        )
    )
    s.add(
        CharacterRuntimeState(
            character_id=character_id,
            active_worldview_key="real",
            relationship_state={},
            emotion_state={},
            current_state={},
            self_model_state={},
            version=1,
        )
    )
    s.add(
        CharacterRelationshipDefinition(
            character_id=character_id,
            kind="initial",
            label="初识",
            description="刚刚认识，关系需要通过真实互动逐步发展。",
            version=1,
        )
    )
    s.add(
        CharacterUserKnowledge(
            character_id=character_id,
            inherit_profile=inherit_user_profile,
            field_overrides={},
            hidden_fields=[],
            version=1,
        )
    )
    s.add(
        CharacterStoryline(
            character_id=character_id,
            nodes=_initial_storyline_nodes(),
            current_node_id="start",
            version=1,
        )
    )
    return character


@app.post("/ai/characters")
async def ai_character_create(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    """用最小公开资料创建一个可继续补写的角色。

    必填只有 ``name`` 和 ``origin_identity``；其余人格层先用中性、可对话的
    默认值，之后由手机端“公开资料 → 角色档案”补齐。
    """
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=422, detail="body must be an object")
    name = _text_field(
        body, "name", default="", max_length=40, allow_empty=False
    )
    origin_identity = _text_field(
        body, "origin_identity", default="", max_length=2000, allow_empty=False
    )
    tagline = _text_field(body, "tagline", default="", max_length=120)
    welcome_message = _text_field(
        body,
        "welcome_message",
        default=f"嗨，我是{name}。很高兴认识你～",
        max_length=500,
    )
    inherit_user_profile = body.get("inherit_user_profile", False)
    if not isinstance(inherit_user_profile, bool):
        raise HTTPException(
            status_code=422, detail="inherit_user_profile must be a boolean"
        )
    character_id = f"custom_{uuid7()}"
    with db.SessionLocal() as s:
        character = _build_character_record(
            s,
            character_id=character_id,
            name=name,
            tagline=tagline,
            origin_identity=origin_identity,
            memory_enabled=True,
            welcome_message=welcome_message,
            inherit_user_profile=inherit_user_profile,
        )
        s.commit()
        s.refresh(character)
        return {
            "character": ai_gateway.character_to_dict(character),
            "archive": _character_archive_to_dict(s, character),
        }


_SENTINEL = object()


def _validate_asset_or_422(s, asset_id: str) -> None:
    """头像/背景引用校验：media_asset 必须存在且 ready，否则 422。"""
    a = s.get(MediaAsset, asset_id)
    if a is None or a.status != "ready":
        raise HTTPException(
            status_code=422,
            detail={
                "error": {
                    "code": "MEDIA_NOT_READY",
                    "message": "媒体不存在或未就绪",
                    "retryable": False,
                }
            },
        )


@app.patch("/ai/characters/{character_id}")
async def ai_character_patch(
    character_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    """自定义角色头像/背景（010）。body `{avatar_media_id?, background_media_id?}`：
    省略字段=不改；显式 null=恢复默认（glyph 头像 / 灰底背景）。"""
    body = await request.json()
    avatar = body.get("avatar_media_id", _SENTINEL)
    background = body.get("background_media_id", _SENTINEL)

    with db.SessionLocal() as s:
        c = s.get(Character, character_id)
        if c is None:
            raise HTTPException(
                status_code=404,
                detail={
                    "error": {
                        "code": "CHARACTER_NOT_FOUND",
                        "message": "角色不存在",
                        "retryable": False,
                    }
                },
            )
        if avatar is not _SENTINEL:
            if avatar is not None:
                _validate_asset_or_422(s, avatar)
            c.avatar_media_id = avatar
        if background is not _SENTINEL:
            if background is not None:
                _validate_asset_or_422(s, background)
            c.background_media_id = background
        s.commit()
        s.refresh(c)
        d = ai_gateway.character_to_dict(c)
    return {"character": d}


@app.get("/ai/stickers")
async def ai_stickers(_: None = Depends(require_signature)) -> dict:
    """内置表情包目录（009）：前端 id→本地素材渲染；id/name/description 供 AI 与历史。

    description 即"见过"的存档描述（预置中文）→ 内置表情永不调 MiMo。
    """
    return {"stickers": ai_gateway.list_stickers()}


@app.post("/ai/embedding")
async def ai_embedding(request: Request, _: None = Depends(require_signature)) -> dict:
    body = await request.json()
    emb = ai_gateway.embed(body.get("text", ""))
    return {"embedding": emb, "model": ai_gateway.EMBED_MODEL, "dim": len(emb)}


@app.get("/ai/history")
async def ai_history(
    conversation_id: str = "",
    limit: int = 100,
    _: None = Depends(require_signature),
) -> dict:
    """返回某会话的历史消息（微信界面进页面加载用）。按时间正序。

    kind: text | image | file | sticker；图片/文件消息带 media_asset_id/file_name/file_size，
    前端据此渲染缩略图 / 文件卡片；sticker 消息带 sticker_id（内置表情）+ caption
    （"见过"的存档描述：内置→sticker 目录，相册→asset.caption，批量查防 N+1）。
    """
    with db.SessionLocal() as s:
        conversation = s.get(Conversation, conversation_id) if conversation_id else None
        reply_mode = (conversation.reply_mode if conversation else None) or "realtime"
        q = s.query(Message)
        if conversation_id:
            q = q.filter_by(conversation_id=conversation_id)
        rows = (
            q.order_by(Message.created_at.desc(), Message.id.desc())
            .limit(limit)
            .all()
        )
    sticker_ids = [m.sticker_id for m in rows if m.kind == "sticker" and m.sticker_id]
    asset_ids = [m.media_asset_id for m in rows if m.kind == "sticker" and m.media_asset_id]
    sticker_desc = ai_gateway.sticker_descriptions(sticker_ids) if sticker_ids else {}
    asset_caption: dict[str, str] = {}
    if asset_ids:
        with db.SessionLocal() as s:
            for a in s.query(MediaAsset).filter(MediaAsset.id.in_(asset_ids)).all():
                asset_caption[a.id] = a.caption or ""
    # R4 红包领取：批量查 claim 表（防 N+1），按 message_id 分组。
    # redpacket + transfer 都记领取（AI 收到转账同样必回并领取）。
    redpacket_ids = [
        m.id for m in rows if m.kind in ("redpacket", "transfer")
    ]
    claim_map: dict[str, list[dict]] = {}
    if redpacket_ids:
        char_names: dict[str, str] = {}
        with db.SessionLocal() as s:
            claims = (
                s.query(RedPacketClaim)
                .filter(RedPacketClaim.message_id.in_(redpacket_ids))
                .order_by(RedPacketClaim.claimed_at.asc())
                .all()
            )
            cids = {c.character_id for c in claims if c.character_id}
            if cids:
                for c in s.query(Character).filter(Character.id.in_(cids)).all():
                    char_names[c.id] = c.name
        for c in claims:
            claim_map.setdefault(c.message_id, []).append(
                {
                    "character_id": c.character_id,
                    "name": char_names.get(c.character_id) if c.character_id else "你",
                    "claimed_at": (
                        c.claimed_at.isoformat() if c.claimed_at else None
                    ),
                }
            )
    messages = []
    for m in reversed(rows):
        caption = None
        if m.kind == "sticker":
            caption = (sticker_desc.get(m.sticker_id) if m.sticker_id else None) or (
                asset_caption.get(m.media_asset_id) if m.media_asset_id else None
            )
        messages.append(
            {
                "id": m.id,
                "role": m.role,
                # 群聊（032）：NULL=用户消息；群成员消息带发言人 character_id
                "sender_character_id": m.sender_character_id,
                "kind": m.kind or "text",
                "content": m.content,
                "media_asset_id": m.media_asset_id,
                "sticker_id": m.sticker_id,
                "caption": caption,
                "file_name": m.file_name,
                "file_size": m.file_size,
                "audio_duration": m.audio_duration,
                "source_mode": m.source_mode,
                "context_excluded": bool(m.context_excluded),
                "quote_message_id": m.quote_message_id,
                "quote_role": m.quote_role,
                "quote_content": m.quote_content,
                "redpacket_amount": m.redpacket_amount,
                "redpacket_claimed": bool(m.redpacket_claimed),
                "redpacket_claim_time": (
                    m.redpacket_claim_time.isoformat()
                    if m.redpacket_claim_time
                    else None
                ),
                "redpacket_claimers": claim_map.get(m.id, []),
                # 转账收/拒（验收批2）：null=待回应 / true=接受 / false=婉拒
                "transfer_accepted": m.transfer_accepted,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
        )
    return {"messages": messages, "reply_mode": reply_mode}


def _profile_to_dict(row: UserProfile) -> dict:
    return {
        "display_name": row.display_name,
        "lifehub_id": row.lifehub_id,
        "avatar_media_id": row.avatar_media_id,
        "signature": row.signature or "",
        "reality_profile": dict(row.reality_profile or {}),
        "version": row.version,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _relationship_to_dict(row: CharacterRelationshipDefinition) -> dict:
    return {
        "character_id": row.character_id,
        "kind": row.kind,
        "label": row.label,
        "description": row.description or "",
        "version": row.version,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _storyline_to_dict(row: CharacterStoryline) -> dict:
    return {
        "character_id": row.character_id,
        "premise": row.premise or "",
        "progress": row.progress or "",
        "direction": row.direction or "",
        "nodes": list(row.nodes or []),
        "current_node_id": row.current_node_id,
        "version": row.version,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _public_event_to_dict(row: CharacterPublicEvent) -> dict:
    return {
        "key": row.key,
        "event_date": row.event_date,
        "end_date": row.end_date,
        "category": row.category,
        "title": row.title,
        "summary": row.summary,
        "detail": row.detail or "",
        "tags": list(row.tags or []),
        "source_urls": list(row.source_urls or []),
        "source_level": row.source_level,
        "importance": row.importance,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _known_user_to_dict(
    profile: UserProfile | None,
    knowledge: CharacterUserKnowledge | None,
) -> dict:
    if profile is None or knowledge is None:
        return {
            "display_name": "",
            "fields": {},
            "inherit_profile": False,
            "field_overrides": {},
            "hidden_fields": [],
        }
    fields = dict(profile.reality_profile or {}) if knowledge.inherit_profile else {}
    for key in knowledge.hidden_fields or []:
        if isinstance(key, str):
            fields.pop(key, None)
    overrides = dict(knowledge.field_overrides or {})
    for key, value in overrides.items():
        if isinstance(key, str) and isinstance(value, str):
            fields[key] = value
    return {
        "display_name": profile.display_name if knowledge.inherit_profile else "",
        "fields": fields,
        "inherit_profile": bool(knowledge.inherit_profile),
        "field_overrides": overrides,
        "hidden_fields": list(knowledge.hidden_fields or []),
    }


def _character_archive_to_dict(s, character: Character) -> dict:
    """角色语义档案。刻意不返回编译后的 system/noban prompt。"""
    worldviews = (
        s.query(Worldview)
        .filter(Worldview.character_id == character.id, Worldview.enabled.is_(True))
        .order_by(Worldview.sort, Worldview.key)
        .all()
    )
    runtime = s.get(CharacterRuntimeState, character.id)
    relationship = s.get(CharacterRelationshipDefinition, character.id)
    storyline = s.get(CharacterStoryline, character.id)
    knowledge = s.get(CharacterUserKnowledge, character.id)
    profile = s.get(UserProfile, "owner")
    lore = (
        s.query(CharacterLoreEntry)
        .filter(
            CharacterLoreEntry.character_id == character.id,
            CharacterLoreEntry.enabled.is_(True),
        )
        .order_by(CharacterLoreEntry.priority.desc(), CharacterLoreEntry.key)
        .all()
    )
    events = (
        s.query(CharacterPublicEvent)
        .filter(
            CharacterPublicEvent.character_id == character.id,
            CharacterPublicEvent.enabled.is_(True),
        )
        .order_by(CharacterPublicEvent.event_date, CharacterPublicEvent.key)
        .all()
    )
    memories = (
        s.query(Memory)
        .filter(Memory.character_id == character.id, Memory.status == "active")
        .order_by(Memory.created_at.desc())
        .all()
    )
    return {
        "character_id": character.id,
        "name": character.name,
        "tagline": character.tagline or "",
        "welcome_message": character.welcome_message or "",
        "persona": {
            "core_personality": character.personality or "",
            "speech_style": character.speech_style or "",
            "appearance": character.appearance or "",
            "interests": character.interests or "",
            "boundaries": character.boundaries or "",
            "catchphrases": character.catchphrases or "",
            "example_dialogue": character.example_dialogue or "",
            "origin_world_enabled": bool(character.origin_world_enabled),
            "origin_identity": character.origin_identity or "",
            "origin_history": character.origin_memory or "",
            "relationship_principles": character.relationship or "",
        },
        "worldviews": [
            {
                "key": row.key,
                "name": row.name,
                "identity": row.identity or "",
                "backstory": row.backstory or "",
                "rules": row.rules or "",
                "preferences": row.preferences or "",
                "user_identity": row.user_identity or "",
                "active": bool(runtime and runtime.active_worldview_key == row.key),
            }
            for row in worldviews
        ],
        "relationship": {
            "definition": {
                "kind": relationship.kind if relationship else "initial",
                "label": relationship.label if relationship else "初识",
                "description": relationship.description or "" if relationship else "",
            },
            "principles": character.relationship or "",
            "runtime": dict(runtime.relationship_state or {}) if runtime else {},
        },
        "runtime": {
            "active_worldview_key": runtime.active_worldview_key if runtime else None,
            "emotion_state": dict(runtime.emotion_state or {}) if runtime else {},
            "current_state": dict(runtime.current_state or {}) if runtime else {},
            "self_model_state": dict(runtime.self_model_state or {}) if runtime else {},
            "version": runtime.version if runtime else 0,
        },
        "known_user": _known_user_to_dict(profile, knowledge),
        "lore": [
            {
                "key": row.key,
                "title": row.title,
                "content": row.content,
                "worldview_key": row.worldview_key,
                "always_on": row.always_on,
                "trigger_keywords": list(row.trigger_keywords or []),
                "priority": row.priority,
            }
            for row in lore
        ],
        "public_history": [_public_event_to_dict(row) for row in events],
        "memories": [
            {
                "id": row.id,
                "type": row.type or "memory",
                "content": row.content or "",
                "importance": row.importance,
                "source_mode": row.source_mode,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in memories
        ],
        "storyline": _storyline_to_dict(storyline) if storyline else {
            "character_id": character.id,
            "premise": "",
            "progress": "",
            "direction": "",
            "nodes": [],
            "current_node_id": None,
            "version": 0,
            "updated_at": None,
        },
    }


def _initial_storyline_nodes() -> list[dict[str, str]]:
    return [{"id": "start", "title": "初始位置", "content": ""}]


def _text_field(
    body: dict,
    key: str,
    *,
    default: str,
    max_length: int,
    allow_empty: bool = True,
) -> str:
    value = body.get(key, default)
    if not isinstance(value, str):
        raise HTTPException(status_code=422, detail=f"{key} must be a string")
    value = value.strip()
    if not allow_empty and not value:
        raise HTTPException(status_code=422, detail=f"{key} cannot be empty")
    if len(value) > max_length:
        raise HTTPException(status_code=422, detail=f"{key} is too long")
    return value


def _custom_character_color(character_id: str) -> str:
    palette = (
        "#E7A5B5",
        "#86B6D8",
        "#9BC69B",
        "#C5A6D8",
        "#D8B486",
        "#83BDB5",
    )
    return palette[sum(character_id.encode("utf-8")) % len(palette)]


def _default_custom_persona(
    name: str, tagline: str, origin_identity: str
) -> dict[str, str]:
    """新角色的中性起点：可聊天，但不抢先编造用户还没填的人格。"""
    return {
        "name": name,
        "tagline": tagline,
        "personality": (
            "你拥有独立的判断和自然的情绪反应。当前人格细节尚未补齐，"
            "只根据已填写的身份、实际聊天与后续角色档案表现，不自行发明重大性格特征。"
        ),
        "speech_style": (
            "使用自然、口语化的中文交流，直接回应对方当下的话。"
            "不复读设定，不伪装知道尚未填写的经历、爱好或关系。"
        ),
        "appearance": "",
        "interests": "",
        "boundaries": (
            "不把未填写的资料当成事实，不伪造与用户的共同过去；"
            "关系和亲密程度只能由实际互动逐步发展。"
        ),
        "catchphrases": "",
        "example_dialogue": "",
        "origin_identity": origin_identity,
        "origin_memory": "",
        "relationship": (
            "默认与用户从初识开始。关系只根据这个角色自己的对话、记忆和剧情推进，"
            "不读取其他角色的亲密关系或共同经历。"
        ),
    }


def _rebuild_character_prompts(
    character: Character, worldview: Worldview | None
) -> None:
    """结构化档案是事实源；保持老路径的物化 prompt 与之同步。"""
    persona = {
        "name": character.name,
        "tagline": character.tagline or "",
        "personality": character.personality or "",
        "speech_style": character.speech_style or "",
        "appearance": character.appearance or "",
        "interests": character.interests or "",
        "boundaries": character.boundaries or "",
        "catchphrases": character.catchphrases or "",
        "example_dialogue": character.example_dialogue or "",
        "origin_identity": character.origin_identity or "",
        "origin_memory": character.origin_memory or "",
        "relationship": character.relationship or "",
    }
    world = None
    if worldview is not None:
        world = {
            "name": worldview.name,
            "identity": worldview.identity or "",
            "backstory": worldview.backstory or "",
            "rules": worldview.rules or "",
            "preferences": worldview.preferences or "",
        }
    character.system_prompt = prompts.build_full_persona_prompt(
        persona,
        world,
        origin_enabled=bool(character.origin_world_enabled),
        noban=False,
    )
    if character.noban_prompt is not None:
        character.noban_prompt = prompts.build_full_persona_prompt(
            persona,
            world,
            origin_enabled=bool(character.origin_world_enabled),
            noban=True,
        )


@app.get("/profile")
async def user_profile_get(_: None = Depends(require_signature)) -> dict:
    """现实用户唯一主资料；首次读取时创建默认行。"""
    with db.SessionLocal() as s:
        row = s.get(UserProfile, "owner")
        if row is None:
            row = UserProfile(id="owner")
            s.add(row)
            s.commit()
            s.refresh(row)
        return {"profile": _profile_to_dict(row)}


@app.patch("/profile")
async def user_profile_patch(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    """更新现实用户资料。手机先落盘，服务端成功后成为跨设备权威副本。"""
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=422, detail="body must be an object")
    allowed_reality_fields = {
        "preferred_name",
        "gender",
        "birthday",
        "location",
        "occupation",
        "appearance",
        "personality",
        "family_background",
        "current_situation",
        "important_experiences",
    }
    with db.SessionLocal() as s:
        row = s.get(UserProfile, "owner")
        if row is None:
            row = UserProfile(id="owner")
            s.add(row)
        if "display_name" in body:
            row.display_name = _text_field(
                body, "display_name", default="我的", max_length=40, allow_empty=False
            )
        if "lifehub_id" in body:
            row.lifehub_id = _text_field(
                body,
                "lifehub_id",
                default="lifehub_user",
                max_length=64,
                allow_empty=False,
            )
        if "signature" in body:
            row.signature = _text_field(
                body, "signature", default="", max_length=240
            )
        if "avatar_media_id" in body:
            avatar = body["avatar_media_id"]
            if avatar is not None and not isinstance(avatar, str):
                raise HTTPException(
                    status_code=422, detail="avatar_media_id must be a string or null"
                )
            if avatar:
                _validate_asset_or_422(s, avatar)
            row.avatar_media_id = avatar or None
        if "reality_profile" in body:
            profile = body["reality_profile"]
            if not isinstance(profile, dict):
                raise HTTPException(
                    status_code=422, detail="reality_profile must be an object"
                )
            cleaned: dict[str, str] = {}
            for key, value in profile.items():
                if key not in allowed_reality_fields or not isinstance(value, str):
                    raise HTTPException(
                        status_code=422, detail=f"invalid reality_profile field: {key}"
                    )
                value = value.strip()
                if len(value) > 2000:
                    raise HTTPException(
                        status_code=422, detail=f"reality_profile.{key} is too long"
                    )
                if value:
                    cleaned[key] = value
            row.reality_profile = cleaned
        row.version = (row.version or 0) + 1
        s.commit()
        s.refresh(row)
        return {"profile": _profile_to_dict(row)}


# --------------------------------------------------------------------------- #
# 朋友圈（028）：用户发布 + 多角色公开动态 + 点赞/评论 + 角色即时回复。
# --------------------------------------------------------------------------- #
def _moment_actor(s, actor_type: str, actor_id: str | None) -> dict:
    if actor_type == "user":
        profile = s.get(UserProfile, "owner")
        return {
            "type": "user",
            "id": "owner",
            "name": profile.display_name if profile else "我的",
            "avatar_media_id": profile.avatar_media_id if profile else None,
        }
    character = s.get(Character, actor_id or "")
    return {
        "type": "character",
        "id": actor_id or "",
        "name": character.name if character else "角色",
        "avatar_media_id": character.avatar_media_id if character else None,
        "avatar_text": character.avatar_text if character else "角",
        "avatar_color": character.avatar_color if character else "#576B95",
    }


def _moment_to_dict(s, row: Moment) -> dict:
    media = (
        s.query(MomentMedia)
        .filter(MomentMedia.moment_id == row.id)
        .order_by(MomentMedia.sort, MomentMedia.id)
        .all()
    )
    likes = (
        s.query(MomentLike)
        .filter(MomentLike.moment_id == row.id)
        .order_by(MomentLike.created_at, MomentLike.id)
        .all()
    )
    comments = (
        s.query(MomentComment)
        .filter(MomentComment.moment_id == row.id)
        .order_by(MomentComment.created_at, MomentComment.id)
        .all()
    )
    author_id = row.character_id if row.author_type == "character" else "owner"
    return {
        "id": row.id,
        "author": _moment_actor(s, row.author_type, author_id),
        "content": row.content or "",
        "location": row.location,
        "source": row.source,
        "source_platform": row.source_platform,
        "source_url": row.source_url,
        "source_post_id": row.source_post_id,
        "published_at": (row.published_at or row.created_at).isoformat(),
        "published_precision": row.published_precision or "datetime",
        "media": [
            {
                "id": item.id,
                "media_asset_id": item.media_asset_id,
                "remote_url": item.remote_url,
                "width": item.width,
                "height": item.height,
            }
            for item in media
        ],
        "likes": [
            {
                "id": item.id,
                "actor": _moment_actor(s, item.actor_type, item.actor_id),
            }
            for item in likes
        ],
        "liked_by_me": any(item.actor_type == "user" for item in likes),
        "comments": [
            {
                "id": item.id,
                "actor": _moment_actor(s, item.actor_type, item.actor_id),
                "content": item.content,
                "reply_to_id": item.reply_to_id,
                "created_at": item.created_at.isoformat(),
            }
            for item in comments
        ],
    }


@app.get("/moments")
async def moments_list(
    author_type: str | None = None,
    character_id: str | None = None,
    limit: int = 50,
    _: None = Depends(require_signature),
) -> dict:
    with db.SessionLocal() as s:
        query = s.query(Moment)
        if author_type in {"user", "character"}:
            query = query.filter(Moment.author_type == author_type)
        if character_id:
            query = query.filter(Moment.character_id == character_id)
        rows = (
            query.order_by(
                func.coalesce(Moment.published_at, Moment.created_at).desc(),
                Moment.id.desc(),
            )
            .limit(max(1, min(limit, 100)))
            .all()
        )
        return {"moments": [_moment_to_dict(s, row) for row in rows]}


@app.post("/moments")
async def moment_create(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    content = str(body.get("content") or "").strip()
    location = str(body.get("location") or "").strip()
    media_ids = body.get("media_asset_ids") or []
    if not isinstance(media_ids, list) or len(media_ids) > 9:
        raise HTTPException(status_code=422, detail="media_asset_ids must contain at most 9 items")
    if not content and not media_ids:
        raise HTTPException(status_code=422, detail="朋友圈内容和图片不能同时为空")
    if len(content) > 5000 or len(location) > 120:
        raise HTTPException(status_code=422, detail="朋友圈内容过长")
    device_id = request.headers.get("X-Device-Id", "")
    with db.SessionLocal() as s:
        assets: list[MediaAsset] = []
        for media_id in media_ids:
            if not isinstance(media_id, str):
                raise HTTPException(status_code=422, detail="invalid media id")
            _validate_asset_or_422(s, media_id)
            asset = s.get(MediaAsset, media_id)
            assets.append(asset)
        row = Moment(
            id=uuid7(),
            author_type="user",
            content=content,
            visibility="private",
            source="manual",
            source_platform="manual",
            location=location or None,
            device_id=device_id,
            published_at=datetime.now(timezone.utc),
            published_precision="datetime",
        )
        s.add(row)
        s.flush()
        for index, asset in enumerate(assets):
            asset.owner_type = "moment"
            asset.owner_id = row.id
            s.add(
                MomentMedia(
                    id=uuid7(),
                    moment_id=row.id,
                    media_asset_id=asset.id,
                    sort=index,
                )
            )
        s.commit()
        s.refresh(row)
        return {"moment": _moment_to_dict(s, row)}


@app.delete("/moments/{moment_id}")
async def moment_delete(
    moment_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        row = s.get(Moment, moment_id)
        if row is None:
            raise HTTPException(status_code=404, detail="moment not found")
        if row.author_type != "user":
            raise HTTPException(status_code=403, detail="公开角色动态不能在这里删除")
        s.delete(row)
        s.commit()
    return {"ok": True}


@app.post("/moments/{moment_id}/like")
async def moment_like_toggle(
    moment_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        row = s.get(Moment, moment_id)
        if row is None:
            raise HTTPException(status_code=404, detail="moment not found")
        existing = (
            s.query(MomentLike)
            .filter_by(moment_id=moment_id, actor_type="user", actor_id="owner")
            .first()
        )
        if existing is None:
            s.add(
                MomentLike(
                    id=uuid7(),
                    moment_id=moment_id,
                    actor_type="user",
                    actor_id="owner",
                )
            )
            liked = True
        else:
            s.delete(existing)
            liked = False
        s.commit()
        return {"liked": liked, "moment": _moment_to_dict(s, row)}


@app.post("/moments/{moment_id}/comments")
async def moment_comment_create(
    moment_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    content = str(body.get("content") or "").strip()
    if not content or len(content) > 1000:
        raise HTTPException(status_code=422, detail="评论不能为空且最多 1000 字")
    raw_reply_to = body.get("reply_to_id")
    with db.SessionLocal() as s:
        moment = s.get(Moment, moment_id)
        if moment is None:
            raise HTTPException(status_code=404, detail="moment not found")
        # 楼中楼（D）：reply_to_id 必须存在且属于本条动态，否则 422。
        reply_to_id = None
        reply_to_context = None
        if raw_reply_to:
            parent = s.get(MomentComment, str(raw_reply_to))
            if parent is None or parent.moment_id != moment_id:
                raise HTTPException(status_code=422, detail="被回复的评论不存在")
            reply_to_id = parent.id
            parent_name = _moment_actor(s, parent.actor_type, parent.actor_id).get(
                "name", "对方"
            )
            reply_to_context = f"{parent_name}：{parent.content[:200]}"
        comment = MomentComment(
            id=uuid7(),
            moment_id=moment_id,
            actor_type="user",
            actor_id="owner",
            content=content,
            reply_to_id=reply_to_id,
        )
        s.add(comment)
        s.commit()
        character_id = moment.character_id if moment.author_type == "character" else None
        post_content = moment.content or "（图片动态）"
        comment_id = comment.id

    # 评论角色公开动态时，由该角色即时回复；模型异常不影响用户评论落库。
    if character_id:
        try:
            raw_reply = ai_gateway.chat(
                (
                    "【朋友圈互动】这是你自己发布的一条朋友圈。"
                    f"朋友圈内容：{post_content[:1000]}\n"
                    + (
                        f"你正在回复这条评论：{reply_to_context}\n"
                        if reply_to_context
                        else ""
                    )
                    + f"用户评论：{content}\n"
                    "请像本人在朋友圈评论区一样自然回复，只回复一条简短评论（一句话以内），不写动作旁白。"
                ),
                character_id=character_id,
                history=[],
                memories=[],
                reply_mode="realtime",
                reply_max_chars=60,
            )
            normalized = ai_gateway.normalize_generated_reply(raw_reply or "", "realtime")
            reply_parts = ai_gateway.split_reply_segments(normalized, "realtime")
            reply = " ".join(part.strip() for part in reply_parts if part.strip())[:1000]
            if reply:
                with db.SessionLocal() as s:
                    s.add(
                        MomentComment(
                            id=uuid7(),
                            moment_id=moment_id,
                            actor_type="character",
                            actor_id=character_id,
                            content=reply,
                            reply_to_id=comment_id,
                        )
                    )
                    s.commit()
        except Exception:
            _logger.exception("朋友圈角色回复失败 moment=%s", moment_id)

    with db.SessionLocal() as s:
        moment = s.get(Moment, moment_id)
        return {"moment": _moment_to_dict(s, moment)}


_RELATIONSHIP_LABELS = {
    "initial": "初识",
    "friend": "朋友",
    "ambiguous": "暧昧",
    "lover": "恋人",
    "partner": "伴侣",
    "married": "夫妻",
}


def _get_character_or_404(s, character_id: str) -> Character:
    character = s.get(Character, character_id)
    if character is None:
        raise HTTPException(status_code=404, detail="character not found")
    return character


def _character_conversations(s, character_id: str) -> list[Conversation]:
    return (
        s.query(Conversation)
        .filter(
            or_(
                Conversation.character_id == character_id,
                Conversation.persona == character_id,
            )
        )
        .all()
    )


def _delete_unshared_media_assets(
    s,
    candidate_ids: set[str],
    *,
    deleted_message_ids: set[str] | None = None,
    deleted_moment_ids: set[str] | None = None,
    deleted_character_id: str | None = None,
) -> list[str]:
    """删除仅由本次目标引用的媒体，保留仍被其他实体共用的资源。"""
    if not candidate_ids:
        return []
    deleted_message_ids = deleted_message_ids or set()
    deleted_moment_ids = deleted_moment_ids or set()
    protected: set[str] = set()

    message_query = s.query(Message.media_asset_id).filter(
        Message.media_asset_id.in_(candidate_ids)
    )
    if deleted_message_ids:
        message_query = message_query.filter(Message.id.notin_(deleted_message_ids))
    protected.update(row[0] for row in message_query.all() if row[0])

    moment_query = s.query(MomentMedia.media_asset_id).filter(
        MomentMedia.media_asset_id.in_(candidate_ids)
    )
    if deleted_moment_ids:
        moment_query = moment_query.filter(
            MomentMedia.moment_id.notin_(deleted_moment_ids)
        )
    protected.update(row[0] for row in moment_query.all() if row[0])

    character_query = s.query(
        Character.avatar_media_id, Character.background_media_id
    )
    if deleted_character_id:
        character_query = character_query.filter(Character.id != deleted_character_id)
    for avatar_id, background_id in character_query.all():
        if avatar_id in candidate_ids:
            protected.add(avatar_id)
        if background_id in candidate_ids:
            protected.add(background_id)

    protected.update(
        row[0]
        for row in s.query(UserProfile.avatar_media_id)
        .filter(UserProfile.avatar_media_id.in_(candidate_ids))
        .all()
        if row[0]
    )
    voice_query = s.query(CharacterVoiceProfile.sample_media_id).filter(
        CharacterVoiceProfile.sample_media_id.in_(candidate_ids)
    )
    if deleted_character_id:
        voice_query = voice_query.filter(
            CharacterVoiceProfile.character_id != deleted_character_id
        )
    protected.update(row[0] for row in voice_query.all() if row[0])

    face_query = s.query(FaceGallery.source_asset_id).filter(
        FaceGallery.source_asset_id.in_(candidate_ids)
    )
    if deleted_character_id:
        face_query = face_query.filter(FaceGallery.character_id != deleted_character_id)
    protected.update(row[0] for row in face_query.all() if row[0])

    removable_ids = candidate_ids - protected
    if not removable_ids:
        return []
    rows = s.query(MediaAsset).filter(MediaAsset.id.in_(removable_ids)).all()
    storage_paths = [row.storage_path for row in rows if row.storage_path]
    for row in rows:
        s.delete(row)
    return storage_paths


def _remove_media_files_safely(storage_paths: list[str]) -> None:
    """只删除 uploads 目录内已精确解析出的单个文件，不做递归操作。"""
    upload_root = os.path.realpath(os.path.abspath(config.UPLOAD_DIR))
    for storage_path in set(storage_paths):
        target = os.path.realpath(os.path.abspath(os.path.join(upload_root, storage_path)))
        try:
            inside_uploads = os.path.commonpath([upload_root, target]) == upload_root
        except ValueError:
            inside_uploads = False
        if not inside_uploads:
            _logger.warning("拒绝删除 uploads 外文件 storage_path=%s", storage_path)
            continue
        if os.path.isfile(target):
            try:
                os.remove(target)
            except OSError as error:
                _logger.warning("角色媒体文件删除失败 path=%s error=%s", target, error)


@app.delete("/ai/characters/{character_id}/conversations")
async def character_conversations_delete(
    character_id: str,
    _: None = Depends(require_signature),
) -> dict:
    """微信首页“删除该聊天”：删该角色全部会话，明确保留长期记忆。"""
    storage_paths: list[str] = []
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        conversations = _character_conversations(s, character_id)
        conversation_ids = [row.id for row in conversations]
        messages = (
            s.query(Message)
            .filter(Message.conversation_id.in_(conversation_ids))
            .all()
            if conversation_ids
            else []
        )
        message_ids = {row.id for row in messages}
        media_ids = {row.media_asset_id for row in messages if row.media_asset_id}
        storage_paths = _delete_unshared_media_assets(
            s,
            media_ids,
            deleted_message_ids=message_ids,
        )
        if conversation_ids:
            s.query(Message).filter(
                Message.conversation_id.in_(conversation_ids)
            ).delete(synchronize_session=False)
            s.query(Conversation).filter(
                Conversation.id.in_(conversation_ids)
            ).delete(synchronize_session=False)
        s.commit()
    _remove_media_files_safely(storage_paths)
    return {
        "ok": True,
        "character_id": character_id,
        "deleted_messages": len(messages),
        "deleted_conversations": len(conversations),
        "deleted_conversation_ids": conversation_ids,
        "deleted_media_ids": sorted(media_ids),
        "preserved": ["character_definition", "memories", "relationship", "storyline"],
    }


@app.delete("/ai/characters/{character_id}")
async def character_delete(
    character_id: str,
    _: None = Depends(require_signature),
) -> dict:
    """永久删除人物以及全部人物级数据；墓碑阻止内置人物被种子复活。"""
    storage_paths: list[str] = []
    deleted: dict[str, int] = {}
    with db.SessionLocal() as s:
        character = _get_character_or_404(s, character_id)
        if character.id == "assistant" or character.is_file_transfer:
            raise HTTPException(status_code=422, detail="tool character cannot be deleted")

        conversations = _character_conversations(s, character_id)
        conversation_ids = [row.id for row in conversations]
        messages = (
            s.query(Message)
            .filter(Message.conversation_id.in_(conversation_ids))
            .all()
            if conversation_ids
            else []
        )
        message_ids = {row.id for row in messages}
        memories = s.query(Memory).filter(Memory.character_id == character_id).all()
        memory_ids = [row.id for row in memories]
        moments = s.query(Moment).filter(Moment.character_id == character_id).all()
        moment_ids = {row.id for row in moments}
        moment_media = (
            s.query(MomentMedia)
            .filter(MomentMedia.moment_id.in_(moment_ids))
            .all()
            if moment_ids
            else []
        )
        voice_profile = s.get(CharacterVoiceProfile, character_id)
        faces = s.query(FaceGallery).filter(FaceGallery.character_id == character_id).all()
        media_ids = {
            value
            for value in (
                character.avatar_media_id,
                character.background_media_id,
                voice_profile.sample_media_id if voice_profile else None,
                *[row.source_asset_id for row in faces],
                *[row.media_asset_id for row in messages],
                *[row.media_asset_id for row in moment_media],
            )
            if value
        }
        storage_paths = _delete_unshared_media_assets(
            s,
            media_ids,
            deleted_message_ids=message_ids,
            deleted_moment_ids=moment_ids,
            deleted_character_id=character_id,
        )

        deleted["memory_revisions"] = (
            s.query(MemoryRevision)
            .filter(MemoryRevision.memory_id.in_(memory_ids))
            .delete(synchronize_session=False)
            if memory_ids
            else 0
        )
        deleted["memories"] = s.query(Memory).filter(
            Memory.character_id == character_id
        ).delete(synchronize_session=False)
        deleted["memory_refine_logs"] = s.query(MemoryRefineLog).filter(
            MemoryRefineLog.character_id == character_id
        ).delete(synchronize_session=False)

        if conversation_ids:
            deleted["messages"] = s.query(Message).filter(
                Message.conversation_id.in_(conversation_ids)
            ).delete(synchronize_session=False)
            deleted["conversations"] = s.query(Conversation).filter(
                Conversation.id.in_(conversation_ids)
            ).delete(synchronize_session=False)
        else:
            deleted["messages"] = 0
            deleted["conversations"] = 0

        # 群聊联动（032）：删成员行；角色在群消息里的发言归属置空（历史保留，前端兜底头像）；
        # 成员被删后空群 → 连带删群+群消息（群是成员的组合体，无成员即无群）。
        member_rows = (
            s.query(ConversationMember)
            .filter(ConversationMember.character_id == character_id)
            .all()
        )
        group_conv_ids = [r.conversation_id for r in member_rows]
        deleted["group_memberships"] = len(member_rows)
        s.query(Message).filter(Message.sender_character_id == character_id).update(
            {Message.sender_character_id: None}, synchronize_session=False
        )
        s.query(ConversationMember).filter(
            ConversationMember.character_id == character_id
        ).delete(synchronize_session=False)
        deleted["groups_removed"] = 0
        for gid in group_conv_ids:
            remaining = (
                s.query(ConversationMember)
                .filter(ConversationMember.conversation_id == gid)
                .count()
            )
            if remaining == 0:
                s.query(Message).filter(Message.conversation_id == gid).delete(
                    synchronize_session=False
                )
                s.query(ConversationMember).filter(
                    ConversationMember.conversation_id == gid
                ).delete(synchronize_session=False)
                s.query(Conversation).filter(Conversation.id == gid).delete(
                    synchronize_session=False
                )
                deleted["groups_removed"] += 1

        like_filters = [
            (MomentLike.actor_type == "character")
            & (MomentLike.actor_id == character_id)
        ]
        comment_filters = [
            (MomentComment.actor_type == "character")
            & (MomentComment.actor_id == character_id)
        ]
        if moment_ids:
            like_filters.append(MomentLike.moment_id.in_(moment_ids))
            comment_filters.append(MomentComment.moment_id.in_(moment_ids))
        deleted["moment_likes"] = s.query(MomentLike).filter(
            or_(*like_filters)
        ).delete(synchronize_session=False)
        deleted["moment_comments"] = s.query(MomentComment).filter(
            or_(*comment_filters)
        ).delete(synchronize_session=False)
        deleted["moment_media"] = (
            s.query(MomentMedia)
            .filter(MomentMedia.moment_id.in_(moment_ids))
            .delete(synchronize_session=False)
            if moment_ids
            else 0
        )
        deleted["moments"] = s.query(Moment).filter(
            Moment.character_id == character_id
        ).delete(synchronize_session=False)

        table_models = (
            ("worldviews", Worldview),
            ("runtime_states", CharacterRuntimeState),
            ("relationships", CharacterRelationshipDefinition),
            ("user_knowledge", CharacterUserKnowledge),
            ("storylines", CharacterStoryline),
            ("lore", CharacterLoreEntry),
            ("public_history", CharacterPublicEvent),
            ("voice_profiles", CharacterVoiceProfile),
            ("face_gallery", FaceGallery),
        )
        for key, model in table_models:
            deleted[key] = s.query(model).filter(
                model.character_id == character_id
            ).delete(synchronize_session=False)

        s.add(CharacterDeletion(character_id=character_id))
        s.delete(character)
        deleted["characters"] = 1
        deleted["media_assets"] = len(storage_paths)
        s.commit()

    _remove_media_files_safely(storage_paths)
    return {
        "ok": True,
        "character_id": character_id,
        "deleted": deleted,
        "deleted_conversation_ids": conversation_ids,
        "deleted_media_ids": sorted(media_ids),
    }


@app.get("/ai/characters/{character_id}/public-history")
async def character_public_history_get(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    """返回角色公开正史时间线；来源元数据供后续维护与人物主页使用。"""
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        rows = (
            s.query(CharacterPublicEvent)
            .filter(
                CharacterPublicEvent.character_id == character_id,
                CharacterPublicEvent.enabled.is_(True),
            )
            .order_by(CharacterPublicEvent.event_date, CharacterPublicEvent.key)
            .all()
        )
        return {
            "character_id": character_id,
            "events": [_public_event_to_dict(row) for row in rows],
        }


@app.get("/ai/characters/{character_id}/archive")
async def character_archive_get(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    """手机端只读角色档案：展示所有语义层，不暴露编译后的系统提示词。"""
    with db.SessionLocal() as s:
        character = _get_character_or_404(s, character_id)
        return {"archive": _character_archive_to_dict(s, character)}


@app.patch("/ai/characters/{character_id}/archive")
async def character_archive_patch(
    character_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    """改写角色的稳定语义档案；不直接改聊天记忆、动态情绪或剧情位置。"""
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=422, detail="body must be an object")
    persona_body = body.get("persona", {})
    worldview_body = body.get("worldview", {})
    known_user_body = body.get("known_user", {})
    if not isinstance(persona_body, dict):
        raise HTTPException(status_code=422, detail="persona must be an object")
    if not isinstance(worldview_body, dict):
        raise HTTPException(status_code=422, detail="worldview must be an object")
    if not isinstance(known_user_body, dict):
        raise HTTPException(status_code=422, detail="known_user must be an object")

    persona_fields = {
        "core_personality": ("personality", 12000),
        "speech_style": ("speech_style", 8000),
        "appearance": ("appearance", 8000),
        "interests": ("interests", 8000),
        "boundaries": ("boundaries", 8000),
        "catchphrases": ("catchphrases", 4000),
        "example_dialogue": ("example_dialogue", 12000),
        "origin_identity": ("origin_identity", 8000),
        "origin_history": ("origin_memory", 20000),
        "relationship_principles": ("relationship", 12000),
    }
    worldview_fields = {
        "identity": 8000,
        "backstory": 20000,
        "rules": 12000,
        "preferences": 12000,
    }

    with db.SessionLocal() as s:
        character = _get_character_or_404(s, character_id)
        if "name" in body:
            character.name = _text_field(
                body,
                "name",
                default=character.name,
                max_length=40,
                allow_empty=False,
            )
            character.avatar_text = character.name[0]
        if "tagline" in body:
            value = _text_field(
                body,
                "tagline",
                default=character.tagline or "",
                max_length=120,
            )
            character.tagline = value or None
        if "welcome_message" in body:
            value = _text_field(
                body,
                "welcome_message",
                default=character.welcome_message or "",
                max_length=500,
            )
            character.welcome_message = value or None
        if "origin_world_enabled" in persona_body:
            enabled = persona_body["origin_world_enabled"]
            if not isinstance(enabled, bool):
                raise HTTPException(
                    status_code=422,
                    detail="origin_world_enabled must be a boolean",
                )
            character.origin_world_enabled = enabled
        for public_key, (column_name, max_length) in persona_fields.items():
            if public_key not in persona_body:
                continue
            value = _text_field(
                persona_body,
                public_key,
                default=getattr(character, column_name) or "",
                max_length=max_length,
            )
            setattr(character, column_name, value or None)

        worldview = s.get(Worldview, f"{character_id}:real")
        if worldview is None:
            worldview = Worldview(
                id=f"{character_id}:real",
                character_id=character_id,
                key="real",
                name="现实世界",
                enabled=True,
                sort=0,
            )
            s.add(worldview)
        if "name" in worldview_body:
            worldview.name = _text_field(
                worldview_body,
                "name",
                default=worldview.name or "现实世界",
                max_length=80,
                allow_empty=False,
            )
        for key, max_length in worldview_fields.items():
            if key not in worldview_body:
                continue
            value = _text_field(
                worldview_body,
                key,
                default=getattr(worldview, key) or "",
                max_length=max_length,
            )
            setattr(worldview, key, value or None)

        if known_user_body:
            knowledge = s.get(CharacterUserKnowledge, character_id)
            if knowledge is None:
                knowledge = CharacterUserKnowledge(
                    character_id=character_id,
                    inherit_profile=False,
                    field_overrides={},
                    hidden_fields=[],
                    version=1,
                )
                s.add(knowledge)
            if "inherit_profile" in known_user_body:
                inherit_profile = known_user_body["inherit_profile"]
                if not isinstance(inherit_profile, bool):
                    raise HTTPException(
                        status_code=422,
                        detail="known_user.inherit_profile must be a boolean",
                    )
                knowledge.inherit_profile = inherit_profile
            knowledge_fields = known_user_body.get("fields", {})
            if not isinstance(knowledge_fields, dict):
                raise HTTPException(
                    status_code=422, detail="known_user.fields must be an object"
                )
            allowed_knowledge_fields = {
                "preferred_name",
                "character_call_name",
                "gender",
                "birthday",
                "location",
                "occupation",
                "appearance",
                "personality",
                "family_background",
                "current_situation",
                "meeting_story",
                "important_experiences",
                "notes",
            }
            overrides = dict(knowledge.field_overrides or {})
            for key, raw_value in knowledge_fields.items():
                if key not in allowed_knowledge_fields:
                    raise HTTPException(
                        status_code=422,
                        detail=f"invalid known_user field: {key}",
                    )
                if not isinstance(raw_value, str):
                    raise HTTPException(
                        status_code=422,
                        detail=f"known_user.{key} must be a string",
                    )
                value = raw_value.strip()
                if len(value) > 4000:
                    raise HTTPException(
                        status_code=422,
                        detail=f"known_user.{key} is too long",
                    )
                if value:
                    overrides[key] = value
                else:
                    overrides.pop(key, None)
            knowledge.field_overrides = overrides
            knowledge.version = (knowledge.version or 0) + 1

        _rebuild_character_prompts(character, worldview)
        s.commit()
        s.refresh(character)
        return {
            "character": ai_gateway.character_to_dict(character),
            "archive": _character_archive_to_dict(s, character),
        }


@app.get("/ai/characters/{character_id}/relationship")
async def character_relationship_get(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        row = s.get(CharacterRelationshipDefinition, character_id)
        if row is None:
            row = CharacterRelationshipDefinition(character_id=character_id)
            s.add(row)
            s.commit()
            s.refresh(row)
        return {"relationship": _relationship_to_dict(row)}


@app.patch("/ai/characters/{character_id}/relationship")
async def character_relationship_patch(
    character_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=422, detail="body must be an object")
    kind = _text_field(
        body, "kind", default="initial", max_length=20, allow_empty=False
    )
    if kind not in {*_RELATIONSHIP_LABELS, "custom"}:
        raise HTTPException(status_code=422, detail="invalid relationship kind")
    if kind == "custom":
        label = _text_field(
            body, "label", default="", max_length=30, allow_empty=False
        )
    else:
        label = _RELATIONSHIP_LABELS[kind]
    description = _text_field(
        body, "description", default="", max_length=1000
    )
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        row = s.get(CharacterRelationshipDefinition, character_id)
        if row is None:
            row = CharacterRelationshipDefinition(character_id=character_id)
            s.add(row)
        row.kind = kind
        row.label = label
        row.description = description or None
        row.version = (row.version or 0) + 1
        s.commit()
        s.refresh(row)
        return {"relationship": _relationship_to_dict(row)}


@app.get("/ai/characters/{character_id}/storyline")
async def character_storyline_get(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        row = s.get(CharacterStoryline, character_id)
        if row is None:
            row = CharacterStoryline(
                character_id=character_id,
                nodes=_initial_storyline_nodes(),
                current_node_id="start",
            )
            s.add(row)
            s.commit()
            s.refresh(row)
        return {"storyline": _storyline_to_dict(row)}


@app.patch("/ai/characters/{character_id}/storyline")
async def character_storyline_patch(
    character_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=422, detail="body must be an object")
    allowed = {"premise", "progress", "direction", "nodes", "current_node_id"}
    if not any(key in body for key in allowed):
        raise HTTPException(status_code=422, detail="no storyline fields supplied")
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        row = s.get(CharacterStoryline, character_id)
        if row is None:
            row = CharacterStoryline(character_id=character_id)
            s.add(row)
        for key in {"premise", "progress", "direction"}:
            if key not in body:
                continue
            value = body[key]
            if not isinstance(value, str):
                raise HTTPException(status_code=422, detail=f"{key} must be a string")
            value = value.strip()
            if len(value) > 12000:
                raise HTTPException(status_code=422, detail=f"{key} is too long")
            setattr(row, key, value or None)
        if "nodes" in body:
            raw_nodes = body["nodes"]
            if not isinstance(raw_nodes, list) or not 1 <= len(raw_nodes) <= 60:
                raise HTTPException(
                    status_code=422,
                    detail="nodes must be a list of 1 to 60 items",
                )
            cleaned_nodes: list[dict[str, str]] = []
            seen_ids: set[str] = set()
            for index, node in enumerate(raw_nodes):
                if not isinstance(node, dict):
                    raise HTTPException(status_code=422, detail="invalid storyline node")
                node_id = node.get("id")
                title = node.get("title")
                content = node.get("content")
                if not isinstance(node_id, str) or not node_id.strip() or len(node_id) > 64:
                    raise HTTPException(status_code=422, detail="invalid storyline node id")
                node_id = node_id.strip()
                if node_id in seen_ids:
                    raise HTTPException(status_code=422, detail="duplicate storyline node id")
                seen_ids.add(node_id)
                if not isinstance(title, str) or len(title.strip()) > 120:
                    raise HTTPException(status_code=422, detail="invalid storyline node title")
                if not isinstance(content, str) or len(content.strip()) > 4000:
                    raise HTTPException(status_code=422, detail="invalid storyline node content")
                cleaned_nodes.append(
                    {
                        "id": node_id,
                        "title": title.strip() or f"位置 {index + 1}",
                        "content": content.strip(),
                    }
                )
            row.nodes = cleaned_nodes
            row.premise = cleaned_nodes[0]["content"] or None
            row.progress = None
            row.direction = None
        available_nodes = list(row.nodes or [])
        available_ids = {
            node.get("id") for node in available_nodes if isinstance(node, dict)
        }
        if "current_node_id" in body:
            current_node_id = body["current_node_id"]
            if current_node_id is not None and not isinstance(current_node_id, str):
                raise HTTPException(status_code=422, detail="invalid current_node_id")
            if current_node_id and current_node_id not in available_ids:
                raise HTTPException(status_code=422, detail="current_node_id is not in nodes")
            row.current_node_id = current_node_id or None
        elif "nodes" in body and row.current_node_id not in available_ids:
            row.current_node_id = (
                cleaned_nodes[0]["id"] if cleaned_nodes else None
            )
        row.version = (row.version or 0) + 1
        s.commit()
        s.refresh(row)
        return {"storyline": _storyline_to_dict(row)}


@app.post("/ai/characters/{character_id}/reset")
async def character_reset(
    character_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    """让角色与用户重新认识。

    清除聊天、角色记忆、记忆提炼审计、动态状态和手动关系定义；保留角色卡、
    世界观、用户资料、自我识别库及人物头像/背景。该边界用于正式版前反复测试。
    """
    body = await request.json()
    if not isinstance(body, dict) or body.get("scope") != "reintroduce":
        raise HTTPException(status_code=422, detail="invalid reset scope")
    with db.SessionLocal() as s:
        _get_character_or_404(s, character_id)
        conversations = (
            s.query(Conversation)
            .filter(
                or_(
                    Conversation.character_id == character_id,
                    Conversation.persona == character_id,
                )
            )
            .all()
        )
        conversation_ids = [row.id for row in conversations]
        deleted_messages = 0
        if conversation_ids:
            deleted_messages = (
                s.query(Message)
                .filter(Message.conversation_id.in_(conversation_ids))
                .delete(synchronize_session=False)
            )
        deleted_conversations = len(conversations)
        for conversation in conversations:
            s.delete(conversation)

        memories = s.query(Memory).filter(Memory.character_id == character_id).all()
        memory_ids = [row.id for row in memories]
        deleted_revisions = 0
        if memory_ids:
            deleted_revisions = (
                s.query(MemoryRevision)
                .filter(MemoryRevision.memory_id.in_(memory_ids))
                .delete(synchronize_session=False)
            )
        deleted_memories = len(memories)
        for memory in memories:
            s.delete(memory)
        deleted_refine_logs = (
            s.query(MemoryRefineLog)
            .filter(MemoryRefineLog.character_id == character_id)
            .delete(synchronize_session=False)
        )
        deleted_runtime = (
            s.query(CharacterRuntimeState)
            .filter(CharacterRuntimeState.character_id == character_id)
            .delete(synchronize_session=False)
        )
        relationship = s.get(CharacterRelationshipDefinition, character_id)
        if relationship is None:
            relationship = CharacterRelationshipDefinition(character_id=character_id)
            s.add(relationship)
        else:
            relationship.kind = "initial"
            relationship.label = "初识"
            relationship.description = None
            relationship.version = (relationship.version or 0) + 1
        storyline = s.get(CharacterStoryline, character_id)
        if storyline is not None:
            storyline.progress = None
            storyline.direction = None
            nodes = list(storyline.nodes or [])
            storyline.current_node_id = (
                nodes[0].get("id")
                if nodes and isinstance(nodes[0], dict)
                else None
            )
            storyline.version = (storyline.version or 0) + 1
        s.commit()
    return {
        "ok": True,
        "scope": "reintroduce",
        "deleted": {
            "messages": deleted_messages,
            "conversations": deleted_conversations,
            "memories": deleted_memories,
            "memory_revisions": deleted_revisions,
            "memory_refine_logs": deleted_refine_logs,
            "runtime_states": deleted_runtime,
        },
        "relationship": {
            "character_id": character_id,
            "kind": "initial",
            "label": "初识",
            "description": "",
        },
        "preserved": [
            "user_profile",
            "character_definition",
            "worldviews",
            "self_identity_gallery",
            "character_avatar",
            "chat_background",
            "story_premise",
            "storyline_nodes",
        ],
    }
    return {
        "conversation_id": conversation_id,
        "reply_mode": reply_mode,
        "messages": messages,
    }


@app.delete("/ai/conversation/{conversation_id}/messages")
async def ai_conversation_clear(
    conversation_id: str,
    _: None = Depends(require_signature),
) -> dict:
    """清空某会话的聊天记录（微信「清空聊天记录」）。保留会话本身，前端显示空聊天。
    删除全部消息；媒体文件仍在 media_asset（供记忆/其他地方引用）。"""
    with db.SessionLocal() as s:
        deleted = (
            s.query(Message)
            .filter(Message.conversation_id == conversation_id)
            .delete()
        )
        s.commit()
    return {"ok": True, "deleted": deleted}


@app.delete("/ai/conversation/{conversation_id}/messages/noban")
async def ai_conversation_clear_noban(
    conversation_id: str,
    _: None = Depends(require_signature),
) -> dict:
    """剔除某会话无违禁期间形成的聊天消息（群无违禁关闭「剔除并关闭」）。
    群聊不产生记忆，仅 Message.source_mode='noban' 行；普通消息不受影响。
    单聊走 DELETE /ai/characters/{cid}/memories/noban（含记忆+消息），本端点只管群会话消息。"""
    with db.SessionLocal() as s:
        deleted = (
            s.query(Message)
            .filter(
                Message.conversation_id == conversation_id,
                Message.source_mode == "noban",
            )
            .delete()
        )
        s.commit()
    return {"ok": True, "deleted_messages": deleted, "source_mode": "noban"}


@app.patch("/ai/conversation/{conversation_id}")
async def ai_conversation_update(
    conversation_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    """立即同步会话级设置；当前仅开放回复模式。"""
    body = await request.json()
    reply_mode = body.get("reply_mode")
    if reply_mode not in ("realtime", "roleplay"):
        raise HTTPException(status_code=422, detail="invalid reply_mode")
    with db.SessionLocal() as s:
        conversation = s.get(Conversation, conversation_id)
        if conversation is None:
            raise HTTPException(status_code=404, detail="conversation not found")
        conversation.reply_mode = reply_mode
        s.commit()
    return {"conversation_id": conversation_id, "reply_mode": reply_mode}


@app.get("/ai/conversations")
async def ai_conversations(_: None = Depends(require_signature)) -> dict:
    """每角色会话的最后一条消息（会话列表真实预览用，轻量、不含未读）。

    按消息时间降序遍历，每 conversation 取最新一条、每角色取最新会话；
    kind=image 显示 [图片]、kind=sticker 显示 [表情包]、kind=file 显示文件名。
    """
    with db.SessionLocal() as s:
        rows = (
            s.query(Conversation, Message)
            .join(Message, Message.conversation_id == Conversation.id)
            .order_by(Message.created_at.desc())
            .limit(1000)
            .all()
        )
    latest_by_char: dict[str, Message] = {}
    latest_by_group: dict[str, tuple[Conversation, Message]] = {}
    for conv, msg in rows:
        if conv.type == "group":
            if conv.id not in latest_by_group:
                latest_by_group[conv.id] = (conv, msg)
            continue
        cid = conv.character_id or conv.persona
        if cid and cid not in latest_by_char:
            latest_by_char[cid] = msg
    items = []
    for cid, msg in latest_by_char.items():
        items.append(
            {
                "type": "single",
                "character_id": cid,
                "last_content": _preview_content(msg),
                "last_kind": msg.kind or "text",
                "last_at": msg.created_at.isoformat() if msg.created_at else None,
            }
        )
    for gid, (conv, msg) in latest_by_group.items():
        sender_name = None
        if msg.sender_character_id:
            with db.SessionLocal() as s:
                c = s.get(Character, msg.sender_character_id)
            sender_name = c.name if c else None
        items.append(
            {
                "type": "group",
                "group_id": gid,
                "group_name": conv.name or "群聊",
                "last_content": _preview_content(msg),
                "last_sender_name": sender_name,
                "last_kind": msg.kind or "text",
                "last_at": msg.created_at.isoformat() if msg.created_at else None,
            }
        )
    return {"items": items}


# 记忆路由已拆至 app.routers.memory；上方导入保留直接函数名以兼容现有工具测试。

# --------------------------------------------------------------------------- #
# 媒体（微信富媒体 008）：两步上传，签名沿用 METHOD|path|sha256(body)|ts
#   POST /media               JSON 元数据 → media_id（status=pending）
#   PUT  /media/{id}/content  原始字节 body → 写盘 + status=ready
#   GET  /media/{id}/content  下载（图片 inline 展示，其他附件下载）
# --------------------------------------------------------------------------- #
def _media_path(storage_path: str) -> str:
    """媒体文件路径：相对 UPLOAD_DIR 的随机文件名（避免恶意文件名/路径穿越）。"""
    return os.path.join(config.UPLOAD_DIR, storage_path)


def _new_media(file_name: str, mime_type: str | None, size: int, *, device_id: str = "") -> tuple[str, str]:
    """建 pending 媒体元数据（TTS 合成结果落库用）→ (media_id, storage_path)。"""
    with db.SessionLocal() as s:
        media = MediaAsset(
            id=uuid7(),
            owner_type="chat",
            owner_id=None,
            storage_path=uuid7(),
            file_name=file_name,
            mime_type=mime_type,
            size=size,
            status="pending",
            device_id=device_id,
        )
        s.add(media)
        s.commit()
        return media.id, media.storage_path


def _maybe_tts(character_id: str, text: str) -> tuple[str | None, int | None]:
    """AI 回复合成克隆音色语音（014）：未就绪/任何异常 → (None, None) 静默降级纯文字。"""
    if not tts_minimax.is_ready():
        return None, None
    try:
        wav = tts_minimax.synthesize(text, character_id=character_id)
    except Exception as e:
        _logger.warning("TTS 降级纯文字: %s", e)
        return None, None
    duration = tts_minimax._wav_duration(wav)
    try:
        media_id, storage_path = _new_media("voice.wav", "audio/wav", len(wav))
        with open(_media_path(storage_path), "wb") as f:
            f.write(wav)
        with db.SessionLocal() as s:
            media = s.get(MediaAsset, media_id)
            media.status = "ready"
            media.size = len(wav)
            s.commit()
    except Exception as e:
        _logger.warning("TTS 落库失败: %s", e)
        return None, None
    return media_id, int(round(duration)) or None


@app.post("/media")
async def media_create(request: Request, _: None = Depends(require_signature)) -> dict:
    body = await request.json()
    file_name = (body.get("file_name") or "").strip()
    if not file_name:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "缺少 file_name", "retryable": False}},
        )
    size = int(body.get("size") or 0)
    if size <= 0 or size > config.MAX_MEDIA_SIZE:
        raise HTTPException(
            status_code=413,
            detail={"error": {"code": "MEDIA_TOO_LARGE", "message": "文件超过大小上限", "retryable": False}},
        )
    device_id = request.headers.get("X-Device-Id", "")
    with db.SessionLocal() as s:
        media = MediaAsset(
            id=uuid7(),
            owner_type=body.get("owner_type") or "chat",
            owner_id=None,  # 聊天媒体：归属 message，上传时未建
            storage_path=uuid7(),  # 预生成文件路径（避免暴露 id 与路径耦合）
            file_name=file_name,
            mime_type=body.get("mime_type"),
            size=size,
            status="pending",
            device_id=device_id,
        )
        s.add(media)
        s.commit()
        media_id = media.id
        storage_path = media.storage_path
    return {"media_id": media_id, "storage_path": storage_path}


@app.put("/media/{media_id}/content")
async def media_put_content(
    media_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    """第二步：上传原始字节。body=request.body()（与 require_signature 同源缓存，
    签名串 sha256(body) 与客户端逐字节一致）。"""
    body = await request.body()
    if not body:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "内容为空", "retryable": False}},
        )
    if len(body) > config.MAX_MEDIA_SIZE:
        raise HTTPException(
            status_code=413,
            detail={"error": {"code": "MEDIA_TOO_LARGE", "message": "文件超过大小上限", "retryable": False}},
        )
    os.makedirs(config.UPLOAD_DIR, exist_ok=True)
    with db.SessionLocal() as s:
        media = s.get(MediaAsset, media_id)
        if media is None:
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "媒体不存在", "retryable": False}},
            )
        storage_path = media.storage_path
    path = _media_path(storage_path)
    with open(path, "wb") as f:
        f.write(body)
    digest = hashlib.sha256(body).hexdigest()
    with db.SessionLocal() as s:
        media = s.get(MediaAsset, media_id)
        if media is None:
            os.remove(path)
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "媒体不存在", "retryable": False}},
            )
        media.status = "ready"
        media.size = len(body)
        media.file_hash = digest
        s.commit()
    return {"ok": True, "media_id": media_id, "size": len(body), "sha256": digest}


@app.get("/media/{media_id}/content")
async def media_get_content(media_id: str, _: None = Depends(require_signature)) -> FileResponse:
    """下载媒体：图片 → inline 展示（前端 Image.network）；其他 → 附件下载。"""
    with db.SessionLocal() as s:
        media = s.get(MediaAsset, media_id)
        if media is None or media.status != "ready":
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "媒体不存在", "retryable": False}},
            )
        mime = media.mime_type or "application/octet-stream"
        file_name = media.file_name or media_id
        storage_path = media.storage_path
    path = _media_path(storage_path)
    if not os.path.exists(path):
        raise HTTPException(
            status_code=404,
            detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "文件缺失", "retryable": False}},
        )
    if mime.startswith("image/"):
        return FileResponse(path, media_type=mime)  # 无 filename → inline（不弹下载）
    return FileResponse(path, media_type=mime, filename=file_name)  # 附件下载


# 自我识别路由已拆至 app.routers.self_identity。

# --------------------------------------------------------------------------- #
# AI 语音 TTS（027）：每角色独立音色档案 + 设计/授权复刻
# --------------------------------------------------------------------------- #
@app.get("/ai/characters/{character_id}/voice")
async def character_voice_status(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    """当前角色的语音档案；未定制时返回默认系统女声状态。"""
    return {
        "configured": tts_minimax.is_configured(),
        "ready": tts_minimax.is_ready(),
        "default_voice": config.MINIMAX_TTS_VOICE,
        **tts_minimax.get_profile(character_id),
    }


@app.patch("/ai/characters/{character_id}/voice")
async def character_voice_update(
    character_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    """启停和微调角色语音；数值在网关层做安全范围裁剪。"""
    body = await request.json()
    allowed = {
        k: body[k]
        for k in (
            "enabled",
            "reply_policy",
            "speed",
            "volume",
            "pitch",
            "language_boost",
        )
        if k in body
    }
    try:
        return tts_minimax.update_profile(character_id, allowed)
    except (TypeError, ValueError) as e:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VALIDATION_ERROR", "message": str(e), "retryable": False}},
        )


def _store_tts_preview(audio: bytes) -> tuple[str, int]:
    is_wav = audio[:4] == b"RIFF" and audio[8:12] == b"WAVE"
    duration = tts_minimax._wav_duration(audio) if is_wav else 0
    media_id, storage_path = _new_media(
        "voice_preview.wav" if is_wav else "voice_preview.mp3",
        "audio/wav" if is_wav else "audio/mpeg",
        len(audio),
    )
    with open(_media_path(storage_path), "wb") as f:
        f.write(audio)
    with db.SessionLocal() as s:
        media = s.get(MediaAsset, media_id)
        media.status = "ready"
        media.size = len(audio)
        s.commit()
    return media_id, max(1, int(round(duration)))


@app.post("/ai/characters/{character_id}/voice/design")
async def character_voice_design(
    character_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    """通过音色描述生成角色专属的非真人复刻声线，并返回试听语音。"""
    if not tts_minimax.is_configured():
        raise HTTPException(
            status_code=503,
            detail={"error": {"code": "TTS_NOT_CONFIGURED", "message": "语音服务未配置", "retryable": False}},
        )
    body = await request.json()
    try:
        voice_id, audio = tts_minimax.voice_design(
            character_id,
            str(body.get("prompt") or ""),
            str(body.get("preview_text") or ""),
        )
        media_id, duration = _store_tts_preview(audio)
    except tts_minimax.TTSGatewayError as e:
        raise HTTPException(
            status_code=502,
            detail={"error": {"code": "TTS_DESIGN_FAILED", "message": str(e), "retryable": True}},
        )
    return {
        **tts_minimax.get_profile(character_id),
        "voice_id": voice_id,
        "preview_media_id": media_id,
        "preview_duration": duration,
    }


@app.post("/ai/characters/{character_id}/voice/clone")
async def character_voice_clone(
    character_id: str, request: Request, _: None = Depends(require_signature)
) -> dict:
    """用本人或已获授权的样本复刻角色音色；服务端强制要求授权确认。"""
    if not tts_minimax.is_configured():
        raise HTTPException(
            status_code=503,
            detail={"error": {"code": "TTS_NOT_CONFIGURED", "message": "语音服务未配置", "retryable": False}},
        )
    body = await request.json()
    if body.get("consent_confirmed") is not True:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VOICE_CONSENT_REQUIRED", "message": "仅可复刻本人或已明确获得授权的声音", "retryable": False}},
        )
    media_asset_id = (body.get("media_asset_id") or "").strip()
    if not media_asset_id:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "缺少 media_asset_id", "retryable": False}},
        )
    try:
        file_id = tts_minimax.upload_file(media_asset_id)
        preview_text = str(body.get("text") or "你好，很高兴以这个声音和你聊天。")
        voice_id = tts_minimax.voice_clone(
            file_id,
            preview_text,
            character_id=character_id,
            sample_media_id=media_asset_id,
        )
        # 首次真实 T2A 同时完成试听，并在官方 7 天期限内激活保留该音色。
        audio = tts_minimax.synthesize(preview_text, character_id=character_id)
        media_id, duration = _store_tts_preview(audio)
    except tts_minimax.TTSGatewayError as e:
        raise HTTPException(
            status_code=502,
            detail={"error": {"code": "TTS_CLONE_FAILED", "message": str(e), "retryable": True}},
        )
    return {
        **tts_minimax.get_profile(character_id),
        "voice_id": voice_id,
        "preview_media_id": media_id,
        "preview_duration": duration,
    }


@app.delete("/ai/characters/{character_id}/voice")
async def character_voice_delete(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    """删除当前角色的远端自定义音色及本地档案，恢复默认系统女声。"""
    try:
        tts_minimax.delete_provider_voice(character_id)
    except tts_minimax.TTSGatewayError as e:
        raise HTTPException(
            status_code=502,
            detail={"error": {"code": "TTS_DELETE_FAILED", "message": str(e), "retryable": True}},
        )
    return {"ok": True}


# 014 旧状态端点保留只读兼容，统一映射到第一个角色。
@app.get("/ai/tts/status")
async def tts_status(_: None = Depends(require_signature)) -> dict:
    return {
        "configured": tts_minimax.is_configured(),
        "ready": tts_minimax.is_ready(),
        "voice_id": tts_minimax.get_voice_id("companion"),
        "default_voice": config.MINIMAX_TTS_VOICE,
    }


# --------------------------------------------------------------------------- #
# 同步协议（轻量变更日志）
# --------------------------------------------------------------------------- #
@app.post("/sync/push")
async def sync_push(request: Request, _: None = Depends(require_signature)) -> dict:
    device_id = request.headers.get("X-Device-Id", "")
    body = await request.json()
    events = body.get("events", [])
    accepted = 0
    conflicts: list[dict] = []
    with db.SessionLocal() as s:
        for ev in events:
            et = ev.get("entity_type")
            eid = ev.get("entity_id")
            op = ev.get("operation")
            client_event_id = ev.get("id")  # 客户端本地事件 id（幂等去重键）
            if not (et and eid and op):
                conflicts.append({"error": "missing_field", "raw": ev})
                continue
            # 幂等：同设备同一 client_event_id 已存在则跳过（网络抖动重推去重）
            if client_event_id:
                exists = (
                    s.query(SyncEvent.id)
                    .filter_by(device_id=device_id, client_event_id=client_event_id)
                    .first()
                )
                if exists:
                    continue
            # 同一实体每变更 version+1（最终一致 reconcile 用）
            max_v = s.query(func.max(SyncEvent.version)).filter_by(entity_type=et, entity_id=eid).scalar() or 0
            new_ev = SyncEvent(
                id=uuid7(),
                device_id=device_id,
                entity_type=et,
                entity_id=eid,
                operation=op,
                payload=ev.get("payload"),
                version=max_v + 1,
                client_event_id=client_event_id,
                synced_at=func.now(),
            )
            s.add(new_ev)
            # 当前态镜像：定义类事件增量应用到 entity_snapshot（同事务，幂等）
            snapshot.apply_sync_event(s, new_ev)
            accepted += 1
        s.commit()
    return {"accepted": accepted, "conflicts": conflicts}


@app.get("/sync/pull")
async def sync_pull(cursor: str = "", limit: int = 100, _: None = Depends(require_signature)) -> dict:
    with db.SessionLocal() as s:
        q = s.query(SyncEvent)
        if cursor:
            q = q.filter(SyncEvent.id > cursor)  # uuidv7 字典序≈时间序，可作游标
        rows = q.order_by(SyncEvent.id).limit(limit).all()
        events = [
            {
                "id": r.id,
                "device_id": r.device_id,
                "entity_type": r.entity_type,
                "entity_id": r.entity_id,
                "operation": r.operation,
                "payload": r.payload,
                "version": r.version,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ]
        next_cursor = rows[-1].id if rows else cursor
    return {"events": events, "next_cursor": next_cursor}


# --------------------------------------------------------------------------- #
# 时间线（跨模块统一记录流，v0.5）
# --------------------------------------------------------------------------- #
@app.get("/timeline")
async def timeline_get(days: int = 14, _: None = Depends(require_signature)) -> dict:
    """跨模块时间线：按实体发生时间降序，已按实体 id 去重。

    `days` 控制回溯天数（1..90，默认 14）。时间戳为实体本地墙上时间原样透出，
    前端 DateTime.parse 按本地时间解析。
    """
    return {"items": timeline.get_timeline(days=days)}


# --------------------------------------------------------------------------- #
# 小米运动健康自动同步（v0.4-4）
# --------------------------------------------------------------------------- #
@app.post("/mi_fitness/sync")
async def mi_fitness_sync_trigger(_: None = Depends(require_signature)) -> dict:
    """手动触发一次小米云增量同步（近 2 天），返回各类同步条数。"""
    return mi_fitness_sync.run_sync(days_back=1)


@app.get("/mi_fitness/status")
async def mi_fitness_status(_: None = Depends(require_signature)) -> dict:
    """小米同步配置/状态/数据量探针（运动页自动记录区状态用）。"""
    return mi_fitness_sync.status()


@app.get("/mi_fitness/daily")
async def mi_fitness_daily(
    start: str = "",
    end: str = "",
    _: None = Depends(require_signature),
) -> dict:
    """每日步数/距离/活动卡路里（运动页自动记录区）。start/end 为 YYYY-MM-DD。"""
    with db.SessionLocal() as s:
        q = s.query(MiActivityDaily)
        if start:
            q = q.filter(MiActivityDaily.date >= start)
        if end:
            q = q.filter(MiActivityDaily.date <= end)
        rows = q.order_by(MiActivityDaily.date).all()
    return {
        "days": [
            {
                "date": r.date,
                "steps": r.steps,
                "distance_m": r.distance_m,
                "active_kcal": r.active_kcal,
            }
            for r in rows
        ]
    }


@app.get("/mi_fitness/workouts")
async def mi_fitness_workouts(
    start: str = "",
    end: str = "",
    limit: int = 100,
    _: None = Depends(require_signature),
) -> dict:
    """自动同步的运动记录列表（按开始时间倒序）。start/end 为 YYYY-MM-DD。"""
    with db.SessionLocal() as s:
        q = s.query(MiWorkout)
        if start:
            q = q.filter(
                MiWorkout.start_at >= datetime.fromisoformat(start).replace(tzinfo=timezone.utc)
            )
        if end:
            q = q.filter(
                MiWorkout.start_at
                < datetime.fromisoformat(end + "T23:59:59").replace(tzinfo=timezone.utc)
            )
        rows = q.order_by(MiWorkout.start_at.desc()).limit(limit).all()
    return {
        "workouts": [
            {
                "id": r.id,
                "activity_type": r.activity_type,
                "start_at": r.start_at.isoformat() if r.start_at else None,
                "end_at": r.end_at.isoformat() if r.end_at else None,
                "duration_min": r.duration_min,
                "distance_m": r.distance_m,
                "calories_kcal": r.calories_kcal,
                "avg_hr_bpm": r.avg_hr_bpm,
                "max_hr_bpm": r.max_hr_bpm,
                "total_steps": r.total_steps,
            }
            for r in rows
        ]
    }


# Keep dormant implementations and historical data, but do not expose their APIs.
# Re-enable before process startup together with the mobile feature flag.
if not config.LIFE_TRACKING_ENABLED:
    _dormant_api_prefixes = ("/sync", "/timeline", "/mi_fitness")
    app.router.routes[:] = [
        route for route in app.router.routes
        if not any(
            getattr(route, "path", "") == prefix
            or getattr(route, "path", "").startswith(prefix + "/")
            for prefix in _dormant_api_prefixes
        )
    ]
