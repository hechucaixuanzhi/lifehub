import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/providers.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/character_avatar.dart';
import '../ai/ai_providers.dart';
import '../ai/models/character.dart';
import '../ai/ui/character_create_page.dart';
import '../ai/ui/group_create_page.dart';
import '../ai/ui/profile_page.dart';
import '../ai/ui/worldbook_manage_page.dart';

const _contactStorage = FlutterSecureStorage();

/// 微信式通讯录。固定功能保留位置；真实联系人由后端角色列表驱动。
class WeChatContactsPage extends ConsumerWidget {
  const WeChatContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars =
        (ref.watch(charactersProvider).valueOrNull ?? defaultCharacters)
            .where((character) => character.id != 'assistant')
            .toList();
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ContactShortcut(
            icon: Icons.person_add_alt_1,
            color: const Color(0xFFFA9D3B),
            label: '添加人物',
            onTap: () => _addCharacter(context),
          ),
          _ContactShortcut(
            icon: Icons.group,
            color: const Color(0xFF07C160),
            label: '群聊',
            onTap: () => _createGroup(context, ref),
          ),
          _ContactShortcut(
            icon: Icons.sell,
            color: const Color(0xFF2782D7),
            label: '标签',
            onTap: () => _worldbooks(context, ref),
          ),
          _ContactShortcut(
            icon: Icons.campaign,
            color: const Color(0xFF2782D7),
            label: '公众号',
            onTap: () => _placeholder(context, '公众号'),
          ),
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 16, top: 8),
            color: const Color(0xFFEDEDED),
            child: const Text(
              '人物',
              style: TextStyle(fontSize: 13, color: Color(0xFF737373)),
            ),
          ),
          for (final c in chars)
            _CharacterRow(
              character: c,
              onTap: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => ProfilePage(character: c)),
              ),
              onLongPress: () => _deleteCharacter(context, ref, c),
            ),
        ],
      ),
    );
  }

  static void _placeholder(BuildContext context, String label) {
    showAppToast(context, '$label（暂未实现）');
  }

  /// 群聊入口 → 发起群聊；返回后后台刷新会话预览（新群出现）。
  static Future<void> _createGroup(BuildContext context, WidgetRef ref) {
    return Navigator.of(context)
        .push(AppPageRoute(builder: (_) => const GroupCreatePage()))
        .then((_) {
      if (context.mounted) {
        ref.read(conversationsProvider.notifier).reload();
        ref.read(groupsProvider.notifier).reload();
      }
    });
  }

  /// 标签入口 → 世界书库。
  static void _worldbooks(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const WorldbookManagePage()),
    );
  }

  static Future<void> _addCharacter(BuildContext context) async {
    final character = await Navigator.of(context).push<Character>(
      AppPageRoute(builder: (_) => const CharacterCreatePage()),
    );
    if (character == null || !context.mounted) return;
    await Navigator.of(context).push(
      AppPageRoute(builder: (_) => ProfilePage(character: character)),
    );
  }

  static Future<void> _deleteCharacter(
    BuildContext context,
    WidgetRef ref,
    Character character,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除角色'),
        content: Text(
          '确定永久删除「${character.name}」吗？\n\n'
          '她的聊天记录、长期记忆、关系与情绪、剧情、朋友圈与互动、角色档案、声音和自我识别资料都会一并删除，且无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '永久删除',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final response = await ref
          .read(apiProvider)
          .delete('/ai/characters/${character.id}')
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw StateError('delete failed: ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final conversationIds = (body['deleted_conversation_ids'] as List? ?? [])
          .whereType<String>()
          .toSet();
      final localConversationId =
          await _contactStorage.read(key: character.convKey);
      if (localConversationId != null && localConversationId.isNotEmpty) {
        conversationIds.add(localConversationId);
      }
      for (final conversationId in conversationIds) {
        await ref.read(dbProvider).deleteChatMessages(conversationId);
      }
      final mediaIds =
          (body['deleted_media_ids'] as List? ?? []).whereType<String>();
      await ref.read(dbProvider).deleteMediaCaches(mediaIds);
      await _contactStorage.delete(key: character.convKey);
      await AppPrefs.clearCharacterState(character.id);
      for (final key in <String>[
        'character_archive_v1_${character.id}',
        'relationship_definition_${character.id}',
        'relationship_pending_${character.id}',
        'character_storyline_${character.id}',
        'character_storyline_pending_${character.id}',
      ]) {
        await ref.read(dbProvider).deleteKv(key);
      }
      ref.read(conversationsProvider.notifier).removeLocal(character.id);
      ref.read(charactersProvider.notifier).removeLocal(character.id);
      if (context.mounted) {
        showAppToast(context, '已删除「${character.name}」及全部相关数据');
      }
    } on Object {
      if (context.mounted) showAppToast(context, '角色删除失败，请重试');
    }
  }
}

class _ContactShortcut extends StatelessWidget {
  const _ContactShortcut({
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
    return _ContactRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        alignment: Alignment.center,
        child: Icon(icon, size: 25, color: Colors.white),
      ),
      label: label,
      onTap: onTap,
    );
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({
    required this.character,
    required this.onTap,
    required this.onLongPress,
  });

  final Character character;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return _ContactRow(
      leading: CharacterAvatar(character: character, size: 40, radius: 5),
      label: character.name,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(
      {required this.leading,
      required this.label,
      required this.onTap,
      this.onLongPress});

  final Widget leading;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 16),
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 58,
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: Color(0xFFE5E5E5), width: .5)),
                  ),
                  child: Text(
                    label,
                    style:
                        const TextStyle(fontSize: 17, color: Color(0xFF111111)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
