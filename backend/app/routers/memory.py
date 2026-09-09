"""Character-scoped memory CRUD, search, cleanup, and refinement routes."""

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import or_

from .. import ai_gateway, db, memory_refine
from ..models import (
    Character,
    Conversation,
    Memory,
    MemoryRefineLog,
    Message,
)
from ..security import require_signature

router = APIRouter(tags=["memory"])


def _error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={
            "error": {
                "code": code,
                "message": message,
                "retryable": False,
            }
        },
    )


def _memory_dict(memory: Memory) -> dict:
    return {
        "id": memory.id,
        "type": memory.type,
        "content": memory.content,
        "character_id": memory.character_id,
        "source_mode": memory.source_mode,
        "created_at": (
            memory.created_at.isoformat() if memory.created_at else None
        ),
    }


@router.post("/ai/memory/search")
async def memory_search(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    limit = int(body.get("limit", 5))
    character_id = body.get("character_id")
    results = ai_gateway.memory_search(
        body.get("query", ""), limit, character_id=character_id
    )
    return {"results": results}


@router.get("/ai/memory/list")
async def memory_list(
    character_id: str = "",
    limit: int = 50,
    _: None = Depends(require_signature),
) -> dict:
    with db.SessionLocal() as session:
        query = session.query(Memory)
        if character_id:
            query = query.filter(Memory.character_id == character_id)
        rows = query.order_by(Memory.created_at.desc()).limit(limit).all()
    return {
        "memories": [
            {
                **_memory_dict(memory),
                "status": memory.status,
                "superseded_by": memory.superseded_by,
                "refined_at": (
                    memory.refined_at.isoformat() if memory.refined_at else None
                ),
                "importance": memory.importance,
                "last_accessed_at": (
                    memory.last_accessed_at.isoformat()
                    if memory.last_accessed_at
                    else None
                ),
            }
            for memory in rows
        ]
    }


@router.post("/ai/memory")
async def memory_create(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    content = (body.get("content") or "").strip()
    memory_type = body.get("type") or "fact"
    character_id = body.get("character_id") or "assistant"
    if not content:
        raise _error(422, "VALIDATION_ERROR", "记忆内容不能为空")
    if ai_gateway.get_character(character_id) is None:
        raise _error(422, "VALIDATION_ERROR", "未知角色")
    memory_id = ai_gateway.memory_add(
        content,
        type=memory_type,
        embedding=ai_gateway._embed_tolerant(content),
        character_id=character_id,
    )
    with db.SessionLocal() as session:
        memory = session.get(Memory, memory_id)
    return {"memory": _memory_dict(memory)}


@router.patch("/ai/memory/{memory_id}")
async def memory_patch(
    memory_id: str,
    request: Request,
    _: None = Depends(require_signature),
) -> dict:
    body = await request.json()
    content = (
        (body.get("content") or "").strip()
        if body.get("content") is not None
        else None
    )
    if content is not None and not content:
        raise _error(422, "VALIDATION_ERROR", "记忆内容不能为空")
    memory = ai_gateway.memory_update(
        memory_id, content=content, type=body.get("type")
    )
    if memory is None:
        raise _error(404, "MEMORY_NOT_FOUND", "记忆不存在")
    return {"memory": _memory_dict(memory)}


@router.delete("/ai/characters/{character_id}/memories/noban")
async def character_noban_memories_delete(
    character_id: str, _: None = Depends(require_signature)
) -> dict:
    with db.SessionLocal() as session:
        if session.get(Character, character_id) is None:
            raise _error(404, "CHARACTER_NOT_FOUND", "角色不存在")
        deleted = (
            session.query(Memory)
            .filter(
                Memory.character_id == character_id,
                Memory.source_mode == "noban",
            )
            .delete(synchronize_session=False)
        )
        conversation_ids = [
            row[0]
            for row in session.query(Conversation.id)
            .filter(
                or_(
                    Conversation.character_id == character_id,
                    Conversation.persona == character_id,
                )
            )
            .all()
        ]
        deleted_messages = 0
        if conversation_ids:
            deleted_messages = (
                session.query(Message)
                .filter(
                    Message.conversation_id.in_(conversation_ids),
                    Message.source_mode == "noban",
                )
                .delete(synchronize_session=False)
            )
        session.commit()
    return {
        "ok": True,
        "deleted": deleted,
        "deleted_messages": deleted_messages,
        "source_mode": "noban",
    }


@router.delete("/ai/memory/{memory_id}")
async def memory_delete(
    memory_id: str, _: None = Depends(require_signature)
) -> dict:
    if not ai_gateway.memory_delete(memory_id):
        raise _error(404, "MEMORY_NOT_FOUND", "记忆不存在")
    return {"ok": True, "id": memory_id}


@router.post("/ai/memory/clear")
async def memory_clear(
    request: Request, _: None = Depends(require_signature)
) -> dict:
    body = await request.json()
    character_ids = [
        character_id
        for character_id in (body.get("character_ids") or [])
        if isinstance(character_id, str) and character_id
    ]
    if not character_ids:
        raise _error(422, "VALIDATION_ERROR", "缺少 character_ids")
    with db.SessionLocal() as session:
        deleted = (
            session.query(Memory)
            .filter(Memory.character_id.in_(character_ids))
            .delete(synchronize_session=False)
        )
        refine_logs = (
            session.query(MemoryRefineLog)
            .filter(MemoryRefineLog.character_id.in_(character_ids))
            .delete(synchronize_session=False)
        )
        session.commit()
    return {"ok": True, "deleted": deleted, "refine_logs": refine_logs}


@router.post("/ai/memory/refine")
async def memory_refine_endpoint(
    character_id: str = "assistant",
    _: None = Depends(require_signature),
) -> dict:
    if ai_gateway.get_character(character_id) is None:
        raise _error(422, "VALIDATION_ERROR", "未知角色")
    return {"summary": memory_refine.refine_memories(character_id)}


@router.get("/ai/memory/stats")
async def memory_stats_endpoint(
    character_id: str = "assistant",
    _: None = Depends(require_signature),
) -> dict:
    return memory_refine.memory_stats(character_id)


@router.get("/ai/memory/{memory_id}/revisions")
async def memory_revisions_endpoint(
    memory_id: str, _: None = Depends(require_signature)
) -> dict:
    return {
        "memory_id": memory_id,
        "revisions": memory_refine.list_revisions(memory_id),
    }


@router.post("/ai/memory/{memory_id}/rollback")
async def memory_rollback_endpoint(
    memory_id: str, _: None = Depends(require_signature)
) -> dict:
    memory = memory_refine.rollback_memory(memory_id)
    if memory is None:
        raise _error(
            404,
            "MEMORY_NOT_FOUND",
            "记忆不存在或无可回滚记录",
        )
    return {"memory": memory}
