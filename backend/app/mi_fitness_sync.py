"""小米运动健康（Mi Fitness）自动同步（v0.4-4）。

移植自 binglua/mi-fitness-mcp-cn（MIT）的 Mi Fitness 云读取适配器，
改为同步实现（httpx.Client）并落 PostgreSQL（models.py mi_* 表）。

数据流：
  凭据（backend/.env 的 MI_FITNESS_USER_ID / MI_FITNESS_PASS_TOKEN）
  → 登录握手 account.xiaomi.com（自动刷新 passToken + 拿 ssecurity）
  → RC4/SHA1 签名 POST hlth.io.mi.com 拉各数据 key
  → 解析 → upsert 落库（稳定 id 幂等，重复同步不产生重复行）

调度：start_scheduler() 后台线程，启动补最近 30 天，之后每日增量。
手动：POST /mi_fitness/sync。
"""
import base64
import hashlib
import json
import logging
import os
import random
import struct
import threading
import time as _time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlencode

import httpx
from sqlalchemy import func

from . import config, db
from .models import (
    MiAbnormalHeartbeat,
    MiActivityDaily,
    MiBodyMeasurement,
    MiHeartRateSample,
    MiSleepSession,
    MiSpo2Sample,
    MiStressSample,
    MiWorkout,
)

logger = logging.getLogger(__name__)

LOGIN_PREFIX = b"&&&START&&&"
CN_TZ = timezone(timedelta(hours=8))


# --------------------------------------------------------------------------- #
# 小米签名加密（RC4 + SHA1），移植自 xiaomi_crypto / cn 适配器
# --------------------------------------------------------------------------- #
def rc4_crypt(key: bytes, payload: bytes) -> bytes:
    s = list(range(256))
    j = 0
    key_len = len(key)
    for i in range(256):
        j = (j + s[i] + key[i % key_len]) % 256
        s[i], s[j] = s[j], s[i]
    i = 0
    j = 0

    def next_byte() -> int:
        nonlocal i, j
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        return s[(s[i] + s[j]) % 256]

    for _ in range(1024):
        next_byte()
    return bytes(v ^ next_byte() for v in payload)


