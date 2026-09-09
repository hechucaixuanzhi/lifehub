import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/features/ai/models/ai_chat_message.dart';
import 'package:lifehub/features/ai/ui/widgets/voice_bubble.dart';
import 'package:lifehub/features/ai/ui/widgets/wechat_bubble.dart';

void main() {
  test('pending message JSON survives page exit with status', () {
    final original = AiMessage(
      id: 'local-1',
      role: 'user',
      content: '退出聊天也不能丢',
      createdAt: DateTime.utc(2026, 8, 9, 12),
      status: AiMsgStatus.failed,
    );

    final restored = AiMessage.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.content, original.content);
    expect(restored.createdAt, original.createdAt);
    expect(restored.status, AiMsgStatus.failed);
  });

  testWidgets('sending is visually silent and failure shows red icon',
      (tester) async {
    Future<void> pumpStatus(AiMsgStatus status) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WeChatBubble(
                isMe: true,
                status: status,
                child: const Text('消息'),
              ),
            ),
          ),
        );

    await pumpStatus(AiMsgStatus.sending);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);

    await pumpStatus(AiMsgStatus.failed);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('voice message uses WeChat duration bubble without play triangle',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: VoiceBubble(
              audioId: 'voice-test',
              isMe: false,
              durationSeconds: 3,
              transcript: '只在转文字后显示',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('wechat_voice_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('wechat_voice_duration')), findsOneWidget);
    expect(find.text('3″'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.text('只在转文字后显示'), findsNothing);
  });
}
