"""自我识别模块（017_self_identity）—— 后端纯 stdlib 相似度引擎 + 三态判定。

设计稿 docs/DESIGN_SELF_IDENTITY.md v1.0：
- 核心原则：**LLM 不负责认脸**。前端本地检测 + embedding（MobileFaceNet/ArcFace 512d），
  后端只做相似度比对与判定，结果结构化喂 LLM。
- 身份库 face_gallery：embedding 存 **BLOB float32**（`struct.unpack('=512f')` 解析，约 2KB/张）。
- 三态判定 SELF / POSSIBLE_SELF / UNKNOWN：**阈值不硬编码**，走校准（见 calibrate()），
  校准结果写 AppSetting（self_identity_* 键），未校准时用保守默认兜底。
- 0 新增依赖：struct + math + 纯 Python 余弦，不引 numpy/onnx。
"""
import math
import struct
from datetime import datetime, timezone

from app import db
from app.models import AppSetting, FaceGallery

# embedding 维度 = 具体模型输出决定（实测 mobile_face_net.tflite = 192d）。
# 设计稿初版建议 512d，但可用轻量模型（5.2MB，社区最广泛 Flutter 人脸识别模型）
# 输出 192 维；512d 模型（face_net_512.tflite）24MB 过大。192 维在人脸识别领域
# 是成熟选择，阈值走校准与维度无关 → 前端换模型只需改这里。
EMBED_DIM = 192
_FMT = "=" + "f" * EMBED_DIM  # '=' 标准大小对齐，float32
_FMT_SIZE = struct.calcsize(_FMT)

# AppSetting 键（校准结果，工具 tools/calibrate_threshold.py 写入）
K_SELF = "self_identity_self_threshold"
K_POSSIBLE = "self_identity_possible_threshold"

# 未校准兜底阈值（保守：宁可 UNKNOWN 也不硬认）。仅占位，正式值由校准产出。
_DEFAULT_SELF = 0.62
_DEFAULT_POSSIBLE = 0.50


def pack_embedding(vec: list[float]) -> bytes:
    """list[float] → float32 原始字节（BLOB）。维度必须恰为 EMBED_DIM。"""
    if len(vec) != EMBED_DIM:
        raise ValueError(f"embedding 维度必须为 {EMBED_DIM}，实际 {len(vec)}")
    return struct.pack(_FMT, *vec)


def unpack_embedding(blob: bytes) -> list[float]:
    """BLOB → list[float]（float32×512）。长度不符抛 ValueError。"""
    if len(blob) != _FMT_SIZE:
        raise ValueError(f"embedding BLOB 长度应为 {_FMT_SIZE}，实际 {len(blob)}")
    return list(struct.unpack(_FMT, blob))


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """纯 stdlib 余弦相似度。零向量返回 0.0（无信息）。"""
    if len(a) != len(b):
        raise ValueError(f"维度不一致 {len(a)} vs {len(b)}")
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (na * nb)


# --------------------------------------------------------------------------- #
# 阈值：AppSetting 持久化（可调），未校准用保守默认
# --------------------------------------------------------------------------- #
def get_thresholds() -> dict:
    """读校准阈值 {self, possible}。未校准 → 保守默认（不硬认）。"""
    out = {"self": _DEFAULT_SELF, "possible": _DEFAULT_POSSIBLE}
    with db.SessionLocal() as s:
        for key, default in ((K_SELF, _DEFAULT_SELF), (K_POSSIBLE, _DEFAULT_POSSIBLE)):
            row = s.query(AppSetting).filter_by(key=key).first()
            if row and row.value:
                try:
                    out["self" if key == K_SELF else "possible"] = float(row.value)
                except ValueError:
                    pass
    return out


def set_thresholds(self_threshold: float, possible_threshold: float) -> None:
    """写入校准结果（tools/calibrate_threshold.py 调用）。"""
    with db.SessionLocal() as s:
        for key, val in ((K_SELF, self_threshold), (K_POSSIBLE, possible_threshold)):
            row = s.query(AppSetting).filter_by(key=key).first()
            if row:
                row.value = str(val)
            else:
                s.add(AppSetting(key=key, value=str(val)))
        s.commit()


def is_calibrated() -> bool:
    """是否已跑过阈值校准（AppSetting 中有 self_identity_* 键）。"""
    with db.SessionLocal() as s:
        return s.query(AppSetting).filter(
            AppSetting.key.in_([K_SELF, K_POSSIBLE])
        ).count() > 0


def classify(similarity: float) -> str:
    """单点相似度 → 三态。SELF ≥ self；possible ≤ x < self → POSSIBLE_SELF；< possible → UNKNOWN。"""
    th = get_thresholds()
    if similarity >= th["self"]:
        return "SELF"
    if similarity >= th["possible"]:
        return "POSSIBLE_SELF"
    return "UNKNOWN"


