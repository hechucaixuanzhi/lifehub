import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import 'models/character.dart';
import 'models/group_chat.dart';
import 'models/sticker.dart';
import 'models/worldbook.dart';

/// 带重试的 GET 辅助：慢隧道下首连（冷连接）可能超时，先试 [firstTimeout]，
/// 失败用 [retryTimeout] 重试一次——避免冷启动误回退本地兜底导致媒体 ID 丢失。
Future<T?> _fetchWithRetry<T>(
  ApiClient api,
  String path,
  T? Function(int status, dynamic body) onOk, {
  Duration firstTimeout = const Duration(seconds: 15),
  Duration retryTimeout = const Duration(seconds: 25),
}) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final resp = await api
          .get(path)
          .timeout(attempt == 0 ? firstTimeout : retryTimeout);
      if (resp.statusCode == 200) {
        return onOk(resp.statusCode, resp.body);
      }
    } on Object catch (e) {
      debugPrint('[api:$path] attempt ${attempt + 1} failed: $e');
    }
  }
  return null;
}

/// 角色列表（人格层）：本地缓存优先（优化1：冷启动秒开，免走慢隧道）。
/// - 有磁盘缓存 → 立刻返回（首屏不阻塞），仅当缓存过期才后台拉新替换 state。
/// - 无缓存 / 解析失败 → 等网络；网络失败兜底本地两角色（离线可进聊天）。
/// - 换头像/背景后 [CharactersNotifier.applyLocal] 写穿缓存立即生效，不依赖随后的
///   网络刷新成功。
/// 数据驱动会话列表 / 通讯录 / 聊天页 / 记忆页（全部只读 .valueOrNull，兼容 AsyncValue）。
final charactersProvider =
    AsyncNotifierProvider<CharactersNotifier, List<Character>>(
  CharactersNotifier.new,
);

class CharactersNotifier extends AsyncNotifier<List<Character>> {
// 版本升级可让旧安装丢弃过期的角色列表缓存。
  static const _cacheKey = 'characters_v2';

  @override
  Future<List<Character>> build() async {
    final db = ref.read(dbProvider);
    // 1) 磁盘缓存秒出（有缓存就先用，不阻塞渲染）。
    KvCacheRow? cached;
    try {
      cached = await db.getKvRow(_cacheKey);
    } on Object catch (e) {
      debugPrint('[characters] cache read failed: $e');
    }
    if (cached != null && cached.value.isNotEmpty) {
      final chars = _parse(cached.value);
      if (chars != null) {
        // 角色列表很小：每次启动都后台刷新，新增人物无需等 6 小时缓存过期。
        // 磁盘缓存仍负责首屏秒开，不阻塞 UI。
        unawaited(_refresh());
        debugPrint('[characters] served from local cache');
        return chars;
      }
    }
    // 3) 无缓存 / 解析失败 → 等网络（首次安装必走，之后冷启动秒开）。
    final chars = await _fetch();
    if (chars != null) return chars;
    debugPrint('[characters] fallback to local defaults (backend unreachable)');
    return defaultCharacters;
  }

  /// 本地即时更新：PATCH 成功后写穿缓存并立即生效（头像/背景改动不依赖网络再拉）。
  void applyLocal(Character updated) {
    final current = state.valueOrNull;
    final next = current == null
        ? <Character>[updated]
        : current.any((character) => character.id == updated.id)
            ? <Character>[
                for (final character in current)
                  if (character.id == updated.id) updated else character,
              ]
            : <Character>[...current, updated];
    next.sort(_compareCharacters);
    state = AsyncData(next);
    try {
      final db = ref.read(dbProvider);
      unawaited(db.upsertKv(
        _cacheKey,
        jsonEncode([for (final c in next) c.toJson()]),
      ));
    } on Object {
      // 写缓存失败静默：state 已生效，下次刷新再落盘。
    }
  }

