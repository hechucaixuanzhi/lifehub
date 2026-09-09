"""Character-scoped conversation feedback endpoints.

Feedback remains observational: these routes collect and aggregate signals but
never mutate a character prompt or reply policy.
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request

from .. import db
from ..models import ConversationFeedback, Message
from ..security import require_signature

router = APIRouter(prefix="/ai/feedback", tags=["ai-feedback"])

FEEDBACK_REASONS = [
    "too_formal",
    "too_verbose",
    "too_cold",
    "preachy",
    "misunderstood",
    "out_of_character",
    "wrong_emotion",
]


@router.post("")
async def feedback_submit(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    rating = body.get("rating")
    character_id = body.get("character_id")
    conversation_id = body.get("conversation_id")
    message_id = body.get("message_id")
    reasons = body.get("reasons") or []
    custom_feedback = (body.get("custom_feedback") or "").strip() or None
    preferred_reply = (body.get("preferred_reply") or "").strip() or None

    if rating not in ("positive", "negative", "none"):
        raise _validation_error("rating 必须为 positive|negative|none")
    if not character_id or not isinstance(character_id, str):
        raise _validation_error("缺少 character_id")
    if not conversation_id or not isinstance(conversation_id, str):
        raise _validation_error("缺少 conversation_id")
    if not message_id or not isinstance(message_id, str):
        raise _validation_error("缺少 message_id")
    if not isinstance(reasons, list) or any(
        reason not in FEEDBACK_REASONS for reason in reasons
    ):
        raise _validation_error("reasons 必须是合法原因集合")
    reasons = list(dict.fromkeys(reasons)) or None

    if rating == "none":
        with db.SessionLocal() as session:
            removed = (
                session.query(ConversationFeedback)
                .filter(ConversationFeedback.message_id == message_id)
                .delete()
            )
            session.commit()
        return {"ok": True, "removed": removed}

    ai_message = None
    user_message = None
    with db.SessionLocal() as session:
        message = session.query(Message).filter(Message.id == message_id).first()
        if message is not None and message.role == "assistant":
            ai_message = message.content
            previous_user = (
                session.query(Message)
                .filter(
                    Message.conversation_id == conversation_id,
                    Message.role == "user",
                    Message.created_at
                    <= (message.created_at or datetime.now(timezone.utc)),
                )
                .order_by(Message.created_at.desc())
                .first()
            )
            if previous_user is not None:
                user_message = previous_user.content

    with db.SessionLocal() as session:
        row = (
            session.query(ConversationFeedback)
            .filter(ConversationFeedback.message_id == message_id)
            .first()
        )
        if row is None:
            row = ConversationFeedback(message_id=message_id)
            session.add(row)
        row.character_id = character_id
        row.conversation_id = conversation_id
        row.rating = rating
        row.reasons = reasons
        row.custom_feedback = custom_feedback
        row.preferred_reply = preferred_reply
        row.user_message = user_message
        row.ai_message = ai_message
        session.flush()
        feedback_id = row.id
        session.commit()
    return {"ok": True, "id": feedback_id}


@router.get("")
async def feedback_list(
    character_id: str = "",
    conversation_id: str = "",
    _: None = Depends(require_signature),
) -> dict:
    with db.SessionLocal() as session:
        query = session.query(ConversationFeedback)
        if character_id:
            query = query.filter(ConversationFeedback.character_id == character_id)
        if conversation_id:
            query = query.filter(
                ConversationFeedback.conversation_id == conversation_id
            )
        items = [
            {
                "message_id": row.message_id,
                "rating": row.rating,
                "conversation_id": row.conversation_id,
                "user_message": row.user_message,
                "ai_message": row.ai_message,
                "reasons": row.reasons or [],
                "custom_feedback": row.custom_feedback,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in query.order_by(ConversationFeedback.created_at.desc()).all()
        ]
    return {"items": items}


@router.get("/stats")
async def feedback_stats(
    character_id: str = "",
    days: int = 30,
    _: None = Depends(require_signature),
) -> dict:
    if not character_id:
        raise _validation_error("缺少 character_id")
    effective_days = max(0, min(int(days), 365))
    window = None
    if effective_days > 0:
        window = datetime.now(timezone.utc) - timedelta(days=effective_days)

    with db.SessionLocal() as session:
        query = session.query(ConversationFeedback).filter(
            ConversationFeedback.character_id == character_id
        )
        if window is not None:
            query = query.filter(ConversationFeedback.created_at >= window)
        rows = query.all()

    positive = sum(1 for row in rows if row.rating == "positive")
    negative = sum(1 for row in rows if row.rating == "negative")
    counts: dict[str, int] = {}
    with_custom = 0
    for row in rows:
        if row.rating != "negative":
            continue
        if row.custom_feedback:
            with_custom += 1
        for code in row.reasons or []:
            counts[code] = counts.get(code, 0) + 1

    reasons = {
        code: {
            "count": count,
            "confidence": round(_feedback_confidence(count), 2),
            "mention_rate": round(count / negative, 3) if negative else 0.0,
        }
        for code, count in sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    }
    return {
        "character_id": character_id,
        "window_days": effective_days,
        "total": len(rows),
        "positive": positive,
        "negative": negative,
        "reasons": reasons,
        "with_custom_feedback": with_custom,
    }


def _feedback_confidence(count: int) -> float:
    if count <= 0:
        return 0.0
    if count <= 5:
        return 0.1 + (count - 1) * 0.1
    if count <= 20:
        return 0.5 + (count - 5) * (0.4 / 15)
    return 0.9


def _validation_error(message: str) -> HTTPException:
    return HTTPException(
        status_code=422,
        detail={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": message,
                "retryable": False,
            }
        },
    )
