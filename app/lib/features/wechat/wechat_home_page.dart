import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/providers.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/character_avatar.dart';
import '../ai/ai_providers.dart';
import '../ai/models/character.dart';
import '../ai/models/group_chat.dart';
import '../ai/ui/ai_persona_chat_page.dart';
import '../ai/ui/group_chat_page.dart';

const _homeStorage = FlutterSecureStorage();

/// 微信首页（会话列表）：圆角方形头像 + 名称 + 最后消息预览 + 时间。
/// 单聊 + 群聊统一行（032）：单聊数据驱动自角色列表，群聊驱动自 groupsProvider
/// （全量群）+ conversationsProvider（群预览 senderName/最后消息）。
/// **有草稿时优先显示「草稿：xxx」（微信语义，仅单聊）**；**置顶排最前 + 浅色底**；
/// **标为未读 → 头像红徽标**；**不显示该聊天 → 隐藏**。从聊天页返回时后台刷新。
class WeChatHomePage extends ConsumerStatefulWidget {
  const WeChatHomePage({super.key});

  @override
  ConsumerState<WeChatHomePage> createState() => _WeChatHomePageState();
}

/// 会话列表行：单聊或群聊。
sealed class _HomeItem {
  String get key;
}

class _HomeSingle extends _HomeItem {
  _HomeSingle(this.character);
  final Character character;
  @override
  String get key => character.id;
}

class _HomeGroup extends _HomeItem {
  _HomeGroup(this.group, this.preview);
  final GroupChat group;
  final ConversationPreview? preview;
  @override
  String get key => group.id;
}

/// 会话列表所需本地态快照（草稿 / 置顶 / 未读 / 隐藏；键=角色id或群id）。
class _HomeState {
  const _HomeState(this.drafts, this.pins, this.unread, this.hidden);
  final Map<String, String> drafts;
  final Set<String> pins;
  final Set<String> unread;
  final Set<String> hidden;
}

class _WeChatHomePageState extends ConsumerState<WeChatHomePage> {
  static const _empty =
      _HomeState(<String, String>{}, <String>{}, <String>{}, <String>{});

  late Future<_HomeState> _data;

  @override
  void initState() {
    super.initState();
    _data = _fetchData();
  }

  Future<_HomeState> _fetchData() async {
    final chars = ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    final groups = ref.read(groupsProvider).valueOrNull ?? const <GroupChat>[];
    final drafts = <String, String>{};
    final pins = <String>{};
    final unread = <String>{};
    final hidden = <String>{};
    // 单聊：角色 id 作键
    for (final c in chars) {
      final d = (await AppPrefs.chatDraft(c.id)).trim();
      if (d.isNotEmpty) drafts[c.id] = d;
      if (await AppPrefs.isChatPinned(c.id)) pins.add(c.id);
      if (await AppPrefs.isChatUnread(c.id)) unread.add(c.id);
      if (await AppPrefs.isChatHidden(c.id)) hidden.add(c.id);
    }
    // 群聊：群 id 作键（与单聊 id 天然不冲突）
    for (final g in groups) {
      if (await AppPrefs.isChatPinned(g.id)) pins.add(g.id);
      if (await AppPrefs.isChatUnread(g.id)) unread.add(g.id);
      if (await AppPrefs.isChatHidden(g.id)) hidden.add(g.id);
    }
    return _HomeState(drafts, pins, unread, hidden);
  }

  /// 菜单操作后重读本地态（置顶/未读/隐藏变更即时生效）。
  void _reload() => setState(() => _data = _fetchData());

