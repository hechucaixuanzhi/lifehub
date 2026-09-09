"""MiniMax 语音 TTS（014）：克隆音色 + 文字合成，全 httpx + 标准库。

国产基址 api.minimaxi.com，Authorization: Bearer key。三件套：
  POST /v1/files/upload     multipart 上传样本（purpose=voice_clone）→ file_id
  POST /v1/voice_clone      用样本克隆音色 → voice_id（计费在首次合成时）
  POST /v1/t2a_v2           文字 → wav 字节（output_format=hex，16k mono）

纪律：克隆/合成任何异常都抛 [TTSGatewayError]，由 /ai/chat 静默降级纯文字，
不让语音问题阻断聊天。当前克隆音色 voice_id 存 app_setting.tts_voice_id。
"""
import logging
import os
import uuid
from datetime import datetime, timezone

import httpx

from . import config, db
from .models import AppSetting, CharacterVoiceProfile, MediaAsset

_logger = logging.getLogger("lifehub")

_BASE = config.MINIMAX_BASE_URL.rstrip("/")
_HEADERS = {"Authorization": f"Bearer {config.MINIMAX_API_KEY}"}
_CLONE_MODEL = config.MINIMAX_TTS_MODEL
_MAX_SAMPLE_SIZE = 20 * 1024 * 1024  # MiniMax 样本上限 20MB（样本需 10s~5min）
_VOICE_ID_PREFIX = "lh_"
_SETTING_KEY = "tts_voice_id"  # 014 旧全局配置，仅供 companion 平滑读取

# t2a 失败时命中「音色不存在/过期」的 status_msg 关键词 → 自动清 voice_id 提示重克隆
_VOICE_GONE_HINTS = ("voice_id", "voice not", "音色", "clone")


class TTSGatewayError(Exception):
    """MiniMax 网关错误：code/status_msg 可读，调用方统一降级纯文字。"""

    def __init__(self, message: str, *, code: int | None = None, status_msg: str | None = None):
        super().__init__(message)
        self.code = code
        self.status_msg = status_msg or message


# --------------------------------------------------------------------------- #
# 状态 / voice_id 存取（app_setting.tts_voice_id）
# --------------------------------------------------------------------------- #
def is_configured() -> bool:
    return bool(config.MINIMAX_API_KEY) and config.MINIMAX_TTS_ENABLED


def is_ready() -> bool:
    # 克隆放缓（014）：无克隆音色时用默认内置女声即可合成；克隆后自动优先克隆音色
    return is_configured()


def get_voice_id(character_id: str = "companion") -> str | None:
    with db.SessionLocal() as s:
        profile = s.get(CharacterVoiceProfile, character_id)
        if profile and profile.enabled and profile.status == "ready":
            return profile.voice_id or None
        # 旧测试库可能只有全局 voice_id；只允许首个角色兼容读取，不能扩散到新角色。
        if character_id == "companion" and profile is None:
            row = s.get(AppSetting, _SETTING_KEY)
            return row.value if row and row.value else None
        return None


def set_voice_id(
    character_id: str,
    voice_id: str,
    *,
    source_type: str,
    sample_media_id: str | None = None,
    design_prompt: str | None = None,
    consent_attested: bool = False,
) -> None:
    with db.SessionLocal() as s:
        row = s.get(CharacterVoiceProfile, character_id)
        if row is None:
            row = CharacterVoiceProfile(character_id=character_id)
            s.add(row)
        row.provider = "minimax"
        row.source_type = source_type
        row.voice_id = voice_id
        row.sample_media_id = sample_media_id
        row.design_prompt = design_prompt
        row.status = "ready"
        row.enabled = True
        row.last_error = None
        row.consent_attested_at = (
            datetime.now(timezone.utc) if consent_attested else None
        )
        s.commit()


def clear_voice(character_id: str = "companion") -> None:
    with db.SessionLocal() as s:
        row = s.get(CharacterVoiceProfile, character_id)
        if row is not None:
            s.delete(row)
        # companion 清理时同步清掉 014 旧全局值，避免删除后又回退到旧音色。
        if character_id == "companion":
            legacy = s.get(AppSetting, _SETTING_KEY)
            if legacy is not None:
                s.delete(legacy)
        s.commit()


