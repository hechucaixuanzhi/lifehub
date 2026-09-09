"""单聊/群聊共用的媒体、引用、历史组装辅助（032_group_worldbook）。

从 main.py 抽取，避免 main.py ⇄ group_chat.py 循环依赖：main 与 group_chat 都
import 本模块，共享同一套行为（表情包/图片描述、引用回填、历史文本化）。
"""
import base64
import os
import re

from fastapi import HTTPException

from . import ai_gateway, config, db, identity_veto, prompts
from .models import MediaAsset, Message, Sticker


def media_path(storage_path: str) -> str:
    """媒体文件路径：相对 UPLOAD_DIR 的随机文件名（避免恶意文件名/路径穿越）。"""
    return os.path.join(config.UPLOAD_DIR, storage_path)


def sticker_media_ctx(
    sticker_id: str | None, media_asset_id: str | None
) -> tuple[dict | None, str | None, int | None]:
    """表情包媒体上下文（009）：返回 (media_ctx, file_name, file_size)。

    统一触发逻辑（用户确认）：见过（有描述）直接用，没见过才调 MiMo 并存档。
    - 内置：sticker_id → 目录预置描述，永不调 MiMo
    - 相册：media_asset_id → asset.caption 命中即复用（存档缓存）；无描述且为图片
      → MiMo 描述并写回 caption（同图再发/历史渲染命中缓存，不重调 MiMo）
    """
    if sticker_id:
        with db.SessionLocal() as s:
            st = s.get(Sticker, sticker_id)
        if st is None:
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "STICKER_NOT_FOUND", "message": "表情包不存在", "retryable": False}},
            )
        return {"kind": "sticker", "description": st.description}, None, None

    if media_asset_id:
        with db.SessionLocal() as s:
            asset = s.get(MediaAsset, media_asset_id)
        if asset is None or asset.status != "ready":
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "媒体不存在", "retryable": False}},
            )
        description = (asset.caption or "").strip() or None  # 见过 → 直接复用，不调 MiMo
        if description is None and asset.mime_type and asset.mime_type.startswith("image/"):
            try:
                with open(media_path(asset.storage_path), "rb") as f:
                    description = ai_gateway.vision_describe(
                        base64.b64encode(f.read()).decode(), asset.mime_type
                    )
            except Exception:
                description = None
            if description:
                with db.SessionLocal() as s:
                    asset = s.get(MediaAsset, media_asset_id)
                    asset.caption = description  # 存档：见过复用，不重调 MiMo
                    s.commit()
        return {"kind": "sticker", "description": description}, asset.file_name, asset.size

    raise HTTPException(
        status_code=422,
        detail={"error": {"code": "STICKER_NO_REF", "message": "表情包缺少 sticker_id 或 media_asset_id", "retryable": False}},
    )


def resolve_media_context(
    media_kind: str,
    media_asset_id: str | None,
    sticker_id: str | None,
    self_identity: dict | None,
) -> tuple[dict | None, str | None, int | None]:
    """媒体上下文：表情包 → 目录/存档描述；图片 → MiMo 瞬时描述 + 自我识别注入；
    文件 → 文件名。返回 (media_ctx, media_file_name, media_file_size)。"""
    media_ctx: dict | None = None
    media_file_name: str | None = None
    media_file_size: int | None = None
    if media_kind == "sticker":
        media_ctx, media_file_name, media_file_size = sticker_media_ctx(sticker_id, media_asset_id)
    elif media_asset_id:
        with db.SessionLocal() as s:
            asset = s.get(MediaAsset, media_asset_id)
        if asset is None or asset.status != "ready":
            raise HTTPException(
                status_code=404,
                detail={"error": {"code": "MEDIA_NOT_FOUND", "message": "媒体不存在", "retryable": False}},
            )
        media_file_name = asset.file_name
        media_file_size = asset.size
        if media_kind == "image":
            caption = None
            if asset.mime_type and asset.mime_type.startswith("image/"):
                try:
                    with open(media_path(asset.storage_path), "rb") as f:
                        caption = ai_gateway.vision_describe(
                            base64.b64encode(f.read()).decode(), asset.mime_type
                        )
                except Exception:
                    caption = None
            media_ctx = {"kind": "image", "caption": caption}
            # 自我识别注入（017/018）：check 结果 → 标准注入段；先过 caption 语义闸门，
            # 防表情包/假脸误判 SELF。
            if isinstance(self_identity, dict) and self_identity.get("identity_state"):
                if caption:
                    self_identity = identity_veto.apply_veto(self_identity, caption)
                media_ctx["identity_prompt"] = prompts.build_self_identity_prompt(self_identity)
        elif media_kind == "file":
            media_ctx = {"kind": "file", "file_name": media_file_name or media_asset_id}
    return media_ctx, media_file_name, media_file_size


