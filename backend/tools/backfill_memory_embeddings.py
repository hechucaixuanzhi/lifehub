"""WS3 数据维护：回填 / 重算 memory 的 embedding。

默认：只补 embedding IS NULL 的记忆（生产 PG 下为 pgvector NULL）。
--force：对全部 active 行重算（覆盖历史上 _dev_embed 写入的确定性假向量——
  接真实 embedding provider 前必须先跑一次，否则 vector 分支会拿假向量打分）。
维度契约：与 memory.embedding vector(1024) 一致，ai_gateway.embed 返回长度不匹配会抛错，
  此处对失败行降级存 None（内容仍保留，检索跳过该行）。

运行（容器内）：
  docker cp backend/tools/backfill_memory_embeddings.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/backfill_memory_embeddings.py            # dry-run，仅报告
  docker exec lifehub-backend python tools/backfill_memory_embeddings.py --apply    # 只补 NULL
  docker exec lifehub-backend python tools/backfill_memory_embeddings.py --force --apply   # 全量重算
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import ai_gateway, db  # noqa: E402
from app.models import Memory  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description="回填/重算 memory embedding")
    ap.add_argument("--apply", action="store_true", help="落库（默认 dry-run 只报告）")
    ap.add_argument(
        "--force",
        action="store_true",
        help="重算全部 active 行（覆盖历史假向量）；不传则只补 embedding IS NULL",
    )
    args = ap.parse_args()

    with db.SessionLocal() as s:
        q = s.query(Memory).filter(Memory.status == "active")
        if not args.force:
            q = q.filter(Memory.embedding.is_(None))
        rows = q.all()
        scope = "全部 active（force 覆盖）" if args.force else "仅 embedding IS NULL"
        print(f"待处理：{len(rows)} 条（{scope}）")
        if not rows:
            return
        ok = fail = 0
        for m in rows:
            vec = ai_gateway._embed_tolerant(m.content or "")
            if vec is None:
                fail += 1
                print(f"  [skip] {m.id[:8]} type={m.type} embed 失败（内容仍保留，不阻塞）")
                continue
            ok += 1
            if args.apply:
                m.embedding = vec
            if ok <= 5:
                print(f"  [{'apply' if args.apply else 'dry'}] {m.id[:8]} type={m.type} -> {len(vec)} 维")
        if ok > 5:
            print(f"  ... 共 {ok} 条可处理（仅展示前 5）")
        if args.apply:
            s.commit()
            print(f"[done] 已处理 {ok} 条；失败 {fail} 条")
        else:
            print(f"[dry] 将处理 {ok} 条；失败 {fail} 条（--apply 生效）")


if __name__ == "__main__":
    main()