def get_profile(character_id: str) -> dict:
    with db.SessionLocal() as s:
        row = s.get(CharacterVoiceProfile, character_id)
        legacy_voice = None
        if row is None and character_id == "companion":
            legacy = s.get(AppSetting, _SETTING_KEY)
            legacy_voice = legacy.value if legacy and legacy.value else None
        if row is None:
            return {
                "character_id": character_id,
                "provider": "minimax",
                "source_type": "clone" if legacy_voice else "system",
                "voice_id": legacy_voice,
                "status": "ready",
                "enabled": True,
                "reply_policy": "mirror",
                "speed": 1.0,
                "volume": 1.0,
                "pitch": 0,
                "language_boost": "auto",
                "has_custom_voice": bool(legacy_voice),
            }
        return {
            "character_id": row.character_id,
            "provider": row.provider,
            "source_type": row.source_type,
            "voice_id": row.voice_id,
            "status": row.status,
            "enabled": row.enabled,
            "reply_policy": row.reply_policy,
            "speed": row.speed,
            "volume": row.volume,
            "pitch": row.pitch,
            "language_boost": row.language_boost,
            "design_prompt": row.design_prompt,
            "has_custom_voice": bool(row.voice_id),
        }


def update_profile(character_id: str, values: dict) -> dict:
    with db.SessionLocal() as s:
        row = s.get(CharacterVoiceProfile, character_id)
        if row is None:
            row = CharacterVoiceProfile(
                character_id=character_id,
                provider="minimax",
                source_type="system",
                status="ready",
            )
            s.add(row)
        if "enabled" in values:
            row.enabled = bool(values["enabled"])
        if "reply_policy" in values:
            policy = str(values["reply_policy"])
            if policy not in ("off", "mirror", "sometimes", "always"):
                raise ValueError("无效的语音回复方式")
            row.reply_policy = policy
        if "speed" in values:
            row.speed = min(2.0, max(0.5, float(values["speed"])))
        if "volume" in values:
            row.volume = min(10.0, max(0.1, float(values["volume"])))
        if "pitch" in values:
            row.pitch = min(12, max(-12, int(values["pitch"])))
        if "language_boost" in values:
            language = str(values["language_boost"] or "auto")
            row.language_boost = language[:40]
        s.commit()
    return get_profile(character_id)


# --------------------------------------------------------------------------- #
# MiniMax 调用基元
# --------------------------------------------------------------------------- #
def _post(
    path: str,
    json_body: dict | None = None,
    *,
    files=None,
    data: dict | None = None,
    timeout: float = 120.0,
) -> dict:
    url = f"{_BASE}{path}"
    try:
        resp = httpx.post(
            url, headers=_HEADERS, json=json_body, files=files, data=data, timeout=timeout
        )
    except httpx.HTTPError as e:
        raise TTSGatewayError(f"MiniMax 网络错误 {path}: {e}") from e
    try:
        payload = resp.json()
    except Exception:
        raise TTSGatewayError(f"MiniMax 响应非 JSON（HTTP {resp.status_code}）") from None
    # HTTP 非 2xx 但 JSON 可解析 → 转业务错误，便于上层读 status_msg
    if resp.status_code >= 400:
        code = payload.get("status_code") or payload.get("base_resp", {}).get("status_code")
        msg = payload.get("status_msg") or payload.get("base_resp", {}).get("status_msg") or str(resp.status_code)
        raise TTSGatewayError(f"MiniMax HTTP {resp.status_code}: {msg}", code=code, status_msg=msg)
    return payload


def _assert_ok(payload: dict, action: str) -> None:
    """MiniMax 业务码：status_code==0 成功（顶栏或 base_resp 里）；缺失视为成功。"""
    code = payload.get("status_code")
    if code is None:
        code = (payload.get("base_resp") or {}).get("status_code")
    msg = payload.get("status_msg") or (payload.get("base_resp") or {}).get("status_msg") or ""
    if code not in (0, None):
        raise TTSGatewayError(f"MiniMax {action} 失败: {msg}", code=code, status_msg=msg)


