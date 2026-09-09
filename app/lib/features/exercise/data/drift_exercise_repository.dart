import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/domain/entities/exercise_session.dart';
import 'package:lifehub/domain/entities/exercise_type.dart';
import 'package:lifehub/domain/repositories/exercise_repository.dart';
import 'package:uuid/uuid.dart';

/// Drift 实现：运动类型 / 手动记一笔（同时入同步队列）。
class DriftExerciseRepository implements ExerciseRepository {
  DriftExerciseRepository(this.db);
  final AppDatabase db;

  @override
  Future<List<ExerciseType>> getTypes() async =>
      (await db.select(db.exerciseTypes).get()).map((r) => ExerciseType(
            id: r.id,
            name: r.name,
            iconName: r.iconName,
            metrics: r.metrics,
            countUnit: r.countUnit,
            distanceUnit: r.distanceUnit,
            colorArgb: r.colorArgb,
            createdAt: r.createdAt,
          )).toList();

  @override
  Future<ExerciseType> addType({
    required String name,
    required String iconName,
    required List<String> metrics,
    required String countUnit,
    required String distanceUnit,
    required int colorArgb,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final metricsStr = metrics.join(',');
    await db.into(db.exerciseTypes).insert(
          ExerciseTypesCompanion.insert(
            id: id,
            name: name,
            iconName: Value(iconName),
            metrics: Value(metricsStr),
            countUnit: Value(countUnit),
            distanceUnit: Value(distanceUnit),
            colorArgb: Value(colorArgb),
            createdAt: Value(now),
          ),
        );
    await _enqueue('exercise_type', id, 'create', {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'metrics': metricsStr,
      'count_unit': countUnit,
      'distance_unit': distanceUnit,
      'color_argb': colorArgb,
      'created_at': now.toIso8601String(),
    });
    return ExerciseType(
      id: id,
      name: name,
      iconName: iconName,
      metrics: metricsStr,
      countUnit: countUnit,
      distanceUnit: distanceUnit,
      colorArgb: colorArgb,
      createdAt: now,
    );
  }

  @override
  Future<void> deleteType(String typeId) async {
    final sessions = await getSessions(typeId);
    for (final s in sessions) {
      await _enqueue('exercise_session', s.id, 'delete', {'id': s.id});
    }
    await (db.delete(db.exerciseSessions)
          ..where((t) => t.typeId.equals(typeId)))
        .go();
    await (db.delete(db.exerciseTypes)..where((t) => t.id.equals(typeId)))
        .go();
    await _enqueue('exercise_type', typeId, 'delete', {'id': typeId});
  }

  @override
  Future<List<ExerciseSession>> getSessions(String typeId) async {
    final rows = await (db.select(db.exerciseSessions)
          ..where((t) => t.typeId.equals(typeId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows
        .map((r) => ExerciseSession(
              id: r.id,
              typeId: r.typeId,
              occurredAt: r.occurredAt,
              count: r.count,
              durationSeconds: r.durationSeconds,
              distanceMeters: r.distanceMeters,
              sets: r.sets,
              weightKg: r.weightKg,
              note: r.note,
            ))
        .toList();
  }

  @override
  Future<void> addSession({
    required String typeId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.exerciseSessions).insert(
          ExerciseSessionsCompanion.insert(
            id: id,
            typeId: typeId,
            occurredAt: Value(now),
            count: Value(count),
            durationSeconds: Value(durationSeconds.toDouble()),
            distanceMeters: Value(distanceMeters),
            sets: Value(sets),
            weightKg: Value(weightKg),
            note: Value(note),
          ),
        );
    await _enqueue('exercise_session', id, 'create', {
      'id': id,
      'type_id': typeId,
      'occurred_at': now.toIso8601String(),
      'count': count,
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'sets': sets,
      'weight_kg': weightKg,
      'note': note,
    });
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
  }) async {
    await (db.update(db.exerciseSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(
          ExerciseSessionsCompanion(
            count: Value(count),
            durationSeconds: Value(durationSeconds.toDouble()),
            distanceMeters: Value(distanceMeters),
            sets: Value(sets),
            weightKg: Value(weightKg),
          ),
        );
    await _enqueue('exercise_session', sessionId, 'update', {
      'id': sessionId,
      'count': count,
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'sets': sets,
      'weight_kg': weightKg,
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
