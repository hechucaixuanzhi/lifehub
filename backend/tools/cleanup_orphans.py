"""WS3 数据维护：清理孤儿记录（默认 dry-run，--apply 才删）。

- 孤儿 memory_revision：memory_id 指向的记忆已删除（如 e2e 清理遗留的 18 条）
- 孤儿 media_asset：ready 且无任何引用（message.media_asset_id / character 头像背景 /
  pet_log payload.media_asset_id），或 pending 超过 N 天未完成（废弃上传）
- 删文件仅限 UPLOAD_DIR 内相对路径（防误删容器其他文件）
- 附带报告：message 引用了不存在的 media_asset（信息性，不删）

运行（容器内）：
  docker cp backend/tools/cleanup_orphans.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/cleanup_orphans.py [--apply] [--pending-days 7]
"""
import argparse
import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import config, db  # noqa: E402
from app.models import Character, MediaAsset, Memory, MemoryRevision, Message, SyncEvent  # noqa: E402


def _referenced_media_ids(s) -> set[str]:
    """服务端 media_asset.id 的所有合法引用来源。"""
    refs: set[str] = set()
    for (mid,) in s.query(Message.media_asset_id).filter(Message.media_asset_id.is_not(None)):
        refs.add(mid)
    for (aid,) in s.query(Character.avatar_media_id).filter(Character.avatar_media_id.is_not(None)):
        refs.add(aid)
    for (bid,) in s.query(Character.background_media_id).filter(Character.background_media_id.is_not(None)):
        refs.add(bid)
    # pet_log 的 media_asset_id 在真机上是手机本地路径（/data/...），不会命中服务端 id；
    # 但未来版本可能存服务端 id，这里仍扫描，命中即保留（字段存在且非空）。
    for (payload,) in s.query(SyncEvent.payload).filter(
        SyncEvent.entity_type == "pet_log", SyncEvent.payload.is_not(None)
    ):
        v = payload.get("media_asset_id") if isinstance(payload, dict) else None
        if v:
            refs.add(str(v))
    return refs


def _delete_file_safe(storage_path: str | None, upload_dir: str) -> bool:
    """只在 upload_dir 内删相对路径；返回是否删掉（找不到文件也算安全）。"""
    if not storage_path:
        return True  # 无文件可删（或已不存在）
    if os.path.isabs(storage_path):
        return False  # 绝对路径：不碰
    parts = storage_path.replace("\\", "/").split("/")
    if ".." in parts:
        return False  # 路径穿越：不碰
    real_dir = os.path.realpath(upload_dir)
    target = os.path.realpath(os.path.join(upload_dir, storage_path))
    if not (target == real_dir or target.startswith(real_dir + os.sep)):
        return False
    try:
        if os.path.exists(target):
            os.remove(target)
        return True
    except OSError:
        return False


def main() -> None:
    ap = argparse.ArgumentParser(description="清理孤儿记录（默认 dry-run）")
    ap.add_argument("--apply", action="store_true", help="真正删除（默认只报告）")
    ap.add_argument("--pending-days", type=int, default=7, help="pending 超过 N 天视为废弃，默认 7")
    args = ap.parse_args()

    app_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    upload_dir = os.path.join(app_root, config.UPLOAD_DIR) if not os.path.isabs(config.UPLOAD_DIR) else config.UPLOAD_DIR
    mode = "apply" if args.apply else "dry"

    with db.SessionLocal() as s:
        # --- 1. 孤儿 memory_revision -------------------------------------------------
        orphan_revs = (
            s.query(MemoryRevision)
            .filter(
                ~s.query(Memory.id)
                .filter(Memory.id == MemoryRevision.memory_id)
                .exists()
            )
            .all()
        )
        print(f"孤儿 memory_revision：{len(orphan_revs)} 条（memory 已删）")
        for r in orphan_revs[:10]:
            print(f"  [{mode}] revision {r.id[:8]} memory={r.memory_id[:8]} action={r.action}")

        # --- 2. 孤儿 media_asset -----------------------------------------------------
        refs = _referenced_media_ids(s)
        now = datetime.now(timezone.utc)
        pending_cutoff = now - timedelta(days=args.pending_days)
        media = s.query(MediaAsset).order_by(MediaAsset.created_at).all()
        delete_ready: list[MediaAsset] = []
        delete_pending: list[MediaAsset] = []
        for m in media:
            if m.id in refs:
                continue  # 被引用，保留
            if m.status == "ready" and m.owner_type == "chat" and m.owner_id is None:
                delete_ready.append(m)  # 上传完成但从无消息引用
            elif m.status == "pending" and m.owner_id is None and (m.created_at or now) <= pending_cutoff:
                delete_pending.append(m)  # 长期未完成上传
        print(f"\nmedia_asset：ready 孤儿 {len(delete_ready)} 条 / pending 废弃 {len(delete_pending)} 条"
              f"（引用总数 {len(refs)}）")
        for m in delete_ready + delete_pending:
            reason = "ready 但无引用" if m in delete_ready else f"pending 超 {args.pending_days} 天"
            print(f"  [{mode}] {m.id[:8]} {m.status} {m.owner_type} {reason}")

        # --- 3. 信息性：message 引用不存在的 media_asset -------------------------------
        existing = {m.id for m in media}
        dangling = [mid for mid in refs if mid not in existing and not mid.startswith("/")]
        if dangling:
            print(f"\n[info] message 引用了不存在的 media_asset：{len(dangling)} 个（仅报告，不删）")
            for d in dangling[:10]:
                print(f"  [info] {d[:8]}")

        # --- 执行 ------------------------------------------------------------------
        if not args.apply:
            print(f"\n[dry] 未做任何删除；--apply 生效。孤儿 revision {len(orphan_revs)} / media {len(delete_ready) + len(delete_pending)}")
            return

        deleted_files = 0
        for r in orphan_revs:
            s.delete(r)
        for m in delete_ready + delete_pending:
            if _delete_file_safe(m.storage_path, upload_dir):
                deleted_files += 1
            s.delete(m)
        s.commit()
        print(f"\n[done] 已删孤儿 revision {len(orphan_revs)} 条；media {len(delete_ready) + len(delete_pending)} 条"
              f"（删文件 {deleted_files}）")


if __name__ == "__main__":
    main()