  /// 角色删除成功后立即从内存列表与磁盘缓存移除，防止离线回退时短暂复活。
  void removeLocal(String characterId) {
    final current = state.valueOrNull ?? const <Character>[];
    if (!current.any((character) => character.id == characterId)) return;
    final next = [
      for (final character in current)
        if (character.id != characterId) character,
    ];
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(
            _cacheKey,
            jsonEncode([for (final c in next) c.toJson()]),
          ));
    } on Object {
      // state 已更新；后续网络刷新会继续以服务端为准。
    }
  }

  /// 显式网络刷新：写缓存 + 替换 state（保留接口，供将来下拉刷新等使用）。
  Future<void> reload() async {
    final chars = await _fetch();
    if (chars != null) _setState(chars);
  }

  /// 后台刷新：缓存过期时由 build 触发，不 await（不阻塞渲染）。
  Future<void> _refresh() async {
    final chars = await _fetch();
    if (chars != null) _setState(chars);
  }

  /// 替换 state；provider 非 autoDispose 存活整个 app 生命周期，这里仅防御
  /// 极端 dispose 竞态（设置已销毁的 state 会抛错，忽略即可）。
  void _setState(List<Character> chars) {
    try {
      state = AsyncData(chars);
    } on Object {
      // ignore: 容器已销毁，结果丢弃
    }
  }

  Future<List<Character>?> _fetch() async {
    final chars = await _fetchWithRetry<List<Character>>(
      ref.read(apiProvider),
      '/ai/characters',
      (status, body) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final list = (json['characters'] as List? ?? []);
        final parsed = [
          for (final c in list) Character.fromJson(c as Map<String, dynamic>),
        ]..sort(_compareCharacters);
        return parsed.isNotEmpty ? parsed : null;
      },
    );
    if (chars != null) {
      try {
        await ref.read(dbProvider).upsertKv(
            _cacheKey, jsonEncode([for (final c in chars) c.toJson()]));
      } on Object catch (e) {
        debugPrint('[characters] cache write failed: $e');
      }
      debugPrint('[characters] fetched ${chars.length} from backend');
    }
    return chars;
  }

  /// 缓存 JSON → 角色列表；空/缺 id/解析失败 → null（触发网络回源）。
  List<Character>? _parse(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      final chars = [
        for (final c in list) Character.fromJson(c as Map<String, dynamic>),
      ]..sort(_compareCharacters);
      if (chars.isEmpty || chars.any((c) => c.id.isEmpty)) return null;
      return chars;
    } on Object {
      return null;
    }
  }
}

/// 角色按后端 sort，再按 id 稳定排序。
int _compareCharacters(Character a, Character b) {
  if (a.id == 'companion' && b.id != 'companion') return -1;
  if (b.id == 'companion' && a.id != 'companion') return 1;
  final bySort = a.sort.compareTo(b.sort);
  return bySort != 0 ? bySort : a.id.compareTo(b.id);
}

/// 内置表情包目录（009）：从后端拉取，失败/空兜底本地 defaultStickers（离线可渲染）。
/// 表情面板「表情包」tab 数据源；id → 本地素材 assets/stickers/<id>.png。
final stickersProvider = FutureProvider<List<Sticker>>((ref) async {
  final stickers = await _fetchWithRetry<List<Sticker>>(
    ref.read(apiProvider),
    '/ai/stickers',
    (status, body) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = (json['stickers'] as List? ?? []);
      final parsed = [
        for (final s in list) Sticker.fromJson(s as Map<String, dynamic>),
      ]..sort((a, b) => a.sort.compareTo(b.sort));
      return parsed.isNotEmpty ? parsed : null;
    },
  );
  return stickers ?? defaultStickers;
});

/// 会话预览（GET /ai/conversations）：单聊 character_id / 群聊 group_id → 最后一条消息。
/// v2：type=single|group；单聊键=characterId（兼容旧缓存字段），群聊键='g:<groupId>'。
class ConversationPreview {
  const ConversationPreview({
    this.type = 'single',
    required this.characterId,
    this.groupId = '',
    this.groupName,
    this.senderName,
    required this.lastContent,
    required this.lastKind,
    this.lastAt,
  });

