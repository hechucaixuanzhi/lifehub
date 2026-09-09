"""群聊流程（032_group_worldbook）：多角色群聊的发言决策 + 逐成员全量生成。

与单聊 ai_chat 共享 ai_gateway.chat() / chat_common 的媒体与历史辅助，但独立
管理「谁发言」与每条消息的 sender_character_id。MVP 约束：群回复不做 TTS、
不自动抽取记忆（N 回复配对歧义）；语音输入仍走 ASR→文本→文本回复。
"""
from typing import Iterator
from datetime import datetime, timezone

from fastapi import HTTPException

from . import ai_gateway, chat_common, config, db, prompts
from .models import (
    Character,
    Conversation,
    ConversationMember,
    Message,
    RedPacketClaim,
    Worldbook,
)


def _worldbook_to_dict(wb: Worldbook | None) -> dict | None:
    """Worldbook → world_context 层可用的 worldview 形 dict。

    rules 即世界规则；summary 作为「当前世界身份」锚点（世界简介，全员共享）；
    cards（R6 世界卡）供群聊情境层注入势力/地点/情节线。
    与 character_context._worldview_to_dict 输出字段对齐（name/rules/identity）。
    """
    if wb is None:
        return None
    return {
        "name": wb.name,
        "rules": wb.rules,
        "identity": wb.summary,
        "cards": wb.cards or [],
    }


def get_group_members(session, conversation_id: str) -> list[Character]:
    """按 sort 序取群成员；成员角色已被删除时静默跳过（不崩群）。"""
    rows = (
        session.query(ConversationMember)
        .filter(ConversationMember.conversation_id == conversation_id)
        .order_by(ConversationMember.sort, ConversationMember.character_id)
        .all()
    )
    return [c for r in rows if (c := session.get(Character, r.character_id)) is not None]


def ensure_group_ready(conversation_id: str) -> None:
    """预检流式群聊（200 前抛 HTTPException）：会话存在 / 是群聊 / 成员非空。

    流式端点先调本函数，把校验类错误拦在 StreamingResponse 之前——否则
    HTTPException 在生成器首个 yield 前抛出时，响应头已是 200，前端只能看到
    空 SSE 流。非流式路径（group_chat_flow）在正常请求处理中抛错，无需预检。
    """
    with db.SessionLocal() as s:
        conv = s.get(Conversation, conversation_id)
        if conv is None:
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "CONVERSATION_NOT_FOUND", "message": "会话不存在", "retryable": False}},
            )
        if conv.type != "group":
            raise HTTPException(
                status_code=422,
                detail={"error": {"code": "NOT_GROUP", "message": "该会话不是群聊", "retryable": False}},
            )
        members = get_group_members(s, conversation_id)
        if not members:
            raise HTTPException(
                status_code=422,
                detail={"error": {"code": "GROUP_EMPTY", "message": "群成员为空", "retryable": False}},
            )


def get_group_member_world_identities(
    session, conversation_id: str
) -> dict[str, str]:
    """{character_id: world_identity}，成员级世界身份预设（可为空串）。"""
    rows = (
        session.query(ConversationMember)
        .filter(ConversationMember.conversation_id == conversation_id)
        .all()
    )
    return {r.character_id: (r.world_identity or "") for r in rows}


def _member_roster(chars: list[Character]) -> list[dict]:
    """群成员名单（LLM 可见）：id 参与选人，name/tagline 供人格识别。"""
    return [{"id": c.id, "name": c.name, "tagline": c.tagline} for c in chars]


def _resolve_speakers(
    speaker_mode: str,
    members: list[Character],
    roster: list[dict],
    worldbook_dict: dict | None,
    group_name: str,
    group_history: list[dict],
    current_message: str,
    mention_character_id: str | None,
) -> list[Character]:
    """按模式决定本轮发言成员。

    mention：点名成员（非群成员 422）；all：全部；auto：LLM 选人（内部自带
    确定性回退链，绝不抛错，见 ai_gateway.select_group_speaker）。
    """
    if mention_character_id:
        hit = [c for c in members if c.id == mention_character_id]
        if not hit:
            raise HTTPException(
                status_code=422,
                detail={
                    "error": {
                        "code": "MENTION_NOT_MEMBER",
                        "message": "点名的成员不在本群",
                        "retryable": False,
                    }
                },
            )
        return hit
    if speaker_mode == "all":
        return list(members)
    picked_id = ai_gateway.select_group_speaker(
        roster, worldbook_dict, group_name, group_history, current_message
    )
    for c in members:
        if c.id == picked_id:
            return [c]
    return [members[0]]  # LLM 返回未知 id → 兜底首成员


