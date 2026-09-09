import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../models/group_chat.dart';
import 'memory_type_badge.dart';

/// 收藏进记忆（R7）：长按消息 → 收藏 → 弹窗确认后存为角色长期记忆。
/// 复用 POST /ai/memory，零新端点；content 预填消息内容、可编辑，可切换目标角色
/// 与记忆类型（事实/偏好/事件/禁止事项）。
/// - 单聊：[fixedCharacterId] 非空 → 目标角色锁定；
/// - 群聊：[members] 提供下拉，[defaultCharacterId] 预选（AI 成员消息默认归发言者）。
/// 成功保存后 pop(true)，调用方据此提示「已收藏为记忆」。
class CollectMemoryDialog extends ConsumerStatefulWidget {
  const CollectMemoryDialog({
    super.key,
    required this.initialContent,
    this.fixedCharacterId,
    this.fixedCharacterName,
    this.members = const [],
    this.defaultCharacterId,
  });

  final String initialContent;
  final String? fixedCharacterId;
  final String? fixedCharacterName;
  final List<GroupMember> members;
  final String? defaultCharacterId;

  @override
  ConsumerState<CollectMemoryDialog> createState() =>
      _CollectMemoryDialogState();
}

const _memoryTypes = [
  ('fact', '事实'),
  ('preference', '偏好'),
  ('event', '事件'),
  ('forbidden', '禁止事项'),
];

class _CollectMemoryDialogState extends ConsumerState<CollectMemoryDialog> {
  late final TextEditingController _content;
  late String _type = 'fact';
  String? _targetCharacterId;
  bool _saving = false;

  bool get _isGroupTargets => widget.members.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initialContent);
    _targetCharacterId = widget.fixedCharacterId ?? widget.defaultCharacterId;
    if (_targetCharacterId == null && _isGroupTargets) {
      _targetCharacterId = widget.members.first.id;
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _content.text.trim();
    if (content.isEmpty) {
      showAppToast(context, '记忆内容不能为空');
      return;
    }
    final target = _targetCharacterId ?? widget.fixedCharacterId;
    if (target == null) {
      showAppToast(context, '请选择收藏给哪个角色');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final resp = await ref
          .read(apiProvider)
          .post('/ai/memory', {
            'content': content,
            'type': _type,
            'character_id': target,
          })
          .timeout(const Duration(seconds: 30));
      final root = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        final err = root['error'];
        final msg = err is Map && err['message'] is String
            ? err['message'] as String
            : '收藏失败（${resp.statusCode}）';
        if (mounted) showAppToast(context, msg);
        return;
      }
      if (mounted) {
        showAppToast(context, '已收藏为记忆');
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) showAppToast(context, '收藏失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _targetName(String id) {
    if (widget.fixedCharacterName != null) return widget.fixedCharacterName!;
    for (final m in widget.members) {
      if (m.id == id) return m.name;
    }
    return '该角色';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('收藏为记忆',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 收藏给谁
              _isGroupTargets
                  ? _buildTargetSelector()
                  : _buildFixedTarget(),
              const SizedBox(height: 12),
              TextField(
                controller: _content,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: '记忆内容',
                  hintText: '这条消息想记住什么？',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              const Text('记忆类型',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _memoryTypes)
                    // 验收批3④：选中色与文字色按类型语义色区分（琥珀/蓝/红/紫）。
                    ChoiceChip(
                      label: Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              color: _type == value
                                  ? memoryTypeColor(value)
                                  : const Color(0xFF333333))),
                      selected: _type == value,
                      selectedColor: memoryTypeSoftColor(value),
                      showCheckmark: false,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _type = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '收藏中…' : '确认收藏'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单聊：目标角色锁定展示。
  Widget _buildFixedTarget() {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 18, color: Color(0xFF07C160)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '收藏给：${_targetName(_targetCharacterId ?? '')}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
          ),
        ),
      ],
    );
  }

  /// 群聊：成员下拉选择（AI 成员消息默认归发言者本人）。
  Widget _buildTargetSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _targetCharacterId,
      decoration: const InputDecoration(
        labelText: '收藏给哪个角色',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final m in widget.members)
          DropdownMenuItem(value: m.id, child: Text(m.name)),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _targetCharacterId = value),
    );
  }
}
