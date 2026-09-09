"""当前态快照（011）：定义类实体的镜像表应用器 + 默认种子 + AI 读辅助。

背景（任务 3 / docs/AI_DATA_ARCHITECTURE.md §2）：
- 手机端所有写操作以 sync_event 上送（变更日志），但后端只有日志、无当前态表，
  AI 无法回答「我现在有哪些学习资源/宠物/习惯」。
- entity_snapshot 以「当前定义」为唯一语义：payload 是每个实体的最新完整定义
  （snake_case，对齐 sync_event.payload / applyRemoteEvent 的解析字段），
  事件流（*_session/*_log/*_event）不进快照，留在 sync_event 供聚合。
- 维护：/sync/push 增量应用 + 启动全量重放（reconcile）兜底。

注意（种子镜像漂移）：
- _SEED_DEFAULTS 与 Flutter 端种子必须保持一致——
  app/lib/main.dart `_seedDefaultHabits` / `_seedStudyResources`
  app/lib/features/exercise/data/exercise_presets.dart
  改动任一侧需同步另一侧。
"""
from datetime import datetime, timezone

from sqlalchemy import func

from . import db
from .models import EntitySnapshot, SyncEvent

# 定义类实体：create/update → upsert payload；delete → 删行。事件流类型不进快照。
DEFINITION_TYPES = {
    "study_resource",
    "exercise_type",
    "pet",
    "inbox_item",
    "life_habit",
}

DEFAULT_SCOPE = "user"

# 种子守卫：仅当某默认 id 在 sync_event 中从未出现过（无 create/update/delete）才补，
# 这样用户删除过的默认资源不会被重启「复活」。习惯类永远无事件 → 始终补齐。

_SEED_HABITS: list[tuple[str, dict]] = [
    ("habit_water", dict(name="喝水", icon_name="water", color_argb=0xFF2196F3,
                         daily_target=8, unit="杯", type="counter", behavior="normal")),
    ("habit_sleep", dict(name="睡眠", icon_name="sleep", color_argb=0xFF9C27B0,
                         daily_target=480, unit="min", type="timer", behavior="overnight")),
    ("habit_sun", dict(name="晒太阳", icon_name="sun", color_argb=0xFFFBC02D,
                       daily_target=20, unit="min", type="timer", behavior="normal")),
    ("habit_med", dict(name="冥想", icon_name="meditate", color_argb=0xFF4CAF50,
                       daily_target=10, unit="min", type="timer", behavior="normal")),
    ("habit_meal", dict(name="三餐", icon_name="meal", color_argb=0xFFFF9800,
                        daily_target=3, unit="次", type="counter", behavior="normal")),
    ("habit_brush", dict(name="刷牙", icon_name="brush", color_argb=0xFF00BCD4,
                         daily_target=2, unit="次", type="counter", behavior="normal")),
    ("habit_eye", dict(name="护眼", icon_name="eye", color_argb=0xFF3F51B5,
                       daily_target=1, unit="次", type="counter", behavior="normal")),
    ("habit_fruit", dict(name="水果", icon_name="fruit", color_argb=0xFFE91E63,
                         daily_target=1, unit="份", type="counter", behavior="normal")),
    ("habit_coffee", dict(name="咖啡", icon_name="coffee", color_argb=0xFF795548,
                          daily_target=1, unit="杯", type="counter", behavior="normal")),
]

_SEED_STUDY_RESOURCES: list[tuple[str, dict]] = [
    ("sr_book", dict(name="阅读一本书", category="小说", icon_name="menu_book",
                     color_argb=0xFF16A085, goal_amount=30, goal_unit="页")),
    ("sr_course", dict(name="数学专业课", category="数学", icon_name="calculate",
                       color_argb=0xFFC0392B, goal_amount=40, goal_unit="章")),
    ("sr_paper", dict(name="读论文", category="论文", icon_name="article",
                      color_argb=0xFF2980B9, goal_amount=20, goal_unit="页")),
    ("sr_en", dict(name="英语", category="英语", icon_name="translate",
                   color_argb=0xFF27AE60, goal_amount=20, goal_unit="min")),
    ("sr_jp", dict(name="日语", category="日语", icon_name="language",
                   color_argb=0xFFE67E22, goal_amount=15, goal_unit="min")),
]

_SEED_EXERCISE_TYPES: list[tuple[str, dict]] = [
    ("ex_run", dict(name="跑步", icon_name="directions_run", metrics="time,distance",
                    count_unit="次", distance_unit="km", color_argb=0xFFE53935)),
    ("ex_walk", dict(name="散步", icon_name="walk", metrics="time,distance",
                     count_unit="次", distance_unit="km", color_argb=0xFF43A047)),
    ("ex_pushup", dict(name="俯卧撑", icon_name="fitness_center", metrics="count",
                       count_unit="个", distance_unit="m", color_argb=0xFFFB8C00)),
    ("ex_squat", dict(name="深蹲", icon_name="squat", metrics="count",
                      count_unit="个", distance_unit="m", color_argb=0xFF8E24AA)),
    ("ex_plank", dict(name="平板", icon_name="plank", metrics="time",
                      count_unit="次", distance_unit="m", color_argb=0xFF00ACC1)),
    ("ex_crunch", dict(name="卷腹", icon_name="crunches", metrics="count",
                       count_unit="个", distance_unit="m", color_argb=0xFF3949AB)),
]

