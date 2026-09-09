"""WS3 一致性审计：entity_snapshot vs sync_event 重放对账（只读，绝不改动）。

对每个定义类实体类型（study_resource/exercise_type/pet/inbox_item/life_habit）：
- 按 id（uuidv7≈时间序）重放 sync_event，得「事件权威状态」（entity_id → (payload, version)）
- 与 entity_snapshot 当前行比对，报告三类漂移：
  1. 快照行无法由事件解释（种子 id 白名单豁免）
  2. 事件权威状态未镜像到快照
  3. version 漂移（快照版本 ≠ 最近事件版本）
- 结尾汇总对账一致（0 漂移）即通过。

运行（容器内）：
  docker cp backend/tools/audit_sync_drift.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/audit_sync_drift.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import db, snapshot  # noqa: E402
from app.models import EntitySnapshot, SyncEvent  # noqa: E402


def _replay_state(s, entity_type: str) -> dict[str, tuple[dict, int]]:
    """重放 sync_event（order by id）→ entity_id → (payload, version)。"""
    rows = (
        s.query(SyncEvent)
        .filter(SyncEvent.entity_type == entity_type)
        .order_by(SyncEvent.id)
        .all()
    )
    state: dict[str, tuple[dict, int]] = {}
    for ev in rows:
        if ev.operation == "delete":
            state.pop(ev.entity_id, None)
        else:
            state[ev.entity_id] = ((ev.payload or {}), ev.version)
    return state


def main() -> None:
    seed_ids = {
        entity_type: {eid for eid, _ in defaults}
        for entity_type, defaults in snapshot._SEED_DEFAULTS.items()
    }
    total_unexplained = total_unmirrored = total_version = 0
    with db.SessionLocal() as s:
        for entity_type in sorted(snapshot.DEFINITION_TYPES):
            replay = _replay_state(s, entity_type)
            snap_rows = (
                s.query(EntitySnapshot)
                .filter_by(scope="user", entity_type=entity_type)
                .all()
            )
            snap = {r.entity_id: (r.payload or {}, r.version) for r in snap_rows}

            explained = set(replay) | seed_ids.get(entity_type, set())
            unexplained = [eid for eid in snap if eid not in explained]
            unmirrored = [eid for eid in replay if eid not in snap]
            version = [
                (eid, snap[eid][1], replay[eid][1])
                for eid in replay
                if eid in snap and snap[eid][1] != replay[eid][1]
            ]
            total_unexplained += len(unexplained)
            total_unmirrored += len(unmirrored)
            total_version += len(version)

            print(f"[{entity_type}] 快照 {len(snap)} / 事件权威 {len(replay)} / 种子 {len(seed_ids.get(entity_type, set()))}")
            for eid in unexplained[:10]:
                kind = "种子" if eid in seed_ids.get(entity_type, set()) else "?"
                print(f"    ! 快照无法由事件解释：{eid}（{kind}）")
            for eid in unmirrored[:10]:
                print(f"    ! 定义未镜像：{eid}（有事件但无快照行）")
            for eid, sv, rv in version[:10]:
                print(f"    ! version 漂移：{eid} 快照={sv} 事件={rv}")

    print(f"\n对账汇总：无法解释 {total_unexplained} / 未镜像 {total_unmirrored} / version 漂移 {total_version}")
    if total_unexplained == 0 and total_unmirrored == 0 and total_version == 0:
        print("[ok] 快照与 sync_event 重放一致")
    else:
        print("[fail] 存在漂移，需人工核对（本脚本只读，不做修复）")


if __name__ == "__main__":
    main()
