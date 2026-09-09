"""011+012 E2E：当前态快照（/sync/push → entity_snapshot）+ 记忆 AI 提炼闭环。

运行（在容器内跑可做 DB 断言；宿主机跑只验证 HTTP 行为）：
  docker cp backend/tools/e2e_snapshot_memory.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/e2e_snapshot_memory.py
LIFEHUB_BASE 默认 http://127.0.0.1:8000（容器内即本服务）。

快照链路：
  1. push create study_resource e2e_sr_python → accepted 1 → DB 断言 snapshot 出现
  2. 同 client_event_id 重推 → accepted 0（幂等）
  3. push update（新 payload）→ accepted 1 → version=2、payload 更新
  4. push delete → accepted 1 → snapshot 行消失
  5. push 事件流类型（study_session）→ accepted 1 → 无 snapshot 行（定义类才镜像）

记忆提炼链路（companion，测试后清理，不污染真实记忆）：
  6. 插入 10 条近重复 preference（美式咖啡）→ 全 active
  7. POST /ai/memory/refine → summary.merged >= 1（LLM 合并近重复）
  8. list → 出现 superseded/archived；stats 计数一致
  9. 取一条 superseded → GET revisions 非空 → POST rollback → 恢复 active
  10. memory_search → 返回 id 全部 ∈ active 集合（superseded/archived 不注入）
  11. 清理：删除全部测试记忆（无论状态）
"""
import base64
import hashlib
import json
import os
import sys
import time

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = f"e2e-snapmem-{int(time.time())}"  # 每次唯一，避免 409 DEVICE_EXISTS
CHARACTER_ID = "companion"

# 容器内跑时把包根(/app)插进 sys.path（PYTHONPATH 会被 MSYS 改写，不可靠）
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    from app.db import engine
    from sqlalchemy import text
    DB_OK = True
except Exception:  # 宿主机跑时无 app 包 → 跳过 DB 断言
    DB_OK = False

_priv = Ed25519PrivateKey.generate()
_test_memory_ids: list[str] = []


def _sig(method: str, path: str, body: bytes) -> dict:
    # 签名路径不含查询串（split('?').first）
    ts = str(int(time.time() * 1000))
    msg = f"{method}|{path.split('?')[0]}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    return {
        "X-Device-Id": DEVICE_ID,
        "X-Timestamp": ts,
        "X-Signature": base64.b64encode(_priv.sign(msg)).decode(),
        "Content-Type": "application/json",
    }


def call(method: str, path: str, body: bytes = b"", signed: bool = True) -> httpx.Response:
    headers = _sig(method, path, body) if signed else {"Content-Type": "application/json"}
    return httpx.request(method, f"{BASE}{path}", content=body, headers=headers)


