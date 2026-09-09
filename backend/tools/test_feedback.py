"""AI 角色反馈（037+038）端到端单测：纯内存 SQLite，不碰真实数据/Provider。

覆盖：成功落库 / 快照（ai_message + user_message）/ custom_feedback 落库 /
非法 rating 422 / 非白名单 reasons 422（含旧中文串废弃）/ 缺 character_id 422 /
缺 conversation_id 422 / 缺 message_id 422 / 未知 message_id 容忍（快照 null 仍记录）/
重复 message_id upsert 覆盖（created_at 保留）/ 取消（rating=none 删行）/
GET 拉取已评价态（含 custom_feedback）/ 无签名 401 /
V3-A 统计观察层（置信度锚点 / 聚合 / mention_rate / 排序 / 角色隔离 / 缺 character_id 422 / 窗口过滤）。
"""
import asyncio
import os
import sys

# 必须在 import app.db 前设置，保证本测试绝不写 spike.db / 生产 PG。
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["DEV_CREATE_TABLES"] = "true"
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from datetime import datetime, timedelta, timezone  # noqa: E402

from fastapi import HTTPException  # noqa: E402

from app import config, db, main as api_main  # noqa: E402
from app.models import Conversation, ConversationFeedback, Message  # noqa: E402


class _Request:
    def __init__(self, payload: dict):
        self.payload = payload

    async def json(self) -> dict:
        return self.payload


class _UnsignedRequest:
    """无签名头的假请求：require_signature 在 headers 缺失时即 401。"""

    headers: dict = {}


def _seed_conversation() -> tuple[str, str]:
    """seed：一个角色 + 会话 + 一条用户消息 + 一条 assistant 消息。返回 (conv_id, msg_id)。"""
    db.init_db()
    with db.SessionLocal() as s:
        conv = Conversation(id="fb-conv-1", character_id="companion", persona="companion")
        s.add(conv)
        s.add(
            Message(
                id="fb-user-1",
                conversation_id="fb-conv-1",
                role="user",
                content="今天项目失败了，我好难过",
            )
        )
        s.add(
            Message(
                id="fb-ai-1",
                conversation_id="fb-conv-1",
                role="assistant",
                content="你应该继续努力，失败是成功之母。",
            )
        )
        s.commit()
    return "fb-conv-1", "fb-ai-1"


def _post(body: dict) -> dict:
    return asyncio.run(api_main.feedback_submit(_Request(body), None))


def _expect_422(label: str, body: dict) -> None:
    try:
        _post(body)
    except HTTPException as e:
        assert e.status_code == 422, f"{label}: 期望 422，实得 {e.status_code}"
        return
    raise AssertionError(f"{label}: 应当 422 却未抛错")


def _row(message_id: str) -> ConversationFeedback:
    with db.SessionLocal() as s:
        return s.query(ConversationFeedback).filter(
            ConversationFeedback.message_id == message_id
        ).first()


def _seed_stats_character(cid: str) -> None:
    """V3-A 统计数据：5 负 + 1 正，覆盖多选/无原因/custom_feedback。"""
    rows = [
        ("st-1", "negative", ["preachy", "too_verbose"], "先共情再说话"),
        ("st-2", "negative", ["preachy"], None),
        ("st-3", "negative", ["preachy"], None),
        ("st-4", "negative", ["too_cold"], None),
        ("st-5", "negative", ["preachy", "too_cold"], None),
        ("st-6", "positive", None, None),
    ]
    with db.SessionLocal() as s:
        for mid, rating, reasons, custom in rows:
            s.add(ConversationFeedback(
                character_id=cid,
                conversation_id="st-conv",
                message_id=mid,
                rating=rating,
                reasons=reasons,
                custom_feedback=custom,
            ))
        s.commit()


