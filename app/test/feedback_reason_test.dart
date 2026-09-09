import 'package:flutter_test/flutter_test.dart';

import 'package:lifehub/features/ai/models/ai_chat_message.dart';
import 'package:lifehub/features/ai/ui/widgets/feedback.dart';

/// 反馈自动候选原因规则（A3：一步提交、不弹窗，规则自动生成，V3 AI 可覆盖）。
void main() {
  group('analyzeFeedbackReason', () {
    test('太说教 preachy：倾诉语境下短建议（用户评审用例：去世 → 节哀，你要坚强）', () {
      final r = analyzeFeedbackReason('我妈去世了', '节哀，你要坚强。');
      expect(r, contains('preachy'));
    });

    test('太说教 preachy：无倾诉语境但硬说教词', () {
      final r = analyzeFeedbackReason('这道题怎么做', '你应该先看课本。');
      expect(r, contains('preachy'));
    });

    test('太冷淡 too_cold：用户倾诉时极短且无共情', () {
      final r = analyzeFeedbackReason('我分手了，好难受', '嗯');
      expect(r, contains('too_cold'));
    });

    test('太冷淡 too_cold：倾诉但回复含共情词则不算', () {
      final r = analyzeFeedbackReason('我分手了，好难受', '我在，你慢慢说');
      expect(r, isNot(contains('too_cold')));
    });

    test('太啰嗦 too_verbose：超长回复', () {
      final long = List.filled(60, '这是一个非常非常长的句子用来触发啰嗦检测。').join();
      final r = analyzeFeedbackReason('今天天气不错', long);
      expect(r, contains('too_verbose'));
    });

    test('倾诉共情且足够长：不误报冷淡/说教', () {
      final r =
          analyzeFeedbackReason('我考砸了，好难过', '我理解你现在很难受，你已经很努力了。');
      expect(r, isEmpty);
    });

    test('无命中：普通闲聊返回空数组（快照照旧落库）', () {
      final r = analyzeFeedbackReason('今天天气不错', '嗯嗯，确实挺好');
      expect(r, isEmpty);
    });
  });

  group('precedingUserMessage', () {
    test('取目标消息之前最近的用户文字消息', () {
      final msgs = [
        AiMessage(
            id: 'u1', role: 'user', content: '我妈去世了', createdAt: DateTime(2026)),
        AiMessage(
            id: 'a1',
            role: 'assistant',
            content: '节哀，你要坚强。',
            createdAt: DateTime(2026)),
      ];
      expect(precedingUserMessage(msgs, msgs[1]), '我妈去世了');
    });

    test('跨条向前找；目标前面没有用户文字消息返回空串', () {
      final msgs = [
        AiMessage(
            id: 'u1',
            role: 'user',
            kind: 'image',
            content: '[图片]',
            createdAt: DateTime(2026)),
        AiMessage(
            id: 'u2',
            role: 'user',
            content: '今天天气不错',
            createdAt: DateTime(2026)),
        AiMessage(
            id: 'a1', role: 'assistant', content: '嗯嗯', createdAt: DateTime(2026)),
      ];
      expect(precedingUserMessage(msgs, msgs[2]), '今天天气不错');
      expect(precedingUserMessage(msgs, msgs[0]), '');
    });
  });
}
