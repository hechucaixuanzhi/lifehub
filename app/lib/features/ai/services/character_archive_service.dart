import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// 手机端角色档案。服务端保存权威副本，本地 KV 保存最近一次完整快照。
class CharacterArchiveData {
  const CharacterArchiveData({
    required this.characterId,
    required this.name,
    required this.tagline,
    required this.welcomeMessage,
    required this.persona,
    required this.worldviews,
    required this.relationship,
    required this.runtime,
    required this.knownUser,
    required this.lore,
    required this.publicHistory,
    required this.memories,
    required this.storyline,
  });

  final String characterId;
  final String name;
  final String tagline;
  final String welcomeMessage;
  final Map<String, dynamic> persona;
  final List<Map<String, dynamic>> worldviews;
  final Map<String, dynamic> relationship;
  final Map<String, dynamic> runtime;
  final Map<String, dynamic> knownUser;
  final List<Map<String, dynamic>> lore;
  final List<Map<String, dynamic>> publicHistory;
  final List<Map<String, dynamic>> memories;
  final Map<String, dynamic> storyline;

  factory CharacterArchiveData.fromJson(Map<String, dynamic> json) {
    return CharacterArchiveData(
      characterId: json['character_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      welcomeMessage: json['welcome_message'] as String? ?? '',
      persona: _asMap(json['persona']),
      worldviews: _asMapList(json['worldviews']),
      relationship: _asMap(json['relationship']),
      runtime: _asMap(json['runtime']),
      knownUser: _asMap(json['known_user']),
      lore: _asMapList(json['lore']),
      publicHistory: _asMapList(json['public_history']),
      memories: _asMapList(json['memories']),
      storyline: _asMap(json['storyline']),
    );
  }

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'name': name,
        'tagline': tagline,
        'welcome_message': welcomeMessage,
        'persona': persona,
        'worldviews': worldviews,
        'relationship': relationship,
        'runtime': runtime,
        'known_user': knownUser,
        'lore': lore,
        'public_history': publicHistory,
        'memories': memories,
        'storyline': storyline,
      };
}

final characterArchiveProvider = AsyncNotifierProvider.family<
    CharacterArchiveNotifier,
    CharacterArchiveData,
    String>(CharacterArchiveNotifier.new);

class CharacterArchiveNotifier
    extends FamilyAsyncNotifier<CharacterArchiveData, String> {
  late String _characterId;

  String get _cacheKey => 'character_archive_v1_$_characterId';

  @override
  Future<CharacterArchiveData> build(String arg) async {
    _characterId = arg;
    final database = ref.read(dbProvider);
    final cached = _decode((await database.getKvRow(_cacheKey))?.value);
    if (cached != null) {
      unawaited(_fetchRemote());
      return cached;
    }
    final remote = await _fetchRemote(updateState: false);
    if (remote != null) return remote;
    throw StateError('角色档案暂时无法加载');
  }

  Future<void> refreshArchive() async {
    final remote = await _fetchRemote();
    if (remote == null && state.valueOrNull == null) {
      state = AsyncError(StateError('角色档案暂时无法加载'), StackTrace.current);
    }
  }

  Future<CharacterArchiveData> saveDefinition(
    Map<String, dynamic> definition,
  ) async {
    final response = await ref
        .read(apiProvider)
        .patch('/ai/characters/$_characterId/archive', definition)
        .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) {
      throw StateError('保存角色档案失败（${response.statusCode}）');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final archive = CharacterArchiveData.fromJson(
      Map<String, dynamic>.from(root['archive'] as Map),
    );
    state = AsyncData(archive);
    await ref
        .read(dbProvider)
        .upsertKv(_cacheKey, jsonEncode(archive.toJson()));
    return archive;
  }

  Future<CharacterArchiveData?> _fetchRemote({bool updateState = true}) async {
    try {
      final response = await ref
          .read(apiProvider)
          .get('/ai/characters/$_characterId/archive')
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final archive = CharacterArchiveData.fromJson(
        Map<String, dynamic>.from(root['archive'] as Map),
      );
      if (updateState) state = AsyncData(archive);
      await ref
          .read(dbProvider)
          .upsertKv(_cacheKey, jsonEncode(archive.toJson()));
      return archive;
    } on Object catch (error) {
      debugPrint('[character-archive:$_characterId] fetch failed: $error');
      return null;
    }
  }

  CharacterArchiveData? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return CharacterArchiveData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