def calibrate(pos_sims: list[float], neg_sims: list[float], margin: float = 0.08) -> dict:
    """按正/负样本相似度分布定阈值（设计稿 §5），并写入 AppSetting。

    - possible_threshold = 正负分布边界 min(min(pos), max(neg))：低于此必然 UNKNOWN。
    - self_threshold     = max(neg) + margin（最高负样本 + 安全距离），且不低于 possible+margin。
    - 负样本与本人之间有重叠区 → 重叠区整段划为 POSSIBLE_SELF（不硬认）。
    - margin 默认 0.08，可调；分布完全分离时阈值自然落在合理处。
    """
    if not pos_sims or not neg_sims:
        raise ValueError("校准需要正样本与负样本相似度分布")
    min_pos, max_pos = min(pos_sims), max(pos_sims)
    min_neg, max_neg = min(neg_sims), max(neg_sims)
    possible_threshold = min(min_pos, max_neg)
    self_threshold = max(max_neg + margin, possible_threshold + margin)
    set_thresholds(self_threshold, possible_threshold)
    return {
        "self_threshold": round(self_threshold, 4),
        "possible_threshold": round(possible_threshold, 4),
        "stats": {
            "pos": {"min": round(min_pos, 4), "max": round(max_pos, 4), "n": len(pos_sims)},
            "neg": {"min": round(min_neg, 4), "max": round(max_neg, 4), "n": len(neg_sims)},
        },
    }


# --------------------------------------------------------------------------- #
# 身份库读写
# --------------------------------------------------------------------------- #
def add_gallery_entry(character_id: str, embedding: list[float],
                      sub_identity: str | None = None,
                      source_asset_id: str | None = None) -> dict:
    """导入一张参考图 embedding 入身份库（M1 导入）。返回入库行 dict。"""
    if len(embedding) != EMBED_DIM:
        raise ValueError(f"embedding 维度必须为 {EMBED_DIM}，实际 {len(embedding)}")
    row = FaceGallery(
        character_id=character_id,
        sub_identity=sub_identity,
        embedding=pack_embedding(embedding),
        source_asset_id=source_asset_id,
    )
    with db.SessionLocal() as s:
        s.add(row)
        s.commit()
        return {"id": row.id, "character_id": row.character_id,
                "sub_identity": row.sub_identity, "source_asset_id": row.source_asset_id}


def list_gallery(character_id: str) -> list[dict]:
    """身份库列表（不含 embedding 本体，只给元信息）。"""
    with db.SessionLocal() as s:
        rows = (s.query(FaceGallery).filter_by(character_id=character_id)
                .order_by(FaceGallery.created_at.desc()).all())
        return [{"id": r.id, "sub_identity": r.sub_identity,
                 "source_asset_id": r.source_asset_id,
                 "created_at": r.created_at.isoformat() if r.created_at else None}
                for r in rows]


def clear_gallery(character_id: str) -> int:
    """清空某角色身份库（重新导入用）。返回删除条数。"""
    with db.SessionLocal() as s:
        n = s.query(FaceGallery).filter_by(character_id=character_id).delete()
        s.commit()
        return n


def gallery_vectors(character_id: str) -> list[list[float]]:
    """身份库全部 embedding 向量（阈值校准用，不解 BLOB 的直接通道）。"""
    with db.SessionLocal() as s:
        rows = (s.query(FaceGallery).filter_by(character_id=character_id).all())
    return [unpack_embedding(r.embedding) for r in rows]


# --------------------------------------------------------------------------- #
# check：前端每脸 embedding → 三态结构化结果（设计稿 §4.2）
# --------------------------------------------------------------------------- #
def check_faces(faces: list[dict], character_id: str = "companion") -> dict:
    """faces: [{"embedding": [512 floats]}, ...]（前端 ML Kit 检测 + 本地模型逐脸提取）。

    返回设计稿 §4.2 结构化结果：
      {identity_state, confidence, faces: [{face_id, is_self, similarity, sub_identity}],
       gallery_size}
    - identity_state 取相似度最高的那张脸的三态（多脸合影时"图里有没有自己"）。
    - 身份库为空 → UNKNOWN（gallery_size=0），不硬认。
    - 无有效脸 → UNKNOWN。
    """
    with db.SessionLocal() as s:
        rows = (s.query(FaceGallery).filter_by(character_id=character_id).all())
    if not rows:
        return {"identity_state": "UNKNOWN", "confidence": 0.0,
                "faces": [], "gallery_size": 0}
    gallery = [{"sub_identity": r.sub_identity, "vec": unpack_embedding(r.embedding)} for r in rows]

    results: list[dict] = []
    best_sim, best_state = 0.0, "UNKNOWN"
    for idx, f in enumerate(faces):
        vec = f.get("embedding") or []
        if len(vec) != EMBED_DIM:
            continue
        sim = max(cosine_similarity(vec, g["vec"]) for g in gallery)
        best_g = max(gallery, key=lambda g: cosine_similarity(vec, g["vec"]))
        state = classify(sim)
        results.append({
            "face_id": idx + 1,
            "is_self": state == "SELF",
            "similarity": round(sim, 4),
            "sub_identity": best_g["sub_identity"],
        })
        if sim > best_sim:
            best_sim, best_state = sim, state
    if not results:
        return {"identity_state": "UNKNOWN", "confidence": 0.0,
                "faces": [], "gallery_size": len(gallery)}
    return {
        "identity_state": best_state,
        "confidence": round(best_sim, 4),
        "faces": results,
        "gallery_size": len(gallery),
    }
