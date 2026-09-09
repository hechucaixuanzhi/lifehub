"""Global cross-character reply guideline endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Request

from .. import ai_gateway, db
from ..models import AppSetting
from ..security import require_signature

router = APIRouter(prefix="/ai/reply-guideline", tags=["ai-settings"])


@router.get("")
async def reply_guideline_get(_: None = Depends(require_signature)) -> dict:
    return {"guideline": ai_gateway.get_reply_guideline()}


@router.put("")
async def reply_guideline_put(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    guideline = (body.get("guideline") or "").strip()
    if len(guideline) > 4000:
        raise HTTPException(
            status_code=422,
            detail={
                "error": {
                    "code": "VALIDATION_ERROR",
                    "message": "回复规范过长（最多 4000 字）",
                    "retryable": False,
                }
            },
        )
    with db.SessionLocal() as session:
        row = (
            session.query(AppSetting)
            .filter_by(key=ai_gateway.REPLY_GUIDELINE_KEY)
            .first()
        )
        if row is None:
            session.add(
                AppSetting(key=ai_gateway.REPLY_GUIDELINE_KEY, value=guideline)
            )
        else:
            row.value = guideline
        session.commit()
    return {"ok": True, "guideline": guideline}
