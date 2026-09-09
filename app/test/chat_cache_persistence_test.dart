import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/core/database/app_database.dart';
import 'package:lifehub/features/ai/models/ai_chat_message.dart';
import 'package:lifehub/features/ai/services/chat_cache_store.dart';

void main() {
  test('optimistic local message survives reopening until confirmed', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final createdAt = DateTime.utc(2026, 8, 9, 12);
    final cache = ChatCacheStore(database);

    await cache.upsert('conversation-1', [
      AiMessage(
        id: 'local-1',
        role: 'user',
        kind: 'text',
        content: '快速退出也不能消失',
        createdAt: createdAt,
      ),
    ]);

    final restored = await cache.read('conversation-1');
    expect(restored, hasLength(1));
    expect(restored.single.id, 'local-1');
    expect(restored.single.content, '快速退出也不能消失');

    await database.deleteChatMessage('conversation-1', 'local-1');
    expect(await database.getChatMessages('conversation-1'), isEmpty);
  });
}
