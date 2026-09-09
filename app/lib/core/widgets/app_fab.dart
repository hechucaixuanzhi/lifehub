import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_tokens.dart';

/// 全局「记一笔」FAB（对齐原型 fab）：右下 56 圆形，强调色填充，elevation-2。
/// 点击唤起全局捕获 Sheet（由 Shell 装配 onPressed）。
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      shape: const CircleBorder(),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      child: const Icon(AppNavIcons.plus, size: 24),
    );
  }
}