_SEED_DEFAULTS: dict[str, list[tuple[str, dict]]] = {
    "life_habit": _SEED_HABITS,
    "study_resource": _SEED_STUDY_RESOURCES,
    "exercise_type": _SEED_EXERCISE_TYPES,
}


def _upsert(
    s,
    entity_type: str,
    entity_id: str,
    payload: dict,
    version: int | None = None,
    scope: str = DEFAULT_SCOPE,
) -> None:
    row = s.get(EntitySnapshot, (scope, entity_type, entity_id))
    if row is None:
        s.add(EntitySnapshot(
            scope=scope,
            entity_type=entity_type,
            entity_id=entity_id,
            payload=payload,
            version=version or 1,
        ))
    else:
        row.payload = payload
        if version is not None:
            row.version = version
        row.updated_at = func.now()


def apply_sync_event(s, ev: SyncEvent, scope: str = DEFAULT_SCOPE) -> bool:
    """把一条 sync_event 应用到快照。事件流类型直接忽略；返回是否应用。"""
    if ev.entity_type not in DEFINITION_TYPES:
        return False
    if ev.operation == "delete":
        row = s.get(EntitySnapshot, (scope, ev.entity_type, ev.entity_id))
        if row is not None:
            s.delete(row)
    else:  # create | update —— payload 是全量定义，直接覆盖
        payload = ev.payload or {}
        if not isinstance(payload, dict):
            payload = {"raw": payload}
        # WS2 自愈：老版本客户端上送收件箱缺 created_at → 用事件时间兜底，
        # 使日报/收件箱按日分桶立即可见（不改 sync_event 行，老事件也覆盖）。
        if not payload.get("created_at"):
            payload = dict(payload)
            payload["created_at"] = (
                ev.created_at.isoformat()
                if ev.created_at
                else datetime.now(timezone.utc).isoformat()
            )
        _upsert(s, ev.entity_type, ev.entity_id, payload, version=ev.version, scope=scope)
    return True


def reconcile_snapshots(
    s,
    entity_type: str | None = None,
    scope: str = DEFAULT_SCOPE,
) -> int:
    """全量重放 sync_event（仅定义类）重建当前态。幂等，处理重复推送。

    启动时跑一次兜底；事件按 id（uuidv7≈时间序）应用，后写的全量定义覆盖先写。
    """
    q = s.query(SyncEvent).filter(SyncEvent.entity_type.in_(DEFINITION_TYPES))
    if entity_type:
        q = q.filter(SyncEvent.entity_type == entity_type)
    rows = q.order_by(SyncEvent.id).all()
    applied = 0
    for ev in rows:
        if apply_sync_event(s, ev, scope=scope):
            applied += 1
    s.commit()
    return applied


def seed_default_snapshots(s, scope: str = DEFAULT_SCOPE) -> int:
    """补齐 Flutter 端默认种子（仅当该 id 在 sync_event 里从未出现）。

    用户增删的实体走事件流（reconcile 已覆盖）；这里只补「用户从未触碰的默认」。
    """
    now_iso = datetime.now(timezone.utc).isoformat()
    seeded = 0
    for entity_type, defaults in _SEED_DEFAULTS.items():
        for eid, base in defaults:
            touched = (
                s.query(SyncEvent.id)
                .filter_by(entity_type=entity_type, entity_id=eid)
                .first()
            )
            if touched:
                continue
            payload = {"id": eid, "created_at": now_iso, **base}
            _upsert(s, entity_type, eid, payload, version=1, scope=scope)
            seeded += 1
    s.commit()
    return seeded


def ensure_snapshot(scope: str = DEFAULT_SCOPE) -> dict:
    """启动时跑一次：reconcile（事件权威）+ seed（补默认）。幂等、可重复。"""
    with db.SessionLocal() as s:
        reconciled = reconcile_snapshots(s, scope=scope)
        seeded = seed_default_snapshots(s, scope=scope)
    return {"reconciled": reconciled, "seeded": seeded}


# --------------------------------------------------------------------------- #
# AI 读辅助（只读，供 ai_gateway 工具使用）
# --------------------------------------------------------------------------- #
def get_snapshot(s, entity_type: str, entity_id: str, scope: str = DEFAULT_SCOPE) -> dict | None:
    row = s.get(EntitySnapshot, (scope, entity_type, entity_id))
    return row.payload if row is not None else None


def list_snapshots(s, entity_type: str, scope: str = DEFAULT_SCOPE) -> list[dict]:
    rows = (
        s.query(EntitySnapshot)
        .filter_by(scope=scope, entity_type=entity_type)
        .order_by(EntitySnapshot.entity_id)
        .all()
    )
    return [r.payload for r in rows]


def name_of(s, entity_type: str, entity_id: str, key: str = "name") -> str | None:
    """给事件流里的裸 id 解析名字（resource_id/type_id/pet_id/habit_id → name）。"""
    payload = get_snapshot(s, entity_type, entity_id)
    if payload and isinstance(payload.get(key), str):
        return payload[key]
    return None
