import 'package:flutter/material.dart';

/// LifeHub 设计 Token — 对齐 docs/design/tokens.md（单一强调色 + 中性灰 + 大量留白）。
/// 常量类，无业务依赖，供组件与页面直接引用。颜色用 ARGB，间距 4dp 基线。

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;
}

class AppElevation {
  /// elevation-1：卡片极淡阴影 `0 1px 1px rgba(0,0,0,.04)`
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// elevation-2：悬浮元素 `0 2px 8px rgba(0,0,0,.08)`
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

class AppColors {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF2F3F5); // 弱化卡片/标签底色（如「已并入」）
  static const Color onBg = Color(0xFF1A1A1A);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color muted = Color(0x73000000); // rgba(0,0,0,.45)
  static const Color accent = Color(0xFF4CAF50); // 唯一强调色（绿色调）
  static const Color accentSoft = Color(0x1F4CAF50); // rgba(76,175,80,.12)
  static const Color danger = Color(0xFFE5484D);
  static const Color heart = Color(0xFFFF5C8A);
  static const Color chatBg = Color(0xFFEDEDED);
  static const Color bubbleAi = Color(0xFFFFFFFF);
  static const Color bubbleMe = Color(0xFF95EC69); // 微信绿
  static const Color wechatGreen = Color(0xFF07C160); // 微信品牌绿（Tab 激活/徽标）
  static const Color wechatRed = Color(0xFFFA5151); // 微信红（未读徽标）

  // ---- 记忆类型语义色（验收批3④）：仅用于徽标/芯片，不用于按钮 ----
  static const Color memoryPreference = Color(0xFFF59E0B); // 偏好-琥珀
  static const Color memoryFact = Color(0xFF3B82F6); // 事实-蓝
  static const Color memoryBan = Color(0xFFE5484D); // 禁止-红（同 danger）
  static const Color memoryEvent = Color(0xFF8B5CF6); // 事件-紫
  // 各自 10% alpha 的浅底变体，供芯片/徽标底色（深色文字对比度足够）。
  static const Color memoryPreferenceSoft = Color(0x1AF59E0B);
  static const Color memoryFactSoft = Color(0x1A3B82F6);
  static const Color memoryBanSoft = Color(0x1AE5484D);
  static const Color memoryEventSoft = Color(0x1A8B5CF6);

  /// 图标线稿灰（状态填充底：未达标时的中性底）。
  static const Color iconBase = Color(0xFFC3C9C1);
}

class AppTypography {
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onBg,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    color: AppColors.onBg,
    height: 1.5,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    color: AppColors.onBg,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.muted,
  );

  /// 分区小标题（sec-label：13sp/muted/600）。
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    color: AppColors.muted,
    fontWeight: FontWeight.w600,
  );
}
