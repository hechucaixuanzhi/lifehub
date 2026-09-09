import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../ai_providers.dart';
import '../models/character.dart';
import '../models/group_chat.dart';
import '../models/worldbook.dart';
import '../services/media_image_normalizer.dart';
import 'media_crop_page.dart';
import 'search_history_page.dart';

/// 群聊信息页（右上角 ⋯ 进入的全屏页面）：群名 / 世界书 / 发言模式 / 成员管理 /
/// 清空聊天记录 / 清空群内角色记忆 / 删除群。
/// 每项修改即 PATCH，成功写穿 [groupsProvider.applyLocal]。
/// pop 'deleted' = 群已被删除（聊天页据此退出）；pop 'cleared' = 聊天记录已清空；
/// 否则聊天页回来重拉详情。
class GroupSettingsSheet extends ConsumerStatefulWidget {
  const GroupSettingsSheet({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupSettingsSheet> createState() =>
      _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends ConsumerState<GroupSettingsSheet> {
  GroupChat? _group;
  bool _loading = true;
  bool _saving = false;
  bool _groupNoban = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _groupNoban = await AppPrefs.isGroupChatNoban(widget.groupId);
    final cached = ref
        .read(groupsProvider)
        .valueOrNull
        ?.where((g) => g.id == widget.groupId)
        .firstOrNull;
    if (cached != null) {
      setState(() {
        _group = cached;
        _loading = false;
      });
    }
    final detail = await fetchGroupDetail(ref.read(apiProvider), widget.groupId);
    if (!mounted) return;
    if (detail != null) {
      ref.read(groupsProvider.notifier).applyLocal(detail);
      setState(() {
        _group = detail;
        _loading = false;
      });
    } else if (cached == null) {
      setState(() => _loading = false);
    }
  }

  Future<void> _setReplyMode(String mode) async {
    final group = _group;
    if (group == null || group.replyMode == mode) return;
    await _patch({'reply_mode': mode});
  }

  Future<void> _setReplyChars(String mode, int value) async {
    final group = _group;
    if (group == null) return;
    final key = mode == 'roleplay' ? 'reply_chars_roleplay' : 'reply_chars_realtime';
    final cur = mode == 'roleplay'
        ? group.replyCharsRoleplay
        : group.replyCharsRealtime;
    if (cur == value) return;
    await _patch({key: value});
  }

  Future<void> _setReplyCount(int value) async {
    final group = _group;
    if (group == null || group.replyCount == value) return;
    await _patch({'reply_count': value});
  }

  /// 回复字数滑杆（真实 60-600 / 剧情 300-3000，步长 round）。
  Widget _charSliderRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required String mode,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF111111))),
              const Spacer(),
              Text('$value 字',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted)),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            activeColor: const Color(0xFF07C160),
            // 拖动中不逐帧 PATCH（onChangeEnd 松手才保存）
            onChanged: _saving ? null : (_) {},
            onChangeEnd: _saving
                ? null
                : (v) => _setReplyChars(mode, v.round()),
          ),
        ],
      ),
    );
  }

  /// 真实回复条数 1-5 步进器。
  Widget _countRow() {
    final count = _group?.replyCount ?? 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Text('真实回复条数',
              style: TextStyle(fontSize: 15, color: Color(0xFF111111))),
          const Spacer(),
          _stepBtn(Icons.remove, count > 1,
              () => _setReplyCount(count - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          _stepBtn(Icons.add, count < 5, () => _setReplyCount(count + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled && !_saving ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF2F2F2) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? const Color(0xFF111111)
                : const Color(0xFFBBBBBB)),
      ),
    );
  }

  void _openSearchHistory() {
    final group = _group;
    if (group == null) return;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => SearchHistoryPage(
          conversationId: group.id,
          groupMembers: group.members,
        ),
      ),
    );
  }

  /// 设置当前聊天背景：相册选图 → 裁切（9:16）→ 上传 → PATCH 群 → 本地缓存即时生效。
  Future<void> _setGroupBackground() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;
      final sourceBytes = await picked.readAsBytes();
      final cropBytes = await prepareImageForCropping(sourceBytes);
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        AppPageRoute(
          builder: (_) => MediaCropPage(
            bytes: cropBytes,
            isAvatar: false,
            fileName: 'chat-background.png',
            mime: 'image/png',
          ),
          // 裁切页内平移/缩放/捏合优先，禁右滑返回防止误触发
          enableSwipeBack: false,
        ),
      );
      if (cropped == null || !mounted) return;
      final normalized = normalizeCroppedMedia(cropped, isAvatar: false);
      final api = ref.read(apiProvider);
      final mediaId = await api.uploadAsset(
        normalized.bytes,
        normalized.fileName,
        normalized.mimeType,
      );
      final resp = await api
          .patch('/ai/groups/${widget.groupId}',
              {'background_media_id': mediaId})
          .timeout(const Duration(seconds: 30));
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw Exception('PATCH group background ${resp.statusCode}');
      }
      final group = GroupChat.fromJson(
          Map<String, dynamic>.from(root['group'] as Map));
      // 服务端确认后立即把裁切成品写入 Drift；慢隧道下不依赖重拉即可显示。
      await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
            mediaId: mediaId,
            bytes: normalized.bytes,
            aspect: normalized.aspect,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
      ref.invalidate(mediaBytesProvider(mediaId));
      ref.read(groupsProvider.notifier).applyLocal(group);
      if (!mounted) return;
      setState(() => _group = group);
      showAppToast(context, '背景已更新');
    } on Object catch (e) {
      if (mounted) showAppToast(context, '更新失败，请重试');
      debugPrint('[group-background] $e');
    }
  }

  Future<void> _toggleNoban(bool value) async {
    if (_saving) return;
    if (value) {
      setState(() => _groupNoban = true);
      await AppPrefs.setGroupChatNoban(widget.groupId, true);
      if (mounted) showAppToast(context, '已开启群无违禁模式');
      return;
    }
    // 关闭：清理/保留机制（验收批3①）——镜像单聊 chat_info_page.dart:82-155。
    // 群聊不落记忆，剔除只清本群无违禁聊天消息；成员长期记忆/设定不受影响。
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭无违禁模式'),
        content: const Text(
          '关闭后将恢复当前关系阶段的亲密边界。\n\n'
          '是否同时剔除本群无违禁聊天期间形成的聊天消息？'
          '普通聊天消息、成员长期记忆与设定不会受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('保留消息'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('purge'),
            child: const Text(
              '剔除并关闭',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _saving = true);
    try {
      var deletedMessages = 0;
      if (choice == 'purge') {
        final response = await ref
            .read(apiProvider)
            .delete('/ai/conversation/${widget.groupId}/messages/noban')
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) throw Exception('purge failed');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        deletedMessages = (body['deleted_messages'] as num?)?.toInt() ?? 0;
      }
      await AppPrefs.setGroupChatNoban(widget.groupId, false);
      if (!mounted) return;
      setState(() => _groupNoban = false);
      showAppToast(
        context,
        choice == 'purge'
            ? '已关闭：剔除 $deletedMessages 条无违禁消息'
            : '已关闭，相关消息已保留',
      );
      if (choice == 'purge' && mounted) {
        Navigator.of(context).pop('noban_purged');
      }
    } on Object {
      if (mounted) showAppToast(context, '未能剔除消息，无违禁模式仍保持开启');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 仅当群内任一成员支持无违禁（hasNoban）时才显示开关。
  bool _anyMemberHasNoban(List<GroupMember> members) =>
      members.any((m) => _charOf(m)?.hasNoban == true);

  Future<bool> _patch(Map<String, dynamic> body) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final resp = await ref
          .read(apiProvider)
          .patch('/ai/groups/${widget.groupId}', body)
          .timeout(const Duration(seconds: 30));
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        final err = root['error'];
        final msg = err is Map && err['message'] is String
            ? err['message'] as String
            : '修改失败（${resp.statusCode}）';
        if (mounted) showAppToast(context, msg);
        return false;
      }
      if (root['deleted'] == true) {
        ref.read(groupsProvider.notifier).removeLocal(widget.groupId);
        if (mounted) Navigator.of(context).pop('deleted');
        return true;
      }
      final group = GroupChat.fromJson(
          Map<String, dynamic>.from(root['group'] as Map));
      ref.read(groupsProvider.notifier).applyLocal(group);
      // 群名/世界书变化同步会话预览（首页行名即时更新）
      if (mounted && _group != null && _group!.name != group.name) {
        final previews = ref.read(conversationsProvider).valueOrNull;
        final key = 'g:${widget.groupId}';
        final prev = previews?[key];
        if (prev != null) {
          ref.read(conversationsProvider.notifier).applyGroupLocal(
                widget.groupId,
                ConversationPreview(
                  type: 'group',
                  characterId: '',
                  groupId: widget.groupId,
                  groupName: group.name,
                  senderName: prev.senderName,
                  lastContent: prev.lastContent,
                  lastKind: prev.lastKind,
                  lastAt: prev.lastAt,
                ),
              );
        }
      }
      setState(() => _group = group);
      return true;
    } on Object catch (e) {
      if (mounted) showAppToast(context, '修改失败：$e');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename() async {
    final group = _group;
    if (group == null) return;
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改群聊名称'),
        content: TextField(
          controller: controller,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '群聊名称',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == group.name || !mounted) return;
    await _patch({'name': name});
  }

  Future<void> _pickWorldbook() async {
    final group = _group;
    if (group == null) return;
    final books = ref.read(worldbooksProvider).valueOrNull ?? const [];
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 380,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择世界书',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _wbOption(ctx, '现实世界（不穿越）', '群成员以现实身份参与', null),
                    for (final w in books)
                      _wbOption(
                          ctx, w.name, w.summary.isEmpty ? '无简介' : w.summary, w.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    final target = picked.isEmpty ? null : picked;
    if (target == group.worldbookId) return;
    await _patch({'worldbook_id': target});
  }

  Widget _wbOption(
      BuildContext ctx, String title, String subtitle, String? value) {
    final group = _group;
    final checked = value == group?.worldbookId;
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(value ?? ''),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.public, size: 20, color: Color(0xFF2782D7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF111111))),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (checked)
              const Icon(Icons.check_circle,
                  size: 22, color: Color(0xFF07C160)),
          ],
        ),
      ),
    );
  }

  Future<void> _setSpeakerMode(String mode) async {
    final group = _group;
    if (group == null || group.speakerMode == mode) return;
    await _patch({'speaker_mode': mode});
  }

  Future<void> _addMember() async {
    final group = _group;
    if (group == null) return;
    final existing = {for (final m in group.members) m.id};
    final candidates = [
      for (final c in (ref.read(charactersProvider).valueOrNull ??
          defaultCharacters))
        if (c.id != 'assistant' && !existing.contains(c.id)) c,
    ];
    // 世界书配角卡（验收批2）：已绑世界书且尚未入群的 supporting 卡可临时加入
    // （后端 temporary_join：无 character_id 先转 Character 再挂临时成员）。
    final wb = group.worldbook;
    final wbSupporting = wb == null
        ? <WorldbookCard>[]
        : [
            for (final card in wb.cards)
              if (card.kind == 'supporting' &&
                  (card.characterId == null ||
                      !existing.contains(card.characterId)))
                card,
          ];
    if (candidates.isEmpty && wbSupporting.isEmpty) {
      showAppToast(context, '没有可添加的角色');
      return;
    }
    final picked =
        await showModalBottomSheet<({Character? character, WorldbookCard? card})>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 480,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('添加成员',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (candidates.isNotEmpty) ...[
                      _sectionLabel('已创建角色'),
                      for (final c in candidates)
                        ListTile(
                          leading: CharacterAvatar(
                              character: c, size: 40, radius: 5),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontSize: 16, color: Color(0xFF111111))),
                          subtitle: const Text('直接加入本群',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                          onTap: () =>
                              Navigator.of(ctx).pop((character: c, card: null)),
                        ),
                    ],
                    if (wbSupporting.isNotEmpty) ...[
                      _sectionLabel('本世界书配角卡'),
                      for (final card in wbSupporting)
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _hexColor(card.avatarColor),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              card.avatarText.isNotEmpty
                                  ? card.avatarText
                                  : card.name.characters.first,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(card.name,
                              style: const TextStyle(
                                  fontSize: 16, color: Color(0xFF111111))),
                          subtitle: Text(
                            card.description.trim().isEmpty
                                ? '临时加入本群'
                                : '${card.description.trim()} · 临时加入',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                          onTap: () => Navigator.of(ctx)
                              .pop((character: null, card: card)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final character = picked.character;
    if (character != null) {
      final ok = await _patch({'add_member_ids': [character.id]});
      if (ok && mounted) showAppToast(context, '已添加 ${character.name}');
      return;
    }
    // 世界书配角 → temporary_join 端点（后端转角色 + 挂临时成员）
    final card = picked.card;
    if (card == null || wb == null) return;
    try {
      final resp = await ref
          .read(apiProvider)
          .post(
            '/worldbooks/${wb.id}/cards/${card.id}/temporary_join',
            {'group_id': group.id},
          )
          .timeout(const Duration(seconds: 30));
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        final err = root['error'];
        final msg = err is Map && err['message'] is String
            ? err['message'] as String
            : '添加失败（${resp.statusCode}）';
        if (mounted) showAppToast(context, msg);
        return;
      }
      // 刷新群详情（新成员进 members 列表并带 temporary 角标）
      final detail = await fetchGroupDetail(ref.read(apiProvider), group.id);
      if (detail != null && mounted) {
        ref.read(groupsProvider.notifier).applyLocal(detail);
        setState(() => _group = detail);
      }
      if (mounted) showAppToast(context, '已添加 ${card.name}');
    } on Object catch (e) {
      if (mounted) showAppToast(context, '添加失败：$e');
    }
  }

  Future<void> _removeMember(GroupMember m) async {
    final ok = await _patch({'remove_member_ids': [m.id]});
    if (ok && mounted) showAppToast(context, '已移除 ${m.name}');
  }

  /// 成员格右上角 ✕ → 确认弹窗（验收批2：显式移除按钮）。
  Future<void> _confirmRemove(GroupMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出群聊'),
        content: Text('确定将「${m.name}」移出本群吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移出', style: TextStyle(color: Color(0xFFFA5151))),
          ),
        ],
      ),
    );
    if (ok == true) await _removeMember(m);
  }

  Future<void> _deleteGroup() async {
    final group = _group;
    if (group == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除群聊'),
        content: Text('确定删除群「${group.name}」及全部聊天记录吗？\n\n角色本身不受影响。'),
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
    if (confirmed != true || !mounted) return;
    try {
      final resp = await ref
          .read(apiProvider)
          .delete('/ai/groups/${widget.groupId}')
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        if (mounted) showAppToast(context, '删除失败，请重试');
        return;
      }
      ref.read(groupsProvider.notifier).removeLocal(widget.groupId);
      if (mounted) Navigator.of(context).pop('deleted');
    } on Object {
      if (mounted) showAppToast(context, '删除失败，请重试');
    }
  }

  /// 清空群聊天记录（DELETE /ai/conversation/{id}/messages）。成功后 pop('cleared')，
  /// 聊天页据此清空本地消息列表。
  Future<void> _clearChat() async {
    final group = _group;
    if (group == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: Text('确定清空群「${group.name}」的全部聊天记录吗？\n\n此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '清空',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final resp = await ref
          .read(apiProvider)
          .delete('/ai/conversation/${widget.groupId}/messages')
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        if (mounted) showAppToast(context, '清空失败，请重试');
        return;
      }
      if (mounted) showAppToast(context, '已清空聊天记录');
      if (mounted) Navigator.of(context).pop('cleared');
    } on Object {
      if (mounted) showAppToast(context, '清空失败，请重试');
    }
  }

  /// 清空群内所有角色的长期记忆（POST /ai/memory/clear {character_ids}）。
  Future<void> _clearMemories() async {
    final group = _group;
    if (group == null || group.members.isEmpty) return;
    final shown =
        group.members.map((m) => m.name).take(3).join('、');
    final more = group.members.length > 3
        ? ' 等 ${group.members.length} 人'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空群内所有角色记忆'),
        content: Text('确定清空 $shown$more 的长期记忆吗？\n\n'
            '角色将忘记关于你们的过往。此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '清空',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final resp = await ref
          .read(apiProvider)
          .post('/ai/memory/clear', {
            'character_ids': [for (final m in group.members) m.id],
          })
          .timeout(const Duration(seconds: 30));
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        final err = root['error'];
        final msg = err is Map && err['message'] is String
            ? err['message'] as String
            : '清空失败（${resp.statusCode}）';
        if (mounted) showAppToast(context, msg);
        return;
      }
      if (mounted) {
        showAppToast(context, '已清空 ${root['deleted'] ?? 0} 条记忆');
      }
    } on Object {
      if (mounted) showAppToast(context, '清空失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('群聊信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading || group == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // 群头像 glyph + 群名
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEDEDED),
                    padding: const EdgeInsets.only(top: 10, bottom: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF576B95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            group.name.isNotEmpty ? group.name[0] : '群',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, color: Color(0xFF111111))),
                      ],
                    ),
                  ),
                        // 成员网格（微信群信息页风格）：点头像 → 编辑本世界身份
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          child: _memberGrid(group.members),
                        ),
                        const SizedBox(height: 8),
                        // 群聊名称
                        Container(
                          color: Colors.white,
                          child: _row(
                            icon: Icons.badge_outlined,
                            title: '群聊名称',
                            subtitle: group.name,
                            onTap: _rename,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 世界书
                        Container(
                          color: Colors.white,
                          child: _row(
                            icon: Icons.public,
                            title: '世界书',
                            subtitle: group.worldbook == null
                                ? '现实世界（不穿越）'
                                : group.worldbook!.name,
                            onTap: _pickWorldbook,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 查找聊天记录 / 设置当前聊天背景（验收批2）
                        Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.search,
                                    color: Color(0xFF2782D7)),
                                title: const Text('查找聊天记录',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF111111))),
                                trailing: const Icon(Icons.chevron_right,
                                    size: 20, color: Color(0xFFC8C8C8)),
                                onTap: _saving ? null : _openSearchHistory,
                              ),
                              const Divider(height: 1, indent: 56),
                              ListTile(
                                leading: const Icon(Icons.wallpaper,
                                    color: Color(0xFF2782D7)),
                                title: const Text('设置当前聊天背景',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF111111))),
                                subtitle: Text(
                                  (group.backgroundMediaId ?? '').isEmpty
                                      ? '当前使用默认背景'
                                      : '已设置自定义背景',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted),
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    size: 20, color: Color(0xFFC8C8C8)),
                                onTap: _saving ? null : _setGroupBackground,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 发言模式
                        Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('发言模式'),
                              RadioGroup<String>(
                                groupValue: group.speakerMode,
                                onChanged: (mode) {
                                  if (_saving || mode == null) return;
                                  _setSpeakerMode(mode);
                                },
                                child: Column(
                                  children: [
                                    for (final (mode, label, desc) in const [
                                      ('auto', '自动选人', '模型根据对话内容选择最合适的人回复'),
                                      ('all', '全员各回一条', '所有成员各回一条（延迟较高）'),
                                      ('mention', '点名@某人', '只回复你 @ 的那位成员'),
                                    ])
                                      RadioListTile<String>(
                                        value: mode,
                                        activeColor: const Color(0xFF07C160),
                                        title: Text(label,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF111111))),
                                        subtitle: Text(desc,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 回复模式
                        Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('回复模式'),
                              RadioGroup<String>(
                                groupValue: group.replyMode,
                                onChanged: (mode) {
                                  if (_saving ||
                                      mode == null ||
                                      mode == group.replyMode) {
                                    return;
                                  }
                                  _setReplyMode(mode);
                                },
                                child: Column(
                                  children: [
                                    for (final (mode, label, desc) in const [
                                      ('realtime', '真实回复', '像微信一样，按语气发送一条或连续几条短消息'),
                                      ('roleplay', '剧情回复', '允许括号动作、环境描写和较长回复推动情节'),
                                    ])
                                      RadioListTile<String>(
                                        value: mode,
                                        activeColor: const Color(0xFF07C160),
                                        title: Text(label,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF111111))),
                                        subtitle: Text(desc,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted)),
                                      ),
                                  ],
                                ),
                              ),
                              // 回复字数/条数（036）：后端持久化，变更即保存
                              const Divider(height: 1, indent: 16),
                              _charSliderRow(
                                label: '真实回复字数',
                                value: group.replyCharsRealtime,
                                min: 60,
                                max: 600,
                                step: 10,
                                mode: 'realtime',
                              ),
                              _charSliderRow(
                                label: '剧情回复字数',
                                value: group.replyCharsRoleplay,
                                min: 300,
                                max: 3000,
                                step: 100,
                                mode: 'roleplay',
                              ),
                              _countRow(),
                            ],
                          ),
                        ),
                        if (_anyMemberHasNoban(group.members)) ...[
                          const SizedBox(height: 8),
                          Container(
                            color: Colors.white,
                            child: SwitchListTile(
                              value: _groupNoban,
                              onChanged: _saving ? null : _toggleNoban,
                              activeThumbColor: const Color(0xFF07C160),
                              title: const Text('无违禁模式',
                                  style: TextStyle(
                                      fontSize: 16, color: Color(0xFF111111))),
                              subtitle: const Text('仅对支持无违禁的成员生效',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // 清空聊天记录
                        Container(
                          color: Colors.white,
                          child: ListTile(
                            title: const Text(
                              '清空聊天记录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFFE64340)),
                            ),
                            onTap: _saving ? null : _clearChat,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 清空群内所有角色记忆
                        Container(
                          color: Colors.white,
                          child: ListTile(
                            title: const Text(
                              '清空群内所有角色记忆',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFFE64340)),
                            ),
                            onTap: _saving ? null : _clearMemories,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 删除群聊
                        Container(
                          color: Colors.white,
                          child: ListTile(
                            title: const Text(
                              '删除群聊',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFFE64340)),
                            ),
                            onTap: _deleteGroup,
                          ),
                        ),
                      ],
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2782D7)),
      title: Text(title,
          style: const TextStyle(fontSize: 16, color: Color(0xFF111111))),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC8C8C8)),
      onTap: _saving ? null : onTap,
    );
  }

  Character? _charOf(GroupMember m) {
    final chars = ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    for (final c in chars) {
      if (c.id == m.id) return c;
    }
    return null;
  }

  /// 成员头像（#1）：真实角色头像优先，角色已删 → 色块 glyph 兜底。
  Widget _memberAvatar(GroupMember m, {double size = 48}) {
    final c = _charOf(m);
    if (c != null) {
      return CharacterAvatar(character: c, size: size, radius: 6);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _hexColor(m.avatarColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        m.avatarText?.isNotEmpty == true ? m.avatarText! : '?',
        style: TextStyle(
            color: Colors.white, fontSize: size * 0.36,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 成员网格：头像 + 名字，点按 → 编辑本世界身份（#2）。
  Widget _memberGrid(List<GroupMember> members) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final m in members)
          SizedBox(
            width: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _saving ? null : () => _editMember(m),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _memberAvatar(m),
                      const SizedBox(height: 4),
                      Text(m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF555555))),
                      // R6 配角临时成员角标：群设置可移除（移除不影响角色卡本身）
                      if (m.temporary)
                        Container(
                          margin: const EdgeInsets.only(top: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Text('临时',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFE65100),
                                  height: 1.1)),
                        ),
                    ],
                  ),
                ),
                // 移除按钮（验收批2）：右上角小红 ✕，确认后移出本群
                Positioned(
                  top: -4,
                  right: -4,
                  child: InkWell(
                    onTap: _saving ? null : () => _confirmRemove(m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE64340),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child:
                          const Icon(Icons.close, size: 11, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // "+" 添加成员
        SizedBox(
          width: 60,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _saving ? null : _addMember,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add,
                      size: 26, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 4),
                const Text('添加',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 成员编辑弹层（#2）：多行 world_identity 设定，保存 → PATCH；
  /// 底部"移出本群"。留空 = 清除身份预设。
  Future<void> _editMember(GroupMember m) async {
    final controller = TextEditingController(text: m.worldIdentity ?? '');
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _memberAvatar(m, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '本世界身份设定（留空 = 无）',
            hintText: '例如：青莲剑宗大师姐，御剑飞行',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('remove'),
            child: const Text('移出本群',
                style: TextStyle(color: Color(0xFFFA5151))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (!mounted) return;
    if (action == 'save') {
      if (text == (m.worldIdentity ?? '')) return;
      await _patch({'member_world_identities': {m.id: text}});
    } else if (action == 'remove') {
      await _removeMember(m);
    }
  }

  static Color _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF576B95);
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF576B95) : Color(0xFF000000 | v);
  }
}
