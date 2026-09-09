import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 空状态（对齐 tokens「不写说明书式文案」：图标 + 一句 muted 短文案）。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, style: AppTypography.caption),
        ],
      ),
    );
  }
}
