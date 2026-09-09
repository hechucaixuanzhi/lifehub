import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../ai_providers.dart';
import '../models/ai_memory.dart';
import '../models/character.dart';
import 'widgets/memory_type_badge.dart';

/// AI 长期记忆页（从「我 → AI 记忆」进入）：每角色独立记忆，手机可增删改。
/// 角色取首个 memory_enabled；离线时使用本地示例角色。
class AiMemoriesPage extends ConsumerStatefulWidget {
  const AiMemoriesPage({super.key});

  @override
  ConsumerState<AiMemoriesPage> createState() => _AiMemoriesPageState();
}

class _AiMemoriesPageState extends ConsumerState<AiMemoriesPage> {
  List<AiMemory> _memories = [];
  bool _loading = true;
  bool _saving = false;
  bool _refining = false;
  String? _error;
  String _characterId = 'companion';

  @override
  void initState() {
    super.initState();
    _resolveCharacter();
    _load();
  }

  /// 当前角色不存在时才回退首个 memory_enabled；用户手动切换后不能被刷新重置。
  void _resolveCharacter() {
    final chars = ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    final targets = chars.where((c) => c.memoryEnabled).toList();
    if (targets.isEmpty) return;
    if (!targets.any((character) => character.id == _characterId)) {
      _characterId = targets.first.id;
    }
  }

  Future<void> _selectCharacter(String? characterId) async {
    if (characterId == null || characterId == _characterId) return;
    setState(() {
      _characterId = characterId;
      _memories = [];
    });
    await _load();
  }

