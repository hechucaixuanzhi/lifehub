import 'dart:convert';

import '../database/app_database.dart';
import '../network/api_client.dart';

class SyncResult {
  const SyncResult({required this.accepted, required this.offline});
  final int accepted;
  final bool offline;
}

/// 同步管理器：把本地未同步事件批量推送到后端 /sync/push。
/// 离线 / 超时不抛异常——本地数据完全不受影响（本地优先）。
class SyncManager {
  SyncManager(this.db, this.api);

  final AppDatabase db;
  final ApiClient api;

  Future<SyncResult> push() async {
    final events = await db.getUnsynced();
    if (events.isEmpty) return const SyncResult(accepted: 0, offline: false);

    final payload = events
        .map((e) => {
              'id': e.id, // 本地事件 id（服务端幂等去重键）
              'entity_type': e.entityType,
              'entity_id': e.entityId,
              'operation': e.operation,
              'payload': jsonDecode(e.payload),
            })
        .toList();

    try {
      final resp = await api
          .post('/sync/push', {'events': payload})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final accepted = data['accepted'] as int? ?? events.length;
        await db.markSynced(events.map((e) => e.id).toList());
        return SyncResult(accepted: accepted, offline: false);
      }
      return const SyncResult(accepted: 0, offline: false);
    } on Object {
      // SocketException / TimeoutException / 服务器不可达 → 离线
      return const SyncResult(accepted: 0, offline: true);
    }
  }

  /// 从服务端拉取全部同步事件并重放（重装恢复 / 多设备合并）。
  /// 后端只存事件日志，无当前态表 → 恢复 = 客户端逐一 applyRemoteEvent 重放。
  /// 分页拉取 /sync/pull?cursor=&limit=200，按 uuid7 游标增量；离线 / 超时安全返回。
  Future<SyncResult> pull() async {
    var cursor = '';
    var applied = 0;
    try {
      while (true) {
        final resp = await api
            .get('/sync/pull?cursor=${Uri.encodeComponent(cursor)}&limit=200')
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) break;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final events = (data['events'] as List?) ?? [];
        if (events.isEmpty) break;
        for (final ev in events) {
          final raw = ev['payload'];
          final payload = raw is String ? jsonDecode(raw) : raw;
          await db.applyRemoteEvent(
            ev['entity_type'] as String,
            ev['operation'] as String,
            payload as Map<String, dynamic>,
          );
          applied++;
        }
        final next = data['next_cursor'] as String?;
        if (next == null || next == cursor) break;
        cursor = next;
      }
      return SyncResult(accepted: applied, offline: false);
    } on Object {
      // SocketException / TimeoutException / 服务器不可达 → 离线
      return SyncResult(accepted: applied, offline: true);
    }
  }
}
