import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../ai_providers.dart';
import '../models/group_chat.dart';
import '../models/worldbook.dart';
import 'worldbook_detail_page.dart';

/// 世界书卡片详情/编辑（R6）：按 kind 展示对应字段。
/// 角色卡（主角/配角）在未转角色前提供「加入群聊 / 临时加入群聊」，成功回填
/// character_id（卡片角标「已入群」，此群内即成为正式/临时成员）。
/// 保存成功后写穿 [worldbooksProvider]（applyLocal），详情页自动刷新。
class WorldbookCardPage extends ConsumerStatefulWidget {
  const WorldbookCardPage({
    super.key,
    required this.worldbookId,
    required this.kind,
    this.card,
  });

  final String worldbookId;
  final String kind;
  final WorldbookCard? card;

  @override
  ConsumerState<WorldbookCardPage> createState() => _WorldbookCardPageState();
}

/// 卡片 avatar 色板（与后端 _card_color 同源近似，保证新卡即有稳定底色）。
const _avatarPalette = [
  '#E7A5B5',
  '#86B6D8',
  '#9BC69B',
  '#C5A6D8',
  '#D8B486',
  '#83BDB5',
  '#F0B36A',
  '#8FA9C9',
];

class _NodeDraft {
  _NodeDraft(this.title, this.content);

  final TextEditingController title;
  final TextEditingController content;

  void dispose() {
    title.dispose();
    content.dispose();
  }
}

class _WorldbookCardPageState extends ConsumerState<WorldbookCardPage> {
  late String _kind;
  late String _avatarColor;
  late final TextEditingController _name;
  late final TextEditingController _avatarText;
  late final TextEditingController _description;
  late final TextEditingController _roleRank;
  late final TextEditingController _premise;
  late final TextEditingController _progress;
  late final TextEditingController _direction;
  late final List<_NodeDraft> _nodes;
  String? _characterId;
  bool _saving = false;
  bool _joining = false;

