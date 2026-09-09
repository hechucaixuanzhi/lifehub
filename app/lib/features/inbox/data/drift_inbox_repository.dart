import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/domain/entities/inbox_item.dart';
import 'package:lifehub/domain/repositories/inbox_repository.dart';
import 'package:uuid/uuid.dart';

class DriftInboxRepository implements InboxRepository {
  DriftInboxRepository(this.db);
  final AppDatabase db;

  @override
  Future<List<InboxItem>> getItems() async =>
      (await db.getInboxItems()).map((r) => InboxItem(
            id: r.id,
            content: r.content,
            kind: r.kind,
            createdAt: r.createdAt,
            synced: r.synced,
          )).toList();

  @override
  Future<void> add(String content, {String kind = 'note'}) async {
    final id = const Uuid().v4();
    await db.addInboxItem(
      InboxItemsCompanion.insert(
        id: id,
        content: content,
        kind: Value(kind),
      ),
    );
    await db.enqueue(
      SyncEventsLocalCompanion.insert(
        id: const Uuid().v4(),
        entityType: 'inbox_item',
        entityId: id,
        operation: 'create',
        payload: jsonEncode({
          'id': id,
          'content': content,
          'kind': kind,
          'created_at': DateTime.now().toIso8601String(),
        }),
      ),
    );
  }
}
