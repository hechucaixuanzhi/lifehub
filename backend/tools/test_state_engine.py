"""角色状态系统 V1 隔离单测（纯内存 SQLite，不碰真实数据/Provider）。

覆盖（对照计划 B4）：
- update_state 信号分级 / energy 衰减 / intimacy·response_style 不驱动
- detect_purpose 目的识别
- compute_policy 长度归 Policy、情绪不调长度、目的覆盖、低精力不降长度
- policy_prompt_text 数字约束 / 共情 / 不出现「我累了」
- build_reply_mode_prompt policy_text 分支与 None 逐字节兼容
- reply_needs_regeneration 只防空+防截断（B 最关键）
- max_tokens_for / load_state·apply_state roundtrip
"""
import os
import sys
from datetime import datetime, timedelta, timezone

# 必须在 import app.db 前设置，保证本测试绝不写 spike.db / 生产 PG。
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["DEV_CREATE_TABLES"] = "true"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import ai_gateway, db, prompts, state_engine as se  # noqa: E402

T0 = datetime(2026, 8, 11, 12, 0, tzinfo=timezone.utc)


def _state(**overrides) -> dict:
    s = dict(se.DEFAULT_STATE)
    s.update(overrides)
    return s


# --------------------------------------------------------------------------- #
# update_state
# --------------------------------------------------------------------------- #
def test_update_state_weak_signal_does_not_jump():
    """普通信号 ±5/次（上限 ±15）：哈哈×3 → 65，不 jump excited（用户评审 #1）。"""
    s = _state()
    out = se.update_state(s, "哈哈 哈哈 哈哈", now=T0)
    assert out["mood_score"] == 65
    assert out["mood"] != "excited"
    # 单次弱信号只 +5
    assert se.update_state(s, "哈哈", now=T0)["mood_score"] == 55


def test_update_state_strong_event():
    """强事件 ±20/次 + 强触发：终于上岸了！！！ → excited。"""
    s = _state()
    out = se.update_state(s, "终于上岸了！！！", now=T0)
    assert out["mood_score"] >= 75
    assert out["mood"] == "excited"


def test_update_state_crash_forces_low():
    """我崩了 → 强负向，强制压到 30 进 low。"""
    s = _state()
    out = se.update_state(s, "我崩了", now=T0)
    assert out["mood_score"] <= 30
    assert out["mood"] == "low"


def test_update_state_clamp():
    """clamp 0-100：高分继续强正只到 100。"""
    s = _state(mood_score=90)
    out = se.update_state(s, "成功上岸了", now=T0)
    assert out["mood_score"] == 100
    assert out["mood"] == "excited"


def test_update_state_energy_decay():
    """energy 时间衰减：2h→-10、floor 10、≥6h→70。"""
    s = se.update_state(_state(), "在吗", now=T0)
    s2 = se.update_state(s, "在吗", now=T0 + timedelta(hours=2))
    assert s2["energy"] == 60  # 70 - 5*2
    s3 = dict(s2, energy=15)  # s2 在 T0+2h 更新
    s4 = se.update_state(s3, "在吗", now=T0 + timedelta(hours=4))  # 距 s3 更新 2h
    assert s4["energy"] == 10  # floor
    s5 = se.update_state(s, "在吗", now=T0 + timedelta(hours=7))
    assert s5["energy"] == 70  # 睡醒恢复


def test_update_state_preserves_intimacy_and_style():
    """intimacy 只存不驱动、response_style 稳定不每轮重算（评审 #4/#6）。"""
    s = _state(intimacy=88, response_style="long")
    out = se.update_state(s, "哈哈哈哈哈哈", now=T0)
    assert out["intimacy"] == 88
    assert out["response_style"] == "long"


# --------------------------------------------------------------------------- #
# detect_purpose
# --------------------------------------------------------------------------- #
def test_detect_purpose():
    assert se.detect_purpose("我妈妈去世了，我好难过") == "emotional_support"
    assert se.detect_purpose("我崩了") == "emotional_support"
    assert se.detect_purpose("我成功上岸了！") == "celebration"
    assert se.detect_purpose("在吗") == "trivial"
    assert se.detect_purpose("你好") == "trivial"
    assert se.detect_purpose("今天天气真不错啊") == "normal"


# --------------------------------------------------------------------------- #
# compute_policy
# --------------------------------------------------------------------------- #
def test_compute_policy_mood_does_not_touch_length():
    """happy + 用户偏好 short → 仍是 short（评审 #2 核心：情绪不调长度）。"""
    p = se.compute_policy(_state(mood="happy"), "normal", 100)
    assert p["length_bias"] == "short"
    assert p["warmth"] == "high"
    assert p["temperature"] == 1.1