  @override
  Widget build(BuildContext context) {
    final chars =
        ref.watch(charactersProvider).valueOrNull ?? defaultCharacters;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <GroupChat>[];
    final convs = ref.watch(conversationsProvider).valueOrNull ??
        const <String, ConversationPreview>{};
    final items = <_HomeItem>[
      for (final c in chars)
        if (c.id != 'assistant') _HomeSingle(c),
      for (final g in groups) _HomeGroup(g, convs['g:${g.id}']),
    ];
    return FutureBuilder<_HomeState>(
      future: _data,
      builder: (context, snap) {
        final s = snap.data ?? _empty;
        final visible = [
          ...items.where((it) => s.pins.contains(it.key) && !s.hidden.contains(it.key)),
          ...items.where((it) => !s.pins.contains(it.key) && !s.hidden.contains(it.key)),
        ];
        return ColoredBox(
          color: Colors.white,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const Divider(
              height: .5,
              thickness: .5,
              indent: 80,
              color: Color(0xFFE5E5E5),
            ),
            itemBuilder: (_, i) => _buildRow(visible[i], s),
          ),
        );
      },
    );
  }

  Widget _buildRow(_HomeItem item, _HomeState s) {
    final pinned = s.pins.contains(item.key);
    final unread = s.unread.contains(item.key);
    return switch (item) {
      _HomeSingle(:final character) =>
        _buildSingleRow(character, s, pinned, unread),
      _HomeGroup(:final group, :final preview) =>
        _buildGroupRow(group, preview, pinned, unread),
    };
  }

  Widget _buildSingleRow(Character c, _HomeState s, bool pinned, bool unread) {
    final conv = ref.read(conversationsProvider).valueOrNull?[c.id];
    final preview = conv?.lastContent;
    final base = (preview == null || preview.isEmpty)
        ? (c.tagline ?? '')
        : preview;
    final draft = s.drafts[c.id];
    return Builder(
      builder: (ctx) => Material(
        color: pinned ? const Color(0xFFEDEDED) : Colors.white,
        child: InkWell(
          onTap: () => _openSingle(c),
          onLongPress: () {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box == null) return;
            _showChatMenu(
              itemKey: c.id,
              name: c.name,
              rect: box.localToGlobal(Offset.zero) & box.size,
              pinned: pinned,
              unread: unread,
              onDelete: () => _deleteSingleConversation(c),
            );
          },
          child: _rowLayout(
            avatar: _AvatarWithBadge(character: c, unread: unread),
            name: c.name,
            previewText: draft != null ? null : base,
            draft: draft,
            lastAt: conv?.lastAt,
            unread: unread,
            pinned: pinned,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRow(
    GroupChat g,
    ConversationPreview? conv,
    bool pinned,
    bool unread,
  ) {
    final senderName = conv?.senderName;
    final content = conv?.lastContent ?? '';
    final previewText = (senderName != null &&
            senderName.isNotEmpty &&
            content.isNotEmpty)
        ? '$senderName: $content'
        : content;
    return Builder(
      builder: (ctx) => Material(
        color: pinned ? const Color(0xFFEDEDED) : Colors.white,
        child: InkWell(
          onTap: () => _openGroup(g),
          onLongPress: () {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box == null) return;
            _showChatMenu(
              itemKey: g.id,
              name: g.name,
              rect: box.localToGlobal(Offset.zero) & box.size,
              pinned: pinned,
              unread: unread,
              onDelete: () => _deleteGroup(g),
            );
          },
          child: _rowLayout(
            avatar: _GroupAvatarWithBadge(group: g, unread: unread),
            name: g.name,
            previewText: previewText,
            draft: null,
            lastAt: conv?.lastAt,
            unread: unread,
            pinned: pinned,
          ),
        ),
      ),
    );
  }

  /// 统一行布局：头像 / 名称 + 预览 / 时间。
  Widget _rowLayout({
    required Widget avatar,
    required String name,
    required String? previewText,
    required String? draft,
    required DateTime? lastAt,
    required bool unread,
    required bool pinned,
  }) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        color: const Color(0xFF111111),
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (draft != null)
                      _draftText(draft)
                    else
                      Text(
                        previewText ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          color: const Color(0xFFB2B2B2),
                          fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _relativeTime(lastAt),
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFFB2B2B2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSingle(Character c) {
    Navigator.of(context)
        .push(
      AppPageRoute(builder: (_) => AiPersonaChatPage(character: c)),
    )
        .then((_) {
      // 后台刷新（非阻塞）：缓存已写穿，首页立即显示最新预览；
      ref.read(conversationsProvider.notifier).reload();
      _reload();
    });
  }

  void _openGroup(GroupChat g) {
    Navigator.of(context)
        .push(
      AppPageRoute(builder: (_) => GroupChatPage(groupId: g.id)),
    )
        .then((_) {
      ref.read(conversationsProvider.notifier).reload();
      ref.read(groupsProvider.notifier).reload();
      _reload();
    });
  }

  /// 长按聊天条 → 微信式白色圆角菜单：标为未读/已读、置顶/取消置顶、
  /// 不显示该聊天、删除该聊天。
  void _showChatMenu({
    required String itemKey,
    required String name,
    required Rect rect,
    required bool pinned,
    required bool unread,
    required VoidCallback onDelete,
  }) {
    showMenu<String>(
      context: context,
      position:
          RelativeRect.fromRect(rect, Offset.zero & MediaQuery.sizeOf(context)),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          value: 'unread',
          child: _MenuRow(
            unread
                ? PhosphorIconsRegular.envelopeOpen
                : PhosphorIconsRegular.envelope,
            unread ? '标为已读' : '标为未读',
          ),
        ),
        PopupMenuItem(
          value: 'pin',
          child: _MenuRow(
            PhosphorIconsRegular.pushPin,
            pinned ? '取消置顶' : '置顶聊天',
          ),
        ),
        const PopupMenuItem(
          value: 'hide',
          child: _MenuRow(PhosphorIconsRegular.eyeSlash, '不显示该聊天'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuRow(PhosphorIconsRegular.trash, '删除该聊天'),
        ),
      ],
    ).then((id) async {
      if (id == null) return;
      switch (id) {
        case 'unread':
          await AppPrefs.setChatUnread(itemKey, !unread);
          _reload();
        case 'pin':
          await AppPrefs.setChatPinned(itemKey, !pinned);
          _reload();
        case 'hide':
          await AppPrefs.setChatHidden(itemKey, true);
          _reload();
        case 'delete':
          onDelete();
      }
    });
  }

  Future<void> _deleteSingleConversation(Character character) async {
    final confirmed = await _confirmDelete('「${character.name}」',
        '角色档案、长期记忆、关系状态和剧情都会保留；被删除的聊天消息无法恢复。');
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref
          .read(apiProvider)
          .delete('/ai/characters/${character.id}/conversations')
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('delete failed: ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final conversationIds = (body['deleted_conversation_ids'] as List? ?? [])
          .whereType<String>()
          .toSet();
      final localConversationId =
          await _homeStorage.read(key: character.convKey);
      if (localConversationId != null && localConversationId.isNotEmpty) {
        conversationIds.add(localConversationId);
      }
      for (final conversationId in conversationIds) {
        await ref.read(dbProvider).deleteChatMessages(conversationId);
      }
      await ref.read(dbProvider).deleteMediaCaches(
            (body['deleted_media_ids'] as List? ?? []).whereType<String>(),
          );
      await _homeStorage.delete(key: character.convKey);
      await AppPrefs.clearConversationState(character.id);
      await AppPrefs.setChatHidden(character.id, true);
      ref.read(conversationsProvider.notifier).removeLocal(character.id);
      if (!mounted) return;
      _reload();
      showAppToast(context, '聊天已删除，角色长期记忆已保留');
    } on Object {
      if (mounted) showAppToast(context, '删除聊天失败，请重试');
    }
  }

  Future<void> _deleteGroup(GroupChat group) async {
    final confirmed = await _confirmDelete('群「${group.name}」',
        '该群的聊天记录会一并删除且无法恢复；角色本身不受影响。');
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref
          .read(apiProvider)
          .delete('/ai/groups/${group.id}')
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('delete failed: ${response.statusCode}');
      }
      await ref.read(dbProvider).deleteChatMessages(group.id);
      await AppPrefs.clearConversationState(group.id);
      await AppPrefs.setChatHidden(group.id, true);
      ref.read(conversationsProvider.notifier).removeGroupLocal(group.id);
      ref.read(groupsProvider.notifier).removeLocal(group.id);
      if (!mounted) return;
      _reload();
      showAppToast(context, '群聊已删除');
    } on Object {
      if (mounted) showAppToast(context, '删除群聊失败，请重试');
    }
  }

  Future<bool?> _confirmDelete(String what, String detail) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该聊天'),
        content: Text('确定删除$what的全部聊天记录吗？\n\n$detail'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
  }

  /// 草稿行（微信样式）：红色「【草稿】」前缀 + 灰色草稿内容。
  Widget _draftText(String draft) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          const TextSpan(
            text: '【草稿】',
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFFE64340),
                fontWeight: FontWeight.w500),
          ),
          TextSpan(
              text: draft,
              style: const TextStyle(fontSize: 14, color: Color(0xFFB2B2B2))),
        ],
      ),
    );
  }

  /// 微信会话列表时间：今天显示上午/下午时刻，随后是昨天、日期。
  String _relativeTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      final period = t.hour < 12 ? '上午' : '下午';
      final hour = t.hour == 0
          ? 12
          : t.hour > 12
              ? t.hour - 12
              : t.hour;
      return '$period$hour:${t.minute.toString().padLeft(2, '0')}';
    }
    final yest = now.subtract(const Duration(days: 1));
    if (t.year == yest.year && t.month == yest.month && t.day == yest.day) {
      return '昨天';
    }
    if (t.year == now.year) return '${t.month}月${t.day}日';
    return '${t.year}/${t.month}/${t.day}';
  }
}

