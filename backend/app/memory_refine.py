"""记忆 AI 提炼（012）：聚类 → LLM 合并 → superseded/archived 归档 → 审计/回滚。

借鉴 Mem0（追加式 + 版本化 + 去重合并）与 Letta/MemGPT（核心记忆小而精）：
- 只处理 active 记忆；近重复簇（语义余弦 >0.86 / 文本相似 >0.9）交给 LLM 判定
  merge/keep/drop；merged 必须涵盖全部原信息（prompt 强约束，防幻觉），
  LLM 失败即跳过该簇，绝不写坏。
- 应用：基底改写为 merged（重算 embedding）+ 其余 merge 项 superseded（并入基底）、
  drop 项 archived；全部写 memory_revision 留痕，可 rollback。
- 只提炼 type in (preference, fact)；event（一次性事实）不动。
- 手动入口：POST /ai/memory/refine；自动入口：start_scheduler() 每日跑。
"""
import json
import logging
import re
import threading
import time as _time
from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher

import httpx
from sqlalchemy import func

from . import config, db
from .ai_gateway import _embed_tolerant
from .models import Character, Memory, MemoryRefineLog, MemoryRevision, uuid7

logger = logging.getLogger("lifehub")

# 聚类阈值：真实语义向量（PG+BGE-M3）余弦 > 0.86；无向量降级文本相似 > 0.90（只并真重复）
SEMANTIC_SIM_THRESHOLD = 0.86
TEXT_SIM_THRESHOLD = 0.90
# 每角色少于该条数不提炼（没有合并价值，省 LLM 调用）
MIN_ACTIVE_MEMORIES = 8
# 可提炼类型（event 是一次性事实，不并）
REFINEABLE_TYPES = {"preference", "fact"}
MAX_CLUSTER_MEMORIES = 20  # 单簇最多喂 LLM 的条数（防超上下文）

# 记忆强化（013）：常驻 vs 过时
HIGH_IMPORTANCE_THRESHOLD = 0.8  # 常驻：永不 merge-away/archived（只作 merge 基底）
STALE_IMPORTANCE_MAX = 0.3  # 过时候选上限（importance 低于此值）
STALE_AGE_DAYS = 90  # 距最近访问（或创建）超过 N 天
STALE_MAX_PER_RUN = 5  # 每轮最多归档条数（有界，保守）
STALE_MIN_ACTIVE = 15  # active 少于该值不跑 stale pass（防掏空小库）

_REFINE_SYSTEM_PROMPT = (
    "你是记忆整理助手。把若干条关于同一话题的用户记忆合并为一条精炼记忆。"
    "铁律：merged 必须涵盖全部原记忆的实质信息，不得编造新事实、不得遗漏；"
    "若原记忆互相矛盾，以时间更新、更具体的为准。"
)


# --------------------------------------------------------------------------- #
# 相似度与聚类
# --------------------------------------------------------------------------- #
def _cosine(a: list[float] | None, b: list[float] | None) -> float:
    if not a or not b:
        return 0.0
    n = min(len(a), len(b))
    if n == 0:
        return 0.0
    dot = sum(x * y for x, y in zip(a[:n], b[:n]))
    na = sum(x * x for x in a[:n]) ** 0.5
    nb = sum(x * x for x in b[:n]) ** 0.5
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def _text_sim(a: str, b: str) -> float:
    return SequenceMatcher(None, a or "", b or "").ratio()


def _near_duplicate(m1: Memory, m2: Memory, semantic: bool) -> bool:
    """semantic=True 且双方都有向量 → 余弦判近重复；否则文本相似（保守只并真重复）。"""
    # 普通与无违禁记忆永不合并，保证用户关闭模式时能精确剔除后者。
    if (m1.source_mode or "standard") != (m2.source_mode or "standard"):
        return False
    if semantic and m1.embedding and m2.embedding:
        return _cosine(m1.embedding, m2.embedding) >= SEMANTIC_SIM_THRESHOLD
    return _text_sim(m1.content or "", m2.content or "") >= TEXT_SIM_THRESHOLD


