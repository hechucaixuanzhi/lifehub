import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// AI 记忆类型 → 语义色与中文名（验收批3④：偏好/事实/禁止/事件颜色区分）。
/// 仅用于徽标/芯片，不用于按钮。三处共享：记忆页徽标、新增/编辑弹窗、
/// 收藏弹窗类型选择。

String memoryTypeLabel(String? type) => switch (type) {
      'preference' => '偏好',
      'fact' => '事实',
      'forbidden' => '禁止事项',
      'event' => '事件',
      _ => '事实',
    };

/// 类型主色（实心文字/图标用）。
Color memoryTypeColor(String? type) => switch (type) {
      'preference' => AppColors.memoryPreference,
      'forbidden' => AppColors.memoryBan,
      'event' => AppColors.memoryEvent,
      _ => AppColors.memoryFact,
    };

/// 类型浅底（芯片/徽标背景用，深色文字对比度足够）。
Color memoryTypeSoftColor(String? type) => switch (type) {
      'preference' => AppColors.memoryPreferenceSoft,
      'forbidden' => AppColors.memoryBanSoft,
      'event' => AppColors.memoryEventSoft,
      _ => AppColors.memoryFactSoft,
    };

/// 记忆类型徽标：浅底 + 类型主色文字。
class MemoryTypeBadge extends StatelessWidget {
  const MemoryTypeBadge(this.type, {super.key});

  final String? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: memoryTypeSoftColor(type),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        memoryTypeLabel(type),
        style: TextStyle(fontSize: 11, color: memoryTypeColor(type)),
      ),
    );
  }
}