def reference_text(message: Message) -> str:
    """把被引用消息转成稳定短文本；服务端记录优先于客户端回传。"""
    content = (message.content or "").strip()
    label = {
        "image": "[图片]",
        "sticker": "[表情包]",
        "audio": "[语音]",
        "file": f"[文件：{message.file_name or ''}]",
    }.get(message.kind or "text", "")
    return f"{label} {content}".strip()[:4000]


def redpacket_amount_text(value) -> str:
    """金额显示：None → 空串；5.0 → '5'；5.5 → '5.5'（无多余 0）。"""
    if value is None:
        return ""
    try:
        return f"{float(value):g}"
    except (TypeError, ValueError):
        return ""


def current_message_with_quote(message: str, quote_role: str | None, quote: str | None) -> str:
    if not quote:
        return message
    quoted_role = "你之前" if quote_role == "assistant" else "用户之前"
    return f"[用户正在引用{quoted_role}的消息：{quote}]\n{message}".strip()


_ROLEPLAY_DIRECTIVE_RE = re.compile(r"【([^】]*)】")


def extract_user_directives(message: str, *, roleplay: bool = False) -> tuple[str, str]:
    """剧情模式（验收批3③）：把用户消息中的【...】提取为剧情方向指示。

    返回 (body, directive)：directive 为保序拼接的指示串（多条用「；」连接），
    body 为剔除【...】后的消息体；（）旁白原样保留（模型已被告知是旁白）。
    非剧情模式（roleplay=False）或没有【】时原样返回 (message, "")。
    必须在记忆提取/消息落库前调用：元指令不进记忆与历史，只进本轮模型输入。
    """
    if not roleplay or not message or "【" not in message:
        return message, ""
    blocks = _ROLEPLAY_DIRECTIVE_RE.findall(message)
    if not blocks:
        return message, ""
    body = _ROLEPLAY_DIRECTIVE_RE.sub("", message).strip()
    directive = "；".join(b.strip() for b in blocks if b.strip())
    return body, directive


def recent_history_rows(session, conversation_id: str) -> list[Message]:
    """取当前消息之前的最近上下文，同时受消息数和字符预算约束。"""
    rows = (
        session.query(Message)
        .filter(
            Message.conversation_id == conversation_id,
            Message.context_excluded.is_(False),
        )
        .order_by(Message.created_at.desc(), Message.id.desc())
        .limit(max(1, config.AI_CHAT_HISTORY_MAX_MESSAGES))
        .all()
    )
    chosen: list[Message] = []
    used = 0
    budget = max(1000, config.AI_CHAT_HISTORY_MAX_CHARS)
    for row in rows:
        size = len(row.content or "") + len(row.quote_content or "") + 32
        if chosen and used + size > budget:
            break
        chosen.append(row)
        used += size
    return list(reversed(chosen))