  final String type; // single | group
  final String characterId;
  final String groupId;
  final String? groupName;
  final String? senderName; // 群：最近发言成员名（主页预览前缀）
  final String lastContent;
  final String lastKind; // text | image | file | sticker | audio
  final DateTime? lastAt;

  /// 会话 map 键：单聊=characterId，群聊='g:<groupId>'（与 c: 前缀的群键区分）。
  String get convKey => type == 'group' ? 'g:$groupId' : characterId;

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'single';
    return ConversationPreview(
      type: type,
      characterId: json['character_id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String?,
      senderName: json['last_sender_name'] as String?,
      lastContent: json['last_content'] as String? ?? '',
      lastKind: json['last_kind'] as String? ?? 'text',
      lastAt: DateTime.tryParse(json['last_at'] as String? ?? ''),
    );
  }
}

/// 会话列表真实预览（微信首页）：每角色最后消息 + 相对时间。
/// 缓存优先（优化1：冷启动 + 从聊天返回都秒出，不再走慢隧道阻塞）：
/// - 有磁盘缓存 → 立即返回，仅缓存过期(30min)才后台拉新替换 state。
/// - 聊天发送成功后 [ConversationsNotifier.applyLocal] 写穿本地 → 返回首页立即最新。
/// - 聊天页返回首页改调 reload()（后台刷新，非阻塞），替代旧 invalidate 卡顿。
final conversationsProvider = AsyncNotifierProvider<ConversationsNotifier,
    Map<String, ConversationPreview>>(ConversationsNotifier.new);