def _assistant_payload(row: Message) -> dict:
    return {
        "id": row.id,
        "sender_character_id": row.sender_character_id,
        "content": row.content or "",
        "kind": row.kind,
        "media_asset_id": row.media_asset_id,
        "sticker_id": row.sticker_id,
        "audio_duration": row.audio_duration,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def _record_claim(s, message_id: str, character_id: str) -> None:
    """红包领取落库（R4）：首次领取置 message.redpacket_claimed；每成员一条 claim。"""
    exists = (
        s.query(RedPacketClaim.id)
        .filter_by(message_id=message_id, character_id=character_id)
        .first()
    )
    if exists:
        return
    ur = s.get(Message, message_id)
    if ur is not None and not ur.redpacket_claimed:
        ur.redpacket_claimed = True
        ur.redpacket_claim_time = datetime.now(timezone.utc)
    s.add(RedPacketClaim(message_id=message_id, character_id=character_id))


def _user_payload(row: Message) -> dict:
    return {
        "id": row.id,
        "role": "user",
        "sender_character_id": None,
        "kind": row.kind or "text",
        "content": row.content or "",
        "media_asset_id": row.media_asset_id,
        "sticker_id": row.sticker_id,
        "file_name": row.file_name,
        "file_size": row.file_size,
        "audio_duration": row.audio_duration,
        "quote_message_id": row.quote_message_id,
        "quote_role": row.quote_role,
        "quote_content": row.quote_content,
        "redpacket_amount": row.redpacket_amount,
        "redpacket_claimed": bool(row.redpacket_claimed),
        "redpacket_claim_time": (
            row.redpacket_claim_time.isoformat()
            if row.redpacket_claim_time
            else None
        ),
        # 转账收/拒（验收批2）：null=待回应 / true=接受 / false=婉拒
        "transfer_accepted": row.transfer_accepted,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def group_chat_flow_events(
    *,
    conversation_id: str,
    message: str,
    media_ctx: dict | None,
    media_file_name: str | None,
    media_file_size: int | None,
    media_kind: str,
    media_asset_id: str | None,
    sticker_id: str | None,
    audio_duration: int | None,
    quote_message_id: str | None,
    quote_role: str | None,
    quote_content: str | None,
    mention_character_id: str | None,
    requested_reply_mode: str | None,
    requested_reply_max_chars: int | None,
    message_source_mode: str,
    noban: bool = False,
    redpacket_amount: float | None = None,
) -> Iterator[dict]:
    """一轮群聊，逐事件产出：user_message → reply×N → done（或 error）。

    - persist-as-you-go：用户消息先落库，每条回复生成完即落库并产出事件，
      流式连接中断时已产出的回复仍留在库里（重进可恢复）；
    - 事件 dict：{"type": "user_message", ...} / {"type": "reply", ...} /
      {"type": "done", conversation_id, speaker_mode, reply_mode} /
      {"type": "error", message}；
    - 校验类 HTTPException 原样上抛；生成失败产 error 事件并中断本轮。
    """
    ensure_group_ready(conversation_id)  # 校验类错误在 200 前上抛
    with db.SessionLocal() as s:
        conv = s.get(Conversation, conversation_id)
        members = get_group_members(s, conversation_id)
        worldbook_dict = None
        if conv.worldbook_id:
            worldbook_dict = _worldbook_to_dict(s.get(Worldbook, conv.worldbook_id))
        world_identity_map = get_group_member_world_identities(s, conversation_id)

        # reply_mode：请求覆盖存储；默认沿用会话设置。
        if requested_reply_mode:
            conv.reply_mode = requested_reply_mode
        reply_mode = conv.reply_mode or "realtime"
        # 验收批3③：剧情模式把用户【...】提取为剧情方向指示（早提取——在记忆提取与
        # 用户消息落库之前；元指令不进记忆/历史/红包附言，只进本轮模型输入）。
        message, user_directive = chat_common.extract_user_directives(
            message, roleplay=reply_mode == "roleplay"
        )
        # 回复字数/条数（036）：群设置持久化到 conv 列，requested 参数可即时覆盖。
        default_chars = (
            conv.reply_chars_roleplay
            if reply_mode == "roleplay"
            else conv.reply_chars_realtime
        )
        if reply_mode == "roleplay":
            reply_max_chars = max(
                300, min(requested_reply_max_chars or (default_chars or 1000), 3000)
            )
        else:
            reply_max_chars = max(
                60, min(requested_reply_max_chars or (default_chars or 180), 600)
            )
        # 真实模式条数 1-5（防刷屏默认 1）；剧情恒 1 条长回复。
        reply_bubble_count = (
            1 if reply_mode == "roleplay" else (conv.reply_count or 1)
        )
        speaker_mode = conv.speaker_mode or "auto"

        # 群历史：每条带发言人前缀（成员名： / 用户：），模型才知道谁说过什么。
        roster = _member_roster(members)
        member_map = {c.id: c.name for c in members}
        # 群聊与私人聊天完全隔离：群聊只读本群会话历史，不并入任何单聊或其他群。
        group_history = chat_common.build_group_history(
            chat_common.recent_history_rows(s, conv.id), member_map
        )
        message_for_ai = chat_common.current_message_with_quote(
            message, quote_role, quote_content
        )
        if media_kind == "redpacket":
            _amt = chat_common.redpacket_amount_text(redpacket_amount)
            message_for_ai = (
                f"用户发来群红包：金额{_amt}元，留言：{message}"
                if message
                else f"用户发来群红包：金额{_amt}元"
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
        # 故在其后统一拼到最终 message_for_ai 前；只进本轮 chat() 输入，不进 history。
        # 群聊每个 speaker 都经 speaker_msg 拿到该 message_for_ai，一处注入覆盖全部成员。
        if user_directive:
            message_for_ai = f"【用户指示：{user_directive}】\n{message_for_ai}"
        message_for_ai = f"用户：{message_for_ai}"

        speakers = _resolve_speakers(
            speaker_mode,
            members,
            roster,
            worldbook_dict,
            conv.name or "群聊",
            group_history,
            message_for_ai,
            mention_character_id,
        )

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
        user_payload = _user_payload(user_row)
        s.commit()
    yield {"type": "user_message", **user_payload}

    # 逐 speaker 生成（串行：MVP 控制并发与各角色历史一致性；后续可并行）。
    any_reply_yet = False  # R4 红包必回：首成员空回复兜底致谢只触发一次
    first_transfer_accepted = None  # 转账收/拒：以首个有效回复成员的决定为准
    for speaker in speakers:
        # 贴近生成点的身份锚定（真机 OOC 根因修复）：system 层声明离历史范例太远，
        # 模型在「自我介绍」任务上会复刻最近最显眼的「我是X」范例。把锚定追加到
        # user 消息末尾（注意力最强位置），只进本 speaker 的 chat() 参数，不进 history。
        speaker_msg = (
            f"{message_for_ai}\n\n"
            f"现在由「{speaker.name}」发言。你就是{speaker.name}，本群名字就叫{speaker.name}。"
            f"如果是自我介绍，第一句说「我是{speaker.name}」；不要把自己说成其他成员，"
            "也不要在自己的话前面加任何名字前缀。"
        )
        try:
            memories = []
            if speaker.memory_enabled:
                try:
                    memories = ai_gateway.memory_search(
                        message, limit=5, character_id=speaker.id
                    )
                except Exception:
                    memories = []
            # 禁止事项（R3）：硬约束，不 gate 在 memory_enabled，每轮常驻注入。
            try:
                forbidden = ai_gateway.memory_forbidden(speaker.id)
            except Exception:
                forbidden = []
            # 按发言者锚定群聊情境层（#5）：重申「你是谁」防 OOC；
            # world_identity = 该成员在本世界的身份预设（#2）。
            group_context = prompts.build_group_context_prompt(
                roster,
                worldbook_dict,
                conv.name or "群聊",
                {"id": speaker.id, "name": speaker.name, "tagline": speaker.tagline},
                world_identity_map.get(speaker.id),
                world_cards=(worldbook_dict or {}).get("cards"),
            )
            reply = ai_gateway.chat(
                speaker_msg,
                character_id=speaker.id,
                history=group_history,
                memories=memories,
                media=media_ctx,
                reply_mode=reply_mode,
                reply_bubble_count=reply_bubble_count,
                reply_max_chars=reply_max_chars,
                worldview_override=worldbook_dict,
                group_context=group_context,
                forbidden_memories=forbidden,
                # 群无违禁：开关对本群打开时，仅对支持无违禁的成员生效（noban_prompt 非空）。
                noban=(noban and speaker.noban_prompt is not None),
            )
            reply = ai_gateway.normalize_generated_reply(reply or "", reply_mode)
            # 转账收/拒（验收批2）：解析 [接受]/[婉拒] 前缀标记，剥离后继续常规拆条。
            transfer_accepted = None
            if media_kind == "transfer":
                transfer_accepted, reply = ai_gateway.parse_transfer_decision(reply)
            reply, parsed_sticker_id = ai_gateway.resolve_sticker_reply(reply)
            segments = ai_gateway.split_reply_segments(
                reply, reply_mode, reply_bubble_count=1
            )
            combined = "\n".join(segments)
            if not combined and not parsed_sticker_id:
                # R4 红包必回：首个成员空回复 → 兜底致谢（后续成员仍可跳过防刷屏）；
                # 转账若标记婉拒，兜底也按婉拒口吻（与决定一致）。
                if media_kind in ("redpacket", "transfer") and not any_reply_yet:
                    if media_kind == "transfer" and transfer_accepted is False:
                        combined = "这钱就不收了，心意领了～"
                    else:
                        combined = (
                            "谢谢老板的红包！"
                            if media_kind == "redpacket"
                            else "收到转账啦，谢谢～"
                        )
                    segments = [combined]
                else:
                    continue  # 空回复（模型拒答）→ 本轮不发该成员
            ai_sticker_id = parsed_sticker_id if config.AI_STICKER_REPLIES_ENABLED else None
            with db.SessionLocal() as s:
                row = Message(
                    conversation_id=conversation_id,
                    role="assistant",
                    sender_character_id=speaker.id,
                    content=combined,
                    kind="sticker" if ai_sticker_id else "text",
                    sticker_id=ai_sticker_id,
                    source_mode=message_source_mode,
                )
                s.add(row)
                s.flush()
                payload = _assistant_payload(row)
                # R4 领取落库：红包/转账必回 → 首个有效回复标记红包已领取；
                # 每位 AI 成员领取一条（判重防重入）。
                if media_kind in ("redpacket", "transfer"):
                    _record_claim(s, user_row.id, speaker.id)
                # 转账收/拒（验收批2）：以首个有效回复成员的决定落库（不明→默认接受）。
                if media_kind == "transfer" and not any_reply_yet:
                    ur = s.get(Message, user_row.id)
                    if ur is not None and ur.transfer_accepted is None:
                        ur.transfer_accepted = (
                            bool(transfer_accepted)
                            if transfer_accepted is not None
                            else True
                        )
                    first_transfer_accepted = (
                        bool(transfer_accepted)
                        if transfer_accepted is not None
                        else True
                    )
                s.commit()
            any_reply_yet = True
            yield {"type": "reply", **payload}
        except HTTPException:
            raise  # 校验类错误原样上抛（前端按错误码处理）
        except Exception as e:  # 生成失败：产 error 事件并中止本轮（不再 done）
            yield {
                "type": "error",
                "conversation_id": conversation_id,
                "speaker_mode": speaker_mode,
                "reply_mode": reply_mode,
                "message": f"{e.__class__.__name__}: {e}",
            }
            return
    yield {
        "type": "done",
        "conversation_id": conversation_id,
        "speaker_mode": speaker_mode,
        "reply_mode": reply_mode,
        # 转账收/拒（验收批2）：以首个有效回复成员的决定为准；非转账恒 None。
        "transfer_accepted": first_transfer_accepted,
    }


def group_chat_flow(**kwargs) -> dict:
    """非流式版本：收集生成器事件，返回与既有契约一致的响应 dict。"""
    user_message = None
    replies: list[dict] = []
    final: dict = {}
    error_message = None
    for event in group_chat_flow_events(**kwargs):
        etype = event["type"]
        if etype == "user_message":
            user_message = {k: v for k, v in event.items() if k != "type"}
        elif etype == "reply":
            replies.append({k: v for k, v in event.items() if k != "type"})
        elif etype in ("done", "error"):
            final = event  # error 也带 conversation_id/speaker_mode，供响应兜底
        if etype == "error":
            error_message = event.get("message")
    response = {
        "replies": replies,
        "user_message": user_message,
        "conversation_id": final.get("conversation_id"),
        "speaker_mode": final.get("speaker_mode"),
        "reply_mode": final.get("reply_mode"),
    }
    if error_message:
        response["error"] = error_message
    return response