def _cluster(memories: list[Memory], semantic: bool) -> list[list[Memory]]:
    """union-find 聚出近重复簇（仅 size≥2 返回）。"""
    parent = list(range(len(memories)))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for i in range(len(memories)):
        for j in range(i + 1, len(memories)):
            if _near_duplicate(memories[i], memories[j], semantic):
                ri, rj = find(i), find(j)
                if ri != rj:
                    parent[ri] = rj
    groups: dict[int, list[Memory]] = {}
    for i, m in enumerate(memories):
        groups.setdefault(find(i), []).append(m)
    return [g for g in groups.values() if len(g) >= 2]


# --------------------------------------------------------------------------- #
# LLM 合并
# --------------------------------------------------------------------------- #
def _build_prompt(cluster: list[Memory]) -> str:
    lines = []
    for i, m in enumerate(cluster):
        ts = m.created_at.isoformat() if m.created_at else "?"
        lines.append(
            f'[{i}] (type={m.type}, importance={(m.importance or 0.5):.1f}, created_at={ts}) content="{m.content}"'
        )
    return (
        "以下是若干条关于同一个话题的用户记忆（可能重复/相互包含/矛盾）：\n"
        + "\n".join(lines)
        + "\n\n请返回一条精炼的 merged 记忆（必须涵盖全部实质信息，不得编造/遗漏）。"
          "importance 取所有成员的 max。"
          "并给每条记忆判定动作，只允许三种："
          "merge=并入合并结果（其信息已被 merged 涵盖，可丢弃原条）；"
          "drop=完全冗余、与 merged 重复，无需保留；keep=需单独保留（有独立信息）。"
          "严格只返回 JSON（不要任何解释）："
          '{"merged":"...","decisions":[{"i":0,"action":"merge"},...]}'
    )


def _parse_decision(reply: str, n: int) -> dict | None:
    obj = None
    try:
        obj = json.loads(reply)
    except (ValueError, TypeError):
        m = re.search(r"\{.*\}", reply, re.S)
        if m:
            try:
                obj = json.loads(m.group(0))
            except (ValueError, TypeError):
                obj = None
    if not isinstance(obj, dict):
        return None
    merged = str(obj.get("merged") or "").strip()
    decisions = obj.get("decisions")
    if not isinstance(decisions, list) or not merged:
        return None
    actions = ["keep"] * n
    for d in decisions:
        if not isinstance(d, dict):
            continue
        i, action = d.get("i"), d.get("action")
        if isinstance(i, int) and 0 <= i < n and action in ("merge", "drop", "keep"):
            actions[i] = action
    return {"merged": merged, "actions": actions}