def test_compute_policy_trivial_squeezes_length():
    """trivial → 压 very_short/short（「在吗」→「干嘛😶」核心机制）。"""
    p = se.compute_policy(_state(response_style="medium"), "trivial", 300)
    assert p["length_bias"] == "short"
    p2 = se.compute_policy(_state(response_style="short"), "trivial", None)
    assert p2["length_bias"] == "very_short"


def test_compute_policy_emotional_support_overrides_length():
    """emotional_support + 偏好 short → 抬 medium（优先级 2>3，绝不「节哀😶」）。"""
    p = se.compute_policy(_state(response_style="short"), "emotional_support", 100)
    assert p["length_bias"] == "medium"


def test_compute_policy_low_energy_flat_not_short():
    """低精力 → 活跃度降（语气平和/emoji 少/温度 0.9），但不减长度（评审 #3）。"""
    p = se.compute_policy(_state(mood="happy", energy=30), "normal", 100)
    assert p["length_bias"] == "short"  # 长度不变
    assert p["warmth"] == "flat"
    assert p["emoji"] == "low"
    assert p["temperature"] == 0.9


def test_compute_policy_response_style_base():
    """滑块默认 180/None → 用 response_style 起底。"""
    p = se.compute_policy(_state(response_style="short"), "normal", None)
    assert p["length_bias"] == "short"
    p2 = se.compute_policy(_state(response_style="long"), "normal", 180)
    assert p2["length_bias"] == "long"


# --------------------------------------------------------------------------- #
# policy_prompt_text
# --------------------------------------------------------------------------- #
def test_policy_prompt_text_numeric():
    p = se.compute_policy(_state(response_style="short"), "normal", None)
    txt = se.policy_prompt_text(p)
    assert "1-2 句" in txt and "50 字以内" in txt  # 数字约束，不用「简短」抽象词
    assert "不要写成小作文" in txt


def test_policy_prompt_text_emotional_support():
    p = se.compute_policy(_state(mood="low"), "emotional_support", None)
    txt = se.policy_prompt_text(p)
    assert "先共情" in txt
    assert "不要讲大道理" in txt


def test_policy_prompt_text_no_tiredness():
    """低精力版不得出现「我累了/不想聊」等拒绝表达（评审 #3）。"""
    p = se.compute_policy(_state(mood="happy", energy=25), "normal", None)
    txt = se.policy_prompt_text(p)
    assert "语气平和自然即可" in txt
    assert "我累了" not in txt and "不想聊" not in txt


# --------------------------------------------------------------------------- #
# build_reply_mode_prompt
# --------------------------------------------------------------------------- #
def test_build_reply_mode_prompt_with_policy():
    policy_prompt = se.policy_prompt_text(
        se.compute_policy(_state(response_style="short"), "normal", None)
    )
    out = prompts.build_reply_mode_prompt(
        "realtime",
        reply_max_chars=300,
        reply_bubble_count=4,
        policy_text=policy_prompt,
    )
    assert "50 字以内" in out  # 策略数字约束已注入
    assert "不要明显低于" not in out  # char 地板行被替换
    assert "恰好发送 4 条" in out  # 气泡分隔规则保留


def test_build_reply_mode_prompt_none_unchanged():
    """policy_text=None → 与老行为逐字节一致（旧断言项复现）。"""
    out = prompts.build_reply_mode_prompt(
        "realtime", reply_max_chars=300, reply_bubble_count=4
    )
    assert "按约 375 字构思" in out
    assert "成品不要明显低于 300 字" in out
    assert "恰好发送 4 条" in out
    assert "3 个 <|BUBBLE|>" in out
    roleplay = prompts.build_reply_mode_prompt("roleplay", reply_max_chars=1800)
    assert "按约 2250 字构思" in roleplay
    assert "成品不要明显低于 1800 字" in roleplay


# --------------------------------------------------------------------------- #
# reply_needs_regeneration（B 最关键：只防空+防截断）
# --------------------------------------------------------------------------- #
def _short_policy() -> dict:
    return se.compute_policy(_state(response_style="short"), "normal", None)


def test_regeneration_short_policy_short_ok():
    """short 策略 + 短回复「嗯」→ 不重写（不再被硬补长）。"""
    p = _short_policy()
    assert (
        ai_gateway.reply_needs_regeneration(
            "嗯",
            "realtime",
            reply_max_chars=180,
            reply_bubble_count=3,
            finish_reason="stop",
            policy=p,
        )
        is False
    )


