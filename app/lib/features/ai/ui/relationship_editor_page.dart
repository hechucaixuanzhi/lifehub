import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../services/relationship_service.dart';

class RelationshipEditorPage extends ConsumerStatefulWidget {
  const RelationshipEditorPage({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  ConsumerState<RelationshipEditorPage> createState() =>
      _RelationshipEditorPageState();
}

class _RelationshipEditorPageState
    extends ConsumerState<RelationshipEditorPage> {
  static const _options = <(String, String)>[
    ('initial', '初识'),
    ('friend', '朋友'),
    ('ambiguous', '暧昧'),
    ('lover', '恋人'),
    ('partner', '伴侣'),
    ('married', '夫妻'),
    ('custom', '自定义'),
  ];

  final _customController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedKind;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _customController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(RelationshipDefinition current) async {
    if (_saving) return;
    final kind = _selectedKind ?? current.kind;
    final predefined = _options.where((item) => item.$1 == kind).first.$2;
    final label = kind == 'custom' ? _customController.text.trim() : predefined;
    if (label.isEmpty) {
      showAppToast(context, '请填写关系名称');
      return;
    }
    setState(() => _saving = true);
    final value = RelationshipDefinition(
      characterId: widget.characterId,
      kind: kind,
      label: label,
      description: _descriptionController.text.trim(),
    );
    final synced = await ref
        .read(relationshipProvider(widget.characterId).notifier)
        .save(value);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppToast(context, synced ? '关系已更新' : '已保存在手机，联网后自动同步');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRelationship =
        ref.watch(relationshipProvider(widget.characterId));
    final loaded = asyncRelationship.valueOrNull;
    final current =
        loaded ?? RelationshipDefinition(characterId: widget.characterId);
    if (!_hydrated && loaded != null) {
      _hydrated = true;
      _selectedKind = current.kind;
      if (current.kind == 'custom') _customController.text = current.label;
      _descriptionController.text = current.description;
    }
    final selected = _selectedKind ?? current.kind;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        title: const Text('与我的关系',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(current),
            child: Text(_saving ? '保存中' : '保存',
                style: const TextStyle(color: Color(0xFF07C160))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) => setState(() => _selectedKind = value),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  for (var i = 0; i < _options.length; i++) ...[
                    RadioListTile<String>(
                      value: _options[i].$1,
                      activeColor: const Color(0xFF07C160),
                      title: Text(_options[i].$2),
                    ),
                    if (i != _options.length - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                ],
              ),
            ),
          ),
          if (selected == 'custom') ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _customController,
                maxLength: 30,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '自定义关系名称',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '关系补充（可选），例如你们如何确定关系、彼此的约定',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Text(
              '这是你明确设定的关系锚点。${widget.characterName}的情绪和信任可以变化，但不会擅自把关系改成别的类型。',
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}
