import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// 本地主库（Drift / SQLite）。离线优先：所有读写都在本地，同步是 best-effort。
/// 生产环境数据库演进走 Alembic（服务端）；本端 Drift schemaVersion 仅管本地迁移。
@DriftDatabase(
  tables: [
    LifeHabits,
    LifeHabitEvents,
    ActiveSessions,
    InboxItems,
    SyncEventsLocal,
    Moments,
    StudyResources,
    StudySessions,
    ExerciseTypes,
    ExerciseSessions,
    Pets,
    PetLogs,
    ChatMessages,
    MediaCache,
    KvCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'lifehub'));

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // behavior 列（HabitMode 行为） + 计时会话表 + 朋友圈预留表
            await m.addColumn(lifeHabits, lifeHabits.behavior);
            await m.createTable(activeSessions);
            await m.createTable(moments);
          }
          if (from < 3) {
            // v0.2：学习 / 运动 / 宠物 6 张表
            await m.createTable(studyResources);
            await m.createTable(studySessions);
            await m.createTable(exerciseTypes);
            await m.createTable(exerciseSessions);
            await m.createTable(pets);
            await m.createTable(petLogs);
          }
          if (from < 4) {
            // v0.4：运动记录加健身组数/重量列（可空，安全迁移）
            await m.addColumn(exerciseSessions, exerciseSessions.sets);
            await m.addColumn(exerciseSessions, exerciseSessions.weightKg);
          }
          if (from < 5) {
            // v0.5：AI 聊天历史本地缓存表（需求2，秒开）
            await m.createTable(chatMessages);
          }
          if (from < 6) {
            // v0.7-优化1：媒体字节 + 字符列表 KV 磁盘缓存（冷启动秒开）
            await m.createTable(mediaCache);
            await m.createTable(kvCache);
          }
          if (from < 7) {
            // v0.8-AI语音：聊天消息加语音时长列（可空，安全迁移）
            await m.addColumn(chatMessages, chatMessages.audioDuration);
          }
          if (from < 8) {
            // 微信引用回复：本地缓存与服务端同时保存，重启后引用条不丢。
            await m.addColumn(chatMessages, chatMessages.quoteMessageId);
            await m.addColumn(chatMessages, chatMessages.quoteRole);
            await m.addColumn(chatMessages, chatMessages.quoteContent);
          }
          if (from < 9) {
            // 群聊（032）：聊天消息加发言人列（可空，安全迁移；单聊恒 NULL）。
            await m.addColumn(chatMessages, chatMessages.senderCharacterId);
          }
          if (from < 10) {
            // 红包/转账（033）：聊天消息加金额列（可空，安全迁移；假钱）。
            await m.addColumn(chatMessages, chatMessages.amount);
          }
          if (from < 11) {
            // 红包领取（034）：聊天消息加 claimed/claimers（安全迁移；旧消息默认未领取）。
            await m.addColumn(chatMessages, chatMessages.claimed);
            await m.addColumn(chatMessages, chatMessages.claimers);
          }
          if (from < 12) {
            // 转账收/拒（验收批2）：聊天消息加 transfer_accepted（可空，旧消息=待回应）。
            await m.addColumn(chatMessages, chatMessages.transferAccepted);
          }
        },
      );

  // ---- Life habits ----
  Future<List<LifeHabitRow>> getAllHabits() => select(lifeHabits).get();

  Future<void> upsertHabit(LifeHabitsCompanion row) =>
      into(lifeHabits).insertOnConflictUpdate(row);

  /// 取某习惯在 [from, to) 时间窗内的全部事件（由调用方按归属日分桶）。
  Future<List<LifeHabitEventRow>> getEventsForHabitInWindow(
    String habitId,
    DateTime from,
    DateTime to,
  ) =>
      (select(lifeHabitEvents)
            ..where((t) => t.habitId.equals(habitId))
            ..where((t) => t.occurredAt.isBiggerOrEqualValue(from))
            ..where((t) => t.occurredAt.isSmallerThanValue(to)))
          .get();

  Future<LifeHabitEventRow> addEvent(LifeHabitEventsCompanion row) =>
      into(lifeHabitEvents).insertReturning(row);

  Future<void> deleteEventById(String id) =>
      (delete(lifeHabitEvents)..where((t) => t.id.equals(id))).go();

  Future<void> updateEventValue(String id, double value) =>
      (update(lifeHabitEvents)..where((t) => t.id.equals(id)))
          .write(LifeHabitEventsCompanion(value: Value(value)));

  // ---- Active session（进行中的计时）----
  Future<ActiveSessionRow?> getActiveSession() =>
      select(activeSessions).getSingleOrNull();

  Future<void> upsertActiveSession(ActiveSessionsCompanion row) =>
      into(activeSessions).insertOnConflictUpdate(row);

  Future<void> deleteActiveSession(String habitId) =>
      (delete(activeSessions)..where((t) => t.habitId.equals(habitId))).go();

  // ---- Inbox ----
  Future<List<InboxItemRow>> getInboxItems() => (select(inboxItems)
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
        ]))
      .get();

  Future<void> addInboxItem(InboxItemsCompanion row) =>
      into(inboxItems).insert(row);

  // ---- AI 聊天历史缓存（v5，需求2）----
  /// 读某会话缓存，按时间正序（最旧→最新，与聊天页存储顺序一致）。
  Future<List<ChatMessageRow>> getChatMessages(String conversationId) =>
      (select(chatMessages)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
            ]))
          .get();

  /// 整会话 upsert（幂等：PK(conversation_id, id) 冲突覆盖；服务端确认消息）。
  Future<void> upsertChatMessages(List<ChatMessageRow> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(chatMessages, rows));
  }

  /// 删除单条本地聊天缓存。用于服务端 UUID 消息确认后移除 local-* 乐观消息，
  /// 避免快速退出/重进时出现重复气泡。
  Future<void> deleteChatMessage(String conversationId, String messageId) =>
      (delete(chatMessages)
            ..where((t) =>
                t.conversationId.equals(conversationId) &
                t.id.equals(messageId)))
          .go();

  /// 清空某会话的本地缓存（配合微信「清空聊天记录」）。
  Future<void> deleteChatMessages(String conversationId) =>
      (delete(chatMessages)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();

  // ---- 本地缓存（v6，优化1：冷启动秒开）----
  Future<MediaCacheRow?> getMediaCache(String mediaId) =>
      (select(mediaCache)..where((t) => t.mediaId.equals(mediaId)))
          .getSingleOrNull();

  Future<void> upsertMediaCache(MediaCacheRow row) =>
      into(mediaCache).insertOnConflictUpdate(row);

  Future<KvCacheRow?> getKvRow(String key) =>
      (select(kvCache)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<void> upsertKv(String key, String value) =>
      into(kvCache).insertOnConflictUpdate(
        KvCacheCompanion(
          key: Value(key),
          value: Value(value),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> deleteKv(String key) =>
      (delete(kvCache)..where((t) => t.key.equals(key))).go();

  Future<void> deleteMediaCaches(Iterable<String> mediaIds) async {
    final ids = mediaIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    await (delete(mediaCache)..where((t) => t.mediaId.isIn(ids))).go();
  }

  // ---- Sync queue ----
  Future<List<SyncEventRow>> getUnsynced() =>
      (select(syncEventsLocal)..where((t) => t.synced.equals(0))).get();

  Future<int> markSynced(List<String> ids) =>
      (update(syncEventsLocal)..where((t) => t.id.isIn(ids))).write(
        const SyncEventsLocalCompanion(synced: Value(1)),
      );

  Future<void> enqueue(SyncEventsLocalCompanion row) =>
      into(syncEventsLocal).insert(row);

  /// 重放远端同步事件（重装恢复 / 多设备合并）。
  /// 幂等：create/update 走 upsert，delete 走按 id 删除；可重复调用。
  /// payload 为 snake_case JSON（与本地 enqueue 格式一致）。
  Future<void> applyRemoteEvent(
    String entityType,
    String operation,
    Map<String, dynamic> p,
  ) async {
    switch (entityType) {
      case 'life_habit_event':
        if (operation == 'delete') {
          await (delete(lifeHabitEvents)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(lifeHabitEvents).insertOnConflictUpdate(
            LifeHabitEventsCompanion(
              id: Value(p['id'] as String),
              habitId: Value(p['habit_id'] as String),
              occurredAt: Value(DateTime.parse(p['occurred_at'] as String)),
              value: Value((p['value'] as num? ?? 1).toDouble()),
              note: p['note'] == null
                  ? const Value.absent()
                  : Value(p['note'] as String?),
            ),
          );
        }

      case 'study_resource':
        if (operation == 'delete') {
          await (delete(studyResources)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(studyResources).insertOnConflictUpdate(
            StudyResourcesCompanion(
              id: Value(p['id'] as String),
              name: Value(p['name'] as String),
              category: Value(p['category'] as String? ?? '其他'),
              iconName: Value(p['icon_name'] as String? ?? 'book'),
              colorArgb: Value(p['color_argb'] as int? ?? 0xFF2196F3),
              goalAmount: Value((p['goal_amount'] as num? ?? 0).toDouble()),
              goalUnit: Value(p['goal_unit'] as String? ?? ''),
              createdAt: Value(DateTime.parse(p['created_at'] as String)),
            ),
          );
        }

      case 'study_session':
        if (operation == 'delete') {
          await (delete(studySessions)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(studySessions).insertOnConflictUpdate(
            StudySessionsCompanion(
              id: Value(p['id'] as String),
              resourceId: Value(p['resource_id'] as String),
              startedAt: Value(DateTime.parse(p['started_at'] as String)),
              durationSeconds:
                  Value((p['duration_seconds'] as num? ?? 0).toDouble()),
              amount: Value((p['amount'] as num? ?? 0).toDouble()),
              note: p['note'] == null
                  ? const Value.absent()
                  : Value(p['note'] as String?),
            ),
          );
        }

      case 'exercise_type':
        if (operation == 'delete') {
          await (delete(exerciseTypes)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(exerciseTypes).insertOnConflictUpdate(
            ExerciseTypesCompanion(
              id: Value(p['id'] as String),
              name: Value(p['name'] as String),
              iconName: Value(p['icon_name'] as String? ?? 'directions_run'),
              metrics: Value(p['metrics'] as String? ?? 'count'),
              countUnit: Value(p['count_unit'] as String? ?? '次'),
              distanceUnit: Value(p['distance_unit'] as String? ?? 'm'),
              colorArgb: Value(p['color_argb'] as int? ?? 0xFFFF5722),
              createdAt: Value(DateTime.parse(p['created_at'] as String)),
            ),
          );
        }

      case 'exercise_session':
        if (operation == 'delete') {
          await (delete(exerciseSessions)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(exerciseSessions).insertOnConflictUpdate(
            ExerciseSessionsCompanion(
              id: Value(p['id'] as String),
              typeId: Value(p['type_id'] as String),
              occurredAt: Value(DateTime.parse(p['occurred_at'] as String)),
              count: Value((p['count'] as num? ?? 0).toInt()),
              durationSeconds:
                  Value((p['duration_seconds'] as num? ?? 0).toDouble()),
              distanceMeters:
                  Value((p['distance_meters'] as num? ?? 0).toDouble()),
              sets: p['sets'] == null
                  ? const Value.absent()
                  : Value((p['sets'] as num).toInt()),
              weightKg: p['weight_kg'] == null
                  ? const Value.absent()
                  : Value((p['weight_kg'] as num).toDouble()),
              note: p['note'] == null
                  ? const Value.absent()
                  : Value(p['note'] as String?),
            ),
          );
        }

      case 'pet':
        if (operation == 'delete') {
          await (delete(pets)..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(pets).insertOnConflictUpdate(
            PetsCompanion(
              id: Value(p['id'] as String),
              name: Value(p['name'] as String),
              species: Value(p['species'] as String? ?? 'cat'),
              avatarPath: p['avatar_path'] == null
                  ? const Value.absent()
                  : Value(p['avatar_path'] as String?),
              createdAt: Value(DateTime.parse(p['created_at'] as String)),
            ),
          );
        }

      case 'pet_log':
        if (operation == 'delete') {
          await (delete(petLogs)..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(petLogs).insertOnConflictUpdate(
            PetLogsCompanion(
              id: Value(p['id'] as String),
              petId: Value(p['pet_id'] as String),
              kind: Value(p['kind'] as String? ?? 'text'),
              content: Value(p['content'] as String? ?? ''),
              value: p['value'] == null
                  ? const Value.absent()
                  : Value((p['value'] as num).toDouble()),
              mediaAssetId: p['media_asset_id'] == null
                  ? const Value.absent()
                  : Value(p['media_asset_id'] as String?),
              note: p['note'] == null
                  ? const Value.absent()
                  : Value(p['note'] as String?),
              occurredAt: Value(DateTime.parse(p['occurred_at'] as String)),
            ),
          );
        }

      case 'inbox_item':
        if (operation == 'delete') {
          await (delete(inboxItems)
                ..where((t) => t.id.equals(p['id'] as String)))
              .go();
        } else {
          await into(inboxItems).insertOnConflictUpdate(
            InboxItemsCompanion(
              id: Value(p['id'] as String),
              content: Value(p['content'] as String),
              kind: Value(p['kind'] as String? ?? 'note'),
            ),
          );
        }
    }
  }
}