def test_regeneration_empty_and_punct():
    p = _short_policy()
    assert (
        ai_gateway.reply_needs_regeneration(
            "", "realtime", reply_max_chars=180, reply_bubble_count=3,
            finish_reason="stop", policy=p,
        )
        is True
    )
    assert (
        ai_gateway.reply_needs_regeneration(
            "。。。", "realtime", reply_max_chars=180, reply_bubble_count=3,
            finish_reason="stop", policy=p,
        )
        is True
    )


def test_regeneration_truncated():
    p = _short_policy()
    assert (
        ai_gateway.reply_needs_regeneration(
            "嗯", "realtime", reply_max_chars=180, reply_bubble_count=3,
            finish_reason="length", policy=p,
        )
        is True
    )


def test_regeneration_short_no_bubble_force():
    """short 策略 + 少气泡 → 不硬拆 N 条。"""
    p = _short_policy()
    assert (
        ai_gateway.reply_needs_regeneration(
            "嗯", "realtime", reply_max_chars=180, reply_bubble_count=3,
            finish_reason="stop", policy=p,
        )
        is False
    )


def test_regeneration_medium_keeps_bubble_check():
    p = se.compute_policy(_state(response_style="medium"), "normal", None)
    assert (
        ai_gateway.reply_needs_regeneration(
            "就一句话", "realtime", reply_max_chars=300, reply_bubble_count=3,
            finish_reason="stop", policy=p,
        )
        is True
    )


def test_regeneration_no_policy_keeps_floor():
    """policy=None（roleplay/老调用方）→ 保持 85% 地板行为。"""
    assert (
        ai_gateway.reply_needs_regeneration(
            "只有一句很短的回复。",
            "realtime",
            reply_max_chars=180,
            reply_bubble_count=3,
        )
        is True
    )


# --------------------------------------------------------------------------- #
# max_tokens_for / load_state·apply_state
# --------------------------------------------------------------------------- #
def test_max_tokens_for():
    assert se.max_tokens_for({"length_bias": "very_short"}) == 150
    assert se.max_tokens_for({"length_bias": "long"}) == 600


def test_state_roundtrip():
    db.init_db()
    se.apply_state(
        "c-roundtrip",
        {
            "mood": "happy",
            "mood_score": 65,
            "energy": 40,
            "intimacy": 88,
            "conversation_mode": "casual",
            "response_style": "long",
            "last_interaction_time": None,
        },
    )
    st = se.load_state("c-roundtrip")
    assert st["mood"] == "happy"
    assert st["response_style"] == "long"
    assert st["intimacy"] == 88
    # 缺失字段由 DEFAULT_STATE 补齐
    assert st["mood_score"] == 65


def main() -> int:
    """顺序执行（保持输出可读），任一步失败即退出非零。"""
    tests = [
        test_update_state_weak_signal_does_not_jump,
        test_update_state_strong_event,
        test_update_state_crash_forces_low,
        test_update_state_clamp,
        test_update_state_energy_decay,
        test_update_state_preserves_intimacy_and_style,
        test_detect_purpose,
        test_compute_policy_mood_does_not_touch_length,
        test_compute_policy_trivial_squeezes_length,
        test_compute_policy_emotional_support_overrides_length,
        test_compute_policy_low_energy_flat_not_short,
        test_compute_policy_response_style_base,
        test_policy_prompt_text_numeric,
        test_policy_prompt_text_emotional_support,
        test_policy_prompt_text_no_tiredness,
        test_build_reply_mode_prompt_with_policy,
        test_build_reply_mode_prompt_none_unchanged,
        test_regeneration_short_policy_short_ok,
        test_regeneration_empty_and_punct,
        test_regeneration_truncated,
        test_regeneration_short_no_bubble_force,
        test_regeneration_medium_keeps_bubble_check,
        test_regeneration_no_policy_keeps_floor,
        test_max_tokens_for,
        test_state_roundtrip,
    ]
    failures = []
    for fn in tests:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
        except AssertionError as exc:
            failures.append((fn.__name__, exc))
            print(f"FAIL  {fn.__name__}: {exc}")
        except Exception as exc:  # noqa: BLE001
            failures.append((fn.__name__, exc))
            print(f"ERROR {fn.__name__}: {exc!r}")
    print(f"\n{len(tests) - len(failures)}/{len(tests)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
