"""WS2 E2E：AI 读库深化 —— 5 个新只读工具 + inbox created_at 自愈。

运行（容器内做 DB 断言与清理）：
  docker cp backend/tools/e2e_ai_readlib2.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/e2e_ai_readlib2.py

验证点（全部用测试数据，结尾清理）：
  A. push 一套假事件（测试习惯/课程/运动/宠物 + 收件箱缺 created_at）→
     inbox 快照 created_at 已被事件时间兜底回填，sync_event 行不被改写
  B. 直调 _get_habit_streaks → 测试习惯当前连胜=3；_get_pet_insights → 体重趋势 2 点
  C. _get_study_trend/_get_exercise_trend/_get_weekly_summary/_get_daily_summary
     → 学习 90min / 运动 3 次 / 当天收件箱含测试笔记
  D. /ai/chat「我这周习惯学习和运动怎么样？」→ 答复含测试名字（工具真触发）
  E. 清理测试事件与快照，恢复原状
"""
import base64
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = f"e2e-readlib2-{int(time.time())}"
CHARACTER_ID = "assistant"

try:
    from app import db as appdb
    from app import snapshot
    from app.ai_gateway import (
        _get_daily_summary,
        _get_exercise_trend,
        _get_habit_streaks,
        _get_pet_insights,
        _get_study_trend,
        _get_weekly_summary,
    )
    from app.models import EntitySnapshot, SyncEvent
    DB_OK = True
except Exception as exc:  # 宿主机跑时无 app 包 → 跳过 DB 断言/清理
    DB_OK = False
    print(f"[warn] 无 app 包（{exc}），DB 断言与清理跳过，仅跑接口层")

_priv = Ed25519PrivateKey.generate()
_touched_ids: list[tuple[str, str]] = []  # (entity_type, entity_id)，清理用

# 测试数据锚点（北京时间自然日）
_bj = datetime.now(timezone.utc) + timedelta(hours=8)
TODAY = _bj.date()
DAY_MINUS = [TODAY - timedelta(days=n) for n in range(0, 5)]  # [今天, 昨天, ...]


def _iso(d, h=12, m=0):
    return datetime(d.year, d.month, d.day, h, m).isoformat()


def _sig(method: str, path: str, body: bytes) -> dict:
    ts = str(int(time.time() * 1000))
    msg = f"{method}|{path.split('?')[0]}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    return {
        "X-Device-Id": DEVICE_ID,
        "X-Timestamp": ts,
        "X-Signature": base64.b64encode(_priv.sign(msg)).decode(),
        "Content-Type": "application/json",
    }


def call(method: str, path: str, body: bytes = b"", timeout: float = 120) -> httpx.Response:
    return httpx.request(method, f"{BASE}{path}", content=body, headers=_sig(method, path, body),
                         timeout=timeout)


