import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../services/storyline_service.dart';

class CharacterStorylinePage extends ConsumerStatefulWidget {
  const CharacterStorylinePage({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  ConsumerState<CharacterStorylinePage> createState() =>
      _CharacterStorylinePageState();
}

class _CharacterStorylinePageState
    extends ConsumerState<CharacterStorylinePage> {
  final List<_EditableStoryNode> _nodes = [];
  String? _currentNodeId;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _hydrate(CharacterStorylineData value) {
    if (_hydrated) return;
    _hydrated = true;
    _nodes.addAll(value.nodes.map(_EditableStoryNode.fromNode));
    if (_nodes.isEmpty) {
      _nodes.add(_EditableStoryNode.empty(id: 'start', title: '初始位置'));
    }
    _currentNodeId = _nodes.any((node) => node.id == value.currentNodeId)
        ? value.currentNodeId
        : _nodes.first.id;
  }

  void _addNode() {
    if (_nodes.length >= 60) {
      showAppToast(context, '最多可添加 60 个位置');
      return;
    }
    setState(() {
      _nodes.add(
        _EditableStoryNode.empty(
          id: 'node_${DateTime.now().microsecondsSinceEpoch}',
          title: '位置 ${_nodes.length + 1}',
        ),
      );
    });
  }

  Future<void> _removeNode(int index) async {
    if (index == 0 || index >= _nodes.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个位置'),
        content: const Text('只会删除这个剧情位置，其他位置不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      final removed = _nodes.removeAt(index);
      if (_currentNodeId == removed.id) {
        _currentNodeId = _nodes[index - 1].id;
      }
      removed.dispose();
    });
  }

  Future<void> _save() async {
    if (_saving || _nodes.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final nodes = <StorylineNode>[
      for (var index = 0; index < _nodes.length; index++)
        StorylineNode(
          id: _nodes[index].id,
          title: _nodes[index].title.text.trim().isEmpty
              ? (index == 0 ? '初始位置' : '位置 ${index + 1}')
              : _nodes[index].title.text.trim(),
          content: _nodes[index].content.text.trim(),
        ),
    ];
    final current = nodes.any((node) => node.id == _currentNodeId)
        ? _currentNodeId!
        : nodes.first.id;
    final synced =
        await ref.read(storylineProvider(widget.characterId).notifier).save(
              CharacterStorylineData(
                characterId: widget.characterId,
                nodes: nodes,
                currentNodeId: current,
              ),
            );
    if (!mounted) return;
    setState(() => _saving = false);
    showAppToast(context, synced ? '剧情路线已保存' : '已保存在手机，联网后自动同步');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final asyncStory = ref.watch(storylineProvider(widget.characterId));
    final loaded = asyncStory.valueOrNull;
    if (loaded != null) _hydrate(loaded);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${widget.characterName}的故事',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: !_hydrated || _saving ? null : _save,
            child: Text(
              _saving ? '保存中' : '保存',
              style: const TextStyle(color: Color(0xFF07C160)),
            ),
          ),
        ],
      ),
      body: !_hydrated
          ? Center(
              child: asyncStory.hasError
                  ? TextButton(
                      onPressed: () => ref.invalidate(
                        storylineProvider(widget.characterId),
                      ),
                      child: const Text('加载失败，点击重试'),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF07C160)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    '剧情按顺序发展。当前位置之前视为已经发生，之后只是计划；每个位置都可以填写和修改。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF777777),
                    ),
                  ),
                ),
                for (var index = 0; index < _nodes.length; index++)
                  _TimelineNodeCard(
                    node: _nodes[index],
                    index: index,
                    isCurrent: _currentNodeId == _nodes[index].id,
                    isLast: index == _nodes.length - 1,
                    onSetCurrent: () => setState(
                      () => _currentNodeId = _nodes[index].id,
                    ),
                    onDelete: index == 0 ? null : () => _removeNode(index),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _addNode,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('添加下一个位置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF07C160),
                    side: const BorderSide(color: Color(0xFF07C160)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    '“重新认识”只会把当前位置退回初始位置，整条剧情路线仍然保留。AI 会读取路线，但不会自行改写。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EditableStoryNode {
  _EditableStoryNode({
    required this.id,
    required String title,
    required String content,
  })  : title = TextEditingController(text: title),
        content = TextEditingController(text: content);

  factory _EditableStoryNode.fromNode(StorylineNode node) => _EditableStoryNode(
        id: node.id,
        title: node.title,
        content: node.content,
      );

  factory _EditableStoryNode.empty({
    required String id,
    required String title,
  }) =>
      _EditableStoryNode(id: id, title: title, content: '');

  final String id;
  final TextEditingController title;
  final TextEditingController content;

  void dispose() {
    title.dispose();
    content.dispose();
  }
}

class _TimelineNodeCard extends StatelessWidget {
  const _TimelineNodeCard({
    required this.node,
    required this.index,
    required this.isCurrent,
    required this.isLast,
    required this.onSetCurrent,
    required this.onDelete,
  });

  final _EditableStoryNode node;
  final int index;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback onSetCurrent;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF07C160);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? green : const Color(0xFFBDBDBD),
                      width: 2,
                    ),
                  ),
                  child: isCurrent
                      ? const Icon(Icons.place, color: Colors.white, size: 15)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF777777),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFD8D8D8),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isCurrent ? const Color(0xFF8DDEB2) : Colors.white,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        index == 0 ? '起点' : '位置 ${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8EF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '当前位置',
                            style: TextStyle(fontSize: 11, color: green),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          tooltip: '删除位置',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFF999999),
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: node.title,
                    maxLength: 120,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222222),
                    ),
                    decoration: const InputDecoration(
                      hintText: '填写这个位置的名称',
                      counterText: '',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: node.content,
                    minLines: 3,
                    maxLines: 10,
                    maxLength: 4000,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF333333),
                    ),
                    decoration: const InputDecoration(
                      hintText: '填写这个位置发生的情节、状态或希望发展的方向',
                      hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                  if (!isCurrent)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onSetCurrent,
                        child: const Text(
                          '设为当前位置',
                          style: TextStyle(color: green),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
