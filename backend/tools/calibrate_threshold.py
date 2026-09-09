"""自我识别阈值校准工具（017_self_identity，设计稿 §5）—— 纯 stdlib。

阈值不硬编码，走校准：SELF 阈值 = 最高负样本相似度 + 安全距离（margin）；
负样本与本人重叠区 → POSSIBLE_SELF；低于该区 → UNKNOWN。

运行（容器内）：
  # 真实数据：从参考图 embedding 算相似度后传入（正样本=本人同人分布，负样本=他人分布）
  docker exec lifehub-backend python tools/calibrate_threshold.py \
      --pos "0.72,0.78,0.81,0.86" --neg "0.25,0.38,0.45,0.55"

  # 无真实数据：合成分布演示链路（正 0.85~0.95 / 负 0.1~0.3）
  docker exec lifehub-backend python tools/calibrate_threshold.py --synthetic

校准结果写入 AppSetting（self_identity_self_threshold / self_identity_possible_threshold），
前端 /ai/self-identity/status 可读，后续可手工调整。
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import self_identity  # noqa: E402


def _parse_floats(raw: str, name: str) -> list[float]:
    vals = [float(x.strip()) for x in raw.split(",") if x.strip()]
    if not vals:
        raise SystemExit(f"--{name} 需要至少一个数值")
    return vals


def main() -> None:
    ap = argparse.ArgumentParser(description="自我识别阈值校准（设计稿 §5）")
    ap.add_argument("--pos", help="正样本相似度列表，逗号分隔（本人同人分布）")
    ap.add_argument("--neg", help="负样本相似度列表，逗号分隔（他人分布）")
    ap.add_argument("--margin", type=float, default=0.08, help="SELF 安全距离（默认 0.08）")
    ap.add_argument("--synthetic", action="store_true", help="用合成分布跑通链路")
    args = ap.parse_args()

    if args.synthetic:
        pos = [0.86, 0.88, 0.90, 0.92, 0.94]
        neg = [0.12, 0.18, 0.22, 0.27, 0.30]
        print("[演示] 使用合成分布：正(同人) 0.85~0.95 / 负(他人) 0.1~0.3")
    elif args.pos and args.neg:
        pos = _parse_floats(args.pos, "pos")
        neg = _parse_floats(args.neg, "neg")
    else:
        ap.print_help()
        raise SystemExit("需提供 --pos/--neg，或 --synthetic")

    if min(pos) < max(neg):
        print("[提示] 正/负分布存在重叠区 → 重叠区将划为 POSSIBLE_SELF（不硬认）")

    result = self_identity.calibrate(pos, neg, margin=args.margin)
    print("\n正样本分布:", result["stats"]["pos"])
    print("负样本分布:", result["stats"]["neg"])
    print(f"\nSELF 阈值     = {result['self_threshold']}   (最高负样本 + margin)")
    print(f"POSSIBLE 阈值 = {result['possible_threshold']}   (正负分布边界)")
    print("\n已写入 AppSetting（self_identity_self_threshold / self_identity_possible_threshold）")
    print("三态判定：similarity >= SELF → SELF；SELF > x >= POSSIBLE → POSSIBLE_SELF；< POSSIBLE → UNKNOWN")


if __name__ == "__main__":
    main()