# --------------------------------------------------------------------------- #
# 上传 / 克隆 / 合成
# --------------------------------------------------------------------------- #
def upload_file(media_asset_id: str) -> str:
    """从 media_asset 取样本字节上传 MiniMax（purpose=voice_clone）→ file_id。"""
    if not is_configured():
        raise TTSGatewayError("MiniMax TTS 未配置")
    with db.SessionLocal() as s:
        asset = s.get(MediaAsset, media_asset_id)
        if asset is None or asset.status != "ready":
            raise TTSGatewayError("样本媒体不存在或未就绪")
        storage_path = asset.storage_path
        mime = asset.mime_type or "audio/wav"
        name = asset.file_name or "sample.wav"
    path = os.path.join(config.UPLOAD_DIR, storage_path)
    if not os.path.exists(path):
        raise TTSGatewayError("样本文件缺失")
    if os.path.getsize(path) > _MAX_SAMPLE_SIZE:
        raise TTSGatewayError("样本超过 20MB 上限")
    with open(path, "rb") as f:
        payload = _post(
            "/v1/files/upload",
            files={"file": (name, f, mime)},
            data={"purpose": "voice_clone"},
            timeout=180.0,
        )
    file_id = payload.get("file_id") or (payload.get("file") or {}).get("file_id")
    if not file_id:
        raise TTSGatewayError(f"MiniMax 上传未返回 file_id: {payload}")
    return file_id


def voice_clone(
    file_id: str,
    text: str,
    *,
    character_id: str,
    sample_media_id: str,
) -> str:
    """用样本克隆音色：voice_id 自生成（lh_+hex），成功即存库。计费发生在首次合成。"""
    if not is_configured():
        raise TTSGatewayError("MiniMax TTS 未配置")
    voice_id = _VOICE_ID_PREFIX + uuid.uuid4().hex[:16]
    payload = _post(
        "/v1/voice_clone",
        json_body={
            "file_id": file_id,
            "voice_id": voice_id,
            "model": _CLONE_MODEL,
            "text": text or "",
            "language_boost": "auto",
            "need_noise_reduction": True,
            "need_volume_normalization": True,
        },
        timeout=180.0,
    )
    _assert_ok(payload, "克隆音色")
    # 以服务端返回的 voice_id 为准（若返回）；请求里自生成的兜底
    ret = payload.get("voice_id") or voice_id
    set_voice_id(
        character_id,
        ret,
        source_type="clone",
        sample_media_id=sample_media_id,
        consent_attested=True,
    )
    return ret


def voice_design(character_id: str, prompt: str, preview_text: str) -> tuple[str, bytes]:
    """按文字描述生成非真人复刻的角色音色，并返回 voice_id + 试听 wav。"""
    if not is_configured():
        raise TTSGatewayError("MiniMax TTS 未配置")
    prompt = (prompt or "").strip()
    preview_text = (preview_text or "").strip()
    if not prompt or not preview_text:
        raise TTSGatewayError("音色描述和试听文字不能为空")
    payload = _post(
        "/v1/voice_design",
        json_body={"prompt": prompt[:1000], "preview_text": preview_text[:500]},
        timeout=180.0,
    )
    _assert_ok(payload, "音色设计")
    voice_id = payload.get("voice_id")
    hex_audio = payload.get("trial_audio")
    if not voice_id or not hex_audio:
        raise TTSGatewayError("音色设计未返回 voice_id 或试听音频")
    try:
        audio = bytes.fromhex(hex_audio)
    except ValueError as e:
        raise TTSGatewayError(f"试听音频解码失败: {e}") from e
    set_voice_id(
        character_id,
        voice_id,
        source_type="design",
        design_prompt=prompt,
    )
    return voice_id, audio


