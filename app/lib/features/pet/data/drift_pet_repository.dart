import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/domain/entities/pet.dart';
import 'package:lifehub/domain/entities/pet_log.dart';
import 'package:lifehub/domain/repositories/pet_repository.dart';
import 'package:uuid/uuid.dart';

/// Drift 实现：宠物档案 / 记录（文字/体重/健康/照片，同时入同步队列）。
/// 照片实体文件存手机本地文档目录，仅记路径 / mediaAssetId。
class DriftPetRepository implements PetRepository {
  DriftPetRepository(this.db);
  final AppDatabase db;

  @override
  Future<List<Pet>> getPets() async =>
      (await db.select(db.pets).get()).map((r) => Pet(
            id: r.id,
            name: r.name,
            species: r.species,
            avatarPath: r.avatarPath,
            createdAt: r.createdAt,
          )).toList();

  @override
  Future<Pet> addPet({
    required String name,
    required String species,
    String? avatarPath,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.pets).insert(
          PetsCompanion.insert(
            id: id,
            name: name,
            species: Value(species),
            avatarPath: Value(avatarPath),
            createdAt: Value(now),
          ),
        );
    await _enqueue('pet', id, 'create', {
      'id': id,
      'name': name,
      'species': species,
      'avatar_path': avatarPath,
      'created_at': now.toIso8601String(),
    });
    return Pet(
      id: id,
      name: name,
      species: species,
      avatarPath: avatarPath,
      createdAt: now,
    );
  }

  @override
  Future<void> deletePet(String petId) async {
    final logs = await getLogs(petId);
    for (final l in logs) {
      await _enqueue('pet_log', l.id, 'delete', {'id': l.id});
    }
    await (db.delete(db.petLogs)..where((t) => t.petId.equals(petId))).go();
    await (db.delete(db.pets)..where((t) => t.id.equals(petId))).go();
    await _enqueue('pet', petId, 'delete', {'id': petId});
  }

  @override
  Future<List<PetLog>> getLogs(String petId, {int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final rows = await (db.select(db.petLogs)
          ..where((t) => t.petId.equals(petId))
          ..where((t) => t.occurredAt.isBiggerOrEqualValue(from))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc)
          ]))
        .get();
    return rows
        .map((r) => PetLog(
              id: r.id,
              petId: r.petId,
              kind: r.kind,
              content: r.content,
              value: r.value,
              mediaAssetId: r.mediaAssetId,
              note: r.note,
              occurredAt: r.occurredAt,
            ))
        .toList();
  }

  @override
  Future<void> addLog({
    required String petId,
    required String kind,
    required String content,
    double? value,
    String? mediaAssetId,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.petLogs).insert(
          PetLogsCompanion.insert(
            id: id,
            petId: petId,
            kind: Value(kind),
            content: Value(content),
            value: Value(value),
            mediaAssetId: Value(mediaAssetId),
            note: Value(note),
            occurredAt: Value(now),
          ),
        );
    await _enqueue('pet_log', id, 'create', {
      'id': id,
      'pet_id': petId,
      'kind': kind,
      'content': content,
      'value': value,
      'media_asset_id': mediaAssetId,
      'note': note,
      'occurred_at': now.toIso8601String(),
    });
  }

  @override
  Future<void> updateLog({
    required String logId,
    required String content,
    double? value,
  }) async {
    await (db.update(db.petLogs)..where((t) => t.id.equals(logId))).write(
          PetLogsCompanion(
            content: Value(content),
            value: Value(value),
          ),
        );
    await _enqueue('pet_log', logId, 'update', {
      'id': logId,
      'content': content,
      'value': value,
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
