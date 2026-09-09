"""014 E2E：AI 语音消息 —— 默认女声 TTS（克隆已放缓）+ 历史/会话预览 + 文字回归。

运行（容器内）：
  docker cp backend/tools/e2e_voice_tts.py lifehub-backend:/app/tools/
  docker exec lifehub-backend python tools/e2e_voice_tts.py

验证点：
  A. /ai/tts/status → configured/ready=true、default_voice=female-shaonv
  B. 语音聊天：user kind='audio'（先上传样本 wav）→ 回复带 audio_media_id+audio_duration；
     GET /media/{audio}/content 返回 RIFF wav
  C. /ai/history：user+assistant 消息均 kind='audio' 且带 audio_duration
  D. /ai/conversations 预览 = [语音]
  E. 纯文本聊天回归：200 且不返回 audio 字段（语音↔语音门控，不阻塞文字聊天）
测试聊天记录用独立 conversation_id，保留不清理（便于真机核对）。
"""
import base64
import hashlib
import io
import json
import os
import sys
import time
import wave

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.getenv("LIFEHUB_BASE", "http://127.0.0.1:8000")
DEVICE_ID = f"e2e-vtts-{int(time.time())}"
CHARACTER_ID = "assistant"

_priv = Ed25519PrivateKey.generate()


def _sig(method, path, body):
    ts = str(int(time.time() * 1000))
    msg = f"{method}|{path.split('?')[0]}|{hashlib.sha256(body).hexdigest()}|{ts}".encode()
    return {
        "X-Device-Id": DEVICE_ID,
        "X-Timestamp": ts,
        "X-Signature": base64.b64encode(_priv.sign(msg)).decode(),
        "Content-Type": "application/json",
    }


def call(method, path, body=b"", timeout=180):
    return httpx.request(method, f"{BASE}{path}", content=body, headers=_sig(method, path, body), timeout=timeout)


def check(cond, msg):
    if not cond:
        raise AssertionError(f"[FAIL] {msg}")
    print(f"[ok] {msg}")


def make_silent_wav(seconds=1.0, sample_rate=16000):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(b"\x00\x00" * int(sample_rate * seconds))
    return buf.getvalue()


def upload_wav(wav_bytes) -> str:
    r = call("POST", "/media", json.dumps({
        "file_name": "voice_sample.wav", "mime_type": "audio/wav",
        "size": len(wav_bytes), "owner_type": "chat",
    }).encode())
    assert r.status_code == 200, f"media create {r.status_code}: {r.text[:200]}"
    media_id = r.json()["media_id"]
    r = call("PUT", f"/media/{media_id}/content", wav_bytes)
    assert r.status_code == 200, f"media put {r.status_code}: {r.text[:200]}"
    return media_id


def main():
    r = call("POST", "/auth/register", json.dumps({
        "device_id": DEVICE_ID,
        "pubkey": base64.b64encode(_priv.public_key().public_bytes_raw()).decode(),
        "name": "e2e voice tts",
    }).encode())
    assert r.status_code == 200, f"register {r.status_code}: {r.text}"

    print("\n===== A. TTS status =====")
    r = call("GET", "/ai/tts/status", b"")
    assert r.status_code == 200, f"status {r.status_code}: {r.text[:200]}"
    st = r.json()
    print("    ", st)
    check(st.get("configured") is True, "configured=true（.env key 生效）")
    check(st.get("ready") is True, "ready=true（默认女声即可合成）")
    check(st.get("default_voice") == "female-shaonv", f"default_voice=female-shaonv（实际 {st.get('default_voice')}）")

    print("\n===== B. 语音聊天 → AI 语音回复 =====")
    user_wav = make_silent_wav()
    user_media = upload_wav(user_wav)
    conv = f"e2e-vtts-{int(time.time())}"
    body = json.dumps({
        "message": "你好呀，简单介绍一下你自己",
        "character_id": CHARACTER_ID,
        "conversation_id": conv,
        "kind": "audio",
        "media_asset_id": user_media,
        "audio_duration": 1,
    }).encode()
    t0 = time.time()
    r = call("POST", "/ai/chat", body)
    dt = time.time() - t0
    assert r.status_code == 200, f"voice chat {r.status_code}: {r.text[:300]}"
    resp = r.json()
    print(f"    chat 耗时 {dt:.1f}s reply={resp.get('reply', '')[:40]!r}")
    check(bool(resp.get("reply")), "AI 文字回复存在")
    check(resp.get("audio_media_id"), f"回复带 audio_media_id（{resp.get('audio_media_id')}）")
    check(resp.get("audio_duration") is not None, f"回复带 audio_duration（{resp.get('audio_duration')}s）")
    actual_conv = resp["conversation_id"]

    aid = resp["audio_media_id"]
    r = call("GET", f"/media/{aid}/content", b"")
    assert r.status_code == 200, f"audio download {r.status_code}: {r.text[:200]}"
    wav = r.content
    check(wav[:4] == b"RIFF", f"AI 语音是 RIFF wav（前 4 字节 {wav[:4]!r}，共 {len(wav)}B）")

    print("\n===== C. /ai/history =====")
    r = call("GET", f"/ai/history?conversation_id={actual_conv}", b"")
    assert r.status_code == 200, f"history {r.status_code}: {r.text[:200]}"
    msgs = r.json()["messages"]
    kinds = [(m["role"], m["kind"], m.get("audio_duration")) for m in msgs]
    print("    ", kinds)
    check(kinds[0][1] == "audio" and kinds[0][0] == "user", "首条 user kind=audio")
    check(kinds[-1][1] == "audio" and kinds[-1][0] == "assistant", "末条 assistant kind=audio")
    check(all(m[2] is not None for m in kinds), "两条消息均带 audio_duration")

    print("\n===== D. /ai/conversations 预览 =====")
    r = call("GET", "/ai/conversations", b"")
    assert r.status_code == 200, f"conversations {r.status_code}: {r.text[:200]}"
    hit = next((i for i in r.json()["items"] if i["character_id"] == CHARACTER_ID), None)
    check(hit is not None and hit["last_kind"] == "audio" and hit["last_content"] == "[语音]",
          f"assistant 会话预览=[语音]（{hit}）")

    print("\n===== E. 纯文本聊天回归（不触发 TTS） =====")
    r = call("POST", "/ai/chat", json.dumps({
        "message": "用文字回复就好",
        "character_id": CHARACTER_ID,
    }).encode())
    assert r.status_code == 200, f"text chat {r.status_code}: {r.text[:300]}"
    resp = r.json()
    check(resp.get("audio_media_id") is None and resp.get("audio_duration") is None,
          "文字聊天不返回 audio 字段（语音↔语音门控，保速度）")

    print("\nALL PASS")


if __name__ == "__main__":
    main()
