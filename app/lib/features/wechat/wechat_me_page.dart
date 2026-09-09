import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/user_avatar.dart';
import '../ai/ui/ai_memories_page.dart';
import '../ai/ui/ai_settings_page.dart';
import '../moments/ui/moments_page.dart';
import '../profile/logic/user_profile_notifier.dart';
import '../profile/models/user_profile.dart';
import '../profile/ui/user_profile_page.dart';

/// 微信式「我」页。
///
/// LifeHub 已有能力映射到真实入口：收藏 → AI 记忆，设置 → AI 设置。
/// 微信有而 LifeHub 尚未提供的功能保持原位，点击明确提示「暂未实现」。
class WeChatMePage extends ConsumerWidget {
  const WeChatMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(userProfileProvider).valueOrNull ?? const UserProfileData();
    return ColoredBox(
      color: const Color(0xFFEDEDED),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHeader(
              profile: profile,
              onOpen: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => const UserProfilePage()),
              ),
              onPlaceholder: (label) => _placeholder(context, label),
            ),
            const SizedBox(height: 10),
            _MeGroup(
              children: [
                _MeRow(
                  icon: Icons.support_agent_outlined,
                  iconColor: const Color(0xFF07C160),
                  label: '服务',
                  onTap: () => _placeholder(context, '服务'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MeGroup(
              children: [
                _MeRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF4D93E6),
                  label: '收藏',
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(builder: (_) => const AiMemoriesPage()),
                  ),
                ),
                _MeRow(
                  icon: Icons.photo_outlined,
                  iconColor: const Color(0xFF4D93E6),
                  label: '朋友圈',
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => const MomentsPage(userOnly: true),
                    ),
                  ),
                ),
                _MeRow(
                  icon: Icons.collections_outlined,
                  iconColor: const Color(0xFF35A8E8),
                  label: '作品',
                  onTap: () => _placeholder(context, '作品'),
                ),
                _MeRow(
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFFF06455),
                  label: '小店与卡包',
                  onTap: () => _placeholder(context, '小店与卡包'),
                ),
                _MeRow(
                  icon: Icons.emoji_emotions_outlined,
                  iconColor: const Color(0xFFF2B826),
                  label: '表情',
                  onTap: () => _placeholder(context, '表情'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MeGroup(
              children: [
                _MeRow(
                  icon: Icons.settings_outlined,
                  iconColor: const Color(0xFF348BD4),
                  label: '设置',
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(builder: (_) => const AiSettingsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  static void _placeholder(BuildContext context, String label) {
    showAppToast(context, '$label（暂未实现）');
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.onOpen,
    required this.onPlaceholder,
  });

  final UserProfileData profile;
  final VoidCallback onOpen;
  final ValueChanged<String> onPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const UserAvatar(size: 68, radius: 7),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LifeHub号：${profile.lifehubId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, color: Color(0xFF737373)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => onPlaceholder('我的二维码'),
                    icon: const Icon(Icons.qr_code,
                        size: 25, color: Color(0xFF576B95)),
                    tooltip: '我的二维码',
                  ),
                  const Icon(Icons.chevron_right,
                      size: 27, color: Color(0xFFB2B2B2)),
                ],
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 86),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileChip(
                      label: '＋ 状态',
                      onTap: () => onPlaceholder('状态'),
                    ),
                    _ProfileChip(
                      label: '朋友状态',
                      hasDot: true,
                      onTap: () => onPlaceholder('朋友状态'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip(
      {required this.label, required this.onTap, this.hasDot = false});

  final String label;
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD6D6D6)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF737373))),
            if (hasDot) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFA5151),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeGroup extends StatelessWidget {
  const _MeGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(
                height: .5,
                thickness: .5,
                indent: 64,
                color: Color(0xFFE5E5E5),
              ),
          ],
        ],
      ),
    );
  }
}

class _MeRow extends StatelessWidget {
  const _MeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 24),
              SizedBox(
                width: 28,
                child: Icon(icon, size: 27, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  label,
                  style:
                      const TextStyle(fontSize: 17, color: Color(0xFF111111)),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 27, color: Color(0xFFB2B2B2)),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