def _llm_refine(prompt: str) -> str:
    resp = httpx.post(
        "https://api.deepseek.com/chat/completions",
        headers={"Authorization": f"Bearer {config.DEEPSEEK_API_KEY}", "Content-Type": "application/json"},
        json={
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": _REFINE_SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.2,
            "stream": False,
        },
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"].get("content") or ""


def _apply_cluster(cluster: list[Memory], actions: list[str], merged_content: str) -> dict:
    # 常驻保护（013）：importance >= 0.8 的记忆永不 merge/drop（只作基底，保留独立）
    for i, m in enumerate(cluster):
        if (m.importance or 0.5) >= HIGH_IMPORTANCE_THRESHOLD:
            actions[i] = "keep"
    merge_idxs = [i for i, a in enumerate(actions) if a == "merge"]
    if not merge_idxs:
        return {"merged": 0, "archived": 0, "unchanged": len(cluster)}
    base_i = max(merge_idxs, key=lambda i: len(cluster[i].content or ""))
    base = cluster[base_i]
    old_base = base.content
    now = datetime.now(timezone.utc)
    merged_importance = max((m.importance or 0.5) for m in cluster)  # 合并结果取簇内 max
    merged = archived = unchanged = 0
    with db.SessionLocal() as s:
        for i, m in enumerate(cluster):
            action = actions[i] if i < len(actions) else "keep"
            if i == base_i:
                m.content = merged_content
                m.embedding = _embed_tolerant(merged_content)
                m.importance = merged_importance
                m.refined_at = now
                s.add(m)  # 簇内存量为旧 session 的 detached 实例，需重新挂载才会被跟踪
                s.add(MemoryRevision(
                    id=uuid7(), memory_id=m.id, action="merged",
                    old_content=old_base, new_content=merged_content,
                    reason="记忆提炼：近重复合并",
                ))
                merged += 1
            elif action == "merge":
                m.status = "superseded"
                m.superseded_by = base.id
                m.refined_at = now
                s.add(m)
                s.add(MemoryRevision(
                    id=uuid7(), memory_id=m.id, action="merged_into",
                    old_content=m.content, new_content=merged_content,
                    reason="记忆提炼：并入基底",
                ))
                merged += 1
            elif action == "drop":
                m.status = "archived"
                m.refined_at = now
                s.add(m)
                s.add(MemoryRevision(
                    id=uuid7(), memory_id=m.id, action="archived",
                    old_content=m.content, new_content=None,
                    reason="记忆提炼：与 merged 完全重复，归档",
                ))
                archived += 1
            else:
                unchanged += 1
        s.commit()
    return {"merged": merged, "archived": archived, "unchanged": unchanged}


# --------------------------------------------------------------------------- #
# 过时归档（013）：低价值 + 长期未访问的记忆保守归档（可 rollback）
# --------------------------------------------------------------------------- #
def _last_used(m: Memory) -> datetime | None:
    return m.last_accessed_at or m.created_at


def _archive_stale(mems: list[Memory], character_id: str) -> int:
    """过时记忆归档：importance < 0.3 且距最近访问（或创建）> 90 天。

    按 importance 升序取前 STALE_MAX_PER_RUN 条，写 archived revision 留痕（可 rollback）。
    保守：只当 refine_memories 判定 total >= STALE_MIN_ACTIVE 才被调用。
    """
    now = datetime.now(timezone.utc)
    candidates = [
        m for m in mems
        if (m.importance or 0.5) < STALE_IMPORTANCE_MAX
        and (ref := _last_used(m)) is not None
        and (now - ref) > timedelta(days=STALE_AGE_DAYS)
    ]
    candidates.sort(key=lambda m: m.importance or 0.5)
    candidates = candidates[:STALE_MAX_PER_RUN]
    if not candidates:
        return 0
    with db.SessionLocal() as s:
        for m in candidates:
            row = s.get(Memory, m.id)  # mems 是旧 session 的 detached 实例，重挂载
            if row is None or row.status != "active":
                continue
            row.status = "archived"
            row.refined_at = now
            s.add(MemoryRevision(
                id=uuid7(), memory_id=row.id, action="archived",
                old_content=row.content, new_content=None,
                reason="记忆提炼：低价值长期未访问，保守归档",
            ))
        s.commit()
    return len(candidates)


# --------------------------------------------------------------------------- #
# 提炼主流程 + 审计日志
# --------------------------------------------------------------------------- #
def _finish_log(
    log_id: str,
    total: int,
    merged: int = 0,
    archived: int = 0,
    unchanged: int = 0,
    error: str | None = None,
) -> None:
    with db.SessionLocal() as s:
        log = s.get(MemoryRefineLog, log_id)
        if log is None:
            return
        log.finished_at = datetime.now(timezone.utc)
        log.total = total
        log.merged = merged
        log.archived = archived
        log.unchanged = unchanged
        log.error = error
        s.commit()


def refine_memories(character_id: str) -> dict:
    """对某角色跑一轮提炼。返回 summary / skipped 原因。"""
    with db.SessionLocal() as s:
        mems = (
            s.query(Memory)
            .filter(Memory.character_id == character_id, Memory.status == "active")
            .all()
        )
        semantic = bool(db.IS_PG and config.EMBEDDING_ENDPOINT and config.EMBEDDING_API_KEY)
        refineable = [m for m in mems if m.type in REFINEABLE_TYPES]
        log = MemoryRefineLog(character_id=character_id, total=len(mems))
        s.add(log)
        s.commit()
        log_id = log.id

    total = len(mems)
    if total < MIN_ACTIVE_MEMORIES:
        _finish_log(log_id, total, error=f"skipped:too_few({total})")
        return {"skipped": "too_few", "total": total, "note": f"仅 {total} 条记忆，少于阈值，暂不提炼"}
    if len(refineable) < 2:
        _finish_log(log_id, total, error="skipped:no_refineable")
        return {"skipped": "no_refineable", "note": "可提炼类型（preference/fact）不足 2 条"}
    if not config.DEEPSEEK_API_KEY:
        _finish_log(log_id, total, error="no DEEPSEEK_API_KEY")
        return {"error": "服务端未配置 DEEPSEEK_API_KEY"}

    clusters = _cluster(refineable, semantic)
    if not clusters:
        _finish_log(log_id, total, error="skipped:no_clusters")
        return {"skipped": "no_clusters", "note": "没有发现近重复记忆，无需提炼"}

    merged = archived = unchanged = 0
    errors: list[str] = []
    for cluster in clusters:
        try:
            work = cluster[:MAX_CLUSTER_MEMORIES]
            reply = _llm_refine(_build_prompt(work))
            decision = _parse_decision(reply, len(work))
            if decision is None:
                unchanged += len(work)
                continue
            r = _apply_cluster(work, decision["actions"], decision["merged"])
            merged += r["merged"]
            archived += r["archived"]
            unchanged += r["unchanged"]
        except Exception as exc:  # LLM/解析失败 → 跳过该簇，绝不写坏
            errors.append(str(exc))
            logger.exception("memory refine cluster failed (character=%s)", character_id)

    # 过时归档（013）：active 足够多才跑，防掏空小库
    stale = 0
    if total >= STALE_MIN_ACTIVE:
        stale = _archive_stale(mems, character_id)
        if stale:
            archived += stale

    _finish_log(
        log_id, total, merged=merged, archived=archived, unchanged=unchanged,
        error="; ".join(errors) or None,
    )
    return {
        "total": total,
        "clusters": len(clusters),
        "merged": merged,
        "archived": archived,
        "unchanged": unchanged,
        "stale": stale,
        "errors": errors,
    }


# --------------------------------------------------------------------------- #
# 回滚 / 留痕 / 统计（供端点调用）
# --------------------------------------------------------------------------- #
def list_revisions(memory_id: str) -> list[dict]:
    with db.SessionLocal() as s:
        revs = (
            s.query(MemoryRevision)
            .filter_by(memory_id=memory_id)
            .order_by(MemoryRevision.created_at.desc())
            .all()
        )
        return [
            {
                "id": r.id,
                "action": r.action,
                "old_content": r.old_content,
                "new_content": r.new_content,
                "reason": r.reason,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in revs
        ]


def rollback_memory(memory_id: str) -> dict | None:
    """按最新 revision 还原一条记忆。无留痕或不可还原返回 None。"""
    with db.SessionLocal() as s:
        rev = (
            s.query(MemoryRevision)
            .filter_by(memory_id=memory_id)
            .order_by(MemoryRevision.created_at.desc())
            .first()
        )
        mem = s.get(Memory, memory_id)
        if rev is None or mem is None:
            return None
        now = datetime.now(timezone.utc)
        if rev.action in ("merged_into", "archived"):
            mem.status = "active"
            mem.superseded_by = None
            mem.refined_at = None
            s.add(MemoryRevision(
                id=uuid7(), memory_id=memory_id, action="restored",
                old_content=mem.content, new_content=mem.content,
                reason="回滚：恢复为 active（撤销并入/归档）",
            ))
        elif rev.action == "merged" and rev.old_content:
            mem.content = rev.old_content
            mem.embedding = _embed_tolerant(rev.old_content)
            s.add(MemoryRevision(
                id=uuid7(), memory_id=memory_id, action="restored",
                old_content=mem.content, new_content=rev.old_content,
                reason="回滚：还原为合并前内容",
            ))
        else:
            return None
        mem.refined_at = now
        s.commit()
        s.refresh(mem)
        return {"id": mem.id, "status": mem.status, "content": mem.content}


def _log_dict(log: MemoryRefineLog) -> dict:
    return {
        "id": log.id,
        "started_at": log.started_at.isoformat() if log.started_at else None,
        "finished_at": log.finished_at.isoformat() if log.finished_at else None,
        "total": log.total,
        "merged": log.merged,
        "archived": log.archived,
        "unchanged": log.unchanged,
        "error": log.error,
    }


def memory_stats(character_id: str) -> dict:
    with db.SessionLocal() as s:
        active = (
            s.query(func.count())
            .filter(Memory.character_id == character_id, Memory.status == "active")
            .scalar()
            or 0
        )
        superseded = (
            s.query(func.count())
            .filter(Memory.character_id == character_id, Memory.status == "superseded")
            .scalar()
            or 0
        )
        archived = (
            s.query(func.count())
            .filter(Memory.character_id == character_id, Memory.status == "archived")
            .scalar()
            or 0
        )
        by_type = {
            r[0]: r[1]
            for r in (
                s.query(Memory.type, func.count())
                .filter(Memory.character_id == character_id)
                .group_by(Memory.type)
                .all()
            )
        }
        last = (
            s.query(MemoryRefineLog)
            .filter_by(character_id=character_id)
            .order_by(MemoryRefineLog.started_at.desc())
            .first()
        )
    return {
        "active": active,
        "superseded": superseded,
        "archived": archived,
        "by_type": by_type,
        "last_refine": _log_dict(last) if last else None,
    }


# --------------------------------------------------------------------------- #
# 每日自动提炼（镜像 mi_fitness_sync.start_scheduler 模式）
# --------------------------------------------------------------------------- #
_scheduler_thread: threading.Thread | None = None


def _memory_enabled_characters() -> list[str]:
    with db.SessionLocal() as s:
        rows = s.query(Character.id).filter(Character.memory_enabled.is_(True)).all()
        return [r[0] for r in rows]


def _has_new_memories(character_id: str) -> bool:
    """距上次 refine 之后是否有新增 active 记忆（无则跳过，省 LLM 调用）。"""
    with db.SessionLocal() as s:
        last = (
            s.query(MemoryRefineLog.started_at)
            .filter_by(character_id=character_id)
            .order_by(MemoryRefineLog.started_at.desc())
            .first()
        )
        newest = (
            s.query(Memory.created_at)
            .filter(Memory.character_id == character_id, Memory.status == "active")
            .order_by(Memory.created_at.desc())
            .first()
        )
    if newest is None or newest[0] is None:
        return False
    if last is None or last[0] is None:
        return True
    return newest[0] > last[0]


def start_scheduler() -> None:
    if not config.DEEPSEEK_API_KEY:
        logger.info("Memory refine scheduler skipped (no DEEPSEEK_API_KEY)")
        return
    global _scheduler_thread
    if _scheduler_thread and _scheduler_thread.is_alive():
        return

    def _loop() -> None:
        while True:
            now = datetime.now(timezone.utc)
            target = now.replace(
                hour=config.MEMORY_REFINE_HOUR, minute=7, second=0, microsecond=0
            )
            if target <= now:
                target += timedelta(days=1)
            _time.sleep((target - now).total_seconds())
            try:
                for cid in _memory_enabled_characters():
                    if _has_new_memories(cid):
                        result = refine_memories(cid)
                        logger.info("Memory refine %s: %s", cid, result)
            except Exception:
                logger.exception("Memory refine scheduled run failed")

    _scheduler_thread = threading.Thread(target=_loop, daemon=True, name="memory-refine")
    _scheduler_thread.start()
    logger.info("Memory refine scheduler started")
