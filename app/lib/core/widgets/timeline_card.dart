import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 时间线卡片（对齐原型 `.tl`）：左侧圆点 + 竖线，右侧类型 chip + 内容 + 时间。
/// 用于宠物时间线、历史记录列表。
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.chip,
    required this.content,
    required this.time,
    this.isLast = false,
    this.onTap,
    this.trailing,
  });

  final String chip; // 类型（如「进食」「体重」）
  final String content;
  final String time;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间轴圆点 + 竖线
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                  ),
                  if (!isLast)
                    Container(width: 1, height: 40, color: const Color(0xFFECEEEA)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF0EC),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(chip,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                  const SizedBox(height: 4),
                  Text(content, style: AppTypography.body),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
