import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../ai_providers.dart';
import '../models/worldbook.dart';
import 'worldbook_card_page.dart';

/// 世界书详情页（R6）：世界信息编辑（名称/简介/规则）+ 世界卡片分区。
/// [bookId] 为 null → 新建模式：先保存世界信息创建实体，再展示卡片管理。
class WorldbookDetailPage extends ConsumerStatefulWidget {
  const WorldbookDetailPage({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<WorldbookDetailPage> createState() =>
      _WorldbookDetailPageState();
}

/// 卡片类型展示顺序 + 文案 + 图标（分区渲染共用）。
const List<CardKindInfo> worldbookCardKinds = [
  CardKindInfo('protagonist', '主角', Icons.person, Color(0xFFE7A5B5)),
  CardKindInfo('supporting', '配角', Icons.group, Color(0xFF86B6D8)),
  CardKindInfo('faction', '势力', Icons.flag, Color(0xFF9BC69B)),
  CardKindInfo('location', '地点', Icons.place, Color(0xFFC5A6D8)),
  CardKindInfo('plotline', '情节线', Icons.timeline, Color(0xFFD8B486)),
];

class CardKindInfo {
  const CardKindInfo(this.kind, this.label, this.icon, this.color);

  final String kind;
  final String label;
  final IconData icon;
  final Color color;
}

/// 卡片类型 key → 分区信息（避免页面间重复维护）。
CardKindInfo cardKindInfo(String kind) {
  for (final k in worldbookCardKinds) {
    if (k.kind == kind) return k;
  }
  return const CardKindInfo('', '其他', Icons.label, Color(0xFF9A9A9A));
}

class _WorldbookDetailPageState extends ConsumerState<WorldbookDetailPage> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _rules;
  bool _saving = false;

  /// 新建模式：首次保存后回填，此后按已存在世界书编辑（PATCH）。
  String? _createdId;

  bool get _isCreate => widget.bookId == null && _createdId == null;

  String get _bookId => _createdId ?? widget.bookId ?? '';

  @override
  void initState() {
    super.initState();
    final book = _initialBook();
    _name = TextEditingController(text: book?.name ?? '');
    _summary = TextEditingController(text: book?.summary ?? '');
    _rules = TextEditingController(text: book?.rules ?? '');
  }

  /// 编辑模式：从 provider 取初值（详情页打开时世界书必已在缓存）。
  Worldbook? _initialBook() {
    if (widget.bookId == null) return null;
    for (final w in ref.read(worldbooksProvider).valueOrNull ?? const <Worldbook>[]) {
      if (w.id == widget.bookId) return w;
    }
    return null;
  }

  /// provider 里的最新世界书（卡片变更后 applyLocal 会自动驱动重建）。
  Worldbook? get _liveBook {
    if (_bookId.isEmpty) return null;
    for (final w in ref.read(worldbooksProvider).valueOrNull ?? const <Worldbook>[]) {
      if (w.id == _bookId) return w;
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '请填写世界书名称');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'summary': _summary.text.trim(),
        'rules': _rules.text.trim(),
      };
      final response = await (_isCreate
          ? ref.read(apiProvider).post('/worldbooks', body)
          : ref.read(apiProvider).patch('/worldbooks/$_bookId', body))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('save failed: ${response.statusCode}');
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final book = Worldbook.fromJson(
          Map<String, dynamic>.from(root['worldbook'] as Map));
      ref.read(worldbooksProvider.notifier).applyLocal(book);
      setState(() {
        if (_isCreate) _createdId = book.id;
      });
      if (mounted) showAppToast(context, '已保存「${book.name}」');
    } on Object catch (error) {
      if (mounted) showAppToast(context, '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openCard(String kind, WorldbookCard? card) {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => WorldbookCardPage(
          worldbookId: _bookId,
          kind: card?.kind ?? kind,
          card: card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _liveBook;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: Text(
          _isCreate ? '新建世界书' : (book?.name ?? '世界书'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          // 世界信息编辑
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('世界信息',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '世界书名称 *',
                    hintText: '例如：仙侠界 / 末世废土',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _summary,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '世界简介',
                    hintText: '这个世界是什么样的，一句话说清',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rules,
                  maxLength: 4000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '世界规则 / 社会背景',
                    hintText: '群成员穿越进来后需要遵守的设定：力量体系、禁忌、社会规则等',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _saveInfo,
                    child: Text(_saving ? '保存中…' : '保存世界信息'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 卡片分区（新建模式保存后才展示）
          if (book != null) _buildCardSections(book),
        ],
      ),
    );
  }

  Widget _buildCardSections(Worldbook book) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('世界卡片',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
              const SizedBox(width: 8),
              Text('${book.cards.length}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9A9A9A))),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _openCard('protagonist', null),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('＋ 新建卡片',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF2782D7))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final info in worldbookCardKinds) ...[
            _buildKindGroup(book, info),
            const SizedBox(height: 12),
          ],
          const Text(
            '主角卡可「永久加入」群聊（或建群时勾选）；配角卡「临时加入」现有群，在群设置里可移除，不影响角色本身。势力/地点/情节线会注入群聊情境层供全员感知。',
            style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildKindGroup(Worldbook book, CardKindInfo info) {
    final cards = [
      for (final c in book.cards)
        if (c.kind == info.kind) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(info.icon, size: 16, color: info.color),
            const SizedBox(width: 6),
            Text(info.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (cards.isNotEmpty)
              Text(' ${cards.length}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9A9A9A))),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _openCard(info.kind, null),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text('＋ 新建',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF2782D7))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (cards.isEmpty)
          const Text('暂无',
              style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)))
        else
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [for (final c in cards) _cardTile(book, c)],
          ),
      ],
    );
  }

  Widget _cardTile(Worldbook book, WorldbookCard card) {
    final subtitle = switch (card.kind) {
      'protagonist' || 'supporting' => card.roleRank,
      'plotline' => card.progress,
      _ => card.description,
    };
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openCard(card.kind, card),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hexColor(card.avatarColor) ?? cardKindInfo(card.kind).color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    card.avatarText.isNotEmpty ? card.avatarText : card.name[0],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (card.characterId != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('已入群',
                          style: TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF111111))),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  static Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
