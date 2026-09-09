"""Reply normalization, formatting and length-policy helpers.

This module is provider-light and database-free. ``ai_gateway`` re-exports its
public helpers so existing callers keep the same API while chat orchestration
stays focused on model and tool flow.
"""

import json
import logging
import re

import httpx

from . import config, prompts

logger = logging.getLogger("lifehub")
INTERNAL_REPLY_MARKER_RE = re.compile(r"\[\s*(?:语音回复|文字回复)\s*\]")

def strip_internal_reply_markers(reply: str) -> str:
    """移除只属于消息传输层的内部标签，禁止其进入 UI、历史或角色口吻。"""
    return INTERNAL_REPLY_MARKER_RE.sub("", reply or "").strip()


def _clean_realtime_segment(segment: str) -> str:
    """现实聊天确定性移除括号动作，模型偶发违令也不会泄漏到 UI。"""
    clean = (segment or "").strip()
    # 删除完整中文/英文圆括号块；现实模式不允许用它承载动作或旁白。
    clean = re.sub(r"[（(][^（）()\n]{0,240}[）)]", "", clean)
    # 未闭合括号只去掉符号，避免用户看到角色扮演标记。
    clean = clean.replace("（", "").replace("）", "")
    clean = clean.replace("(", "").replace(")", "")
    clean = re.sub(r"(?m)^[\s，,、；;：:]+", "", clean)
    clean = re.sub(r"[ \t]+\n", "\n", clean)
    clean = re.sub(r"\n{3,}", "\n\n", clean)
    return clean.strip()


_ROLEPLAY_INLINE_QUOTE_RE = re.compile(r'“[^”]+”|"[^"]+"')
_SEMANTIC_TEXT_RE = re.compile(r"[A-Za-z0-9\u3400-\u9fff]")


def normalize_generated_reply(reply: str, reply_mode: str) -> str:
    """清理模型从旧语音历史误学到的传输标签，并恢复被误包成旁白的台词。

    旧历史曾把 assistant 语音写成 ``[语音回复] 正文``。模型偶尔会照抄并在
    剧情模式输出 ``（[语音回复] 正文）``；这段实际是可朗读台词，不是动作。
    """
    raw = reply or ""
    had_voice_marker = bool(re.search(r"\[\s*语音回复\s*\]", raw))
    clean = strip_internal_reply_markers(raw)
    if reply_mode == "roleplay" and had_voice_marker:
        if (
            (clean.startswith("（") and clean.endswith("）"))
            or (clean.startswith("(") and clean.endswith(")"))
        ):
            clean = clean[1:-1].strip()
        clean = clean.strip('“”"')
    return clean


_ACCEPT_KW = ("收下", "谢谢", "收到", "好哒", "感谢", "那就收", "我收")
_REJECT_KW = ("不收", "婉拒", "退回", "退给你", "不能收", "心意领了", "不好意思")


def parse_transfer_decision(reply: str) -> tuple[bool | None, str]:
    """解析转账回复的收下/婉拒决定 → (决定, 剥离标记后的干净回复)。

    - 前缀 ``[接受]``/``[婉拒]`` 优先（提示词已要求模型在回复最前面写标记）；
    - 无标记 → 在回复开头 40 字内做关键词兜底（收下类=接受、婉拒类=拒绝），
      再往后不扫，避免正文里偶然出现的「谢谢」误判；
    - 仍不明 → (None, 原文)，调用方默认按接受处理（与旧行为一致）。
    决定只适用于转账消息；红包不解析（恒接受致谢）。
    """
    text = (reply or "").strip()
    if text.startswith("[接受]"):
        return True, text[len("[接受]") :].lstrip()
    if text.startswith("[婉拒]"):
        return False, text[len("[婉拒]") :].lstrip()
    head = text[:40]
    for kw in _REJECT_KW:
        if kw in head:
            return False, text
    for kw in _ACCEPT_KW:
        if kw in head:
            return True, text
    return None, text


def _balanced_roleplay_parentheses(value: str) -> bool:
    depth = 0
    for char in value.replace("(", "（").replace(")", "）"):
        if char == "（":
            depth += 1
        elif char == "）":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def _roleplay_spoken_text(value: str) -> str:
    """剧情新格式：移除括号叙述后，剩余裸文本就是角色说出口的台词。"""
    spoken = re.sub(r"（[^（）]*）|\([^()]*\)", " ", value or "")
    spoken = spoken.replace("（", " ").replace("）", " ")
    spoken = spoken.replace("(", " ").replace(")", " ")
    spoken = spoken.replace("“", "").replace("”", "").replace('"', "")
    spoken = re.sub(r"[ \t]+", " ", spoken)
    spoken = re.sub(r"\s*\n\s*", "\n", spoken)
    spoken = re.sub(r"\s+([，。！？、；：,.!?;:])", r"\1", spoken)
    return spoken.strip()