def synthesize(
    text: str,
    *,
    character_id: str = "companion",
    sample_rate: int = 32000,
    emotion: str | None = None,
) -> bytes:
    """克隆音色合成 wav 字节（16k mono）。失败抛 TTSGatewayError，调用方降级纯文字。"""
    # 优先克隆音色；无克隆 → 默认内置女声（config.MINIMAX_TTS_VOICE）
    profile = get_profile(character_id)
    voice_id = (
        profile.get("voice_id")
        if profile.get("enabled") and profile.get("status") == "ready"
        else None
    ) or config.MINIMAX_TTS_VOICE
    if not voice_id:
        raise TTSGatewayError("TTS 音色未配置")
    if not text or not text.strip():
        raise TTSGatewayError("TTS 文本为空")
    # 语音时长控制：超长回复按句截断（微信语音上限约 60s），短回复原样合成
    tts_text = text.strip()
    if len(tts_text) > config.MAX_TTS_CHARS:
        tts_text = tts_text[: config.MAX_TTS_CHARS]
        for sep in ("\n", "。", "！", "？", "…"):
            idx = tts_text.rfind(sep)
            if idx > 0:
                tts_text = tts_text[: idx + 1]
                break
    payload = _post(
        "/v1/t2a_v2",
        json_body={
            "model": _CLONE_MODEL,
            "text": tts_text,
            "stream": False,
            "output_format": "hex",
            "voice_setting": {
                "voice_id": voice_id,
                "speed": profile.get("speed", 1.0),
                "vol": profile.get("volume", 1.0),
                "pitch": profile.get("pitch", 0),
                **({"emotion": emotion} if emotion else {}),
            },
            "audio_setting": {"sample_rate": sample_rate, "format": "wav", "channel": 1},
            "language_boost": profile.get("language_boost", "auto"),
        },
        timeout=90.0,
    )
    try:
        _assert_ok(payload, "语音合成")
    except TTSGatewayError as e:
        _maybe_clear_expired_voice(character_id, e)
        raise
    # 真实响应：data 是 dict {audio: "<hex>", status: 2, ced}；兼容 data=裸 hex 字符串
    d = payload.get("data")
    hexdata = d.get("audio") if isinstance(d, dict) else (d if isinstance(d, str) else None)
    if not hexdata:
        raise TTSGatewayError("MiniMax 合成未返回音频数据")
    try:
        return bytes.fromhex(hexdata)
    except ValueError as e:
        raise TTSGatewayError(f"MiniMax 音频 hex 解码失败: {e}") from e


def _maybe_clear_expired_voice(character_id: str, err: TTSGatewayError) -> None:
    """t2a 报「音色不存在/过期」→ 清存量 voice_id，前端提示重新克隆。"""
    msg = (err.status_msg or "").lower()
    if err.code is not None and any(h in msg for h in _VOICE_GONE_HINTS):
        try:
            clear_voice(character_id)
            _logger.info(
                "MiniMax 音色失效，已清 character=%s voice_id（%s）",
                character_id,
                err.status_msg,
            )
        except Exception:
            pass


def delete_provider_voice(character_id: str) -> None:
    """删除 MiniMax 自定义音色并清本地档案；远端失败时不清本地，避免状态假成功。"""
    profile = get_profile(character_id)
    voice_id = profile.get("voice_id")
    source_type = profile.get("source_type")
    if voice_id and source_type in ("clone", "design"):
        payload = _post(
            "/v1/delete_voice",
            json_body={
                "voice_type": (
                    "voice_cloning" if source_type == "clone" else "voice_generation"
                ),
                "voice_id": voice_id,
            },
        )
        _assert_ok(payload, "删除音色")
    clear_voice(character_id)


def _wav_duration(wav: bytes) -> float:
    """从 wav 头算秒数（RIFF 子块遍历，取 data 块字节数）。

    MiniMax 的 wav 在 fmt 与 data 之间可能插入 LIST（Lavf 编码器信息），
    data 不在固定 40 偏移——必须按子块找 data，否则时长算成 0。
    """
    try:
        if len(wav) < 44 or wav[:4] != b"RIFF" or wav[8:12] != b"WAVE":
            return 0.0
        channels = int.from_bytes(wav[22:24], "little")
        sample_rate = int.from_bytes(wav[24:28], "little")
        bits = int.from_bytes(wav[34:36], "little")
        if sample_rate <= 0 or channels <= 0 or bits <= 0:
            return 0.0
        pos = 12
        data_size = 0
        while pos + 8 <= len(wav):
            cid = wav[pos : pos + 4]
            csize = int.from_bytes(wav[pos + 4 : pos + 8], "little")
            if cid == b"data":
                data_size = csize
                break
            pos += 8 + csize + (csize & 1)  # 子块按偶数对齐
        if data_size <= 0:
            data_size = len(wav) - (pos + 8) if pos + 8 < len(wav) else 0
        return data_size / (sample_rate * channels * (bits / 8))
    except Exception:
        return 0.0
