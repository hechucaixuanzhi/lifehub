import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class RelationshipDefinition {
  const RelationshipDefinition({
    required this.characterId,
    this.kind = 'initial',
    this.label = '初识',
    this.description = '',
  });

  final String characterId;
  final String kind;
  final String label;
  final String description;

  factory RelationshipDefinition.fromJson(Map<String, dynamic> json) =>
      RelationshipDefinition(
        characterId: json['character_id'] as String? ?? '',
        kind: json['kind'] as String? ?? 'initial',
        label: json['label'] as String? ?? '初识',
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'kind': kind,
        'label': label,
        'description': description,
      };
}

final relationshipProvider = AsyncNotifierProvider.family<RelationshipNotifier,
    RelationshipDefinition, String>(RelationshipNotifier.new);

class RelationshipNotifier
    extends FamilyAsyncNotifier<RelationshipDefinition, String> {
  late String _characterId;

  String get _cacheKey => 'relationship_definition_$_characterId';
  String get _pendingKey => 'relationship_pending_$_characterId';

  @override
  Future<RelationshipDefinition> build(String arg) async {
    _characterId = arg;
    final cached = _decode(
      (await ref.read(dbProvider).getKvRow(_cacheKey))?.value,
    );
    unawaited(_refreshOrRetry());
    return cached ?? RelationshipDefinition(characterId: arg);
  }

  /// 手机先持久化，再同步后端。false 表示等待后续自动补传。
  Future<bool> save(RelationshipDefinition value) async {
    state = AsyncData(value);
    final raw = jsonEncode(value.toJson());
    final database = ref.read(dbProvider);
    await database.upsertKv(_cacheKey, raw);
    await database.upsertKv(_pendingKey, raw);
    return _push(value);
  }

  Future<void> applyReset() async {
    final initial = RelationshipDefinition(characterId: _characterId);
    state = AsyncData(initial);
    final database = ref.read(dbProvider);
    await database.upsertKv(_cacheKey, jsonEncode(initial.toJson()));
    await database.upsertKv(_pendingKey, '');
  }

  Future<bool> _push(RelationshipDefinition value) async {
    try {
      final response = await ref
          .read(apiProvider)
          .patch('/ai/characters/$_characterId/relationship', value.toJson())
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = RelationshipDefinition.fromJson(
        root['relationship'] as Map<String, dynamic>,
      );
      state = AsyncData(remote);
      final database = ref.read(dbProvider);
      await database.upsertKv(_cacheKey, jsonEncode(remote.toJson()));
      await database.upsertKv(_pendingKey, '');
      return true;
    } on Object catch (error) {
      debugPrint('[relationship:$_characterId] sync failed: $error');
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
      final response = await ref
          .read(apiProvider)
          .get('/ai/characters/$_characterId/relationship')
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = RelationshipDefinition.fromJson(
        root['relationship'] as Map<String, dynamic>,
      );
      state = AsyncData(remote);
      await database.upsertKv(_cacheKey, jsonEncode(remote.toJson()));
    } on Object catch (error) {
      debugPrint('[relationship:$_characterId] refresh failed: $error');
    }
  }

  RelationshipDefinition? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return RelationshipDefinition.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