  bool get _isEdit => widget.card != null;
  bool get _isCharacter =>
      _kind == 'protagonist' || _kind == 'supporting';

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _kind = card?.kind ?? widget.kind;
    _avatarColor = card?.avatarColor ?? '#86B6D8';
    _name = TextEditingController(text: card?.name ?? '');
    _avatarText = TextEditingController(text: card?.avatarText ?? '');
    _description = TextEditingController(text: card?.description ?? '');
    _roleRank = TextEditingController(text: card?.roleRank ?? '');
    _premise = TextEditingController(text: card?.premise ?? '');
    _progress = TextEditingController(text: card?.progress ?? '');
    _direction = TextEditingController(text: card?.direction ?? '');
    _nodes = [
      for (final n in (card?.nodes ?? const []))
        _NodeDraft(
          TextEditingController(text: n['title'] as String? ?? ''),
          TextEditingController(text: n['content'] as String? ?? ''),
        ),
    ];
    _characterId = card?.characterId;
  }

  @override
  void dispose() {
    _name.dispose();
    _avatarText.dispose();
    _description.dispose();
    _roleRank.dispose();
    _premise.dispose();
    _progress.dispose();
    _direction.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// 找到世界书当前对象（provider 缓存为权威）。
  Worldbook? _bookOf(WidgetRef ref) {
    for (final w in ref.read(worldbooksProvider).valueOrNull ?? const <Worldbook>[]) {
      if (w.id == widget.worldbookId) return w;
    }
    return null;
  }

  void _applyCard(WidgetRef ref, WorldbookCard card) {
    final book = _bookOf(ref);
    if (book == null) return;
    final cards = [...book.cards];
    final idx = cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      cards[idx] = card;
    } else {
      cards.add(card);
    }
    ref.read(worldbooksProvider.notifier)
        .applyLocal(book.copyWith(cards: cards));
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '请填写卡片名称');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'kind': _kind,
        'name': name,
        'description': _description.text.trim(),
        'avatar_text': _avatarText.text.trim().isEmpty
            ? name[0]
            : _avatarText.text.trim(),
        'avatar_color': _avatarColor,
        if (_isCharacter) 'role_rank': _roleRank.text.trim(),
        if (_kind == 'plotline') ...{
          'premise': _premise.text.trim(),
          'progress': _progress.text.trim(),
          'direction': _direction.text.trim(),
          'nodes': [
            for (final n in _nodes)
              if (n.title.text.trim().isNotEmpty ||
                  n.content.text.trim().isNotEmpty)
                {'title': n.title.text.trim(), 'content': n.content.text.trim()},
          ],
        },
      };
      final response = await (_isEdit
          ? ref
              .read(apiProvider)
              .patch(
                  '/worldbooks/${widget.worldbookId}/cards/${widget.card!.id}',
                  body)
          : ref.read(apiProvider).post('/worldbooks/${widget.worldbookId}/cards', body))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('save failed: ${response.statusCode}');
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final card = WorldbookCard.fromJson(
          Map<String, dynamic>.from(root['card'] as Map));
      _applyCard(ref, card);
      if (mounted) {
        showAppToast(context, _isEdit ? '已保存' : '已创建「${card.name}」');
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (mounted) showAppToast(context, '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final card = widget.card;
    if (card == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除卡片'),
        content: Text('确定删除卡片「${card.name}」吗？\n'
            '已入群的角色不受影响，只移除这张卡片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFE64340))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final resp = await ref
          .read(apiProvider)
          .delete('/worldbooks/${widget.worldbookId}/cards/${card.id}')
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        if (mounted) showAppToast(context, '删除失败，请重试');
        return;
      }
      final book = _bookOf(ref);
      if (book != null) {
        final cards = [
          for (final c in book.cards)
            if (c.id != card.id) c,
        ];
        ref.read(worldbooksProvider.notifier)
            .applyLocal(book.copyWith(cards: cards));
      }
      if (mounted) {
        showAppToast(context, '已删除');
        Navigator.of(context).pop();
      }
    } on Object {
      if (mounted) showAppToast(context, '删除失败，请重试');
    }
  }

  /// 角色卡入群（R6）：主角 join_group / 配角 temporary_join。
  /// 先刷新群列表再选群；成功后回填 character_id 并写穿 provider。
  Future<void> _joinGroup({required bool temporary}) async {
    if (_joining) return;
    await ref.read(groupsProvider.notifier).reload();
    final groups = ref.read(groupsProvider).valueOrNull ?? const <GroupChat>[];
    if (groups.isEmpty) {
      if (mounted) showAppToast(context, '还没有群聊，请先到通讯录「发起群聊」');
      return;
    }
    final card = widget.card;
    if (card == null || !mounted) return;
    final group = await showAppModalSheet<GroupChat>(
      context: context,
      builder: (ctx) => _GroupPicker(groups: groups),
    );
    if (group == null || !mounted) return;
    setState(() => _joining = true);
    try {
      final path = temporary
          ? '/worldbooks/${widget.worldbookId}/cards/${card.id}/temporary_join'
          : '/worldbooks/${widget.worldbookId}/cards/${card.id}/join_group';
      final resp = await ref
          .read(apiProvider)
          .post(path, {'group_id': group.id})
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw StateError('join failed: ${resp.statusCode}');
      }
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      final characterId = root['character_id'] as String? ?? '';
      if (characterId.isNotEmpty) {
        _applyCard(ref, card.copyWith(characterId: characterId));
        setState(() => _characterId = characterId);
      }
      // 群成员已变化：后台刷新群列表缓存（群设置打开时本就重拉详情，这里兜底）。
      unawaited(ref.read(groupsProvider.notifier).reload());
      if (mounted) {
        showAppToast(
            context, temporary ? '已临时加入「${group.name}」' : '已加入「${group.name}」');
      }
    } on Object catch (error) {
      if (mounted) showAppToast(context, '加入群聊失败：$error');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = cardKindInfo(_kind);
    final alreadyJoined = _characterId != null;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: Text(_isEdit ? '编辑卡片' : '新建卡片',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          // 卡片类型
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('卡片类型',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in worldbookCardKinds)
                      ChoiceChip(
                        label: Text(k.label,
                            style: TextStyle(
                                fontSize: 13,
                                color: _kind == k.kind
                                    ? Colors.white
                                    : const Color(0xFF333333))),
                        selected: _kind == k.kind,
                        selectedColor: k.color,
                        showCheckmark: false,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _kind = k.kind),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 基本信息
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('基本信息',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: '卡片名称 *',
                    hintText: '例如：云中君 / 青莲剑宗 / 天渊秘境',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _avatarText,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: '头像字（1-2 字）',
                          hintText: '留空默认取首字',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('头像底色',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final color in _avatarPalette)
                                GestureDetector(
                                  onTap: _saving
                                      ? null
                                      : () => setState(
                                          () => _avatarColor = color),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _hexColor(color),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _avatarColor == color
                                            ? const Color(0xFF111111)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLength: 4000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: _isCharacter
                        ? '角色设定 / 性格背景'
                        : (_kind == 'plotline' ? '情节概要' : '描述'),
                    hintText: _isCharacter
                        ? '这个角色是怎样的一个人？入群后作为人格底层的补充设定'
                        : '用于群聊情境层注入的世界构成信息',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (_isCharacter) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roleRank,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '地位 / 辈分',
                      hintText: '例如：掌门 / 大师姐 / 三皇子',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_kind == 'plotline') ...[
            const SizedBox(height: 8),
            _buildPlotFields(),
          ],
          // 角色卡入群操作
          if (_isCharacter && _isEdit) ...[
            const SizedBox(height: 8),
            _buildJoinSection(info, alreadyJoined),
          ],
          // 删除
          if (_isEdit) ...[
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              child: ListTile(
                title: const Text('删除卡片',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFFE64340))),
                onTap: _saving ? null : _delete,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlotFields() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('情节线推进',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: _premise,
            maxLength: 4000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '缘起（Premise）',
              hintText: '这条情节线的起因 / 大背景',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _progress,
            maxLength: 4000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '进度（Progress）',
              hintText: '当前进展到哪一步',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _direction,
            maxLength: 4000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '走向（Direction）',
              hintText: '接下来的发展方向 / 悬念',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          const Text('情节节点',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 8),
          for (var i = 0; i < _nodes.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nodes[i].title,
                    maxLength: 80,
                    decoration: InputDecoration(
                      hintText: '节点 ${i + 1} 标题',
                      border: const OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nodes[i].content,
                    maxLength: 4000,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '内容',
                      border: OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _nodes.removeAt(i).dispose();
                          }),
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: Color(0xFFFA5151)),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() => _nodes
                      .add(_NodeDraft(TextEditingController(), TextEditingController()))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加节点',
                  style: TextStyle(fontSize: 13, color: Color(0xFF2782D7))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinSection(CardKindInfo info, bool alreadyJoined) {
    final bool isProtagonist = _kind == 'protagonist';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('加入群聊',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 8),
          if (alreadyJoined)
            const Row(
              children: [
                Icon(Icons.check_circle,
                    size: 20, color: Color(0xFF07C160)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('已入群（角色已创建）',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF111111))),
                ),
              ],
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF07C160),
                  foregroundColor: Colors.white,
                ),
                onPressed: _joining
                    ? null
                    : () => _joinGroup(temporary: !isProtagonist),
                child: Text(_joining
                    ? '加入中…'
                    : (isProtagonist
                        ? '把主角加入群聊'
                        : '把配角临时加入现有群')),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isProtagonist
                  ? '主角转成角色后永久入群；也可在建群/群设置时勾选。'
                  : '配角临时加入短聊，群设置里可移除，不影响角色本身。',
              style: const TextStyle(
                  fontSize: 11, height: 1.4, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  static Color _hexColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? const Color(0xFF86B6D8) : Color(0xFF000000 | v);
  }
}

/// 群选择弹层：列出全部群聊，pop 返回所选 [GroupChat]。
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.groups});

  final List<GroupChat> groups;

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
                child: Text('选择群聊',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final g in groups)
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF576B95),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          g.name.isNotEmpty ? g.name[0] : '群',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, color: Color(0xFF111111))),
                      subtitle: Text('${g.memberCount} 位成员',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                      onTap: () => Navigator.of(context).pop(g),
                    ),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('还没有群聊，请先到通讯录「发起群聊」',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
