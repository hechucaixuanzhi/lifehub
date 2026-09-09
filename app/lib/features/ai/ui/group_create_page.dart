import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../ai_providers.dart';
import '../models/character.dart';
import '../models/group_chat.dart';
import '../models/worldbook.dart';
import 'group_chat_page.dart';

/// 发起群聊：选成员（必选 ≥1）+ 可选世界书（不选 = 现实世界）+ 群名。
/// 创建成功后替换为群聊页（后退回到来源页）。
class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  String? _worldbookId; // null = 现实世界
  final Set<String> _cardIds = {}; // R6 世界书主角卡（勾选转角色入群）
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<Character> get _candidates {
    final chars = ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    return [
      for (final c in chars)
        if (c.id != 'assistant') c, // 排除系统助手，其余角色（含主角）可入群
    ];
  }

  /// R6 主角卡勾选区：选中世界书后显示，勾选卡片创建时转角色入群。
  Widget _buildProtagonistSection(Worldbook book) {
    final protagonists = [
      for (final c in book.cards)
        if (c.kind == 'protagonist') c,
    ];
    if (protagonists.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text('世界书主角（勾选入群）',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(width: 6),
                if (_cardIds.isNotEmpty)
                  Text('${_cardIds.length}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF07C160))),
              ],
            ),
          ),
          for (final card in protagonists)
            InkWell(
              onTap: () => setState(() {
                if (_cardIds.contains(card.id)) {
                  _cardIds.remove(card.id);
                } else {
                  _cardIds.add(card.id);
                }
              }),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _hexColor(card.avatarColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        card.avatarText.isNotEmpty
                            ? card.avatarText
                            : card.name[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 52,
                        alignment: Alignment.centerLeft,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: Color(0xFFE5E5E5), width: .5),
                          ),
                        ),
                        child: Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, color: Color(0xFF111111)),
                        ),
                      ),
                    ),
                    if (card.characterId != null)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text('已入群',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9A9A9A))),
                      ),
                    if (_cardIds.contains(card.id))
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.check_circle,
                            size: 24, color: Color(0xFF07C160)),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF86B6D8);
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF86B6D8) : Color(0xFF000000 | v);
  }

  Future<void> _create() async {
    if (_saving) return;
    if (_selected.isEmpty && _cardIds.isEmpty) {
      showAppToast(context, '请至少选择一位群成员或主角卡');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
        'member_ids': _selected.toList(),
        if (_worldbookId != null) 'worldbook_id': _worldbookId,
        if (_cardIds.isNotEmpty) 'card_ids': _cardIds.toList(),
      };
      final response = await ref
          .read(apiProvider)
          .post('/ai/groups', body)
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw StateError('创建失败（${response.statusCode}）');
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final group = GroupChat.fromJson(
          Map<String, dynamic>.from(root['group'] as Map));
      final conversationId =
          (root['conversation_id'] as String?) ?? group.id;
      ref.read(groupsProvider.notifier).applyLocal(group);
      if (!mounted) return;
      // 创建页 → 群聊页（替换，不让「返回」回到空表单）
      Navigator.of(context).pushReplacement(
        AppPageRoute(builder: (_) => GroupChatPage(groupId: conversationId)),
      );
    } on Object catch (error) {
      if (mounted) showAppToast(context, '创建群聊失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickWorldbook() async {
    final books = ref.read(worldbooksProvider).valueOrNull ?? const [];
    final picked = await showAppModalSheet<String?>(
      context: context,
      builder: (ctx) => _WorldbookPicker(
        books: books,
        selectedId: _worldbookId,
      ),
    );
    if (picked == null) return; // 取消
    setState(() {
      _worldbookId = picked.isEmpty ? null : picked;
      _cardIds.clear(); // 换世界书 → 旧主角卡勾选失效
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedBook = _worldbookId == null
        ? null
        : (ref.read(worldbooksProvider).valueOrNull ?? const [])
            .where((w) => w.id == _worldbookId)
            .firstOrNull;
    final candidates = _candidates;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: const Text('发起群聊',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _create,
            child: Text(_saving ? '创建中' : '完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          // 群名称
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _name,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '群聊名称（可留空，默认「群聊」）',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 世界书
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.public, color: Color(0xFF2782D7)),
              title: const Text('世界书',
                  style: TextStyle(fontSize: 17, color: Color(0xFF111111))),
              subtitle: Text(
                selectedBook == null
                    ? '现实世界（不穿越）'
                    : selectedBook.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selectedBook == null
                      ? AppColors.muted
                      : const Color(0xFF111111),
                ),
              ),
              trailing: const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFFC8C8C8)),
              onTap: _pickWorldbook,
            ),
          ),
          const SizedBox(height: 8),
          // R6 世界书主角卡（可选勾选，转角色入群）
          if (selectedBook != null && selectedBook.cards.isNotEmpty) ...[
            _buildProtagonistSection(selectedBook),
            const SizedBox(height: 8),
          ],
          // 成员
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '选择成员（${_selected.length}）',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ),
                for (final c in candidates)
                  InkWell(
                    onTap: () => setState(() {
                      if (_selected.contains(c.id)) {
                        _selected.remove(c.id);
                      } else {
                        _selected.add(c.id);
                      }
                    }),
                    child: SizedBox(
                      height: 58,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          CharacterAvatar(character: c, size: 40, radius: 5),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              height: 58,
                              alignment: Alignment.centerLeft,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFE5E5E5), width: .5),
                                ),
                              ),
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                    fontSize: 17, color: Color(0xFF111111)),
                              ),
                            ),
                          ),
                          if (_selected.contains(c.id))
                            const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(Icons.check_circle,
                                  size: 24, color: Color(0xFF07C160)),
                            )
                          else
                            const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '还没有可加入的角色，请先到通讯录「添加人物」',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
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

/// 世界书选择弹层：现实世界（无世界书）在最上，其余按列表顺序。
/// pop 返回值：'' = 现实世界；世界书 id；null = 取消。
class _WorldbookPicker extends StatelessWidget {
  const _WorldbookPicker({required this.books, this.selectedId});

  final List<Worldbook> books;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
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
                  _option(
                    context,
                    title: '现实世界（不穿越）',
                    subtitle: '群成员以现实身份参与群聊',
                    value: '',
                  ),
                  const Divider(height: 1, indent: 16),
                  for (final w in books)
                    _option(
                      context,
                      title: w.name,
                      subtitle: w.summary.isEmpty ? '无简介' : w.summary,
                      value: w.id,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
  }) {
    final checked = value == selectedId;
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
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
              const Icon(Icons.check_circle, size: 22, color: Color(0xFF07C160)),
          ],
        ),
      ),
    );
  }
}