def check(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def db_rows(sql: str, **params) -> list:
    with engine.connect() as c:
        return c.execute(text(sql), params).fetchall()


# --------------------------------------------------------------------------- #
def snapshot_chain() -> None:
    print("\n===== 快照链路 =====")
    base = {
        "id": "e2e_sr_python", "name": "Python 入门", "category": "编程",
        "icon_name": "code", "color_argb": 12345678,
        "goal_amount": 30, "goal_unit": "页",
    }
    payload1 = {**base, "created_at": "2026-08-07T10:00:00+00:00"}
    payload2 = {**base, "goal_amount": 60, "created_at": "2026-08-07T10:00:00+00:00"}

    # 1. create → accepted 1 → snapshot 出现（version 用相对断言：不假设从 1 开始）
    body = json.dumps({"events": [{
        "id": "e2e-se1", "entity_type": "study_resource", "entity_id": "e2e_sr_python",
        "operation": "create", "payload": payload1,
    }]}).encode()
    r = call("POST", "/sync/push", body)
    check(r.status_code == 200 and r.json().get("accepted") == 1, f"push create accepted=1 ({r.text[:120]})")
    if DB_OK:
        rows = db_rows(
            "SELECT version, payload->>'name' FROM entity_snapshot "
            "WHERE entity_type='study_resource' AND entity_id='e2e_sr_python'")
        check(len(rows) == 1 and rows[0][1] == "Python 入门",
              f"snapshot 出现 name=Python 入门 {rows}")
        v_create = rows[0][0]

    # 2. 同 client_event_id 重推 → 幂等 accepted 0
    r = call("POST", "/sync/push", body)
    check(r.status_code == 200 and r.json().get("accepted") == 0, "重复 push 同 id 幂等 accepted=0")
    if DB_OK:
        rows = db_rows(
            "SELECT version FROM entity_snapshot WHERE entity_type='study_resource' AND entity_id='e2e_sr_python'")
        check(rows[0][0] == v_create, "重复 push 不 bump version")

    # 3. update → accepted 1 → version 增大、payload 覆盖
    body2 = json.dumps({"events": [{
        "id": "e2e-se2", "entity_type": "study_resource", "entity_id": "e2e_sr_python",
        "operation": "update", "payload": payload2,
    }]}).encode()
    r = call("POST", "/sync/push", body2)
    check(r.status_code == 200 and r.json().get("accepted") == 1, "push update accepted=1")
    if DB_OK:
        rows = db_rows(
            "SELECT version, payload->>'goal_amount' FROM entity_snapshot "
            "WHERE entity_type='study_resource' AND entity_id='e2e_sr_python'")
        check(rows[0][0] > v_create and rows[0][1] == "60", f"snapshot 覆盖 goal=60 version 增大 {rows}")

    # 4. delete → accepted 1 → 行消失
    body3 = json.dumps({"events": [{
        "id": "e2e-se3", "entity_type": "study_resource", "entity_id": "e2e_sr_python",
        "operation": "delete", "payload": None,
    }]}).encode()
    r = call("POST", "/sync/push", body3)
    check(r.status_code == 200 and r.json().get("accepted") == 1, "push delete accepted=1")
    if DB_OK:
        rows = db_rows(
            "SELECT count(*) FROM entity_snapshot WHERE entity_type='study_resource' AND entity_id='e2e_sr_python'")
        check(rows[0][0] == 0, "delete 后 snapshot 行消失")

    # 5. 事件流类型（study_session）→ 不镜像（进程内测 apply_sync_event 分支，事务回滚零污染）
    #    不走 HTTP：真机拉取会把伪造的事件流数据当真实记录应用。
    if DB_OK:
        from app import snapshot as snap_mod
        from app import db as appdb
        from app.models import SyncEvent, uuid7
        with appdb.SessionLocal() as s:
            ev = SyncEvent(
                id=uuid7(), device_id=DEVICE_ID, entity_type="study_session",
                entity_id="e2e-ss-1", operation="create",
                payload={"resource_id": "e2e_sr_python", "amount": 10}, version=1,
            )
            applied = snap_mod.apply_sync_event(s, ev)
            s.rollback()
        check(applied is False, "事件流类型 apply_sync_event 返回 False（不镜像）")
    else:
        print("  [skip] 事件流类型分支（非容器运行，无 DB 断言）")


# --------------------------------------------------------------------------- #
def memory_chain() -> None:
    print("\n===== 记忆 AI 提炼闭环 =====")
    # 6. 插入 10 条近重复 preference（文本相似 >0.90，触发聚簇；dev 无 BGE 走文本回退）
    variants = [
        "用户喜欢喝美式咖啡，不加糖",
        "用户喜欢喝美式咖啡，不加糖。",
        "用户喜欢喝美式咖啡不加糖",
        "用户喜欢美式咖啡，不加糖",
        "用户喜欢喝美式咖啡（不加糖）",
        "用户喜欢喝美式咖啡，不加糖，纯黑",
        "用户喜欢喝美式咖啡，纯黑不加糖",
        "用户爱喝美式咖啡，不加糖",
        "用户喜欢美式咖啡，不要加糖",
        "用户喜欢喝美式咖啡，不加糖和奶",
    ]
    for i, v in enumerate(variants):
        body = json.dumps({"content": v, "type": "preference", "character_id": CHARACTER_ID}).encode()
        r = call("POST", "/ai/memory", body)
        assert r.status_code == 200, f"create mem[{i}] {r.status_code}: {r.text}"
        _test_memory_ids.append(r.json()["memory"]["id"])
    check(len(_test_memory_ids) == 10, "插入 10 条测试记忆")

    # 7. refine → merged >= 1（LLM 合并近重复）
    r = call("POST", f"/ai/memory/refine?character_id={CHARACTER_ID}", b"{}")
    check(r.status_code == 200, f"refine 200 ({r.text[:200]})")
    summary = r.json().get("summary", {})
    print("     summary:", summary)
    if summary.get("skipped"):
        check(False, f"refine 被跳过：{summary.get('note')}")
    check(summary.get("merged", 0) >= 1, f"refine merged={summary.get('merged')} >= 1")

    # 8. list → 出现 superseded/archived；stats 一致
    r = call("GET", f"/ai/memory/list?character_id={CHARACTER_ID}&limit=100", b"")
    mems = r.json()["memories"]
    by_id = {m["id"]: m for m in mems}
    inactive = [m for m in mems if m["status"] != "active"]
    check(len(inactive) >= 1, f"出现非 active 记忆 {len(inactive)} 条")
    r = call("GET", f"/ai/memory/stats?character_id={CHARACTER_ID}", b"")
    stats = r.json()
    check(stats["superseded"] + stats["archived"] >= 1,
          f"stats superseded={stats['superseded']} archived={stats['archived']}")
    print("     stats:", stats)

    # 9. 回滚一条 superseded → 恢复 active
    target = next((m for m in inactive if m["status"] == "superseded"), None)
    if target is None:
        target = inactive[0]
    r = call("GET", f"/ai/memory/{target['id']}/revisions", b"")
    revs = r.json()["revisions"]
    check(len(revs) >= 1, f"revisions 留痕 {len(revs)} 条")
    r = call("POST", f"/ai/memory/{target['id']}/rollback", b"{}")
    check(r.status_code == 200, f"rollback 200 ({r.text[:120]})")
    rb = r.json()
    check(rb.get("memory", {}).get("status") == "active", f"rollback 后 status=active {rb}")
    # 再查 revisions 顶部应新增 restored
    r = call("GET", f"/ai/memory/{target['id']}/revisions", b"")
    check(r.json()["revisions"][0]["action"] == "restored", "revisions 顶部出现 restored")

    # 10. memory_search → 返回 id 全 ∈ active 集合（superseded/archived 不注入）
    #     在回滚之后重新拉列表（回滚把一条 superseded 还原为 active），避免用过期状态
    r = call("GET", f"/ai/memory/list?character_id={CHARACTER_ID}&limit=100", b"")
    active_ids = {m["id"] for m in r.json()["memories"] if m["status"] == "active"}
    r = call("POST", "/ai/memory/search", json.dumps({
        "query": "美式咖啡", "limit": 20, "character_id": CHARACTER_ID,
    }).encode())
    results = r.json()["results"]
    check(len(results) >= 1, f"search 返回 {len(results)} 条")
    leaked = [x["id"] for x in results if x["id"] not in active_ids]
    check(not leaked, f"search 不返回非 active 记忆 {leaked}")

    # 11. 清理：删除全部测试记忆（无论状态）
    for mid in _test_memory_ids:
        call("DELETE", f"/ai/memory/{mid}", b"")
    check(True, f"清理 {len(_test_memory_ids)} 条测试记忆")


def main() -> None:
    # 0. 注册设备公钥
    body = json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e snapshot/mem",
    }).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"
    print("[ok] register device")

    snapshot_chain()
    memory_chain()
    print("\nALL PASS")


if __name__ == "__main__":
    main()