class ConversationsNotifier
    extends AsyncNotifier<Map<String, ConversationPreview>> {
  // v2：加入群聊预览（type/group_id 字段 + 群键）。升级使旧单聊缓存立即失效。
  static const _cacheKey = 'conversations_v2';
  static const _cacheTtl = Duration(minutes: 30);

  @override
  Future<Map<String, ConversationPreview>> build() async {
    final db = ref.read(dbProvider);
    KvCacheRow? cached;
    try {
      cached = await db.getKvRow(_cacheKey);
    } on Object catch (e) {
      debugPrint('[conversations] cache read failed: $e');
    }
    if (cached != null && cached.value.isNotEmpty) {
      final map = _parse(cached.value);
      if (map != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cached.updatedAt;
        if (age > _cacheTtl.inMilliseconds) unawaited(_refresh());
        debugPrint('[conversations] served from local cache');
        return map;
      }
    }
    final fetched = await _fetch();
    if (fetched != null) return fetched;
    return const {};
  }

  /// 发送成功后写穿本地预览：返回首页立即显示最新消息，不依赖随后的网络刷新。
  void applyLocal(String characterId, ConversationPreview preview) {
    final current = state.valueOrNull ?? const <String, ConversationPreview>{};
    final next = {...current, characterId: preview};
    state = AsyncData(next);
    try {
      final db = ref.read(dbProvider);
      unawaited(db.upsertKv(_cacheKey, _encode(next)));
    } on Object {
      // 写缓存失败静默：state 已生效，下次刷新再落盘。
    }
  }

  /// 清空/重新认识后立即移除该角色的会话预览，并同步落盘。
  void removeLocal(String characterId) {
    final current = state.valueOrNull ?? const <String, ConversationPreview>{};
    if (!current.containsKey(characterId)) return;
    final next = {...current}..remove(characterId);
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(_cacheKey, _encode(next)));
    } on Object {
      // state 已更新；下次联网刷新仍可修正。
    }
  }

  /// 群聊发消息后写穿本地预览（微信首页立即更新，不等网络刷新）。
  void applyGroupLocal(String groupId, ConversationPreview preview) {
    final current = state.valueOrNull ?? const <String, ConversationPreview>{};
    final next = {...current, 'g:$groupId': preview};
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(_cacheKey, _encode(next)));
    } on Object {
      // 写缓存失败静默：state 已生效，下次刷新再落盘。
    }
  }

  /// 群被删除/清空后立即移除该群的会话预览，并同步落盘。
  void removeGroupLocal(String groupId) {
    final current = state.valueOrNull ?? const <String, ConversationPreview>{};
    final key = 'g:$groupId';
    if (!current.containsKey(key)) return;
    final next = {...current}..remove(key);
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(_cacheKey, _encode(next)));
    } on Object {
      // state 已更新；下次联网刷新仍可修正。
    }
  }

  /// 显式网络刷新（聊天页返回首页时后台调用，非阻塞）。
  Future<void> reload() async {
    final fetched = await _fetch();
    if (fetched != null) _setState(fetched);
  }

  /// 后台刷新：缓存过期时由 build 触发，不 await（不阻塞渲染）。
  Future<void> _refresh() async {
    final fetched = await _fetch();
    if (fetched != null) _setState(fetched);
  }

  Future<Map<String, ConversationPreview>?> _fetch() async {
    final map = await _fetchWithRetry<Map<String, ConversationPreview>>(
      ref.read(apiProvider),
      '/ai/conversations',
      (status, body) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final items = (json['items'] as List? ?? []);
        final parsed = <String, ConversationPreview>{};
        for (final it in items) {
          final c = ConversationPreview.fromJson(it as Map<String, dynamic>);
          if (c.convKey.isNotEmpty) parsed[c.convKey] = c;
        }
        return parsed.isNotEmpty ? parsed : null;
      },
    );
    if (map != null) {
      try {
        await ref.read(dbProvider).upsertKv(_cacheKey, _encode(map));
      } on Object catch (e) {
        debugPrint('[conversations] cache write failed: $e');
      }
      debugPrint('[conversations] fetched ${map.length} from backend');
    }
    return map;
  }

  /// 缓存 JSON → 预览 map；解析失败 → null（触发网络回源）。
  Map<String, ConversationPreview>? _parse(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      final map = <String, ConversationPreview>{};
      for (final it in list) {
        final c = ConversationPreview.fromJson(it as Map<String, dynamic>);
        if (c.convKey.isNotEmpty) map[c.convKey] = c;
      }
      return map;
    } on Object {
      return null;
    }
  }

  String _encode(Map<String, ConversationPreview> map) => jsonEncode([
        for (final e in map.entries)
          {
            'type': e.value.type,
            'character_id': e.value.characterId,
            'group_id': e.value.groupId,
            'group_name': e.value.groupName,
            'last_sender_name': e.value.senderName,
            'last_content': e.value.lastContent,
            'last_kind': e.value.lastKind,
            'last_at': e.value.lastAt?.toIso8601String(),
          },
      ]);

  /// 替换 state；provider 非 autoDispose，仅防御极端 dispose 竞态。
  void _setState(Map<String, ConversationPreview> map) {
    try {
      state = AsyncData(map);
    } on Object {
      // ignore: 容器已销毁，结果丢弃
    }
  }
}

/// 世界书库（通讯录「标签」）：cache-first，仿 CharactersNotifier。
/// 群聊可选引用（GroupChat.worldbookId）；不选 = 现实世界。
final worldbooksProvider =
    AsyncNotifierProvider<WorldbooksNotifier, List<Worldbook>>(
  WorldbooksNotifier.new,
);

class WorldbooksNotifier extends AsyncNotifier<List<Worldbook>> {
  static const _cacheKey = 'worldbooks_v1';

  @override
  Future<List<Worldbook>> build() async {
    final db = ref.read(dbProvider);
    KvCacheRow? cached;
    try {
      cached = await db.getKvRow(_cacheKey);
    } on Object catch (e) {
      debugPrint('[worldbooks] cache read failed: $e');
    }
    if (cached != null && cached.value.isNotEmpty) {
      final books = _parse(cached.value);
      if (books != null) {
        unawaited(_refresh());
        debugPrint('[worldbooks] served from local cache');
        return books;
      }
    }
    final books = await _fetch();
    if (books != null) return books;
    debugPrint('[worldbooks] fallback to empty (backend unreachable)');
    return const [];
  }

