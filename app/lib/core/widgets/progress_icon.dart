import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'status_icon.dart';

/// 进度图标（学习/运动模块网格单元，同范式复用 StatusIcon 填充核）。
/// 与 HabitIcon 的区别：进度展示为主、名称小字可选（学习/运动场景常带副标题）。
class ProgressIcon extends StatelessWidget {
  const ProgressIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.progress,
    required this.name,
    this.subtitle,
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
  final String? subtitle;
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
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
        ],
      ],
    );
  }
}