def roleplay_reply_needs_format(
    reply: str,
    *,
    require_spoken: bool = False,
) -> bool:
    value = (reply or "").strip()
    if not value:
        return False
    # 新契约中对话不加引号；旧格式或模型遗留引号必须统一剥除。
    if any(mark in value for mark in ('“', '”', '"')):
        return True
    if not _balanced_roleplay_parentheses(value):
        return True
    # 验收批3③：长文裸旁白——完全无括号说明叙述被当裸文本输出（新契约漏生效或
    # 响应截断），超长即触发重排；语音路径（require_spoken）本就期望长裸台词，跳过。
    if not require_spoken and "（" not in value and len(value) > 120:
        return True
    return require_spoken and not _roleplay_spoken_text(value)


def _fallback_roleplay_format(
    reply: str,
    *,
    require_spoken: bool = False,
) -> str:
    """格式服务失败时兜底：括号保留叙述，旧引号台词改成裸台词。"""
    formatted: list[str] = []
    source = reply or ""
    has_legacy_quotes = bool(_ROLEPLAY_INLINE_QUOTE_RE.search(source))
    for block in [p.strip() for p in re.split(r"\n\s*\n+", source) if p.strip()]:
        matches = list(_ROLEPLAY_INLINE_QUOTE_RE.finditer(block))
        if matches:
            cursor = 0
            for match in matches:
                narration = block[cursor : match.start()].strip(" \n：:")
                if narration:
                    formatted.append(f"（{narration.strip('（）()')}）")
                formatted.append(match.group(0)[1:-1].strip())
                cursor = match.end()
            tail = block[cursor:].strip(" \n：:")
            if tail:
                formatted.append(f"（{tail.strip('（）()')}）")
            continue

        value = block.replace("(", "（").replace(")", "）")
        # 若整篇仍是旧“引号台词”格式，同篇未加引号的块按旁白处理。
        if has_legacy_quotes and "（" not in value and "）" not in value:
            formatted.append(f"（{value}）")
            continue

        # 丢掉多余闭括号，补齐未闭合左括号；不会把台词截断。
        balanced: list[str] = []
        depth = 0
        for char in value:
            if char == "（":
                depth += 1
                balanced.append(char)
            elif char == "）":
                if depth > 0:
                    depth -= 1
                    balanced.append(char)
            else:
                balanced.append(char)
        balanced.extend("）" for _ in range(depth))
        normalized = "".join(balanced).strip().strip('“”"')
        if normalized:
            formatted.append(normalized)
    result = "\n\n".join(formatted)
    if require_spoken and not _roleplay_spoken_text(result):
        # 最后的确定性保险：绝不朗读旁白；模型只给动作时，追加最短自然台词，
        # 让“绿色=必须语音回复”成为服务端契约而不是提示词愿望。
        result = f"{result}\n\n嗯，我在。".strip()
    return result


def enforce_roleplay_format(
    reply: str,
    *,
    require_spoken: bool = False,
) -> str:
    """剧情输出格式校验：台词裸写，其他内容全部在中文圆括号内。"""
    if not roleplay_reply_needs_format(reply, require_spoken=require_spoken):
        return reply
    fallback = _fallback_roleplay_format(reply, require_spoken=require_spoken)
    if not config.DEEPSEEK_API_KEY:
        return fallback
    try:
        response = httpx.post(
            "https://api.deepseek.com/chat/completions",
            headers={
                "Authorization": f"Bearer {config.DEEPSEEK_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "deepseek-chat",
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "你只做格式整理，不增删、不改写任何剧情信息。角色真正说出口的台词"
                            "直接写，不添加中文或英文引号；把动作、神态、心理、环境和叙述分别"
                            "完整放进中文圆括号（）。叙述不能裸露在括号外，台词不能放进括号。"
                            + (
                                "本轮必须至少保留一段可朗读台词；如果原文有直接表达但没有引号，"
                                "把最像角色说话的内容保留为裸台词，不能把整篇都归为旁白。"
                                if require_spoken
                                else ""
                            )
                            +
                            "输出严格 JSON：{\"reply\":\"格式化后的全文\"}。"
                        ),
                    },
                    {"role": "user", "content": reply},
                ],
                "response_format": {"type": "json_object"},
                "temperature": 0,
                "stream": False,
            },
            timeout=60,
        )
        response.raise_for_status()
        rewritten = str(
            json.loads(response.json()["choices"][0]["message"].get("content") or "{}")
            .get("reply")
            or ""
        ).strip()
        if rewritten and not roleplay_reply_needs_format(
            rewritten,
            require_spoken=require_spoken,
        ):
            return rewritten
    except Exception:
        logger.exception("剧情回复格式校验失败，使用确定性括号格式兜底")
    return fallback


