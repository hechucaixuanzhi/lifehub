"""将明确获权的本地样本导入指定角色，并生成本地试听文件。

只在用户明确确认声音授权后使用。不会创建聊天消息或角色记忆。
"""
import argparse
import os
import shutil
import sys
import uuid
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import config, db, tts_minimax  # noqa: E402
from app.models import MediaAsset  # noqa: E402


def _store_file(source: Path, *, owner_type: str, mime_type: str) -> str:
    media_id = str(uuid.uuid4())
    storage_path = str(uuid.uuid4())
    target = Path(config.UPLOAD_DIR) / storage_path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    with db.SessionLocal() as session:
        session.add(
            MediaAsset(
                id=media_id,
                owner_type=owner_type,
                storage_path=storage_path,
                file_name=source.name,
                mime_type=mime_type,
                size=target.stat().st_size,
                status="ready",
                device_id="authorized-desktop-import",
            )
        )
        session.commit()
    return media_id


def _store_preview(audio: bytes, character_id: str) -> tuple[str, Path, float]:
    media_id = str(uuid.uuid4())
    storage_path = str(uuid.uuid4())
    target = Path(config.UPLOAD_DIR) / storage_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(audio)
    duration = tts_minimax._wav_duration(audio)
    with db.SessionLocal() as session:
        session.add(
            MediaAsset(
                id=media_id,
                owner_type="voice_preview",
                owner_id=character_id,
                storage_path=storage_path,
                file_name=f"{character_id}_voice_preview.wav",
                mime_type="audio/wav",
                size=len(audio),
                status="ready",
                device_id="authorized-desktop-import",
            )
        )
        session.commit()
    return media_id, target, duration


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sample")
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--preview-text", required=True)
    parser.add_argument("--authorized", action="store_true")
    args = parser.parse_args()
    if not args.authorized:
        raise SystemExit("必须显式传入 --authorized 确认声音授权")

    sample = Path(args.sample)
    if not sample.is_file():
        raise SystemExit(f"样本不存在: {sample}")
    if sample.stat().st_size > 20 * 1024 * 1024:
        raise SystemExit("样本超过 20MB")
    mime = {
        ".mp3": "audio/mpeg",
        ".m4a": "audio/mp4",
        ".wav": "audio/wav",
    }.get(sample.suffix.lower())
    if mime is None:
        raise SystemExit("仅支持 mp3/m4a/wav")

    sample_media_id = _store_file(
        sample, owner_type="voice_sample", mime_type=mime
    )
    file_id = tts_minimax.upload_file(sample_media_id)
    voice_id = tts_minimax.voice_clone(
        file_id,
        args.preview_text,
        character_id=args.character_id,
        sample_media_id=sample_media_id,
    )
    audio = tts_minimax.synthesize(
        args.preview_text, character_id=args.character_id
    )
    preview_media_id, preview_path, duration = _store_preview(
        audio, args.character_id
    )
    print(f"VOICE_ID={voice_id}")
    print(f"SAMPLE_MEDIA_ID={sample_media_id}")
    print(f"PREVIEW_MEDIA_ID={preview_media_id}")
    print(f"PREVIEW_PATH={preview_path}")
    print(f"PREVIEW_SECONDS={duration:.2f}")


if __name__ == "__main__":
    main()
