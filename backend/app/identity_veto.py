"""身份语义拒否层（018）—— MiMo caption 文本 → 本地关键词分类。

用户硬需求：非本人图片（尤其表情包/卡通/AI 假脸/性别年龄明显不符）绝不能误判
为「确定是我」（SELF）。设计稿核心原则「LLM 不负责认脸」依然成立：身份比对仍由
前端本地 embedding（192d 指纹）+ 后端纯 stdlib 余弦完成；本层只是在 /ai/chat
图片分支把**已经生成**的 MiMo 自由描述（caption）做本地关键词兜底，否决掉
「明显不是真实年轻东亚女性」的情况。零新增 MiMo 调用、零新增依赖。

为什么不用 MiMo 直接裁决：实测 mimo-v2.5 对强制格式 prompt（是/否/一行）经常返回
空内容，自由描述可靠但无判别力（同团异人被误判同人、真人姓名被幻觉成别人）。
因此语义层只做**粗粒度 plausibility 闸门**，细粒度身份留给指纹。见
memory/lifehub-self-identity.md。

保守原则（fail-open）：没命中任何拒否特征 → PASS，绝不误伤真实照片；
拒否优先级：非真人 > 性别明显不符 > 年龄段明显不符。
比喻守卫：caption 含「像…一样」等比喻词时，真人夸赞句式（"像动漫少女一样精致"）
不再触发拒否，防止误伤真实偶像照片。
"""
from __future__ import annotations

# 强非真人特征（动漫/绘画/AI/雕塑等）。匹配前会去掉空格、统一小写。
_NON_REAL = [
    "动漫", "卡通", "漫画", "二次元", "插画", "手绘", "素描", "油画", "水彩",
    "雕像", "雕塑", "手办", "假人", "木偶", "泥塑",
    "ai生成", "生成式", "人工智能", "数字人", "虚拟人物", "虚拟偶像", "虚拟形象",
    "纸片人", "赛璐璐",
]
# 性别明显不符（男性特征）
_GENDER_MALE = [
    "男性", "男人", "男子", "男士", "男青年", "年轻男性", "男歌手", "男艺人",
    "男明星", "男生", "男孩", "男童", "小伙子", "大叔", "大哥", "小哥", "叔叔",
    "爷爷", "老爷爷", "老头", "大爷", "老先生",
]
# 年龄段明显不符（老/幼）
_AGE_MISMATCH = [
    "老年", "老人", "老年人", "老太太", "老奶奶", "老爷爷", "老者", "中老年",
    "白发苍苍", "儿童", "小孩", "小女孩", "小男孩", "婴幼儿", "婴儿", "幼儿",
    "幼童", "孩童",
]
# 女性信号（用于比喻守卫：真人被夸"像动漫/像男生"时放行）
_FEMALE_SIGNAL = [
    "女性", "女孩", "少女", "女生", "女子", "姑娘", "女歌手", "女艺人", "女明星",
    "姐姐", "小姐", "小姐姐", "女神",
]
# 比喻句式守卫：命中 → 关键词多为夸赞修辞，不拒否
# 单字"像"单独判断（须排除"肖像/雕像/塑像/画像"等复合词，见 _has_simile）。
_SIMILE = ["如同", "犹如", "宛如", "似的", "一样", "仿佛", "好像", "就像", "像是", "像极", "看起来像", "长得像"]
_SIMILE_COMPOUND_PREFIX = "肖雕塑铜画影图"  # 前一字为这些 → "像"是复合词（肖像/雕像…），非比喻

_GATE_LABEL = {"non_real": "非真人照片", "gender_mismatch": "性别明显不符", "age_mismatch": "年龄段明显不符"}


def _has_simile(text: str) -> bool:
    """是否为比喻句式。多字比喻词直接命中；单字"像"须排除复合词（肖像/雕像…）。"""
    for s in _SIMILE:
        if s in text:
            return True
    for i, ch in enumerate(text):
        if ch == "像":
            if i > 0 and text[i - 1] in _SIMILE_COMPOUND_PREFIX:
                continue
            return True
    return False


def classify(caption: str | None) -> dict:
    """对一句 MiMo 描述做语义闸门分类。

    返回 {"vetoed": bool, "gate": "non_real"|"gender_mismatch"|"age_mismatch"|None,
          "reason": str|None}。没命中 → vetoed=False（fail-open）。
    """
    if not caption or not caption.strip():
        return {"vetoed": False, "gate": None, "reason": None}
    text = caption.replace(" ", "").strip()  # "AI 生成"→"AI生成"
    low = text.lower()
    simile = _has_simile(text)
    has_female = any(s in text for s in _FEMALE_SIGNAL)

    for m in _NON_REAL:
        if m in low:
            # 比喻守卫：真人才会用"像动漫一样"夸赞，放行
            if simile:
                break
            return {"vetoed": True, "gate": "non_real",
                    "reason": f"{_GATE_LABEL['non_real']}·{m}"}
    for m in _GENDER_MALE:
        if m in text:
            if simile and has_female:
                break  # "像男生一样帅气的女生" → 真人，放行
            return {"vetoed": True, "gate": "gender_mismatch",
                    "reason": f"{_GATE_LABEL['gender_mismatch']}·{m}"}
    for m in _AGE_MISMATCH:
        if m in text:
            if simile and has_female:
                break
            return {"vetoed": True, "gate": "age_mismatch",
                    "reason": f"{_GATE_LABEL['age_mismatch']}·{m}"}
    return {"vetoed": False, "gate": None, "reason": None}


def apply_veto(si: dict, caption: str | None) -> dict:
    """对 /ai/self-identity/check 的结构化结果应用语义拒否。

    命中 → 复制结果并把 identity_state 降为 UNKNOWN、confidence 清零、
    附 veto_reason（prompts.build_self_identity_prompt 会展示）。未命中 → 原样返回。
    """
    veto = classify(caption)
    if not veto["vetoed"]:
        return si
    out = dict(si)
    out["identity_state"] = "UNKNOWN"
    out["confidence"] = 0.0
    out["veto_reason"] = veto["reason"]
    return out
