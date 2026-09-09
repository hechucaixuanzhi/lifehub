import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/domain/entities/study_resource.dart';
import 'package:lifehub/domain/entities/study_session.dart';
import 'package:lifehub/domain/repositories/life_repository.dart';
import 'package:lifehub/domain/repositories/study_repository.dart';
import 'package:uuid/uuid.dart';

/// Drift 实现：学习资源 / 计时 / 记一笔（同时入同步队列）。计时复用 ActiveSessions。
class DriftStudyRepository implements StudyRepository {
  DriftStudyRepository(this.db);
  final AppDatabase db;

  @override
  Future<List<StudyResource>> getResources() async =>
      (await db.select(db.studyResources).get()).map((r) => StudyResource(
            id: r.id,
            name: r.name,
            category: r.category,
            iconName: r.iconName,
            colorArgb: r.colorArgb,
            goalAmount: r.goalAmount,
            goalUnit: r.goalUnit,
            createdAt: r.createdAt,
          )).toList();

  @override
  Future<StudyResource> addResource({
    required String name,
    required String category,
    required String iconName,
    required int colorArgb,
    required double goalAmount,
    required String goalUnit,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.studyResources).insert(
          StudyResourcesCompanion.insert(
            id: id,
            name: name,
            category: Value(category),
            iconName: Value(iconName),
            colorArgb: Value(colorArgb),
            goalAmount: Value(goalAmount),
            goalUnit: Value(goalUnit),
            createdAt: Value(now),
          ),
        );
    await _enqueue('study_resource', id, 'create', {
      'id': id,
      'name': name,
      'category': category,
      'icon_name': iconName,
      'color_argb': colorArgb,
      'goal_amount': goalAmount,
      'goal_unit': goalUnit,
      'created_at': now.toIso8601String(),
    });
    return StudyResource(
      id: id,
      name: name,
      category: category,
      iconName: iconName,
      colorArgb: colorArgb,
      goalAmount: goalAmount,
      goalUnit: goalUnit,
      createdAt: now,
    );
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    final sessions = await getSessions(resourceId);
    for (final s in sessions) {
      await _enqueue('study_session', s.id, 'delete', {'id': s.id});
    }
    await (db.delete(db.studySessions)
          ..where((t) => t.resourceId.equals(resourceId)))
        .go();
    await (db.delete(db.studyResources)
          ..where((t) => t.id.equals(resourceId)))
        .go();
    await _enqueue('study_resource', resourceId, 'delete',
        {'id': resourceId});
  }

  @override
  Future<List<StudySession>> getSessions(String resourceId) async {
    final rows = await (db.select(db.studySessions)
          ..where((t) => t.resourceId.equals(resourceId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows
        .map((r) => StudySession(
              id: r.id,
              resourceId: r.resourceId,
              startedAt: r.startedAt,
              durationSeconds: r.durationSeconds,
              amount: r.amount,
              note: r.note,
            ))
        .toList();
  }

  @override
  Future<ActiveTimer?> getActiveSession() async {
    final row = await db.getActiveSession();
    return row == null ? null : ActiveTimer(row.habitId, row.startedAt);
  }

  @override
  Future<void> startTimer(String resourceId) async {
    final existing = await db.getActiveSession();
    if (existing != null && existing.habitId != resourceId) {
      await stopTimer(existing.habitId); // 先结算别的进行中的计时
    }
    final now = DateTime.now();
    await db.upsertActiveSession(
      ActiveSessionsCompanion.insert(
        habitId: resourceId,
        startedAt: Value(now),
      ),
    );
  }

  @override
  Future<int> stopTimer(String resourceId) async {
    final session = await db.getActiveSession();
    if (session == null || session.habitId != resourceId) return 0;
    final seconds = DateTime.now().difference(session.startedAt).inSeconds;
    await addSession(
      resourceId: resourceId,
      durationSeconds: seconds,
      amount: 0,
    );
    await db.deleteActiveSession(resourceId);
    return seconds;
  }

  @override
  Future<void> cancelActiveSession(String resourceId) async =>
      db.deleteActiveSession(resourceId);

  @override
  Future<void> addSession({
    required String resourceId,
    required int durationSeconds,
    required double amount,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: id,
            resourceId: resourceId,
            startedAt: Value(now),
            durationSeconds: Value(durationSeconds.toDouble()),
            amount: Value(amount),
            note: Value(note),
          ),
        );
    await _enqueue('study_session', id, 'create', {
      'id': id,
      'resource_id': resourceId,
      'started_at': now.toIso8601String(),
      'duration_seconds': durationSeconds,
      'amount': amount,
      'note': note,
    });
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required int durationSeconds,
    required double amount,
  }) async {
    await (db.update(db.studySessions)..where((t) => t.id.equals(sessionId))).write(
          StudySessionsCompanion(
            durationSeconds: Value(durationSeconds.toDouble()),
            amount: Value(amount),
          ),
        );
    await _enqueue('study_session', sessionId, 'update', {
      'id': sessionId,
      'duration_seconds': durationSeconds,
      'amount': amount,
    });
  }

  Future<void> _enqueue(String type, String entityId, String op,
          Map<String, dynamic> payload) =>
      db.enqueue(
        SyncEventsLocalCompanion.insert(
          id: const Uuid().v4(),
          entityType: type,
          entityId: entityId,
          operation: op,
          payload: jsonEncode(payload),
        ),
      );
}