  /// 新建/编辑后写穿缓存立即生效（世界书页不依赖随后的网络刷新）。
  void applyLocal(Worldbook updated) {
    final current = state.valueOrNull ?? const <Worldbook>[];
    final next = current.any((w) => w.id == updated.id)
        ? <Worldbook>[
            for (final w in current)
              if (w.id == updated.id) updated else w,
          ]
        : <Worldbook>[...current, updated];
    next.sort((a, b) {
      final bySort = a.sort.compareTo(b.sort);
      return bySort != 0 ? bySort : a.name.compareTo(b.name);
    });
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(
            _cacheKey,
            jsonEncode([for (final w in next) w.toJson()]),
          ));
    } on Object {
      // 写缓存失败静默：state 已生效，下次刷新再落盘。
    }
  }

  /// 删除后立即从内存列表与磁盘缓存移除，防止离线回退时短暂复活。
  void removeLocal(String id) {
    final current = state.valueOrNull ?? const <Worldbook>[];
    if (!current.any((w) => w.id == id)) return;
    final next = [for (final w in current) if (w.id != id) w];
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(
            _cacheKey,
            jsonEncode([for (final w in next) w.toJson()]),
          ));
    } on Object {
      // state 已更新；后续网络刷新会继续以服务端为准。
    }
  }

  Future<void> reload() async {
    final books = await _fetch();
    if (books != null) _setState(books);
  }

  Future<void> _refresh() async {
    final books = await _fetch();
    if (books != null) _setState(books);
  }

  void _setState(List<Worldbook> books) {
    try {
      state = AsyncData(books);
    } on Object {
      // ignore: 容器已销毁，结果丢弃
    }
  }

  Future<List<Worldbook>?> _fetch() async {
    final books = await _fetchWithRetry<List<Worldbook>>(
      ref.read(apiProvider),
      '/worldbooks',
      (status, body) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final list = (json['worldbooks'] as List? ?? []);
        final parsed = [
          for (final w in list) Worldbook.fromJson(w as Map<String, dynamic>),
        ]..sort((a, b) {
            final bySort = a.sort.compareTo(b.sort);
            return bySort != 0 ? bySort : a.name.compareTo(b.name);
          });
        return parsed.isNotEmpty ? parsed : null;
      },
    );
    if (books != null) {
      try {
        await ref.read(dbProvider).upsertKv(
            _cacheKey, jsonEncode([for (final w in books) w.toJson()]));
      } on Object catch (e) {
        debugPrint('[worldbooks] cache write failed: $e');
      }
      debugPrint('[worldbooks] fetched ${books.length} from backend');
    }
    return books;
  }

  /// 缓存 JSON → 世界书列表；空/缺 id/解析失败 → null（触发网络回源）。
  List<Worldbook>? _parse(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      final books = [for (final w in list) Worldbook.fromJson(w as Map<String, dynamic>)];
      if (books.isEmpty || books.any((w) => w.id.isEmpty)) return null;
      return books;
    } on Object {
      return null;
    }
  }
}

/// 群列表（通讯录「群聊」入口 + 建群后回填）：cache-first，仿 CharactersNotifier。
/// 列表项只带 member_ids/member_count；完整 members/worldbook 走 [fetchGroupDetail]。
final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<GroupChat>>(GroupsNotifier.new);

class GroupsNotifier extends AsyncNotifier<List<GroupChat>> {
  static const _cacheKey = 'groups_v1';

  @override
  Future<List<GroupChat>> build() async {
    final db = ref.read(dbProvider);
    KvCacheRow? cached;
    try {
      cached = await db.getKvRow(_cacheKey);
    } on Object catch (e) {
      debugPrint('[groups] cache read failed: $e');
    }
    if (cached != null && cached.value.isNotEmpty) {
      final groups = _parse(cached.value);
      if (groups != null) {
        unawaited(_refresh());
        debugPrint('[groups] served from local cache');
        return groups;
      }
    }
    final groups = await _fetch();
    if (groups != null) return groups;
    debugPrint('[groups] fallback to empty (backend unreachable)');
    return const [];
  }