/// 头像 + 未读红徽标（单聊）。
class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({required this.character, required this.unread});
  final Character character;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CharacterAvatar(character: character, size: 50, radius: 7),
        if (unread) const _UnreadBadge(),
      ],
    );
  }
}

/// 群头像 + 未读红徽标：2×2 成员小头像（来自角色头像），无成员 → 灰底「群」。
class _GroupAvatarWithBadge extends ConsumerWidget {
  const _GroupAvatarWithBadge({required this.group, required this.unread});
  final GroupChat group;
  final bool unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider).valueOrNull;
    final memberIds = group.memberIds.isNotEmpty ? group.memberIds : [
      for (final m in group.members) m.id,
    ];
    final members = [
      for (final id in memberIds.take(4))
        chars?.where((c) => c.id == id).firstOrNull,
    ].whereType<Character>().toList();
    final Widget avatar;
    if (members.isEmpty) {
      avatar = Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF95C7A3),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Text('群',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
      );
    } else {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Column(
            children: [
              for (var r = 0; r < 2; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < 2; c++)
                        Expanded(child: _miniAvatar(members, r * 2 + c)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (unread) const _UnreadBadge(),
      ],
    );
  }

  Widget _miniAvatar(List<Character> members, int index) {
    if (index >= members.length) {
      return Container(color: const Color(0xFFF2F2F2));
    }
    return CharacterAvatar(character: members[index], size: 25, radius: 0);
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -2,
      top: -2,
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.wechatRed,
          shape: BoxShape.circle,
        ),
        child: const Text(
          '1',
          style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 菜单行：图标 + 文字。
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.onBg),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 14, color: AppColors.onBg)),
      ],
    );
  }
}
