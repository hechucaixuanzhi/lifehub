import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_tokens.dart';

/// 顶部固定栏（对齐原型 topbar）：左「我的」圆形图标 + 中间当前 Tab 标题 + 右「宠物」圆形图标。
/// 常驻，不随 Tab 切换。底部分隔线。
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.onMe,
    required this.onPet,
  });

  final String title;
  final VoidCallback onMe;
  final VoidCallback onPet;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      // 高度 = 状态栏高度 + 52（TopBar 内容区），避免与状态栏重合
      padding: EdgeInsets.only(top: top),
      height: top + 52,
      color: AppColors.bg,
      child: Row(
        children: [
          _CircleBtn(icon: AppNavIcons.me, tooltip: '我的', onTap: onMe),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.onBg,
              ),
            ),
          ),
          _CircleBtn(icon: AppNavIcons.pet, tooltip: '宠物', onTap: onPet),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: Icon(icon, size: 22, color: AppColors.onBg),
          ),
        ),
      ),
    );
  }
}