  /// 建群/设置 PATCH 后写穿缓存立即生效（列表/设置面板不等网络刷新）。
  /// [updated] 可为详情（含 members）或列表项；替换时保留已有对象的完整字段。
  void applyLocal(GroupChat updated) {
    final current = state.valueOrNull ?? const <GroupChat>[];
    final idx = current.indexWhere((g) => g.id == updated.id);
    final List<GroupChat> next;
    if (idx >= 0) {
      next = [...current];
      final existing = current[idx];
      next[idx] = GroupChat(
        id: existing.id,
        name: updated.name,
        members: updated.members.isNotEmpty ? updated.members : existing.members,
        memberIds: updated.memberIds.isNotEmpty ? updated.memberIds : existing.memberIds,
        memberCount: updated.memberCount > 0 ? updated.memberCount : existing.memberCount,
        worldbookId: updated.worldbookId,
        worldbook: updated.worldbook ?? existing.worldbook,
        speakerMode: updated.speakerMode,
        replyMode: updated.replyMode,
      );
    } else {
      next = [updated, ...current];
    }
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(
            _cacheKey,
            jsonEncode([for (final g in next) g.toJson()]),
          ));
    } on Object {
      // 写缓存失败静默：state 已生效，下次刷新再落盘。
    }
  }

  /// 群被删除/清空后立即从内存列表与磁盘缓存移除。
  void removeLocal(String groupId) {
    final current = state.valueOrNull ?? const <GroupChat>[];
    if (!current.any((g) => g.id == groupId)) return;
    final next = [for (final g in current) if (g.id != groupId) g];
    state = AsyncData(next);
    try {
      unawaited(ref.read(dbProvider).upsertKv(
            _cacheKey,
            jsonEncode([for (final g in next) g.toJson()]),
          ));
    } on Object {
      // state 已更新；后续网络刷新会继续以服务端为准。
    }
  }

  Future<void> reload() async {
    final groups = await _fetch();
    if (groups != null) _setState(groups);
  }

  Future<void> _refresh() async {
    final groups = await _fetch();
    if (groups != null) _setState(groups);
  }

  void _setState(List<GroupChat> groups) {
    try {
      state = AsyncData(groups);
    } on Object {
      // ignore: 容器已销毁，结果丢弃
    }
  }

  Future<List<GroupChat>?> _fetch() async {
    final groups = await _fetchWithRetry<List<GroupChat>>(
      ref.read(apiProvider),
      '/ai/groups',
      (status, body) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final list = (json['groups'] as List? ?? []);
        final parsed = [
          for (final g in list) GroupChat.fromJson(g as Map<String, dynamic>),
        ];
        return parsed.isNotEmpty ? parsed : null;
      },
    );
    if (groups != null) {
      try {
        await ref.read(dbProvider).upsertKv(
            _cacheKey, jsonEncode([for (final g in groups) g.toJson()]));
      } on Object catch (e) {
        debugPrint('[groups] cache write failed: $e');
      }
      debugPrint('[groups] fetched ${groups.length} from backend');
    }
    return groups;
  }

  /// 缓存 JSON → 群列表；空/缺 id/解析失败 → null（触发网络回源）。
  List<GroupChat>? _parse(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      final groups = [for (final g in list) GroupChat.fromJson(g as Map<String, dynamic>)];
      if (groups.isEmpty || groups.any((g) => g.id.isEmpty)) return null;
      return groups;
    } on Object {
      return null;
    }
  }
}

/// 群详情（GET /ai/groups/{id}）：完整 members + worldbook。群聊页/设置面板打开时拉取；
/// 拿到后调 [GroupsNotifier.applyLocal] 把详情回填进群列表缓存。
Future<GroupChat?> fetchGroupDetail(ApiClient api, String groupId) {
  return _fetchWithRetry<GroupChat>(
    api,
    '/ai/groups/$groupId',
    (status, body) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final g = json['group'] as Map<String, dynamic>?;
      if (g == null) return null;
      final group = GroupChat.fromJson(g);
      return group.id.isNotEmpty ? group : null;
    },
  );
}
