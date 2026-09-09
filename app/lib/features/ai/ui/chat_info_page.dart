import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/providers.dart';
import '../ai_providers.dart';
import '../models/character.dart';
import '../services/relationship_service.dart';
import '../services/storyline_service.dart';
import 'character_media_editor.dart';
import 'character_storyline_page.dart';
import 'profile_page.dart';
import 'search_history_page.dart';
import 'self_identity_page.dart';

const _storage = FlutterSecureStorage();

/// 聊天信息页（微信「聊天信息」，聊天页右上角「⋯」进入）：
/// 头像（→ 个人主页）/ 查找聊天记录 / 置顶聊天 / 提醒 / 设置当前聊天背景 /
/// 更换头像 / 恢复默认 / 清空聊天记录。
/// 清空成功后 pop 返回字符串 'cleared'，聊天页据此清空内存消息。
class ChatInfoPage extends ConsumerStatefulWidget {
  const ChatInfoPage({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends ConsumerState<ChatInfoPage> {
  bool _pinned = false;
  bool _noban = false;
  bool _updatingNoban = false;
  String _replyMode = 'realtime';
  int _realtimeReplyChars = 180;
  int _roleplayReplyChars = 1000;
  int _realtimeReplyCount = 3;

  Character _currentCharacter() {
    final characters = ref.read(charactersProvider).valueOrNull;
    if (characters != null) {
      for (final character in characters) {
        if (character.id == widget.character.id) return character;
      }
    }
    return widget.character;
  }

  @override
  void initState() {
    super.initState();
    _loadPin();
    _loadReplyMode();
    _loadReplySettings();
    _loadNoban();
  }

  Future<void> _loadPin() async {
    final p = await AppPrefs.isChatPinned(widget.character.id);
    if (mounted) setState(() => _pinned = p);
  }

  Future<void> _togglePin(bool v) async {
    setState(() => _pinned = v);
    await AppPrefs.setChatPinned(widget.character.id, v);
  }

  Future<void> _loadNoban() async {
    final value = await AppPrefs.isChatNoban(widget.character.id);
    if (mounted) setState(() => _noban = value);
  }

  Future<void> _toggleNoban(bool value) async {
    if (_updatingNoban || value == _noban) return;
    if (value) {
      setState(() => _noban = true);
      await AppPrefs.setChatNoban(widget.character.id, true);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭无违禁模式'),
        content: const Text(
          '关闭后将恢复当前关系阶段的亲密边界。\n\n'
          '是否同时剔除历次无违禁聊天形成的长期记忆和双方聊天消息？'
          '普通聊天记忆、角色历史、关系设定和剧情不会受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('保留记忆'),
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

    setState(() => _updatingNoban = true);
    try {
      var deleted = 0;
      var deletedMessages = 0;
      if (choice == 'purge') {
        final response = await ref
            .read(apiProvider)
            .delete('/ai/characters/${widget.character.id}/memories/noban')
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) throw Exception('purge failed');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        deleted = (body['deleted'] as num?)?.toInt() ?? 0;
        deletedMessages = (body['deleted_messages'] as num?)?.toInt() ?? 0;
        final convId = await _convId();
        if (convId != null && convId.isNotEmpty) {
          await ref.read(dbProvider).deleteChatMessages(convId);
        }
      }
      await AppPrefs.setChatNoban(widget.character.id, false);
      if (!mounted) return;
      setState(() => _noban = false);
      showAppToast(
        context,
        choice == 'purge'
            ? '已关闭：剔除 $deleted 条记忆和 $deletedMessages 条消息'
            : '已关闭，相关记忆已保留',
      );
      if (choice == 'purge' && mounted) {
        Navigator.of(context).pop('noban_purged');
      }
    } on Object {
      if (mounted) showAppToast(context, '未能剔除记忆，无违禁模式仍保持开启');
    } finally {
      if (mounted) setState(() => _updatingNoban = false);
    }
  }

  Future<void> _loadReplyMode() async {
    final mode = await AppPrefs.chatReplyMode(widget.character.id);
    if (mounted) setState(() => _replyMode = mode);
  }

  Future<void> _loadReplySettings() async {
    final values = await Future.wait<int>([
      AppPrefs.realtimeReplyChars(widget.character.id),
      AppPrefs.roleplayReplyChars(widget.character.id),
      AppPrefs.realtimeReplyCount(widget.character.id),
    ]);
    if (!mounted) return;
    setState(() {
      _realtimeReplyChars = values[0];
      _roleplayReplyChars = values[1];
      _realtimeReplyCount = values[2];
    });
  }

  int get _currentReplyChars =>
      _replyMode == 'roleplay' ? _roleplayReplyChars : _realtimeReplyChars;

  Future<void> _setReplyChars(int value) async {
    if (_replyMode == 'roleplay') {
      setState(() => _roleplayReplyChars = value);
      await AppPrefs.setRoleplayReplyChars(widget.character.id, value);
    } else {
      setState(() => _realtimeReplyChars = value);
      await AppPrefs.setRealtimeReplyChars(widget.character.id, value);
    }
  }

  void _chooseReplyChars() {
    final choices = _replyMode == 'roleplay'
        ? const [(600, '简短'), (1000, '标准'), (1800, '较长'), (2800, '长篇')]
        : const [(100, '简短'), (180, '自然'), (300, '详细'), (500, '长回复')];
    showAppModalSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              ListTile(
                leading: Icon(
                  _currentReplyChars == choice.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF07C160),
                ),
                title: Text('${choice.$2}（目标约 ${choice.$1} 字）'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setReplyChars(choice.$1);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setReplyCount(int value) async {
    setState(() => _realtimeReplyCount = value);
    await AppPrefs.setRealtimeReplyCount(widget.character.id, value);
  }

  void _chooseReplyCount() {
    showAppModalSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var count = 1; count <= 5; count++)
              ListTile(
                leading: Icon(
                  _realtimeReplyCount == count
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF07C160),
                ),
                title: Text('$count 条'),
                subtitle: count == 1
                    ? const Text('整段回复放在一个气泡里')
                    : Text('按语义发送 $count 个连续气泡'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setReplyCount(count);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setReplyMode(String mode) async {
    final value = mode == 'roleplay' ? 'roleplay' : 'realtime';
    setState(() => _replyMode = value);
    await AppPrefs.setChatReplyMode(widget.character.id, value);
    try {
      final convId = await _convId();
      if (convId != null && convId.isNotEmpty) {
        final response = await ref
            .read(apiProvider)
            .patch('/ai/conversation/$convId', {'reply_mode': value});
        if (response.statusCode != 200) throw Exception('sync failed');
      }
      if (mounted) showAppToast(context, '聊天模式已更新');
    } on Object {
      if (mounted) showAppToast(context, '已保存在手机，下次聊天自动同步');
    }
  }

  void _chooseReplyMode() {
    showAppModalSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _replyMode == 'realtime'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF07C160),
              ),
              title: const Text('真实回复'),
              subtitle: const Text('像微信一样，按语气发送一条或连续几条短消息'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setReplyMode('realtime');
              },
            ),
            ListTile(
              leading: Icon(
                _replyMode == 'roleplay'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF07C160),
              ),
              title: const Text('剧情回复'),
              subtitle: const Text('允许括号动作、环境描写和较长回复推动情节'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setReplyMode('roleplay');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _convId() async =>
      _storage.read(key: widget.character.convKey);

  void _openProfile() {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => ProfilePage(character: _currentCharacter())),
    );
  }

  Future<void> _openSearch() async {
    final convId = await _convId();
    if (!mounted) return;
    if (convId == null || convId.isEmpty) {
      showAppToast(context, '暂无聊天记录');
      return;
    }
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => SearchHistoryPage(
          character: _currentCharacter(),
          conversationId: convId,
        ),
      ),
    );
  }

  Future<void> _setBackground() async {
    final r = await pickAndPatchCharacterMedia(
      context,
      ref,
      _currentCharacter(),
      isAvatar: false,
    );
    if (!mounted) return;
    showAppToast(
        context, switch (r) { 'ok' => '背景已更新', 'fail' => '更新失败，请重试', _ => '' });
  }

  Future<void> _setAvatar() async {
    final r = await pickAndPatchCharacterMedia(
      context,
      ref,
      _currentCharacter(),
      isAvatar: true,
    );
    if (!mounted) return;
    showAppToast(
        context, switch (r) { 'ok' => '头像已更新', 'fail' => '更新失败，请重试', _ => '' });
  }

  Future<void> _resetMedia() async {
    final ok = await resetCharacterMedia(context, ref, _currentCharacter());
    if (!mounted) return;
    showAppToast(context, ok ? '已恢复默认' : '恢复失败，请重试');
  }

  /// 提醒（占位）：选择提醒时间 → toast（后续可接通知调度）。
  void _remind() {
    void done(BuildContext sheetCtx, String what) {
      Navigator.of(sheetCtx).pop();
      showAppToast(context, '已设置 $what 提醒（占位）');
    }

    showAppModalSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, what) in [
              ('1小时后提醒', '1 小时后'),
              ('今晚提醒', '今晚'),
              ('明天上午提醒', '明天上午'),
            ])
              ListTile(
                leading: const Icon(Icons.schedule, color: AppColors.onBg),
                title: Text(label,
                    style:
                        const TextStyle(fontSize: 16, color: AppColors.onBg)),
                onTap: () => done(sheetCtx, what),
              ),
          ],
        ),
      ),
    );
  }

  /// 清空聊天记录：确认 → 后端删消息 + 清本地缓存 → pop('cleared')。
  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: Text(
          '确定清空「${widget.character.name}」的可见聊天记录吗？\n\n'
          '长期记忆、人物关系、剧情位置和角色档案都会保留；被删除的消息本身无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空', style: TextStyle(color: Color(0xFFE64340))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final convId = await _convId();
      if (convId != null && convId.isNotEmpty) {
        await ref.read(apiProvider).delete('/ai/conversation/$convId/messages');
        await ref.read(dbProvider).deleteChatMessages(convId);
      }
      ref.read(conversationsProvider.notifier).removeLocal(widget.character.id);
      if (!mounted) return;
      showAppToast(context, '聊天记录已清空，长期记忆已保留');
      Navigator.of(context).pop('cleared');
    } on Object {
      if (mounted) showAppToast(context, '清空失败，请重试');
    }
  }

  /// 正式版前测试入口：让当前角色与用户从初识重新开始。
  Future<void> _reintroduce() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新认识'),
        content: Text(
          '这会清除你和「${widget.character.name}」的聊天、长期记忆、关系与情绪状态，并把关系恢复为“初识”。\n\n'
          '会保留：你的个人资料、角色设定与公开历史、自我识别照片、头像、聊天背景和整条故事路线；剧情当前位置会退回初始位置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('重新认识', style: TextStyle(color: Color(0xFFE64340))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await ref.read(apiProvider).post(
        '/ai/characters/${widget.character.id}/reset',
        {'scope': 'reintroduce'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('reset failed');
      final convId = await _convId();
      if (convId != null && convId.isNotEmpty) {
        await ref.read(dbProvider).deleteChatMessages(convId);
      }
      await _storage.delete(key: widget.character.convKey);
      await AppPrefs.saveChatDraft(widget.character.id, '');
      ref.read(conversationsProvider.notifier).removeLocal(widget.character.id);
      await ref
          .read(relationshipProvider(widget.character.id).notifier)
          .applyReset();
      await ref
          .read(storylineProvider(widget.character.id).notifier)
          .applyReset();
      if (!mounted) return;
      showAppToast(context, '已恢复为初识状态');
      Navigator.of(context).pop('cleared');
    } on Object {
      if (mounted) showAppToast(context, '重新认识失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    var c = widget.character;
    for (final character
        in ref.watch(charactersProvider).valueOrNull ?? const <Character>[]) {
      if (character.id == widget.character.id) {
        c = character;
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
        title: const Text('聊天信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          // 头像卡：点进入个人主页
          Container(
            color: Colors.white,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CharacterAvatar(character: c, size: 56, radius: 7),
              title: Text(c.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w500)),
              subtitle: Text(c.tagline ?? '',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: _openProfile,
            ),
          ),
          const SizedBox(height: 8),
          // 跟随当前角色的故事档案；未来新增角色自动使用各自 character_id。
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.auto_stories_outlined,
                  color: AppColors.onBg),
              title: const Text('故事档案',
                  style: TextStyle(fontSize: 16, color: AppColors.onBg)),
              subtitle: const Text('线性剧情路线与当前位置',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.of(context).push(
                AppPageRoute(
                  builder: (_) => CharacterStorylinePage(
                    characterId: widget.character.id,
                    characterName: widget.character.name,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 查找聊天记录
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.search, color: AppColors.onBg),
              title: const Text('查找聊天记录',
                  style: TextStyle(fontSize: 16, color: AppColors.onBg)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: _openSearch,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.forum_outlined, color: AppColors.onBg),
                  title: const Text('聊天模式',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  subtitle: Text(
                    _replyMode == 'roleplay' ? '剧情回复' : '真实回复',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _chooseReplyMode,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.format_size, color: AppColors.onBg),
                  title: const Text('回复字数',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  subtitle: Text(
                    '${_replyMode == 'roleplay' ? '剧情回复' : '真实回复'} · 约 $_currentReplyChars 字',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _chooseReplyChars,
                ),
                if (_replyMode == 'realtime') ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.splitscreen_outlined,
                        color: AppColors.onBg),
                    title: const Text('回复条数',
                        style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                    subtitle: Text(
                      '目标 $_realtimeReplyCount 条，按完整语义分段',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: _chooseReplyCount,
                  ),
                ],
                if (c.hasNoban) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.favorite_border,
                        color: AppColors.onBg),
                    title: const Text('无违禁模式',
                        style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                    subtitle: const Text('开启后不受当前关系阶段的亲密限制',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    trailing: Switch(
                      value: _noban,
                      activeTrackColor: const Color(0xFF07C160),
                      onChanged: _updatingNoban ? null : _toggleNoban,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 置顶聊天 / 提醒
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined,
                      color: AppColors.onBg),
                  title: const Text('置顶聊天',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  trailing: Switch(
                    value: _pinned,
                    activeTrackColor: const Color(0xFF07C160),
                    onChanged: _togglePin,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.notifications_none,
                      color: AppColors.onBg),
                  title: const Text('提醒',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _remind,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 设置当前聊天背景 / 更换头像 / 恢复默认
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wallpaper, color: AppColors.onBg),
                  title: const Text('设置当前聊天背景',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  subtitle: Text(
                    (c.backgroundMediaId ?? '').isEmpty
                        ? '当前使用默认背景'
                        : '已设置自定义背景',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _setBackground,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural,
                      color: AppColors.onBg),
                  title: const Text('更换头像',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _setAvatar,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: AppColors.onBg),
                  title: const Text('恢复默认头像背景',
                      style: TextStyle(fontSize: 16, color: AppColors.onBg)),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: _resetMedia,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 自我识别（017）：身份库导入 + 阈值校准入口
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.face_retouching_natural,
                  color: AppColors.onBg),
              title: const Text('自我识别',
                  style: TextStyle(fontSize: 16, color: AppColors.onBg)),
              subtitle: const Text('导入参考照，让她认出图里的自己',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => const SelfIdentityPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 清空聊天记录（红色警示）
          Container(
            color: Colors.white,
            child: ListTile(
              title: const Center(
                child: Text('清空聊天记录',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE64340))),
              ),
              onTap: _clearHistory,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: ListTile(
              title: const Center(
                child: Text('重新认识',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE64340))),
              ),
              subtitle: const Center(
                child: Text('清除聊天、记忆和关系状态',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              onTap: _reintroduce,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
