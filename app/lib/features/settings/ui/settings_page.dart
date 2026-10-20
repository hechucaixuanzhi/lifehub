import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/network/api_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../ai/ui/ai_memories_page.dart';
import '../../ai/ui/ai_settings_page.dart';
import '../../inbox/ui/inbox_page.dart';

/// 「我的」面板（对齐原型 panel-me 分组，从 TopBar 全屏进入）。
/// 分组：AI / 数据与权限 / 外观 / 生活习惯 / 健身动作 / 随手记收件箱。
class MyPanel extends ConsumerWidget {
  const MyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider);
    final sync = ref.watch(syncManagerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionLabel('AI'),
          _Card(
            children: [
              _Tile(
                icon: AppNavIcons.ai,
                title: 'AI 模型',
                subtitle: '查看服务状态、测试连接',
                onTap: () => _push(context, const AiSettingsPage()),
              ),
              _Divider(),
              _Tile(
                icon: Icons.memory_outlined,
                title: 'AI 记忆',
                subtitle: 'AI 女友记住的偏好与事实',
                onTap: () => _push(context, const AiMemoriesPage()),
              ),
            ],
          ),
          const _SectionLabel('数据与权限'),
          _Card(
            children: [
              _Tile(
                icon: AppNavIcons.plus,
                title: '立即同步',
                subtitle: '上传本地变更到家庭服务器',
                onTap: () async {
                  final r = await sync.push();
                  if (!context.mounted) return;
                  _snack(context,
                      r.offline ? '家庭服务器未连接（离线，数据已留本地）' : '已同步 ${r.accepted} 条');
                },
              ),
              _Divider(),
              _Tile(
                icon: AppNavIcons.back,
                title: '从服务器恢复',
                subtitle: '拉取远端增量',
                onTap: () async {
                  final r = await sync.pull();
                  if (!context.mounted) return;
                  _snack(context,
                      r.offline ? '家庭服务器未连接（离线，恢复跳过）' : '已从服务器恢复 ${r.accepted} 条');
                },
              ),
              _Divider(),
              _Tile(
                icon: AppNavIcons.me,
                title: '设备 ID',
                subtitle: device.deviceId,
              ),
              _Divider(),
              _Tile(
                icon: AppNavIcons.home,
                title: '服务器',
                subtitle: ApiConfig.baseUrl,
              ),
            ],
          ),
          const _SectionLabel('收件箱'),
          _Card(
            children: [
              _Tile(
                icon: AppNavIcons.plus,
                title: '随手记收件箱',
                subtitle: '未分类的随手记录',
                onTap: () => _push(context, const InboxPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'API Key 仅在家庭服务器（backend/.env）配置，手机不存储任何密钥。',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context)
      .push(AppPageRoute(builder: (_) => page));

  void _snack(BuildContext context, String msg) =>
      showAppToast(context, msg);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(text, style: AppTypography.sectionLabel),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppElevation.e1,
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, color: Color(0xFFECEEEA));
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
      dense: true,
    );
  }
}
