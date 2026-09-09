import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/theme/app_tokens.dart';
import '../services/character_archive_service.dart';
import 'character_archive_editor_page.dart';

class CharacterArchivePage extends ConsumerWidget {
  const CharacterArchivePage({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(characterArchiveProvider(characterId));
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
        title: const Text(
          '角色档案',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          if (archive.valueOrNull != null)
            TextButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  AppPageRoute(
                    builder: (_) => CharacterArchiveEditorPage(
                      archive: archive.valueOrNull!,
                    ),
                  ),
                );
                if (changed == true) {
                  await ref
                      .read(characterArchiveProvider(characterId).notifier)
                      .refreshArchive();
                }
              },
              child: const Text('编辑'),
            ),
        ],
      ),
      body: archive.when(
        data: (data) => _ArchiveBody(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$characterName的档案暂时无法加载',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref
                    .read(characterArchiveProvider(characterId).notifier)
                    .refreshArchive(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveBody extends ConsumerWidget {
  const _ArchiveBody({required this.data});

  final CharacterArchiveData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = data.persona;
    final relationshipDefinition = _map(data.relationship['definition']);
    final relationshipRuntime = _map(data.relationship['runtime']);
    final knownFields = _map(data.knownUser['fields']);
    final storylineNodes = _list(data.storyline['nodes']);
    final currentNodeId = _text(data.storyline, 'current_node_id');

    return RefreshIndicator(
      onRefresh: () => ref
          .read(characterArchiveProvider(data.characterId).notifier)
          .refreshArchive(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBg,
                  ),
                ),
                if (data.tagline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(data.tagline,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ],
                const SizedBox(height: 8),
                const Text(
                  '展示角色当前生效的语义设定；可从右上角改写，不显示系统指令',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ArchiveSection(
            title: '基础身份',
            subtitle: '现实身份与连续自我',
            children: [
              _TextBlock(
                  label: '原世界身份', text: _text(persona, 'origin_identity')),
            ],
          ),
          _ArchiveSection(
            title: '核心人格',
            subtitle: '稳定性格与行为方式',
            children: [
              _TextBlock(
                label: '核心人格',
                text: _text(persona, 'core_personality'),
              ),
            ],
          ),
          _ArchiveSection(
            title: '说话方式',
            subtitle: '口吻、表达习惯与示例',
            children: [
              _TextBlock(label: '说话口吻', text: _text(persona, 'speech_style')),
              _TextBlock(label: '典型表达', text: _text(persona, 'catchphrases')),
              _TextBlock(
                  label: '示例对话', text: _text(persona, 'example_dialogue')),
            ],
          ),
          _ArchiveSection(
            title: '外貌、兴趣与边界',
            subtitle: '外在身份、偏好与不可违背的原则',
            children: [
              _TextBlock(label: '外貌', text: _text(persona, 'appearance')),
              _TextBlock(label: '兴趣与习惯', text: _text(persona, 'interests')),
              _TextBlock(label: '边界', text: _text(persona, 'boundaries')),
            ],
          ),
          _ArchiveSection(
            title: '现实经历与公开正史',
            subtitle: '${data.publicHistory.length} 个公开时间线节点',
            children: [
              _TextBlock(
                label: '人生主线',
                text: _text(persona, 'origin_history'),
              ),
              if (data.publicHistory.isNotEmpty)
                _Timeline(events: data.publicHistory),
            ],
          ),
          _ArchiveSection(
            title: '世界观',
            subtitle: '${data.worldviews.length} 个已启用世界',
            children: [
              for (final worldview in data.worldviews)
                _WorldviewBlock(worldview: worldview),
            ],
          ),
          _ArchiveSection(
            title: '关系层',
            subtitle: _text(relationshipDefinition, 'label', fallback: '初识'),
            children: [
              _TextBlock(
                label: '关系发展原则',
                text: _text(data.relationship, 'principles'),
              ),
              _TextBlock(
                label: '用户确认的当前关系',
                text: [
                  _text(relationshipDefinition, 'label'),
                  _text(relationshipDefinition, 'description'),
                ].where((item) => item.isNotEmpty).join('\n'),
              ),
              _MapBlock(label: '动态关系状态', value: relationshipRuntime),
            ],
          ),
          _ArchiveSection(
            title: '当前状态与自我模型',
            subtitle: '情绪、当前活动与自我认知',
            children: [
              _TextBlock(
                label: '当前世界',
                text: _text(data.runtime, 'active_worldview_key'),
              ),
              _MapBlock(
                label: '情绪状态',
                value: _map(data.runtime['emotion_state']),
              ),
              _MapBlock(
                label: '当前状态',
                value: _map(data.runtime['current_state']),
              ),
              _MapBlock(
                label: '自我模型',
                value: _map(data.runtime['self_model_state']),
              ),
            ],
          ),
          _ArchiveSection(
            title: '她所知道的你',
            subtitle: _text(data.knownUser, 'display_name', fallback: '用户资料'),
            children: [
              _MapBlock(label: '已知信息', value: knownFields),
            ],
          ),
          _ArchiveSection(
            title: '角色知识',
            subtitle: '${data.lore.length} 条按话题激活的知识',
            children: [
              if (data.lore.isEmpty)
                const _EmptyBlock(text: '暂无独立角色知识条目')
              else
                for (final item in data.lore)
                  _TextBlock(
                    label: _text(item, 'title', fallback: '知识条目'),
                    text: _text(item, 'content'),
                    note: _keywordNote(item),
                  ),
            ],
          ),
          _ArchiveSection(
            title: '长期记忆',
            subtitle: '${data.memories.length} 条当前有效记忆',
            children: [
              if (data.memories.isEmpty)
                const _EmptyBlock(text: '暂无长期记忆')
              else
                for (final item in data.memories)
                  _TextBlock(
                    label: _text(item, 'type', fallback: '记忆'),
                    text: _text(item, 'content'),
                  ),
            ],
          ),
          _ArchiveSection(
            title: '线性剧情',
            subtitle: '${storylineNodes.length} 个位置',
            children: [
              if (storylineNodes.isEmpty)
                const _EmptyBlock(text: '暂无线性剧情')
              else
                for (var index = 0; index < storylineNodes.length; index++)
                  _TextBlock(
                    label:
                        '${index + 1}. ${_text(storylineNodes[index], 'title', fallback: '位置')}'
                        '${_text(storylineNodes[index], 'id') == currentNodeId ? '（当前位置）' : ''}',
                    text: _text(storylineNodes[index], 'content'),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((child) {
      if (child is _TextBlock) return child.text.trim().isNotEmpty;
      return true;
    }).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, color: AppColors.onBg),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        children: visible.isEmpty
            ? const [
                _EmptyBlock(text: '暂无内容'),
              ]
            : visible,
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.text, this.note = ''});

  final String label;
  final String text;
  final String note;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(note,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
            const SizedBox(height: 6),
            SelectableText(
              text.trim(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: AppColors.onBg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({required this.label, required this.value});

  final String label;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    return _TextBlock(
      label: label,
      text: value.isEmpty ? '暂无' : _prettyMap(value),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ),
      );
}

class _WorldviewBlock extends StatelessWidget {
  const _WorldviewBlock({required this.worldview});

  final Map<String, dynamic> worldview;

  @override
  Widget build(BuildContext context) {
    final active = worldview['active'] == true;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ExpansionTile(
        dense: true,
        title: Text(
          '${_text(worldview, 'name', fallback: '世界观')}${active ? '（当前）' : ''}',
          style: const TextStyle(fontSize: 14, color: AppColors.onBg),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _TextBlock(label: '角色身份', text: _text(worldview, 'identity')),
          _TextBlock(label: '背景经历', text: _text(worldview, 'backstory')),
          _TextBlock(label: '世界规则', text: _text(worldview, 'rules')),
          _TextBlock(label: '偏好习惯', text: _text(worldview, 'preferences')),
          _TextBlock(label: '用户身份', text: _text(worldview, 'user_identity')),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '公开活动时间线',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          for (final event in events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 72,
                child: Text(
                  _text(event, 'event_date'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              title: Text(
                _text(event, 'title', fallback: '公开活动'),
                style: const TextStyle(fontSize: 14, color: AppColors.onBg),
              ),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.muted),
              onTap: () => _showPublicEvent(context, event),
            ),
        ],
      ),
    );
  }
}

void _showPublicEvent(BuildContext context, Map<String, dynamic> event) {
  final sources = event['source_urls'] is List
      ? List<Object?>.from(event['source_urls'] as List)
      : const <Object?>[];
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_text(event, 'title', fallback: '公开活动')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                _text(event, 'event_date'),
                _text(event, 'end_date'),
              ].where((item) => item.isNotEmpty).join(' — '),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SelectableText(
              [
                _text(event, 'summary'),
                _text(event, 'detail'),
              ].where((item) => item.isNotEmpty).join('\n\n'),
              style: const TextStyle(fontSize: 15, height: 1.55),
            ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '来源 · ${_text(event, 'source_level', fallback: '已记录')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              for (final source in sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SelectableText(
                    source?.toString() ?? '',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _text(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _prettyMap(Map<String, dynamic> value) {
  final labels = <String, String>{
    'stage': '关系阶段',
    'summary': '摘要',
    'trust': '信任',
    'primary': '主要情绪',
    'activity': '当前活动',
    'goal': '当前目标',
    'current_self_view': '当前自我认知',
    'preferred_name': '姓名或角色名',
    'character_call_name': '她对你的称呼',
    'gender': '性别或称谓',
    'birthday': '生日',
    'location': '所在城市',
    'occupation': '职业',
    'appearance': '外貌与身体特征',
    'personality': '性格',
    'family_background': '家庭与成长背景',
    'current_situation': '当前生活状态',
    'meeting_story': '如何认识',
    'important_experiences': '重要经历',
    'notes': '补充信息',
  };
  return value.entries.map((entry) {
    final label = labels[entry.key] ?? entry.key;
    final raw = entry.value;
    final rendered = raw is Map || raw is List
        ? const JsonEncoder.withIndent('  ').convert(raw)
        : raw?.toString() ?? '';
    return '$label：$rendered';
  }).join('\n');
}

String _keywordNote(Map<String, dynamic> item) {
  final raw = item['trigger_keywords'];
  if (raw is! List || raw.isEmpty) return item['always_on'] == true ? '常驻' : '';
  final keywords =
      raw.map((value) => value.toString()).where((value) => value.isNotEmpty);
  return '相关话题：${keywords.join('、')}';
}
