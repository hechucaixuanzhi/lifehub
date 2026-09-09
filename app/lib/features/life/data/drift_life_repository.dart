import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/domain/entities/life_habit.dart';
import 'package:lifehub/domain/entities/life_habit_event.dart';
import 'package:lifehub/domain/repositories/life_repository.dart';
import 'package:uuid/uuid.dart';

/// Drift 实现：读习惯 / 记一笔 / 计时 / 纠错（同时入同步队列）。
class DriftLifeRepository implements LifeRepository {
  DriftLifeRepository(this.db);
  final AppDatabase db;

  @override
  Future<List<LifeHabit>> getHabits() async =>
      (await db.getAllHabits()).map((r) => LifeHabit(
            id: r.id,
            name: r.name,
            iconName: r.iconName,
            colorArgb: r.colorArgb,
            dailyTarget: r.dailyTarget,
            unit: r.unit,
            type: r.type,
            behavior: r.behavior,
            createdAt: r.createdAt,
          )).toList();

  /// 取某习惯「归属日 = [day]」的事件（overnight 行为按结束日归属）。
  Future<List<LifeHabitEventRow>> _eventsEffectiveDay(
    String habitId,
    DateTime day,
    String behavior,
  ) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final from = dayStart.subtract(const Duration(days: 1)); // 承接跨午夜开始
    final to = dayStart.add(const Duration(days: 2));
    final rows = await db.getEventsForHabitInWindow(habitId, from, to);
    return rows.where((e) {
      final eff = behavior == 'overnight'
          ? e.occurredAt.add(Duration(seconds: e.value.toInt()))
          : e.occurredAt;
      final ed = DateTime(eff.year, eff.month, eff.day);
      return ed.isAtSameMomentAs(dayStart);
    }).toList();
  }

  @override
  Future<Map<String, double>> getTodayProgress() async {
    final now = DateTime.now();
    final habits = await db.getAllHabits();
    final out = <String, double>{};
    for (final h in habits) {
      final evs = await _eventsEffectiveDay(h.id, now, h.behavior);
      if (h.type == 'timer') {
        final secs = evs.fold(0.0, (s, e) => s + e.value);
        out[h.id] = secs / 60.0; // 分钟
      } else {
        out[h.id] = evs.length.toDouble(); // 次数
      }
    }
    return out;
  }

  @override
  Future<void> recordTap(String habitId) async {
    final now = DateTime.now();
    final eventId = const Uuid().v4();
    await db.addEvent(
      LifeHabitEventsCompanion.insert(
        id: eventId,
        habitId: habitId,
        occurredAt: Value(now),
        value: const Value(1.0),
      ),
    );
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'life_habit_event',
        entityId: eventId,
        operation: 'create',
        payload: jsonEncode({
          'id': eventId,
          'habit_id': habitId,
          'occurred_at': now.toIso8601String(),
          'value': 1.0,
        }),
      ),
    );
  }

  @override
  Future<void> startTimer(String habitId) async {
    final existing = await db.getActiveSession();
    if (existing != null && existing.habitId != habitId) {
      await stopTimer(existing.habitId); // 先结算上一个进行中的计时
    }
    final now = DateTime.now();
    await db.upsertActiveSession(
      ActiveSessionsCompanion.insert(
        habitId: habitId,
        startedAt: Value(now),
      ),
    );
  }

  @override
  Future<int> stopTimer(String habitId) async {
    final session = await db.getActiveSession();
    if (session == null || session.habitId != habitId) return 0;
    final seconds = DateTime.now().difference(session.startedAt).inSeconds;
    final eventId = const Uuid().v4();
    await db.addEvent(
      LifeHabitEventsCompanion.insert(
        id: eventId,
        habitId: habitId,
        occurredAt: Value(session.startedAt),
        value: Value(seconds.toDouble()),
      ),
    );
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'life_habit_event',
        entityId: eventId,
        operation: 'create',
        payload: jsonEncode({
          'id': eventId,
          'habit_id': habitId,
          'occurred_at': session.startedAt.toIso8601String(),
          'value': seconds,
        }),
      ),
    );
    await db.deleteActiveSession(habitId);
    return seconds;
  }

  @override
  Future<ActiveTimer?> getActiveSession() async {
    final row = await db.getActiveSession();
    return row == null ? null : ActiveTimer(row.habitId, row.startedAt);
  }

  @override
  Future<void> cancelActiveSession(String habitId) async =>
      db.deleteActiveSession(habitId);

  @override
  Future<void> deleteLastEventToday(String habitId) async {
    final habits = await db.getAllHabits();
    final h = habits.firstWhere((x) => x.id == habitId);
    final evs = await _eventsEffectiveDay(habitId, DateTime.now(), h.behavior);
    if (evs.isEmpty) return;
    evs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final target = evs.first;
    await db.deleteEventById(target.id);
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'life_habit_event',
        entityId: target.id,
        operation: 'delete',
        payload: jsonEncode({'id': target.id}),
      ),
    );
  }

  @override
  Future<List<LifeHabitEvent>> getHistory(String habitId,
      {int days = 30}) async {
    final habits = await db.getAllHabits();
    final h = habits.firstWhere((x) => x.id == habitId);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final to =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final rows = await db.getEventsForHabitInWindow(habitId, from, to);
    return rows
        .map((e) => LifeHabitEvent(
              id: e.id,
              habitId: e.habitId,
              occurredAt: e.occurredAt,
              value: e.value,
              behavior: h.behavior,
              note: e.note,
            ))
        .toList();
  }

  @override
  Future<void> updateEventDuration(String eventId, int seconds) async {
    await db.updateEventValue(eventId, seconds.toDouble());
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'life_habit_event',
        entityId: eventId,
        operation: 'update',
        payload: jsonEncode({'id': eventId, 'value': seconds}),
      ),
    );
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await db.deleteEventById(eventId);
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'life_habit_event',
        entityId: eventId,
        operation: 'delete',
        payload: jsonEncode({'id': eventId}),
      ),
    );
  }
}
