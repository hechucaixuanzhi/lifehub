"""013 E2E：记忆强化 —— LLM 提取(importance) + 去重 + 排名/访问节流 + refine 常驻保护/过时归档。

运行（容器内做 DB 断言）：
  docker cp backend/tools/e2e_memory_importance.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/e2e_memory_importance.py

验证点（全部用 companion 角色，memory_enabled=True；测试记忆结尾清理）：
  A. /ai/chat 发「我喜欢喝柠檬水，每天一杯」→ /ai/memory/list 出现 importance∈[0,1] 的记忆；
     同句重发 → 不重复写（精确/近重复去重）
  B. /ai/memory/search 「柠檬水」→ 该记忆 last_accessed_at 被节流更新
  C. refine 常驻保护：importance=0.9 的记忆永不 superseded/archived；近重复簇被合并
  D. 过时归档：importance<0.3 且 120 天未访问 → refine 归档（可 rollback）；search 不返回非 active
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
DEVICE_ID = f"e2e-memimp-{int(time.time())}"
CHARACTER_ID = "companion"

try:
    from app import db as appdb
    from app.models import Memory, uuid7
    DB_OK = True
except Exception:  # 宿主机跑时无 app 包 → 跳过 DB 断言
    DB_OK = False

_priv = Ed25519PrivateKey.generate()
_test_ids: list[str] = []


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
    return httpx.request(method, f"{BASE}{path}", content=body, headers=_sig(method, path, body), timeout=timeout)


def check(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def list_memories(limit: int = 100) -> list[dict]:
    r = call("GET", f"/ai/memory/list?character_id={CHARACTER_ID}&limit={limit}", b"")
    assert r.status_code == 200, f"list {r.status_code}: {r.text[:200]}"
    return r.json()["memories"]


def search_memories(query: str) -> list[dict]:
    r = call("POST", "/ai/memory/search", json.dumps({"query": query, "character_id": CHARACTER_ID}).encode())
    assert r.status_code == 200, f"search {r.status_code}: {r.text[:200]}"
    return r.json()["results"]


# --------------------------------------------------------------------------- #
def chat_extraction() -> None:
    print("\n===== A. 聊天 LLM 提取 + 去重 =====")
    msg = "我喜欢喝柠檬水，每天一杯"
    conv = f"e2e-memimp-{int(time.time())}"
    for _ in range(2):
        body = json.dumps({"message": msg, "character_id": CHARACTER_ID, "conversation_id": conv}).encode()
        r = call("POST", "/ai/chat", body)
        check(r.status_code == 200, f"chat 200 ({r.text[:150]})")

    mems = list_memories()
    hits = [m for m in mems if m.get("content") and "柠檬水" in m["content"]]
    check(len(hits) >= 1, f"出现柠檬水记忆 {len(hits)} 条")
    imp = hits[0].get("importance")
    check(isinstance(imp, (int, float)) and 0 <= imp <= 1, f"importance∈[0,1] 实际={imp}")
    check(len(hits) == 1, f"同句重发不重复写（柠檬水记忆恰 1 条，实际 {len(hits)}）")
    _test_ids.extend(m["id"] for m in hits)


def search_touch() -> None:
    print("\n===== B. 检索节流更新 last_accessed_at =====")
    r = search_memories("柠檬水")
    check(len(r) >= 1, f"search 返回 {len(r)} 条")
    top_id = r[0]["id"]
    if DB_OK:
        with appdb.SessionLocal() as s:
            m = s.get(Memory, top_id)
            check(m is not None and m.last_accessed_at is not None, f"top 记忆 last_accessed_at 已填充 (id={top_id[:8]})")


def refine_protection() -> None:
    print("\n===== C. refine 常驻保护 + 近重复合并 =====")
    # 高 importance 常驻
    r = call("POST", "/ai/memory", json.dumps({
        "content": "用户是铁血猫咪派，雷打不动喜欢猫", "type": "preference",
        "character_id": CHARACTER_ID,
    }).encode())
    assert r.status_code == 200, f"create 高imp {r.status_code}: {r.text[:200]}"
    high_id = r.json()["memory"]["id"]
    _test_ids.append(high_id)
    if DB_OK:
        with appdb.SessionLocal() as s:
            m = s.get(Memory, high_id)
            m.importance = 0.9
            s.commit()

    # 近重复簇（易聚合并被 LLM 合并）
    variants = [
        "用户喜欢喝手冲耶加雪菲浅烘咖啡，不加糖",
        "用户喜欢喝手冲耶加雪菲浅烘咖啡不加糖",
        "用户爱喝手冲耶加雪菲浅烘咖啡，不加糖",
        "用户喜欢手冲耶加雪菲浅烘咖啡，不加糖",
    ]
    for v in variants:
        body = json.dumps({"content": v, "type": "preference", "character_id": CHARACTER_ID}).encode()
        r = call("POST", "/ai/memory", body)
        assert r.status_code == 200, f"create 簇 {r.status_code}: {r.text[:200]}"
        _test_ids.append(r.json()["memory"]["id"])

    # 过时候选（importance 0.2、120 天前）—— 走 DB 直插控 created_at
    now = datetime.now(timezone.utc)
    if DB_OK:
        with appdb.SessionLocal() as s:
            for i in range(12):
                m = Memory(
                    id=uuid7(), type="fact", character_id=CHARACTER_ID,
                    content=f"用户曾在 w3s1 测试中购买过物品{i}号", importance=0.2,
                    created_at=now - timedelta(days=120),
                )
                s.add(m)
                _test_ids.append(m.id)
            s.commit()

    r = call("POST", f"/ai/memory/refine?character_id={CHARACTER_ID}", b"{}")
    check(r.status_code == 200, f"refine 200 ({r.text[:200]})")
    summary = r.json().get("summary", {})
    print("     summary:", summary)
    check(summary.get("merged", 0) >= 1, f"近重复簇被合并 merged={summary.get('merged')}")

    mems = list_memories(limit=100)
    by_id = {m["id"]: m for m in mems}
    high = by_id.get(high_id)
    check(high is not None and high["status"] == "active", f"高 importance 记忆 refine 后仍 active（{high and high['status']}）")
    if DB_OK:
        with appdb.SessionLocal() as s:
            m = s.get(Memory, high_id)
            check(m.importance == 0.9, f"高 importance 值未被改写（{m.importance}）")

    archived = [m for m in mems if m["status"] == "archived"]
    check(len(archived) >= 1, f"出现过时归档（{len(archived)} 条）")

    # 回滚一条 archived 测试记忆 → 恢复 active
    target = next((m for m in archived if m["id"] in _test_ids), None)
    if target is not None:
        r = call("POST", f"/ai/memory/{target['id']}/rollback", b"{}")
        check(r.status_code == 200 and r.json().get("memory", {}).get("status") == "active",
              f"rollback 恢复 active（{r.text[:150]}）")

    # search 不返回非 active（对 DB 校验 status，dev/prod 分支都覆盖；不受上一步 rollback 影响）
    if DB_OK:
        results = search_memories("物品0号")
        with appdb.SessionLocal() as s:
            bad = [r["id"] for r in results if (m := s.get(Memory, r["id"])) is not None and m.status != "active"]
        check(not bad, f"search 不返回非 active 记忆（{bad}）")


def cleanup() -> None:
    print("\n===== 清理测试记忆 =====")
    for mid in _test_ids:
        call("DELETE", f"/ai/memory/{mid}", b"")
    print(f"[ok] 清理 {len(_test_ids)} 条测试记忆（任意状态）")


def main() -> None:
    body = json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e memory importance",
    }).encode()
    r = call("POST", "/auth/register", body)
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"

    try:
        chat_extraction()
        search_touch()
        refine_protection()
        print("\nALL PASS")
    finally:
        cleanup()


if __name__ == "__main__":
    main()
