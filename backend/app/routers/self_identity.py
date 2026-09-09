"""Self-face identity gallery and calibration endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Request

from .. import self_identity
from ..security import require_signature

router = APIRouter(prefix="/ai/self-identity", tags=["self-identity"])


@router.post("/import")
async def self_identity_import(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    character_id = body.get("character_id") or "companion"
    entries = body.get("entries") or []
    if not isinstance(entries, list) or not entries:
        raise _validation_error("entries 不能为空")
    imported = 0
    for entry in entries:
        embedding = entry.get("embedding")
        if not isinstance(embedding, list) or len(embedding) != self_identity.EMBED_DIM:
            raise _validation_error(
                f"embedding 必须 {self_identity.EMBED_DIM} 维"
            )
        self_identity.add_gallery_entry(
            character_id,
            embedding,
            sub_identity=entry.get("sub_identity"),
            source_asset_id=entry.get("media_asset_id"),
        )
        imported += 1
    return {
        "imported": imported,
        "gallery_size": len(self_identity.list_gallery(character_id)),
    }


@router.post("/check")
async def self_identity_check(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    character_id = body.get("character_id") or "companion"
    result = self_identity.check_faces(body.get("faces") or [], character_id)
    result["appearance_summary"] = (
        (body.get("appearance_summary") or "").strip() or None
    )
    return result


@router.post("/calibrate")
async def self_identity_calibrate(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    character_id = body.get("character_id") or "companion"
    margin = float(body.get("margin") or 0.08)
    gallery = self_identity.gallery_vectors(character_id)
    if not gallery:
        raise _validation_error("身份库为空：先导入参考图再校准")
    positive_embeddings = body.get("pos_embeddings") or []
    negative_embeddings = body.get("neg_embeddings") or []
    if not isinstance(negative_embeddings, list) or not negative_embeddings:
        raise _validation_error("neg_embeddings 不能为空")

    def max_similarity(vector: list) -> float:
        return max(
            self_identity.cosine_similarity(vector, gallery_vector)
            for gallery_vector in gallery
        )

    if positive_embeddings:
        positive_similarities = [
            max_similarity(embedding) for embedding in positive_embeddings
        ]
    else:
        positive_similarities = []
        for index, gallery_vector in enumerate(gallery):
            others = [
                other
                for other_index, other in enumerate(gallery)
                if other_index != index
            ]
            positive_similarities.append(
                max(
                    (
                        self_identity.cosine_similarity(gallery_vector, other)
                        for other in others
                    ),
                    default=0.0,
                )
            )
    negative_similarities = [
        max_similarity(embedding) for embedding in negative_embeddings
    ]
    result = self_identity.calibrate(
        positive_similarities,
        negative_similarities,
        margin=margin,
    )
    result["status"] = "calibrated"
    result["gallery_size"] = len(gallery)
    return result


@router.get("/gallery")
async def self_identity_gallery(
    character_id: str = "companion", _: None = Depends(require_signature)
) -> dict:
    rows = self_identity.list_gallery(character_id)
    return {"gallery": rows, "gallery_size": len(rows)}


@router.delete("/gallery")
async def self_identity_gallery_clear(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    character_id = body.get("character_id") or "companion"
    return {"deleted": self_identity.clear_gallery(character_id)}


@router.get("/status")
async def self_identity_status(_: None = Depends(require_signature)) -> dict:
    return {
        "gallery_size": len(self_identity.list_gallery("companion")),
        "calibrated": self_identity.is_calibrated(),
        "thresholds": self_identity.get_thresholds(),
    }


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
