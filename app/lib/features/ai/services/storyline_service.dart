import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class StorylineNode {
  const StorylineNode({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;

  factory StorylineNode.fromJson(Map<String, dynamic> json) => StorylineNode(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
      };
}

class CharacterStorylineData {
  const CharacterStorylineData({
    required this.characterId,
    this.nodes = const [
      StorylineNode(id: 'start', title: '初始位置', content: ''),
    ],
    this.currentNodeId = 'start',
  });

  final String characterId;
  final List<StorylineNode> nodes;
  final String currentNodeId;

  factory CharacterStorylineData.fromJson(Map<String, dynamic> json) {
    final nodes = <StorylineNode>[];
    final rawNodes = json['nodes'];
    if (rawNodes is List) {
      for (final raw in rawNodes) {
        if (raw is! Map) continue;
        final node = StorylineNode.fromJson(Map<String, dynamic>.from(raw));
        if (node.id.trim().isNotEmpty) nodes.add(node);
      }
    }

    // 兼容升级前的三段式故事档案，并完整保留用户已经填写的内容。
    if (nodes.isEmpty) {
      final premise = (json['premise'] as String? ?? '').trim();
      final progress = (json['progress'] as String? ?? '').trim();
      final direction = (json['direction'] as String? ?? '').trim();
      nodes.add(
        StorylineNode(id: 'start', title: '初始位置', content: premise),
      );
      if (progress.isNotEmpty) {
        nodes.add(
          StorylineNode(
            id: 'legacy_progress',
            title: '已有剧情进展',
            content: progress,
          ),
        );
      }
      if (direction.isNotEmpty) {
        nodes.add(
          StorylineNode(
            id: 'legacy_direction',
            title: '后续剧情方向',
            content: direction,
          ),
        );
      }
    }

    final requestedCurrent = json['current_node_id'] as String? ?? '';
    final current = nodes.any((node) => node.id == requestedCurrent)
        ? requestedCurrent
        : (nodes.length > 1 &&
                nodes.any((node) => node.id == 'legacy_progress'))
            ? 'legacy_progress'
            : nodes.first.id;
    return CharacterStorylineData(
      characterId: json['character_id'] as String? ?? '',
      nodes: List.unmodifiable(nodes),
      currentNodeId: current,
    );
  }

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'current_node_id': currentNodeId,
      };
}

final storylineProvider = AsyncNotifierProvider.family<StorylineNotifier,
    CharacterStorylineData, String>(StorylineNotifier.new);

class StorylineNotifier
    extends FamilyAsyncNotifier<CharacterStorylineData, String> {
  late String _characterId;

  String get _cacheKey => 'character_storyline_$_characterId';
  String get _pendingKey => 'character_storyline_pending_$_characterId';

  @override
  Future<CharacterStorylineData> build(String arg) async {
    _characterId = arg;
    final cached = _decode(
      (await ref.read(dbProvider).getKvRow(_cacheKey))?.value,
    );
    if (cached != null) {
      unawaited(_refreshOrRetry());
      return cached;
    }
    // 首次进入没有本地副本时必须等云端真实值，否则页面会先用空白覆盖云端。
    final remote = await _fetchRemote(updateState: false);
    return remote ?? CharacterStorylineData(characterId: arg);
  }

  /// 手机先持久化，再同步后端。false 表示等待后续自动补传。
  Future<bool> save(CharacterStorylineData value) async {
    state = AsyncData(value);
    final raw = jsonEncode(value.toJson());
    final database = ref.read(dbProvider);
    await database.upsertKv(_cacheKey, raw);
    await database.upsertKv(_pendingKey, raw);
    return _push(value);
  }

  /// “重新认识”保留整条路线，只把当前位置退回第一个节点。
  Future<void> applyReset() async {
    final database = ref.read(dbProvider);
    var current = state.valueOrNull ??
        _decode((await database.getKvRow(_cacheKey))?.value);
    current ??= await _fetchRemote(updateState: false);
    current ??= CharacterStorylineData(characterId: _characterId);
    final reset = CharacterStorylineData(
      characterId: _characterId,
      nodes: current.nodes,
      currentNodeId: current.nodes.first.id,
    );
    state = AsyncData(reset);
    await database.upsertKv(_cacheKey, jsonEncode(reset.toJson()));
    await database.upsertKv(_pendingKey, '');
  }

  Future<bool> _push(CharacterStorylineData value) async {
    try {
      final response = await ref
          .read(apiProvider)
          .patch(
            '/ai/characters/$_characterId/storyline',
            value.toJson(),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = CharacterStorylineData.fromJson(
        root['storyline'] as Map<String, dynamic>,
      );
      state = AsyncData(remote);
      final database = ref.read(dbProvider);
      await database.upsertKv(_cacheKey, jsonEncode(remote.toJson()));
      await database.upsertKv(_pendingKey, '');
      return true;
    } on Object catch (error) {
      debugPrint('[storyline:$_characterId] sync failed: $error');
      return false;
    }
  }

  Future<void> _refreshOrRetry() async {
    try {
      final database = ref.read(dbProvider);
      final pending = _decode((await database.getKvRow(_pendingKey))?.value);
      if (pending != null) {
        await _push(pending);
        return;
      }
      await _fetchRemote();
    } on Object catch (error) {
      debugPrint('[storyline:$_characterId] refresh failed: $error');
    }
  }

  Future<CharacterStorylineData?> _fetchRemote({
    bool updateState = true,
  }) async {
    try {
      final response = await ref
          .read(apiProvider)
          .get('/ai/characters/$_characterId/storyline')
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = CharacterStorylineData.fromJson(
        root['storyline'] as Map<String, dynamic>,
      );
      if (updateState) state = AsyncData(remote);
      await ref
          .read(dbProvider)
          .upsertKv(_cacheKey, jsonEncode(remote.toJson()));
      return remote;
    } on Object catch (error) {
      debugPrint('[storyline:$_characterId] fetch failed: $error');
      return null;
    }
  }

  CharacterStorylineData? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return CharacterStorylineData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