def main() -> None:
    conv_id, ai_msg_id = _seed_conversation()
    user_msg_id = "fb-user-1"

    # 1. 成功落库（positive，无 reasons）
    r = _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": ai_msg_id,
        "rating": "positive",
    })
    assert r["ok"] is True and r["id"], "positive 应返回 ok+id"
    row = _row(ai_msg_id)
    assert row.rating == "positive", "rating 落库"
    assert row.character_id == "companion", "character_id 落库"
    # 快照：ai_message 取 assistant 消息，user_message 取更早一条用户消息
    assert row.ai_message == "你应该继续努力，失败是成功之母。", "ai_message 快照"
    assert row.user_message == "今天项目失败了，我好难过", "user_message 快照"
    assert row.reasons is None, "无 reasons → null"
    created_first = row.created_at

    # 2. 重复 message_id upsert 覆盖（positive → negative + reasons + custom + preferred）
    r2 = _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": ai_msg_id,
        "rating": "negative",
        "reasons": ["preachy", "preachy", "too_verbose"],  # 含重复 → 去重
        "custom_feedback": "我只是想让她陪我聊聊，不想听大道理",
        "preferred_reply": "先安慰我，不要马上讲道理",
    })
    assert r2["id"] == r["id"], "upsert 应保留原 id"
    row = _row(ai_msg_id)
    assert row.rating == "negative", "upsert 覆盖 rating"
    assert row.reasons == ["preachy", "too_verbose"], "reasons 去重保序"
    assert row.custom_feedback == "我只是想让她陪我聊聊，不想听大道理", "custom_feedback 落库"
    assert row.preferred_reply == "先安慰我，不要马上讲道理", "preferred_reply 落库"
    assert row.created_at == created_first, "upsert 保留首次 created_at"

    # 3. 缺 user 消息的 assistant 消息（快照容忍：user_message 可为 null）
    _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": "fb-ai-1",
        "rating": "negative",
        "reasons": [],
    })
    # 4. 未知 message_id 容忍：仍落库，快照 null
    r4 = _post({
        "character_id": "g9",
        "conversation_id": "fb-conv-9",
        "message_id": "no-such-msg",
        "rating": "positive",
    })
    row4 = _row("no-such-msg")
    assert row4.ai_message is None and row4.user_message is None, "未知消息快照为 null"

    # 5. 非法 rating
    _expect_422("非法 rating", {
        "character_id": "companion", "conversation_id": conv_id,
        "message_id": user_msg_id, "rating": "meh",
    })
    # 6. 非白名单 reasons（码之外/旧中文串均拒绝）
    _expect_422("非白名单 reasons", {
        "character_id": "companion", "conversation_id": conv_id,
        "message_id": user_msg_id, "rating": "negative",
        "reasons": ["不好", "垃圾"],
    })
    _expect_422("旧中文原因串已废弃", {
        "character_id": "companion", "conversation_id": conv_id,
        "message_id": user_msg_id, "rating": "negative",
        "reasons": ["太啰嗦"],
    })
    # 7. 缺 character_id
    _expect_422("缺 character_id", {
        "conversation_id": conv_id, "message_id": user_msg_id, "rating": "positive",
    })
    # 8. 缺 conversation_id
    _expect_422("缺 conversation_id", {
        "character_id": "companion", "message_id": user_msg_id, "rating": "positive",
    })
    # 9. 缺 message_id
    _expect_422("缺 message_id", {
        "character_id": "companion", "conversation_id": conv_id, "rating": "positive",
    })

    # 10. 取消（rating=none → 删行，改主意可取消该条反馈）
    r_none = _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": ai_msg_id,
        "rating": "none",
    })
    assert r_none["ok"] is True and r_none["removed"] == 1, "none 应删除已有行"
    assert _row(ai_msg_id) is None, "取消后行应删除"
    r_none2 = _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": ai_msg_id,
        "rating": "none",
    })
    assert r_none2["removed"] == 0, "重复取消（行不存在）removed=0"
    # 重新提交，供 GET 校验
    _post({
        "character_id": "companion",
        "conversation_id": conv_id,
        "message_id": ai_msg_id,
        "rating": "negative",
        "reasons": ["too_verbose"],
        "custom_feedback": "她记得事情但没有感情",
    })
    _post({
        "character_id": "g9",
        "conversation_id": "fb-conv-9",
        "message_id": "no-such-msg",
        "rating": "positive",
    })

    # 11. GET 拉取已评价态（重进聊天恢复 + 列表页展示用）
    by_char = asyncio.run(api_main.feedback_list("companion", ""))
    by_char_map = {it["message_id"]: it["rating"] for it in by_char["items"]}
    assert by_char_map.get(ai_msg_id) == "negative", "GET 按角色返回已提交反馈"
    assert "no-such-msg" not in by_char_map, "不同角色不串"
    # 完整字段：列表页需要 ai_message/reasons/conversation_id 展示与改主意重提交
    by_char_by_id = {it["message_id"]: it for it in by_char["items"]}
    full = by_char_by_id[ai_msg_id]
    assert full["ai_message"] == "你应该继续努力，失败是成功之母。", "GET 含 ai_message 快照"
    assert full["reasons"] == ["too_verbose"], "GET 含 reasons（码）"
    assert full["custom_feedback"] == "她记得事情但没有感情", "GET 含 custom_feedback"
    assert full["conversation_id"] == conv_id, "GET 含 conversation_id"
    assert full["created_at"], "GET 含 created_at"
    by_conv = asyncio.run(api_main.feedback_list("", conv_id))
    by_conv_map = {it["message_id"]: it["rating"] for it in by_conv["items"]}
    assert by_conv_map.get(ai_msg_id) == "negative", "GET 按会话返回"
    all_items = asyncio.run(api_main.feedback_list("", ""))["items"]
    assert len(all_items) == 2, "两者都空 → 全量（本测试数据仅 2 条）"

    # 12. V3-A 统计观察层（character_feedback_stats）
    # 置信度饱和曲线锚点（1 次 0.1 / 5 次 0.5 / 20 次 0.9，封顶；0 次 → 0）
    assert api_main._feedback_confidence(0) == 0.0, "0 次 → 0"
    assert api_main._feedback_confidence(1) == 0.1, "1 次 → 0.1"
    assert api_main._feedback_confidence(5) == 0.5, "5 次 → 0.5"
    assert api_main._feedback_confidence(20) == 0.9, "20 次 → 0.9"
    assert api_main._feedback_confidence(50) == 0.9, ">20 次封顶 0.9"

    _seed_stats_character("stats-char")
    st = asyncio.run(api_main.feedback_stats("stats-char", 30, None))
    assert st["total"] == 6 and st["positive"] == 1 and st["negative"] == 5, "统计计数"
    assert st["with_custom_feedback"] == 1, "含 custom_feedback 的负反馈数"
    assert list(st["reasons"].keys()) == ["preachy", "too_cold", "too_verbose"], "按 count 降序"
    assert st["reasons"]["preachy"] == {"count": 4, "confidence": 0.4, "mention_rate": 0.8}, "preachy 聚合"
    assert st["reasons"]["too_cold"] == {"count": 2, "confidence": 0.2, "mention_rate": 0.4}, "too_cold 聚合"
    assert st["reasons"]["too_verbose"] == {"count": 1, "confidence": 0.1, "mention_rate": 0.2}, "too_verbose 聚合"
    # 角色隔离：companion 的行不混入 stats-char（companion 现有 1 条 negative [too_verbose]）
    st_comp = asyncio.run(api_main.feedback_stats("companion", 30, None))
    assert st_comp["reasons"] == {"too_verbose": {"count": 1, "confidence": 0.1, "mention_rate": 1.0}}, "companion 隔离统计"
    assert st_comp["with_custom_feedback"] == 1, "companion 该行带 custom_feedback"
    # 缺 character_id → 422
    try:
        asyncio.run(api_main.feedback_stats("", 30, None))
    except HTTPException as e:
        assert e.status_code == 422, f"stats 缺 character_id 应 422，实得 {e.status_code}"
    else:
        raise AssertionError("stats 缺 character_id 应 422 却未抛错")
    # 窗口过滤：把 st-4（too_cold）回拨 60 天 → 30 天窗口不再计入，days<=0 仍全量
    with db.SessionLocal() as s:
        row4 = s.query(ConversationFeedback).filter(
            ConversationFeedback.message_id == "st-4"
        ).first()
        assert row4 is not None, "st-4 应存在"
        row4.created_at = datetime.now(timezone.utc) - timedelta(days=60)
        s.commit()
    st30 = asyncio.run(api_main.feedback_stats("stats-char", 30, None))
    assert st30["total"] == 5 and st30["negative"] == 4, "30 天窗口排除回拨行"
    assert st30["reasons"]["too_cold"] == {"count": 1, "confidence": 0.1, "mention_rate": 0.25}, "窗口内 too_cold 降为 1"
    assert st30["reasons"]["preachy"]["mention_rate"] == 1.0, "窗口内 preachy 占比"
    st_all = asyncio.run(api_main.feedback_stats("stats-char", 0, None))
    assert st_all["total"] == 6 and st_all["negative"] == 5, "days<=0 → 全部历史"
    assert st_all["reasons"]["too_cold"]["count"] == 2, "全部历史含回拨行"

    # 13. 无签名 → 401（require_signature 门禁）
    config.SKIP_AUTH = False  # 强制走验签路径
    try:
        asyncio.run(api_main.require_signature(_UnsignedRequest()))
    except HTTPException as e:
        assert e.status_code == 401, f"无签名应 401，实得 {e.status_code}"
    else:
        raise AssertionError("无签名应 401 却未抛错")
    config.SKIP_AUTH = True

    print(
        "ALL PASS: feedback submit / snapshot / custom_feedback / validation / "
        "upsert / cancel(none) / GET full rows / V3-A stats / 401 gate"
    )


if __name__ == "__main__":
    main()
