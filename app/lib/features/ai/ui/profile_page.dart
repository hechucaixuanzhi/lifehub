import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../ai_providers.dart';
import '../models/character.dart';
import '../services/relationship_service.dart';
import '../../moments/ui/moments_page.dart';
import 'ai_persona_chat_page.dart';
import 'character_archive_page.dart';
import 'character_voice_page.dart';
import 'feedback_list_page.dart';
import 'relationship_editor_page.dart';

/// 个人主页（仿微信个人资料页，聊天信息页头像 / 通讯录进入）：
/// 头像 + 微信号 → 公开资料 → 朋友圈 → 发消息 / 音视频通话。
/// 未实现的功能先占位（toast 提示），结构对齐微信。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var current = character;
    for (final item
        in ref.watch(charactersProvider).valueOrNull ?? const <Character>[]) {
      if (item.id == character.id) {
        current = item;
        break;
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        titleSpacing: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('个人信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                // 头像 + 昵称 + 微信号 + 地区
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CharacterAvatar(character: current, size: 64, radius: 8),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(current.name,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onBg)),
                            const SizedBox(height: 8),
                            Text('聊天号：lh_${current.id}',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.muted)),
                            if ((current.tagline ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(current.tagline!,
                                  style: const TextStyle(
                                      fontSize: 14, color: AppColors.muted)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 公开资料 / 朋友圈
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _Row(
                        icon: Icons.badge_outlined,
                        label: '公开资料',
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute(
                            builder: (_) => _PublicInfoPage(character: current),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _Row(
                        icon: Icons.camera_alt_outlined,
                        label: '朋友圈',
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute(
                            builder: (_) => MomentsPage(
                              characterId: current.id,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      // 我的反馈：查看/编辑对该角色的点赞/点踩（单聊角色与群聊角色共用本页）。
                      _Row(
                        icon: Icons.feedback_outlined,
                        label: '我的反馈',
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute(
                            builder: (_) => FeedbackListPage(
                              characterId: current.id,
                              characterName: current.name,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // 底部：发消息 / 音视频通话
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) => AiPersonaChatPage(character: current),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('发消息',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showAppToast(context, '音视频通话（占位）'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF07C160),
                      side: const BorderSide(color: Color(0xFF07C160)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('音视频通话',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 微信样式行：icon + label + chevron。
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.onBg, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 16, color: AppColors.onBg)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap ?? () => showAppToast(context, '$label（占位）'),
    );
  }
}

/// 公开资料：微信表层保持简洁，角色档案放在页面底部的低调入口。
class _PublicInfoPage extends ConsumerWidget {
  const _PublicInfoPage({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var current = character;
    for (final item
        in ref.watch(charactersProvider).valueOrNull ?? const <Character>[]) {
      if (item.id == character.id) {
        current = item;
        break;
      }
    }
    final relationship =
        ref.watch(relationshipProvider(current.id)).valueOrNull ??
            RelationshipDefinition(characterId: current.id);
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        titleSpacing: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('公开资料',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _Row(
                    icon: Icons.edit_outlined,
                    label: '设置备注和标签',
                    onTap: () => showAppToast(context, '设置备注和标签（占位）')),
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.star_border,
                    label: '设为星标朋友',
                    onTap: () => showAppToast(context, '设为星标朋友（占位）')),
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.description_outlined,
                    label: '描述',
                    onTap: () => showAppToast(context, '描述（占位）')),
                const Divider(height: 1, indent: 56),
                _Row(
                    icon: Icons.group_outlined,
                    label: '我和TA的共同群聊',
                    onTap: () => showAppToast(context, '共同群聊（占位）')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  title: const Text('与我的关系',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(relationship.label,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.muted)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => RelationshipEditorPage(
                        characterId: current.id,
                        characterName: current.name,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('签名',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  subtitle: Text(current.tagline ?? '这个人很懒，什么都没有留下',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 深层入口：不放在聊天页或人物主页主区域，避免喧宾夺主。
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.graphic_eq,
                      size: 18, color: AppColors.muted),
                  title: const Text(
                    '角色声音',
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  subtitle: const Text(
                    '专属音色与语音回复方式',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => CharacterVoicePage(
                        characterId: current.id,
                        characterName: current.name,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 52),
                ListTile(
                  dense: true,
                  leading:
                      const Icon(Icons.tune, size: 18, color: AppColors.muted),
                  title: const Text(
                    '角色档案',
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                  subtitle: const Text(
                    '查看或改写人格、历史与世界观',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => CharacterArchivePage(
                        characterId: current.id,
                        characterName: current.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