def _gen_nonce() -> bytes:
    raw = bytearray(os.urandom(8))
    raw.extend(struct.pack(">I", int(datetime.now().timestamp() // 60)))
    return bytes(raw)


def _gen_signed_nonce(ssecurity: bytes, nonce: bytes) -> bytes:
    return hashlib.sha256(ssecurity + nonce).digest()


def _gen_signature(method: str, path: str, values: dict, signed_nonce: bytes) -> str:
    base = method + "&" + path + "&data=" + values["data"]
    if "rc4_hash__" in values:
        base += "&rc4_hash__=" + values["rc4_hash__"]
    base += "&" + base64.b64encode(signed_nonce).decode()
    return base64.b64encode(hashlib.sha1(base.encode()).digest()).decode()


def _read_login_payload(text: str) -> dict:
    payload = text.encode()
    if not payload.startswith(LOGIN_PREFIX):
        raise RuntimeError("unexpected Xiaomi login response")
    return json.loads(payload[len(LOGIN_PREFIX):].decode())


# --------------------------------------------------------------------------- #
# 解析辅助
# --------------------------------------------------------------------------- #
def _parse_value(item: dict) -> dict:
    raw = item.get("value", "{}")
    if isinstance(raw, dict):
        return raw
    return json.loads(raw)


def _ts_to_dt(timestamp: Any, zone_offset: int = 0) -> datetime:
    tz = timezone(timedelta(seconds=int(zone_offset or 0)))
    return datetime.fromtimestamp(int(timestamp), tz=tz)


def _record_datetime(item: dict) -> datetime:
    return _ts_to_dt(int(item.get("time", 0)), int(item.get("zone_offset", 0) or 0))


def _optional_float(v: Any) -> float | None:
    if v is None:
        return None
    parsed = float(v)
    return None if parsed == 0 else parsed


def _optional_int(v: Any) -> int | None:
    if v is None:
        return None
    parsed = int(float(v))
    return None if parsed == 0 else parsed


def _sleep_stage_name(state: Any) -> str:
    mapping = {1: "deep", 2: "light", 3: "light", 4: "awake", 5: "rem"}
    try:
        return mapping.get(int(state), "light")
    except Exception:
        return "light"


def _stress_level(score: int) -> str:
    if score < 30:
        return "low"
    if score < 60:
        return "medium"
    return "high"


# --------------------------------------------------------------------------- #
# 小米健康云客户端（同步实现）
# --------------------------------------------------------------------------- #
class MiFitnessClient:
    def __init__(self, user_id: str, pass_token: str, region: str = "cn"):
        self.user_id = user_id
        self.pass_token = pass_token
        self.region = (region or "cn").strip().lower()
        self._cookies = ""
        self._ssecurity = b""
        self._client: httpx.Client | None = None
        self._max_pages = 200
        self.last_error: str | None = None

    @property
    def _base_url(self) -> str:
        if self.region in ("", "cn"):
            return "https://hlth.io.mi.com"
        return f"https://{self.region}.hlth.io.mi.com"

    def connect(self) -> bool:
        try:
            self._client = httpx.Client(timeout=30.0, follow_redirects=False)
            self._login_with_token(self.user_id, self.pass_token)
            self.last_error = None
            return True
        except Exception as exc:
            self.last_error = f"{type(exc).__name__}: {exc}"
            logger.warning("Mi Fitness connect failed: %s", self.last_error)
            self._close()
            return False

    def _close(self) -> None:
        if self._client:
            self._client.close()
            self._client = None

    def _login_with_token(self, user_id: str, pass_token: str) -> None:
        if not self._client:
            raise RuntimeError("client not initialized")
        resp = self._client.get(
            "https://account.xiaomi.com/pass/serviceLogin?_json=true&sid=miothealth",
            headers={"Cookie": f"userId={user_id}; passToken={pass_token}"},
        )
        resp.raise_for_status()
        payload = _read_login_payload(resp.text)
        self.pass_token = str(payload["passToken"])
        self.user_id = str(payload["userId"])
        self._ssecurity = base64.b64decode(str(payload["ssecurity"]))
        redirect = self._client.get(str(payload["location"]))
        redirect.raise_for_status()
        self._cookies = "; ".join(
            v.split(";", 1)[0] for v in redirect.headers.get_list("set-cookie")
        )
        if not self._cookies:
            raise RuntimeError("Xiaomi login did not return session cookies")

    def _request(self, path: str, payload: dict) -> dict:
        if not self._client:
            raise RuntimeError("client not initialized")
        last_error: Exception | None = None
        for attempt in range(3):
            try:
                form = {"data": json.dumps(payload, separators=(",", ":"))}
                nonce = _gen_nonce()
                signed_nonce = _gen_signed_nonce(self._ssecurity, nonce)
                form["rc4_hash__"] = _gen_signature("POST", path, form, signed_nonce)
                encrypted = {
                    k: base64.b64encode(rc4_crypt(signed_nonce, v.encode())).decode()
                    for k, v in form.items()
                }
                encrypted["signature"] = _gen_signature("POST", path, encrypted, signed_nonce)
                encrypted["_nonce"] = base64.b64encode(nonce).decode()
                resp = self._client.post(
                    self._base_url + path,
                    headers={
                        "Cookie": self._cookies,
                        "Content-Type": "application/x-www-form-urlencoded",
                    },
                    content=urlencode(encrypted),
                )
                resp.raise_for_status()
                plaintext = rc4_crypt(signed_nonce, base64.b64decode(resp.text))
                body = json.loads(plaintext)
                if body.get("code") != 0:
                    raise RuntimeError(f"mi fitness error: {body.get('message', 'unknown')}")
                return body.get("result", {})
            except Exception as exc:
                last_error = exc
                retryable = isinstance(exc, (httpx.TimeoutException, httpx.NetworkError))
                auth_failed = False
                if isinstance(exc, httpx.HTTPStatusError):
                    status = exc.response.status_code
                    if status in (401, 403):
                        auth_failed = True
                    elif status in (429,) or status >= 500:
                        retryable = True
                if auth_failed and attempt == 0:
                    # 会话失效：用最新 passToken 重登录后重发
                    try:
                        self._login_with_token(self.user_id, self.pass_token)
                        retryable = True
                    except Exception as login_exc:
                        self.last_error = f"auth refresh failed: {login_exc}"
                        retryable = False
                if attempt == 2 or not retryable:
                    break
                _time.sleep(min(4.0, 0.5 * (2**attempt)) + random.random() * 0.1)
        raise RuntimeError(f"Mi Fitness request failed: {last_error}") from last_error

    def _date_range_to_ts(self, start_date: str, end_date: str) -> tuple[int, int]:
        tz = CN_TZ if self.region in ("", "cn") else timezone.utc
        start_dt = datetime.fromisoformat(start_date).replace(tzinfo=tz)
        end_dt = datetime.fromisoformat(end_date + "T23:59:59").replace(tzinfo=tz)
        return int(start_dt.timestamp()), int(end_dt.timestamp())

    def _fetch_key(self, key: str, start_date: str, end_date: str) -> list[dict]:
        start_time, end_time = self._date_range_to_ts(start_date, end_date)
        items: list[dict] = []
        next_key: str | None = None
        seen: set[str] = set()
        for _ in range(self._max_pages):
            payload = {"start_time": start_time, "end_time": end_time, "key": key}
            if next_key:
                payload["next_key"] = next_key
            result = self._request("/app/v1/data/get_fitness_data_by_time", payload)
            items.extend(result.get("data_list", []))
            if not result.get("has_more") or not result.get("next_key"):
                break
            cursor = str(result.get("next_key"))
            if cursor in seen:
                raise RuntimeError("Mi Fitness pagination cursor loop detected")
            seen.add(cursor)
            next_key = cursor
        return items

    def _fetch_sport_records(self, start_date: str, end_date: str) -> list[dict]:
        start_time, end_time = self._date_range_to_ts(start_date, end_date)
        items: list[dict] = []
        next_key: str | None = None
        seen: set[str] = set()
        for _ in range(self._max_pages):
            payload = {"start_time": start_time, "end_time": end_time, "limit": 50}
            if next_key:
                payload["next_key"] = next_key
            result = self._request("/app/v1/data/get_sport_records_by_time", payload)
            items.extend(result.get("sport_records", []))
            if not result.get("has_more") or not result.get("next_key"):
                break
            cursor = str(result.get("next_key"))
            if cursor in seen:
                raise RuntimeError("Mi Fitness sport pagination cursor loop detected")
            seen.add(cursor)
            next_key = cursor
        return items


# --------------------------------------------------------------------------- #
# 落库（稳定 id 幂等）
# --------------------------------------------------------------------------- #
def _upsert(session, model, obj_id: str, values: dict) -> None:
    """obj_id 为模型主键值（MiActivityDaily=date，其余=显式 id）。"""
    values = dict(values)
    if model is not MiActivityDaily:
        values["id"] = obj_id
    row = session.get(model, obj_id)
    if row is None:
        session.add(model(**values))
    else:
        for k, v in values.items():
            setattr(row, k, v)


def _sync_daily_activity(session, client: MiFitnessClient, start: str, end: str) -> int:
    daily: dict[str, dict] = defaultdict(
        lambda: {"steps": 0, "distance_m": 0.0, "active_kcal": 0.0}
    )
    for item in client._fetch_key("steps", start, end):
        p = _parse_value(item)
        d = _record_datetime(item).strftime("%Y-%m-%d")
        daily[d]["steps"] += int(p.get("steps", 0))
        daily[d]["distance_m"] += float(p.get("distance", 0))
        daily[d]["active_kcal"] += float(p.get("calories", 0))
    cal_totals: dict[str, float] = defaultdict(float)
    for item in client._fetch_key("calories", start, end):
        p = _parse_value(item)
        d = _record_datetime(item).strftime("%Y-%m-%d")
        cal_totals[d] += float(p.get("calories", 0))
    for d, total in cal_totals.items():
        daily[d]["active_kcal"] = total
    for d, v in sorted(daily.items()):
        _upsert(session, MiActivityDaily, d, {
            "date": d,
            "steps": int(v["steps"]),
            "distance_m": float(v["distance_m"]),
            "active_kcal": float(v["active_kcal"]),
        })
    return len(daily)


def _sync_heart_rate(session, client: MiFitnessClient, start: str, end: str) -> int:
    rows: list[dict] = []
    for item in client._fetch_key("heart_rate", start, end):
        p = _parse_value(item)
        sample_type = "passive" if int(p.get("type", 0)) == 0 else "active"
        rows.append({
            "timestamp": _record_datetime(item),
            "bpm": int(p.get("bpm", 0)),
            "sample_type": sample_type,
        })
    for item in client._fetch_key("resting_heart_rate", start, end):
        p = _parse_value(item)
        ts = p.get("date_time") or item.get("time")
        rows.append({
            "timestamp": _ts_to_dt(ts, int(item.get("zone_offset", 0) or 0)),
            "bpm": int(p.get("bpm", 0)),
            "sample_type": "resting",
        })
    if not rows:
        return 0
    # 批量去重：只查目标时间窗内已有 (timestamp, sample_type)，避免逐条 query
    timestamps = sorted(r["timestamp"] for r in rows)
    existing = {
        (ts, st) for ts, st in
        session.query(MiHeartRateSample.timestamp, MiHeartRateSample.sample_type)
        .filter(
            MiHeartRateSample.timestamp >= timestamps[0],
            MiHeartRateSample.timestamp <= timestamps[-1],
        )
        .all()
    }
    added = 0
    for r in rows:
        key = (r["timestamp"], r["sample_type"])
        if key in existing:
            continue
        obj_id = f"hr_{int(r['timestamp'].timestamp() * 1000)}_{r['sample_type']}"
        session.add(MiHeartRateSample(id=obj_id, **r))
        existing.add(key)
        added += 1
    return added


def _sync_sleep(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_key("sleep", start, end):
        p = _parse_value(item)
        zone_offset = int(item.get("zone_offset", 0) or 0)
        sleep_start = p.get("bedtime") or p.get("device_bedtime") or p.get("bed_timestamp")
        sleep_end = (
            p.get("wake_up_time")
            or p.get("device_wake_up_time")
            or p.get("out_bed_timestamp")
            or item.get("time")
        )
        if not sleep_start or not sleep_end:
            continue
        start_at = _ts_to_dt(sleep_start, zone_offset)
        end_at = _ts_to_dt(sleep_end, zone_offset)
        duration_min = int(
            p.get("duration") or max(0, (int(sleep_end) - int(sleep_start)) // 60)
        )
        awake_min = int(p.get("awake_duration") or p.get("sleep_awake_duration") or 0)
        asleep_min = max(0, duration_min - awake_min)
        stages: list[dict] = []
        for seg in p.get("items", []) or []:
            try:
                seg_start = int(seg.get("start_time", 0))
                seg_end = int(seg.get("end_time", 0))
                minutes = max(0, (seg_end - seg_start) // 60)
                if minutes:
                    stages.append({
                        "stage": _sleep_stage_name(seg.get("state")),
                        "minutes": minutes,
                    })
            except Exception:
                continue
        sleep_id = f"{item.get('sid', '')}_{item.get('time', int(sleep_end))}"
        _upsert(session, MiSleepSession, f"mi_sleep_{sleep_id}", {
            "sleep_id": sleep_id,
            "start_at": start_at,
            "end_at": end_at,
            "duration_min": duration_min,
            "awake_min": awake_min,
            "asleep_min": asleep_min,
            "score": _optional_int(p.get("score") or p.get("sleep_score")),
            "is_nap": bool(p.get("is_nap", False)),
            "stages": stages or None,
        })
        count += 1
    return count


def _sync_workouts(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_sport_records(start, end):
        p = _parse_value(item)
        zone_offset = int(item.get("zone_offset", 0) or 0)
        start_ts = p.get("start_time") or item.get("time")
        end_ts = p.get("end_time")
        duration_seconds = int(p.get("duration", 0) or 0)
        if not end_ts and start_ts:
            end_ts = int(start_ts) + duration_seconds
        if not start_ts or not end_ts:
            continue
        start_at = _ts_to_dt(start_ts, zone_offset)
        end_at = _ts_to_dt(end_ts, zone_offset)
        duration_min = max(0, int(duration_seconds // 60))
        if duration_min == 0:
            duration_min = max(0, (int(end_ts) - int(start_ts)) // 60)
        native_id = f"{item.get('sid', '')}_{item.get('key', 'workout')}_{item.get('time', start_ts)}"
        _upsert(session, MiWorkout, f"mi_workout_{native_id}", {
            "native_id": native_id,
            "activity_type": str(
                item.get("category")
                or item.get("key")
                or p.get("sport_type")
                or "workout"
            ),
            "sport_category": str(item.get("category") or "") or None,
            "start_at": start_at,
            "end_at": end_at,
            "duration_min": duration_min,
            "distance_m": _optional_float(p.get("distance")),
            "calories_kcal": _optional_float(p.get("calories") or p.get("total_cal")),
            "avg_hr_bpm": _optional_int(p.get("avg_hrm")),
            "max_hr_bpm": _optional_int(p.get("max_hrm")),
            "avg_pace_s_per_km": _optional_float(p.get("avg_pace")),
            "max_pace_s_per_km": _optional_float(p.get("max_pace")),
            "total_steps": _optional_int(p.get("steps") or p.get("total_steps")),
            "raw": item,
        })
        count += 1
    return count


def _sync_body(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_key("weight", start, end):
        p = _parse_value(item)
        obj_id = f"mi_body_{int(item.get('time', 0))}"
        _upsert(session, MiBodyMeasurement, obj_id, {
            "timestamp": _record_datetime(item),
            "weight_kg": float(p.get("weight", 0)),
            "bmi": float(p["bmi"]) if p.get("bmi") is not None else None,
            "body_fat_pct": _optional_float(p.get("body_fat_rate")),
            "muscle_kg": _optional_float(p.get("muscle_rate")),
            "water_pct": _optional_float(p.get("moisture_rate")),
            "bone_kg": _optional_float(p.get("bone_mass")),
            "visceral_fat_score": _optional_int(p.get("visceral_fat")),
            "basal_meta_kcal": _optional_int(p.get("basal_metabolism")),
            "body_age": _optional_int(p.get("body_age")),
        })
        count += 1
    return count


def _sync_spo2(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_key("spo2", start, end):
        p = _parse_value(item)
        ts = p.get("time") or item.get("time")
        spo2 = p.get("spo2") or p.get("value")
        if ts is None or spo2 is None:
            continue
        _upsert(session, MiSpo2Sample, f"mi_spo2_{int(ts)}", {
            "timestamp": _ts_to_dt(ts, int(item.get("zone_offset", 0) or 0)),
            "spo2_pct": int(float(spo2)),
        })
        count += 1
    return count


def _sync_stress(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_key("stress", start, end):
        p = _parse_value(item)
        ts = p.get("time") or item.get("time")
        stress = p.get("stress") or p.get("score") or p.get("value")
        if ts is None or stress is None:
            continue
        score = int(float(stress))
        _upsert(session, MiStressSample, f"mi_stress_{int(ts)}", {
            "timestamp": _ts_to_dt(ts, int(item.get("zone_offset", 0) or 0)),
            "score": score,
            "level": _stress_level(score),
        })
        count += 1
    return count


def _sync_abnormal(session, client: MiFitnessClient, start: str, end: str) -> int:
    count = 0
    for item in client._fetch_key("abnormal_heart_beat", start, end):
        p = _parse_value(item)
        zone_offset = int(item.get("zone_offset", 0) or 0)
        start_ts = p.get("start_time") or item.get("time")
        end_ts = p.get("end_time") or start_ts
        if start_ts is None:
            continue
        _upsert(session, MiAbnormalHeartbeat, f"mi_abhr_{item.get('sid', '')}_{int(start_ts)}", {
            "start_at": _ts_to_dt(start_ts, zone_offset),
            "end_at": _ts_to_dt(end_ts, zone_offset),
            "duration_sec": max(0, int(end_ts) - int(start_ts)),
        })
        count += 1
    return count


# --------------------------------------------------------------------------- #
# 对外入口
# --------------------------------------------------------------------------- #
def sync_range(session, client: MiFitnessClient, start_date: str, end_date: str) -> dict:
    """拉取 start~end 全部数据类型并落库，返回各类条数统计。"""
    stats = {
        "activity_days": _sync_daily_activity(session, client, start_date, end_date),
        "heart_rate_samples": _sync_heart_rate(session, client, start_date, end_date),
        "sleep_sessions": _sync_sleep(session, client, start_date, end_date),
        "workouts": _sync_workouts(session, client, start_date, end_date),
        "body_measurements": _sync_body(session, client, start_date, end_date),
        "spo2_samples": _sync_spo2(session, client, start_date, end_date),
        "stress_samples": _sync_stress(session, client, start_date, end_date),
        "abnormal_heartbeats": _sync_abnormal(session, client, start_date, end_date),
    }
    session.commit()
    return stats


def credentials_configured() -> bool:
    return bool(config.MI_FITNESS_USER_ID and config.MI_FITNESS_PASS_TOKEN)


def run_sync(days_back: int = 1) -> dict:
    """增量同步最近 days_back+1 天（含今天）。幂等，可重复调用。"""
    if not credentials_configured():
        return {"ok": False, "error": "MI_FITNESS 凭据未配置（backend/.env）"}
    client = MiFitnessClient(
        config.MI_FITNESS_USER_ID,
        config.MI_FITNESS_PASS_TOKEN,
        config.MI_FITNESS_REGION,
    )
    if not client.connect():
        return {"ok": False, "error": client.last_error or "连接失败"}
    try:
        today = datetime.now(CN_TZ).date()
        start = (today - timedelta(days=days_back)).isoformat()
        end = today.isoformat()
        with db.SessionLocal() as s:
            stats = sync_range(s, client, start, end)
        return {"ok": True, "range": {"start": start, "end": end}, **stats}
    finally:
        client._close()


def status() -> dict:
    if not credentials_configured():
        return {"configured": False, "error": "MI_FITNESS 凭据未配置（backend/.env）"}
    with db.SessionLocal() as s:
        last = s.query(func.max(MiActivityDaily.synced_at)).scalar()
        counts = {
            "activity_days": s.query(MiActivityDaily).count(),
            "workouts": s.query(MiWorkout).count(),
            "heart_rate_samples": s.query(MiHeartRateSample).count(),
            "sleep_sessions": s.query(MiSleepSession).count(),
            "body_measurements": s.query(MiBodyMeasurement).count(),
            "spo2_samples": s.query(MiSpo2Sample).count(),
            "stress_samples": s.query(MiStressSample).count(),
        }
    return {
        "configured": True,
        "region": config.MI_FITNESS_REGION,
        "last_synced_at": last.isoformat() if last else None,
        "counts": counts,
    }


# --------------------------------------------------------------------------- #
# 定时调度（后台线程，每日增量）
# --------------------------------------------------------------------------- #
_scheduler_thread: threading.Thread | None = None


def start_scheduler() -> None:
    if not config.MI_FITNESS_SYNC_ENABLED or not credentials_configured():
        logger.info("Mi Fitness scheduler skipped (disabled or no credentials)")
        return
    global _scheduler_thread
    if _scheduler_thread and _scheduler_thread.is_alive():
        return

    def _loop() -> None:
        # 启动补最近 30 天（幂等 upsert，安全）
        try:
            result = run_sync(days_back=30)
            logger.info("Mi Fitness initial sync: %s", result)
        except Exception:
            logger.exception("Mi Fitness initial sync failed")
        while True:
            now = datetime.now(timezone.utc)
            target = now.replace(
                hour=config.MI_FITNESS_SYNC_HOUR, minute=5, second=0, microsecond=0
            )
            if target <= now:
                target += timedelta(days=1)
            _time.sleep((target - now).total_seconds())
            try:
                result = run_sync(days_back=1)
                logger.info("Mi Fitness daily sync: %s", result)
            except Exception:
                logger.exception("Mi Fitness scheduled sync failed")

    _scheduler_thread = threading.Thread(target=_loop, daemon=True, name="mi-fitness-sync")
    _scheduler_thread.start()
    logger.info("Mi Fitness scheduler started")