def check(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def push(events: list[dict]) -> None:
    body = json.dumps({"events": events}).encode()
    r = call("POST", "/sync/push", body)
    assert r.status_code == 200, f"push {r.status_code}: {r.text[:300]}"
    check(r.json().get("accepted") == len(events), f"push accepted={r.json().get('accepted')}/{len(events)}")


def ev(entity_type: str, entity_id: str, op: str, payload: dict) -> dict:
    eid = f"e2e-ws2-{entity_type}-{entity_id}"
    _touched_ids.append((entity_type, eid))
    return {"id": f"ce-{int(time.time()*1000)}-{entity_id}", "entity_type": entity_type,
            "entity_id": eid, "operation": op, "payload": payload}


# --------------------------------------------------------------------------- #
def seed_fake_data() -> None:
    print("\n===== A. push 测试事件 =====")
    events = [
        # 宠物定义 + 记录（今天 1 次体重 4.2 + 1 条文字；昨天 1 次体重 4.3）
        ev("pet", "cat", "create", {"id": "e2e-ws2-pet-cat", "name": "测试喵",
                                    "species": "猫", "created_at": _iso(DAY_MINUS[3])}),
        ev("pet_log", "cat-w-d2", "create", {"pet_id": "e2e-ws2-pet-cat", "kind": "weight",
                                             "value": 4.3, "occurred_at": _iso(DAY_MINUS[1], 8)}),
        ev("pet_log", "cat-w-d0", "create", {"pet_id": "e2e-ws2-pet-cat", "kind": "weight",
                                             "value": 4.2, "occurred_at": _iso(DAY_MINUS[0], 9)}),
        ev("pet_log", "cat-t-d0", "create", {"pet_id": "e2e-ws2-pet-cat", "kind": "text",
                                             "content": "今天超乖", "occurred_at": _iso(DAY_MINUS[0], 20)}),
        # 测试习惯（counter 目标 1）+ 连续 3 天达标事件 → 当前连胜 3
        ev("life_habit", "streak", "create", {"id": "e2e-ws2-life_habit-streak", "name": "测试习惯",
                                              "daily_target": 1, "unit": "次", "type": "counter",
                                              "behavior": "normal", "created_at": _iso(DAY_MINUS[4])}),
        ev("life_habit_event", "streak-d2", "create", {"habit_id": "e2e-ws2-life_habit-streak",
                                                       "occurred_at": _iso(DAY_MINUS[2], 10), "value": 1}),
        ev("life_habit_event", "streak-d1", "create", {"habit_id": "e2e-ws2-life_habit-streak",
                                                       "occurred_at": _iso(DAY_MINUS[1], 10), "value": 1}),
        ev("life_habit_event", "streak-d0", "create", {"habit_id": "e2e-ws2-life_habit-streak",
                                                       "occurred_at": _iso(DAY_MINUS[0], 10), "value": 1}),
        # 学习资源 + 会话（今天 30+15min，昨天 45min → 合计 90min）
        ev("study_resource", "course", "create", {"id": "e2e-ws2-study_resource-course",
                                                  "name": "测试课程", "category": "测试",
                                                  "goal_amount": 10, "goal_unit": "页",
                                                  "created_at": _iso(DAY_MINUS[4])}),
        ev("study_session", "s-d0-1", "create", {"resource_id": "e2e-ws2-study_resource-course",
                                                 "started_at": _iso(DAY_MINUS[0], 8), "duration_seconds": 1800}),
        ev("study_session", "s-d0-2", "create", {"resource_id": "e2e-ws2-study_resource-course",
                                                 "started_at": _iso(DAY_MINUS[0], 14), "duration_seconds": 900}),
        ev("study_session", "s-d1-1", "create", {"resource_id": "e2e-ws2-study_resource-course",
                                                 "started_at": _iso(DAY_MINUS[1], 19), "duration_seconds": 2700}),
        # 运动类型 + 记录（今天 1 次 10min/2km，昨天 2 次 → 合计 3 次）
        ev("exercise_type", "run", "create", {"id": "e2e-ws2-exercise_type-run", "name": "测试运动",
                                              "metrics": "time,distance", "count_unit": "次",
                                              "distance_unit": "km", "created_at": _iso(DAY_MINUS[4])}),
        ev("exercise_session", "x-d0-1", "create", {"type_id": "e2e-ws2-exercise_type-run",
                                                    "occurred_at": _iso(DAY_MINUS[0], 18),
                                                    "duration_seconds": 600, "distance_meters": 2000}),
        ev("exercise_session", "x-d1-1", "create", {"type_id": "e2e-ws2-exercise_type-run",
                                                    "occurred_at": _iso(DAY_MINUS[1], 18),
                                                    "duration_seconds": 1200, "distance_meters": 4000}),
        ev("exercise_session", "x-d1-2", "create", {"type_id": "e2e-ws2-exercise_type-run",
                                                    "occurred_at": _iso(DAY_MINUS[1], 20),
                                                    "duration_seconds": 900, "distance_meters": 2500}),
        # 收件箱：inbox1 故意缺 created_at（验证后端自愈）；inbox2 带 created_at
        ev("inbox_item", "milk", "create", {"id": "e2e-ws2-inbox_item-milk",
                                            "content": "测试笔记：记得买牛奶", "kind": "note"}),
        ev("inbox_item", "water", "create", {"id": "e2e-ws2-inbox_item-water",
                                             "content": "测试待办：浇花", "kind": "todo",
                                             "created_at": _iso(DAY_MINUS[0], 9)}),
    ]
    push(events)


def db_assert_inbox_backfill() -> None:
    print("\n===== A2. inbox created_at 自愈 =====")
    with appdb.SessionLocal() as s:
        snap = snapshot.get_snapshot(s, "inbox_item", "e2e-ws2-inbox_item-milk")
        check(snap is not None, "收件箱快照已落库")
        check(snap.get("created_at"), f"缺 created_at 的 inbox 已被事件时间兜底回填（{snap.get('created_at')}）")
        # sync_event 行本身不被改写（仍缺 created_at，老数据保持原样）
        row = (s.query(SyncEvent)
               .filter_by(device_id=DEVICE_ID, entity_type="inbox_item", entity_id="e2e-ws2-inbox_item-milk")
               .first())
        check(row is not None and not row.payload.get("created_at"), "sync_event 行未被改写（保持缺字段）")


def db_assert_streak_and_pet() -> None:
    print("\n===== B. 连胜 + 宠物洞察 =====")
    r = _get_habit_streaks({"days": 30})
    h = next((x for x in r["habits"] if x["name"] == "测试习惯"), None)
    check(h is not None and h["current_streak"] == 3, f"测试习惯当前连胜=3（实际={h and h['current_streak']}）")
    check(h["longest_streak"] == 3, f"窗口内最长连胜=3（实际={h and h['longest_streak']}）")
    p = _get_pet_insights({"days": 30})
    cat = next((x for x in p["pets"] if x["name"] == "测试喵"), None)
    check(cat is not None and len(cat["weight_trend"]) == 2, f"体重趋势 2 点（实际={cat and cat['weight_trend']}）")
    check(cat["weight_trend"][-1]["kg"] == 4.2 and cat["weight_trend"][-1]["date"] == str(TODAY),
          f"最新体重=4.2@今天（实际={cat and cat['weight_trend'][-1]}）")
    check(cat["stale"] is False, "有今天记录 → stale=False")


def db_assert_trends_and_summary() -> None:
    print("\n===== C. 趋势 + 周报 + 日报 =====")
    st = _get_study_trend({"days": 30})
    res = next((x for x in st["by_resource"] if x["name"] == "测试课程"), None)
    check(res is not None and res["minutes"] == 90.0, f"学习合计 90min（实际={res}）")
    day0 = next((x for x in st["days"] if x["date"] == str(TODAY)), None)
    check(day0 is not None and day0["minutes"] == 45.0, f"今天学习 45min（实际={day0}）")

    et = _get_exercise_trend({"days": 30})
    ty = next((x for x in et["by_type"] if x["name"] == "测试运动"), None)
    check(ty is not None and ty["sessions"] == 3, f"运动合计 3 次（实际={ty}）")

    w = _get_weekly_summary({"days": 7})
    wd = next((x for x in w["days"] if x["date"] == str(TODAY)), None)
    check(wd is not None and wd["study_minutes"] == 45.0 and wd["exercise_sessions"] == 1
          and wd["pet_records"] == 2 and wd["inbox"] == 2,
          f"今天周报：学习45/运动1/宠物2/收件箱2（实际={wd}）")

    d = _get_daily_summary({"date": str(TODAY)})
    inbox_notes = [x for x in d["inbox"] if "测试" in str(x.get("content", ""))]
    check(len(inbox_notes) >= 1 and d["study"]["total_minutes"] == 45.0,
          f"日报含收件箱测试笔记 + 学习45min（inbox={d['inbox']}）")


def chat_trigger() -> None:
    print("\n===== D. /ai/chat 触发新工具 =====")
    body = json.dumps({
        "message": "帮我总结下我这周的习惯、学习和运动情况怎么样？",
        "character_id": CHARACTER_ID,
        "conversation_id": f"e2e-readlib2-{int(time.time())}",
    }).encode()
    r = call("POST", "/ai/chat", body, timeout=120)
    assert r.status_code == 200, f"chat {r.status_code}: {r.text[:300]}"
    data = r.json()
    reply = str(data.get("reply") or data.get("message") or data.get("content") or data)
    print("\n=== LLM 答复 ===\n", reply[:600])
    hits = [n for n in ["测试课程", "测试运动", "测试习惯", "测试喵"] if n in reply]
    check(len(hits) >= 1, f"答复含测试数据名字（hits={hits}，证明工具真触发）")


def cleanup() -> None:
    print("\n===== E. 清理测试数据 =====")
    if not DB_OK:
        print("[warn] 无 app 包，无法清理（数据留在 DB，请容器内重跑清理）")
        return
    with appdb.SessionLocal() as s:
        n_ev = n_snap = 0
        for et, eid in _touched_ids:
            n_ev += s.query(SyncEvent).filter_by(device_id=DEVICE_ID, entity_type=et, entity_id=eid).delete()
            snap = s.get(EntitySnapshot, ("user", et, eid))
            if snap is not None:
                s.delete(snap)
                n_snap += 1
        s.commit()
    print(f"[ok] 清理 sync_event {n_ev} 条 / 快照 {n_snap} 条")


def main() -> None:
    body = json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e readlib2",
    }).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"

    try:
        seed_fake_data()
        if DB_OK:
            db_assert_inbox_backfill()
            db_assert_streak_and_pet()
            db_assert_trends_and_summary()
        chat_trigger()
        print("\nALL PASS")
    finally:
        cleanup()


if __name__ == "__main__":
    main()
