import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'status_icon.dart';

/// 习惯图标（生活模块网格单元）：StatusIcon + 常驻名称小字。
/// 名称小字可通过「我的-外观-显示图标名称」隐藏（showLabel 参数控制）。
class HabitIcon extends StatelessWidget {
  const HabitIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.progress,
    required this.name,
    this.fillIcon,
    this.running = false,
    this.reached = false,
    this.showLabel = true,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final double progress;
  final String name;
  final IconData? fillIcon;
  final bool running;
  final bool reached;
  final bool showLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusIcon(
          icon: icon,
          fillIcon: fillIcon,
          color: color,
          progress: progress,
          running: running,
          reached: reached,
          badge: badge,
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label,
          ),
        ],
      ],
    );
  }
}
