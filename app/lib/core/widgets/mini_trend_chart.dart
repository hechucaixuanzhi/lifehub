import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 迷你趋势条形图（自绘，简洁克制，对齐「禁止信息过载」）。
/// 展示最近 N 天的数值分布，条形高度按最大值归一化。
class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({
    super.key,
    required this.values,
    required this.color,
    this.labels,
    this.height = 80,
  });

  /// 每天一个值（如每日学习分钟 / 每日里程）。
  final List<double> values;
  final Color color;

  /// 每根条下方的标签（可选，如日期）。
  final List<String>? labels;

  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    return SizedBox(
      height: height + 20, // 图表 + 标签区
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 条形
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: maxV <= 0
                        ? 2
                        : (values[i] / maxV) * (height - 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.35 + 0.65 * (values[i] / (maxV <= 0 ? 1 : maxV))),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 标签
                  if (labels != null && i < labels!.length)
                    Text(
                      labels![i],
                      style: const TextStyle(fontSize: 9, color: AppColors.muted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
