import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_tokens.dart';

/// 底部四 Tab 导航（对齐原型 nav）：生活 / 学习 / 运动 / AI。
/// 选中强调色 + 加粗 label，未选中 muted。
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final int current;
  final ValueChanged<int> onSelect;

  static const List<(String, IconData)> _tabs = [
    ('生活', AppNavIcons.home),
    ('学习', AppNavIcons.study),
    ('运动', AppNavIcons.exercise),
    ('AI', AppNavIcons.ai),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFECEEEA))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Icon(
                        _tabs[i].$2,
                        size: 22,
                        color: i == current ? AppColors.accent : AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _tabs[i].$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                          color: i == current ? AppColors.accent : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
