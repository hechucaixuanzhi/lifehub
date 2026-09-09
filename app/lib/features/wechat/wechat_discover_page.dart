import 'package:flutter/material.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/widgets/app_toast.dart';
import '../moments/ui/moments_page.dart';

/// 微信式发现页。LifeHub 时间线映射到朋友圈，其余入口保持占位。
class WeChatDiscoverPage extends StatelessWidget {
  const WeChatDiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _DiscoverGroup(children: [
          _DiscoverRow(
            icon: Icons.photo_outlined,
            color: const Color(0xFF2782D7),
            label: '朋友圈',
            onTap: () => Navigator.of(context).push(
              AppPageRoute(builder: (_) => const MomentsPage()),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _DiscoverGroup(children: [
          _DiscoverRow(
            icon: Icons.smart_display_outlined,
            color: const Color(0xFFF1A33B),
            label: '视频号',
            onTap: () => _placeholder(context, '视频号'),
          ),
          _DiscoverRow(
            icon: Icons.live_tv_outlined,
            color: const Color(0xFFE96375),
            label: '直播',
            onTap: () => _placeholder(context, '直播'),
          ),
        ]),
        const SizedBox(height: 10),
        _DiscoverGroup(children: [
          _DiscoverRow(
            icon: Icons.qr_code_scanner,
            color: const Color(0xFF2782D7),
            label: '扫一扫',
            onTap: () => _placeholder(context, '扫一扫'),
          ),
          _DiscoverRow(
            icon: Icons.phone_android,
            color: const Color(0xFF2782D7),
            label: '摇一摇',
            onTap: () => _placeholder(context, '摇一摇'),
          ),
        ]),
        const SizedBox(height: 10),
        _DiscoverGroup(children: [
          _DiscoverRow(
            icon: Icons.article_outlined,
            color: const Color(0xFFF1A33B),
            label: '看一看',
            onTap: () => _placeholder(context, '看一看'),
          ),
          _DiscoverRow(
            icon: Icons.auto_awesome,
            color: const Color(0xFF2782D7),
            label: '搜一搜',
            onTap: () => _placeholder(context, '搜一搜'),
          ),
        ]),
        const SizedBox(height: 10),
        _DiscoverGroup(children: [
          _DiscoverRow(
            icon: Icons.apps,
            color: const Color(0xFF6C9D5C),
            label: '小程序',
            onTap: () => _placeholder(context, '小程序'),
          ),
        ]),
        const SizedBox(height: 28),
      ],
    );
  }

  static void _placeholder(BuildContext context, String label) {
    showAppToast(context, '$label（暂未实现）');
  }
}

class _DiscoverGroup extends StatelessWidget {
  const _DiscoverGroup({required this.children});

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
                  color: Color(0xFFE5E5E5)),
          ],
        ],
      ),
    );
  }
}

class _DiscoverRow extends StatelessWidget {
  const _DiscoverRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 59,
          child: Row(
            children: [
              const SizedBox(width: 22),
              SizedBox(width: 28, child: Icon(icon, size: 27, color: color)),
              const SizedBox(width: 16),
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