def _has_semantic_text(value: str) -> bool:
    return bool(_SEMANTIC_TEXT_RE.search(value or ""))


def _merge_contiguous_parts(parts: list[str], limit: int) -> list[str]:
    """把过多碎片按连续语义均衡合并；绝不产出单独标点。"""
    values = [part for part in parts if _has_semantic_text(part)]
    if len(values) <= limit:
        return values
    groups: list[str] = []
    cursor = 0
    while cursor < len(values) and len(groups) < limit:
        groups_left = limit - len(groups)
        items_left = len(values) - cursor
        if groups_left == 1:
            groups.append("".join(values[cursor:]))
            break
        target = sum(len(item) for item in values[cursor:]) / groups_left
        chunk: list[str] = []
        size = 0
        while cursor < len(values):
            items_after = len(values) - (cursor + 1)
            if chunk and size >= target and items_after >= groups_left - 1:
                break
            item = values[cursor]
            chunk.append(item)
            size += len(item)
            cursor += 1
            if len(values) - cursor == groups_left - 1:
                break
        groups.append("".join(chunk))
    return groups


def _split_realtime_naturally(text: str, limit: int) -> list[str]:
    """漏分隔符时按完整语义分组，不再机械地“一句一个气泡”。"""
    clean = text.strip()
    if limit <= 1:
        return [clean]
    sentences = [
        part.strip()
        for part in re.findall(r"[^。！？!?…\n]+(?:[。！？!?]+|…+)?", clean)
        if _has_semantic_text(part)
    ]
    if len(sentences) <= 1:
        return [clean]
    # 用户明确选择的是目标条数，不再按内容长度自行缩减；如果模型漏了分隔符，
    # 只要有足够的完整句子，就均衡补回所选气泡数。
    natural_limit = min(limit, len(sentences))
    return _merge_contiguous_parts(sentences, natural_limit)


def split_reply_segments(
    reply: str,
    reply_mode: str,
    *,
    require_spoken: bool = False,
    reply_bubble_count: int = 3,
) -> list[str]:
    """现实模式按语义拆微信气泡；剧情模式保留一条且台词不加引号。"""
    clean = normalize_generated_reply(reply, reply_mode).strip()
    if not clean:
        return []
    if reply_mode != "realtime":
        roleplay = clean.replace(prompts.REALTIME_BUBBLE_SEPARATOR, "\n\n").strip()
        return [
            enforce_roleplay_format(
                roleplay,
                require_spoken=require_spoken,
            )
        ]
    limit = max(1, min(int(reply_bubble_count or 1), 5))
    has_separator = prompts.REALTIME_BUBBLE_SEPARATOR in clean
    if has_separator:
        raw_parts = clean.split(prompts.REALTIME_BUBBLE_SEPARATOR)
    else:
        raw_parts = re.split(r"\n\s*\n+", clean)
    sanitized = []
    for part in raw_parts:
        value = _clean_realtime_segment(part).strip('“”"').strip()
        if _has_semantic_text(value):
            sanitized.append(value)
    if not has_separator and len(sanitized) == 1:
        sanitized = _split_realtime_naturally(sanitized[0], limit)
    sanitized = _merge_contiguous_parts(sanitized, limit)
    return sanitized or ["嗯，我在听。"]


def reply_output_metrics(
    reply: str,
    reply_mode: str,
    *,
    reply_bubble_count: int = 1,
) -> tuple[int, int]:
    """统计用户真正看到的非空字符数与有效气泡数，供生成结果闭环校验。"""
    normalized = normalize_generated_reply(reply, reply_mode)
    visible = normalized.replace(prompts.REALTIME_BUBBLE_SEPARATOR, "")
    visible_chars = len(re.sub(r"\s+", "", visible))
    bubbles = split_reply_segments(
        normalized,
        reply_mode,
        reply_bubble_count=reply_bubble_count,
    )
    return visible_chars, len(bubbles)