  /// 验收批3④：底部弹层选择角色（头像横排+搜索），点选后切换并重载记忆。
  Future<void> _showCharacterPicker(List<Character> characters) async {
    final picked = await showModalBottomSheet<Character>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CharacterPickerSheet(
        characters: characters,
        currentId: _characterId,
      ),
    );
    if (picked != null) await _selectCharacter(picked.id);
  }

  Future<void> _load() async {
    _resolveCharacter();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/memory/list?character_id=$_characterId&limit=100')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _memories = [
            for (final m in (body['memories'] as List? ?? []))
              AiMemory.fromJson(m as Map<String, dynamic>),
          ];
        });
      } else {
        setState(() => _error = '加载失败 (${resp.statusCode})');
      }
    } on Object {
      setState(() => _error = 'AI 离线（家庭服务器未连接）');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 新增记忆：弹窗输入内容 + 选择类型 → POST。
  Future<void> _add() async {
    final result = await _editDialog(existing: null);
    if (result == null || mounted == false) return;
    final (content, type) = result;
    if (content.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post('/ai/memory', {
        'content': content.trim(),
        'type': type,
        'character_id': _characterId,
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('已记住');
        await _load();
      } else {
        final body = _errMsg(resp);
        _snack(body);
      }
    } on Object {
      _snack('连接失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 编辑记忆：预填弹窗 → PATCH。
  Future<void> _edit(AiMemory m) async {
    final result = await _editDialog(existing: m);
    if (result == null || mounted == false) return;
    final (content, type) = result;
    if (content.trim().isEmpty) return;
    try {
      final api = ref.read(apiProvider);
      final resp = await api.patch('/ai/memory/${m.id}', {
        'content': content.trim(),
        'type': type,
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('已更新');
        await _load();
      } else {
        _snack(_errMsg(resp));
      }
    } on Object {
      _snack('连接失败');
    }
  }

  /// 删除记忆：确认 → DELETE。
  Future<void> _remove(AiMemory m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记忆？'),
        content: Text(m.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .delete('/ai/memory/${m.id}')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('已删除');
        await _load();
      } else {
        _snack(_errMsg(resp));
      }
    } on Object {
      _snack('连接失败');
    }
  }

  /// 记忆 AI 提炼：近重复记忆由服务端 LLM 合并、归档，返回 summary。
  Future<void> _refine() async {
    if (_refining) return;
    setState(() => _refining = true);
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post(
          '/ai/memory/refine?character_id=$_characterId',
          {}).timeout(const Duration(seconds: 90)); // 提炼同步执行，可能耗时数十秒
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final s = body['summary'] as Map<String, dynamic>? ?? {};
        if (s['skipped'] != null) {
          _snack('无需提炼：${s['note'] ?? s['skipped']}');
        } else {
          _snack('提炼完成：合并 ${s['merged'] ?? 0} · 归档 ${s['archived'] ?? 0}');
        }
        await _load();
      } else {
        _snack(_errMsg(resp));
      }
    } on Object {
      _snack('连接失败（提炼可能仍在后台进行）');
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  /// 回滚一条被提炼的记忆（撤销并入/归档，或还原合并前内容）。
  Future<void> _rollback(AiMemory m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复这条记忆？'),
        content: Text(m.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post('/ai/memory/${m.id}/rollback', {}).timeout(
          const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('已恢复');
        await _load();
      } else {
        _snack(_errMsg(resp));
      }
    } on Object {
      _snack('连接失败');
    }
  }

  /// 新增/编辑共用弹窗。返回 (content, type)；取消返回 null。
  Future<(String, String)?> _editDialog({required AiMemory? existing}) async {
    final ctrl = TextEditingController(text: existing?.content ?? '');
    var type = existing?.type ?? 'fact';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '记一条' : '编辑记忆'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(hintText: '比如：用户喜欢喝美式咖啡'),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Text('类型：', style: TextStyle(fontSize: 13)),
                  for (final t in const [
                    'fact',
                    'preference',
                    'event',
                    'forbidden'
                  ])
                    // 验收批3④：选中色与文字色按类型语义色区分（琥珀/蓝/红/紫）。
                    ChoiceChip(
                      label: Text(memoryTypeLabel(t)),
                      selectedColor: memoryTypeSoftColor(t),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: type == t ? memoryTypeColor(t) : null,
                      ),
                      selected: type == t,
                      onSelected: (_) => setState(() => type = t),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (ctrl.text.trim(), type)),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  /// 后端错误消息（error.message）兜底通用文案。
  String _errMsg(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final err = body['error'];
      if (err is Map && err['message'] is String)
        return err['message'] as String;
    } on Object {
      // ignore
    }
    return '操作失败 (${resp.statusCode})';
  }

  void _snack(String msg) => showAppToast(context, msg);

  @override
  Widget build(BuildContext context) {
    final characters =
        (ref.watch(charactersProvider).valueOrNull ?? defaultCharacters)
            .where((character) => character.memoryEnabled)
            .toList();
    final selected = characters.any((character) => character.id == _characterId)
        ? _characterId
        : (characters.firstOrNull?.id);
    // 当前角色（头部展示用）：selected 恒落在 characters 内（首项兜底）；
    // characters 可能为空（无 memory_enabled 角色），头部整体隐藏。
    final selectedChar = characters.isEmpty
        ? null
        : characters.firstWhere(
            (character) => character.id == selected,
            orElse: () => characters.first,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 记忆'),
        actions: [
          TextButton.icon(
            onPressed: _refining ? null : _refine,
            icon: _refining
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('提炼'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedChar != null)
            // 验收批3④：角色选取改可点的头部 → 底部弹层（头像横排+搜索），
            // 不再用下拉框。
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => _showCharacterPicker(characters),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CharacterAvatar(
                        character: selectedChar,
                        size: 34,
                        radius: 6,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${selectedChar.name}的记忆',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.expand_more,
                          size: 20, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: _buildMemoryBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _add,
        child: const Icon(Icons.add),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMemoryBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
      );
    }
    if (_memories.isEmpty) {
      return const EmptyState(
        icon: Icons.memory_outlined,
        message: '这个角色还没有记忆，点右下角 + 记一条',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _memories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _buildCard(_memories[index]),
    );
  }

  Widget _buildCard(AiMemory m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppElevation.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // 验收批3④：类型徽标按语义色区分（偏好-琥珀/事实-蓝/禁止-红/事件-紫）。
            MemoryTypeBadge(m.type),
            if (m.isInactive)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    m.status == 'superseded' ? '已并入' : '已归档',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ),
            if (m.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _fmtDate(m.createdAt!),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            const Spacer(),
            // 被提炼的记忆 → 提供「恢复」；active → 编辑 / 删除
            if (m.isInactive)
              IconButton(
                icon: const Icon(Icons.restore,
                    size: 18, color: AppColors.accent),
                visualDensity: VisualDensity.compact,
                tooltip: '恢复',
                onPressed: () => _rollback(m),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
                onPressed: () => _edit(m),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                visualDensity: VisualDensity.compact,
                onPressed: () => _remove(m),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text(m.content, style: AppTypography.body),
        ],
      ),
    );
  }

  String _fmtDate(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) {
      final hm =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      return '今天 $hm';
    }
    return '${t.month}月${t.day}日';
  }
}

/// 验收批3④：角色选取底部弹层——搜索框 + 头像横排（可横滑，选中高亮）。
/// 点选某个角色 → pop 返回该角色；键盘弹出时用 viewInsets 上移内容。
class _CharacterPickerSheet extends StatefulWidget {
  const _CharacterPickerSheet({
    required this.characters,
    required this.currentId,
  });

  final List<Character> characters;
  final String? currentId;

  @override
  State<_CharacterPickerSheet> createState() => _CharacterPickerSheetState();
}

class _CharacterPickerSheetState extends State<_CharacterPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Character> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.characters;
    return widget.characters
        .where((character) => character.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // isScrollControlled 下用 viewInsets 让搜索框不被键盘遮挡。
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text(
                    '选择角色',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: '搜索角色',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '没有匹配的角色',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final character in _filtered) _avatarChip(character),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _avatarChip(Character character) {
    final selected = character.id == widget.currentId;
    return InkWell(
      onTap: () => Navigator.pop(context, character),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              selected ? Border.all(color: AppColors.accent, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CharacterAvatar(character: character, size: 46, radius: 8),
            const SizedBox(height: 6),
            Text(
              character.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.accent : AppColors.onBg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
