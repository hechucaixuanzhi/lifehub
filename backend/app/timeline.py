"""时间线聚合：跨模块统一按时间排序的记录流（GET /timeline）。

数据源：sync_event（手机同步日志，operation='create'）。payload 里带实体自身的
时间戳（本地墙上时间、无时区后缀，如 "2026-08-06T12:48:42.463364"）与实体 id。
同一实体被重复同步会有多行（幂等重推），按 payload.id 去重、保留最近一次同步。
life_event 的 payload 只有 {x:1} 无内容，不进时间线。

时间戳纪律：直接原样透出 payload 里的实体时间（前端 DateTime.parse 按本地时间解析），
不做 UTC 换算——与 AI 读库问答（用 sync created_at + 转北京时）区分开。
"""
from datetime import datetime, timedelta, timezone

from . import db
from .models import SyncEvent

# 每个实体类型在 payload 里表示"这件事发生时间"的字段
_TIME_KEY = {
    "study_session": "started_at",
    "exercise_session": "occurred_at",
    "pet_log": "occurred_at",
    "life_habit_event": "occurred_at",
    "pet": "created_at",
}

# 无内容实体类型（不进时间线）
_SKIP_TYPES = {"life_event"}


def _parse_ts(value) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value))
    except (ValueError, TypeError):
        return None


def _to_item(entity_type: str, payload: dict, at: datetime) -> dict:
    item: dict = {
        "type": entity_type,
        "at": at.isoformat(timespec="seconds"),  # 本地墙上时间，无时区
    }
    if entity_type == "study_session":
        item.update({
            "ref_id": payload.get("resource_id"),
            "duration_seconds": payload.get("duration_seconds"),
            "note": payload.get("note"),
        })
    elif entity_type == "exercise_session":
        item.update({
            "ref_id": payload.get("type_id"),
            "duration_seconds": payload.get("duration_seconds"),
            "distance_meters": payload.get("distance_meters"),
            "note": payload.get("note"),
        })
    elif entity_type == "pet_log":
        item.update({
            "kind": payload.get("kind"),
            "content": payload.get("content"),
            "media_asset_id": payload.get("media_asset_id"),
        })
    elif entity_type == "life_habit_event":
        item.update({
            "ref_id": payload.get("habit_id"),
            "value": payload.get("value"),
        })
    elif entity_type == "pet":
        item.update({"content": payload.get("name")})
    return item


_MERGE_GAP = timedelta(seconds=60)  # 同类型同 ref_id 且 60s 内连续 → 合并计数


def get_timeline(days: int = 14) -> list[dict]:
    """跨模块时间线：按实体发生时间降序，已按实体 id 去重。

    同类型同 ref_id（study/exercise/habit）在 60 秒内连续的多条会合并为一条并带
    count（如快速连点"喝水"8 次 → 一条「喝水 ×8」），避免时间线刷屏。
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=max(1, min(int(days), 90)))
    with db.SessionLocal() as s:
        rows = (
            s.query(SyncEvent)
            .filter(SyncEvent.operation == "create")
            .filter(SyncEvent.created_at >= cutoff)
            .order_by(SyncEvent.created_at.desc())
            .all()
        )

    # 去重：payload.id（无则 sync id）相同 → 保留最近一次同步的行
    best: dict[str, SyncEvent] = {}
    for r in rows:
        if r.entity_type in _SKIP_TYPES:
            continue
        pid = (r.payload or {}).get("id")
        key = pid or r.id
        prev = best.get(key)
        if prev is None or (r.created_at and prev.created_at and r.created_at > prev.created_at):
            best[key] = r

    raw: list[tuple[datetime, dict]] = []
    for r in best.values():
        at = _parse_ts((r.payload or {}).get(_TIME_KEY.get(r.entity_type, "")))
        if at is None:
            continue
        raw.append((at, _to_item(r.entity_type, r.payload or {}, at)))
    raw.sort(key=lambda t: t[0])  # 升序便于合并

    # 合并：同 (type, ref_id) 且相邻时间差 ≤ 60s → count 累加，保留最早一条的 at
    merged: list[dict] = []
    for at, item in raw:
        if (
            merged
            and item.get("ref_id")
            and merged[-1].get("type") == item.get("type")
            and merged[-1].get("ref_id") == item.get("ref_id")
            and (at - _parse_ts(merged[-1].get("at")) <= _MERGE_GAP)
        ):
            merged[-1]["count"] = int(merged[-1].get("count", 1)) + 1
            merged[-1]["at"] = at.isoformat(timespec="seconds")  # 取最后一条时间
        else:
            merged.append(item)
    merged.reverse()  # 恢复降序（最新在前）
    return merged