def reply_needs_regeneration(
    reply: str,
    reply_mode: str,
    *,
    reply_max_chars: int,
    reply_bubble_count: int,
    voice_reply_requested: bool = False,
    finish_reason: str | None = None,
    policy: dict | None = None,
) -> bool:
    """是否重写一次回复。

    - policy 非空（状态引擎 realtime 路径）：去掉相对地板，只防空 + 防截断——
      “干嘛😶”不再被 85% 规则硬补成长文（B 最关键改动）。
    - policy 为空（roleplay / 老调用方）：保持原有 85% 字数/气泡行为，逐字节兼容。
    """
    visible_chars, bubbles = reply_output_metrics(
        reply,
        reply_mode,
        reply_bubble_count=reply_bubble_count,
    )
    if reply_mode == "realtime" and policy is not None:
        # 退化护栏：空回复 / 纯标点。
        if visible_chars == 0:
            return True
        if not re.search(r"[^\W\d]", reply):
            return True
        # 截断护栏：max_tokens 命中长度上限。
        if finish_reason == "length":
            return True
        # 短策略不硬拆气泡（「嗯」不强制重写）。
        if policy.get("length_bias") in ("very_short", "short"):
            return False
        # 中长策略保留气泡数检查，但不再有字符地板。
        return (
            not voice_reply_requested
            and reply_bubble_count > 1
            and bubbles < reply_bubble_count
        )
    # “约 N 字”允许少量自然浮动；低于 85% 才认为没有落实用户设置。
    if visible_chars < max(1, int(reply_max_chars * 0.85)):
        return True
    # 语音回复最终是一个微信语音气泡，不强行拆成多个音频；文字回复按所选目标条数。
    return (
        reply_mode == "realtime"
        and not voice_reply_requested
        and reply_bubble_count > 1
        and bubbles < reply_bubble_count
    )


def build_reply_regeneration_request(
    reply: str,
    reply_mode: str,
    *,
    reply_max_chars: int,
    reply_bubble_count: int,
    policy: dict | None = None,
) -> str:
    """把不足原因明确回送给同一模型，要求重新完整输出而不是在末尾续写。"""
    visible_chars, bubbles = reply_output_metrics(
        reply,
        reply_mode,
        reply_bubble_count=reply_bubble_count,
    )
    # 状态引擎路径（B）：去掉“不得明显低于目标”的补句话术；短策略强调自然简短。
    if reply_mode == "realtime" and policy is not None:
        if policy.get("length_bias") in ("very_short", "short"):
            return (
                "上一版回复被截断了或不够自然，请重新完整回复我上一条消息："
                "保持简短自然、像随手回朋友（1-2 句），不要在旧答案后续写。"
                "继续严格遵守既定人格、关系边界和所有事实约束。"
                "不要解释修改过程，只输出新的最终回复。"
            )
        shape = (
            "只输出一条完整消息，不使用分隔符"
            if reply_bubble_count == 1
            else f"恰好输出 {reply_bubble_count} 条有效消息，并使用 "
            f"{reply_bubble_count - 1} 个 {prompts.REALTIME_BUBBLE_SEPARATOR} 分隔"
        )
        return (
            f"上一版回复被截断了或内容不完整，请重新完整回答我上一条消息，不要在旧答案后续写。"
            f"保持约 {policy.get('chars_range', [0, 300])[1]} 字以内的完整回复；{shape}。"
            "继续严格遵守既定人格、关系边界和所有事实约束。"
            "不要解释修改过程，只输出新的最终回复。"
        )
    if reply_mode == "realtime":
        shape = (
            "只输出一条完整消息，不使用分隔符"
            if reply_bubble_count == 1
            else f"恰好输出 {reply_bubble_count} 条有效消息，并使用 "
            f"{reply_bubble_count - 1} 个 {prompts.REALTIME_BUBBLE_SEPARATOR} 分隔"
        )
    else:
        shape = "只输出一条连贯的剧情回复，不使用气泡分隔符"
    return (
        f"上一版只有约 {visible_chars} 个可见字符、{bubbles} 条有效消息，没有落实我的发送设置。"
        f"请重新完整回答我上一条消息，不要在旧答案后续写。成品目标约 {reply_max_chars} 字，"
        f"且不得明显低于该目标；{shape}。继续严格遵守既定人格、关系边界、现实/剧情格式和"
        "所有事实约束。不要解释修改过程，只输出新的最终回复。"
    )


def spoken_text_for_tts(reply: str, reply_mode: str) -> str:
    """从完整回复中提取真正说出口的内容，TTS 永不朗读动作、旁白或环境。

    - 现实聊天：确定性清掉括号动作和系统分隔符，朗读自然短句。
    - 剧情/穿越：移除圆括号叙述，只朗读括号外的裸台词。
    """
    value = normalize_generated_reply(reply, reply_mode)
    value = value.replace(prompts.REALTIME_BUBBLE_SEPARATOR, "\n").strip()
    if not value:
        return ""
    if reply_mode == "roleplay":
        value = _roleplay_spoken_text(value)
    else:
        value = _clean_realtime_segment(value)

    # 即使模型把动作误塞进台词，也不让括号/方括号说明进入语音。
    value = re.sub(r"[（(][^（）()\n]{0,300}[）)]", "", value)
    value = re.sub(r"\[[^\[\]\n]{0,160}\]", "", value)
    value = value.replace("（", "").replace("）", "")
    value = value.replace("(", "").replace(")", "")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()
