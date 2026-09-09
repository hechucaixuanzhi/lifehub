import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/features/ai/models/ai_chat_message.dart';
import 'package:lifehub/features/ai/services/chat_message_session.dart';

AiMessage _message({
  required String id,
  required String role,
  required String content,
  required DateTime createdAt,
}) =>
    AiMessage(
      id: id,
      role: role,
      content: content,
      createdAt: createdAt,
    );

void main() {
  test('local ids stay unique within a chat session', () {
    final session = ChatMessageSession();

    final first = session.nextLocalId();
    final second = session.nextLocalId();

    expect(first, startsWith('local-'));
    expect(second, startsWith('local-'));
    expect(second, isNot(first));
  });

  test('server history retains unmatched optimistic messages', () {
    final session = ChatMessageSession();
    final now = DateTime(2026, 8, 12, 12);
    final confirmed = _message(
      id: 'server-1',
      role: 'user',
      content: '已确认',
      createdAt: now,
    );
    final optimistic = _message(
      id: 'local-1',
      role: 'user',
      content: '仍在发送',
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final merged = session.mergeServerHistory(
      current: [confirmed, optimistic],
      server: [confirmed],
      sameOutgoing: (server, local) =>
          server.role == 'user' &&
          local.role == 'user' &&
          server.content == local.content,
    );

    expect(merged.map((message) => message.id), ['server-1', 'local-1']);
  });

  test('server confirmation replaces matching optimistic message', () {
    final session = ChatMessageSession();
    final now = DateTime(2026, 8, 12, 12);
    final optimistic = _message(
      id: 'local-1',
      role: 'user',
      content: '同一条消息',
      createdAt: now,
    );
    final confirmed = _message(
      id: 'server-1',
      role: 'user',
      content: '同一条消息',
      createdAt: now.add(const Duration(seconds: 1)),
    );

    final merged = session.mergeServerHistory(
      current: [optimistic],
      server: [confirmed],
      sameOutgoing: (server, local) =>
          server.role == 'user' &&
          local.role == 'user' &&
          server.content == local.content,
    );

    expect(merged, hasLength(1));
    expect(merged.single.id, 'server-1');
  });
}
