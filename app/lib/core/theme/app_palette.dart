import 'package:flutter/material.dart';

/// 实体专属可选色（习惯 / 学习 / 运动新增时的取色器用）。
/// 与全局强调色（AppColors.accent）不冲突；饱和度克制，不与强调色打架。
/// 对齐 tokens.md §1「习惯图标专属填充色在 LifeHabit.color 配置，属实体专属色」。
class AppPalette {
  static const List<Color> choices = [
    Color(0xFF2F80ED), // 蓝
    Color(0xFFE8833A), // 橙
    Color(0xFF2BB3A3), // 青
    Color(0xFF8B5E3C), // 棕
    Color(0xFFD64550), // 玫红
    Color(0xFF7FB069), // 草绿
    Color(0xFFF2B705), // 黄
    Color(0xFFC0568F), // 粉
    Color(0xFF5B5BD6), // 紫
    Color(0xFF00ACC1), // 亮青
  ];

  static Color at(int index) => choices[index % choices.length];

  /// 按名称回退：给既存实体（如默认习惯 0xFF2196F3）一个稳定映射。
  static Color fallback(String? name) {
    if (name == null || name.isEmpty) return choices.first;
    return at(name.hashCode.abs());
  }
}
