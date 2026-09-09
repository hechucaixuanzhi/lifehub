import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/features/ai/models/ai_chat_message.dart';
import 'package:lifehub/features/ai/ui/chat_message_utils.dart';

void main() {
  test('single-chat optimistic matching keeps the five minute guard', () {
    final createdAt = DateTime.utc(2026, 8, 11, 8);
    final first = AiMessage(
      id: 'local-1',
      role: 'user',
      content: '你好',
      createdAt: createdAt,
    );
    final near = AiMessage(
      id: 'server-1',
      role: 'user',
      content: '你好',
      createdAt: createdAt.add(const Duration(minutes: 4)),
    );
    final far = AiMessage(
      id: 'server-2',
      role: 'user',
      content: '你好',
      createdAt: createdAt.add(const Duration(minutes: 6)),
    );

    expect(isOptimisticMessage(first), isTrue);
    expect(sameRecentOutgoingMessage(first, near), isTrue);
    expect(sameRecentOutgoingMessage(first, far), isFalse);
    expect(sameOutgoingMessage(first, far), isTrue);
  });

  test('message labels and time labels preserve the previous UI text', () {
    final image = AiMessage(
      id: '1',
      role: 'assistant',
      kind: 'image',
      content: '',
      createdAt: DateTime.utc(2026, 8, 11),
    );
    expect(chatMessageDisplayText(image), '[图片]');
    expect(imageMimeFor('photo.WEBP'), 'image/webp');
    expect(
      chatTimeLabel(
        DateTime(2026, 8, 10, 9, 5),
        now: DateTime(2026, 8, 11, 12),
      ),
      '昨天 09:05',
    );
  });
}