def _sticker_descriptions(rows: list[Message]) -> tuple[dict[str, str], dict[str, str]]:
    """批量取表情描述：内置 sticker 目录 + 相册 asset.caption（防 N+1）。"""
    sticker_ids = [m.sticker_id for m in rows if m.kind == "sticker" and m.sticker_id]
    asset_ids = [m.media_asset_id for m in rows if m.kind == "sticker" and m.media_asset_id]
    sticker_desc = ai_gateway.sticker_descriptions(sticker_ids) if sticker_ids else {}
    asset_caption: dict[str, str] = {}
    if asset_ids:
        with db.SessionLocal() as s:
            for a in s.query(MediaAsset).filter(MediaAsset.id.in_(asset_ids)).all():
                asset_caption[a.id] = a.caption or ""
    return sticker_desc, asset_caption


def _content_for(
    m: Message,
    sticker_desc: dict[str, str],
    asset_caption: dict[str, str],
    *,
    speaker_name: str | None = None,
) -> str:
    """单条消息文本化：媒体转描述、引用回填、群聊发言人前缀。"""
    content = m.content or ""
    if m.role == "assistant":
        content = ai_gateway.strip_internal_reply_markers(content)
    if m.kind == "sticker":
        desc = (sticker_desc.get(m.sticker_id) if m.sticker_id else None) or (
            asset_caption.get(m.media_asset_id) if m.media_asset_id else None
        )
        if m.role == "assistant":
            label = f"[表情包：{desc}]" if desc else "[表情包]"
        else:
            label = f"[用户发来一个表情包：{desc}]" if desc else "[用户发来一个表情包]"
        content = f"{label} {content}".strip()
    elif m.kind == "image":
        content = f"[用户发来一张图片] {content}".strip()
    elif m.kind == "file":
        content = f"[文件] {m.file_name or ''}".rstrip()
    elif m.kind == "audio":
        # 语音转写本身就是本轮说过的话；不注入“[语音回复]”等传输标签。
        content = content.strip()
    elif m.kind == "redpacket":
        amt = redpacket_amount_text(m.redpacket_amount)
        content = (
            f"[用户发来红包：金额{amt}元，留言：{content}]"
            if content
            else f"[用户发来红包：金额{amt}元]"
        )
    elif m.kind == "transfer":
        amt = redpacket_amount_text(m.redpacket_amount)
        content = (
            f"[用户转账{amt}元，附言：{content}]" if content else f"[用户转账{amt}元]"
        )
    if m.quote_content:
        quoted_role = "你之前" if m.quote_role == "assistant" else "用户之前"
        content = f"[这条消息引用了{quoted_role}的消息：{m.quote_content}]\n{content}".strip()
    if speaker_name:
        # 模型有时会在回复里自加「名字：」前缀（复刻群聊历史格式）。剥离同名
        # 前缀，避免落到「角色名：角色名：...」双重前缀，进一步诱导格式复刻。
        for sep in ("：", ":"):
            prefix = f"{speaker_name}{sep}"
            if content.startswith(prefix):
                content = content[len(prefix):].lstrip()
                break
        content = f"{speaker_name}：{content}"
    return content


def build_history(rows: list[Message]) -> list[dict]:
    """单聊历史：媒体消息转描述文本，AI 才知道发过图/文件/表情包。"""
    sticker_desc, asset_caption = _sticker_descriptions(rows)
    history = []
    for m in rows:
        if m.role not in ("user", "assistant"):
            continue
        history.append({"role": m.role, "content": _content_for(m, sticker_desc, asset_caption)})
    return history
def build_group_history(rows: list[Message], member_map: dict[str, str]) -> list[dict]:
    """群聊历史：每条带发言人前缀（用户 / 成员名），模型才知道谁说了什么。

    member_map：{character_id: name}；assistant 消息按 sender_character_id 归属。
    """
    sticker_desc, asset_caption = _sticker_descriptions(rows)
    history = []
    for m in rows:
        if m.role not in ("user", "assistant"):
            continue
        if m.role == "user":
            name = "用户"
        else:
            name = member_map.get(m.sender_character_id) or "成员"
        history.append(
            {
                "role": m.role,
                "content": _content_for(m, sticker_desc, asset_caption, speaker_name=name),
            }
        )
    return history
