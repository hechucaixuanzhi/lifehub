import '../models/ai_chat_message.dart';

const chatEmojis = [
  '😀', '😂', '😍', '😘', '🥰', '😎', '🤔', '😭',
  '😅', '😡', '👍', '🙏', '💕', '❤️', '🔥', '✨',
  '🌹', '🍺', '🐱', '🎉', '😴', '🤗', '😇', '💔',
  '😋', '😝', '😜', '🤪', '😏', '😒', '😢', '🥺',
  '😪', '😵', '🤯', '🥳', '😱', '😨', '😷', '🤒',
];

bool isOptimisticMessage(AiMessage message) =>
    message.id.startsWith('local-');

bool sameOutgoingMessage(AiMessage a, AiMessage b) =>
    a.isMe && b.isMe && a.kind == b.kind && a.content == b.content;

bool sameRecentOutgoingMessage(AiMessage a, AiMessage b) =>
    sameOutgoingMessage(a, b) &&
    a.createdAt.difference(b.createdAt).abs() < const Duration(minutes: 5);

String imageMimeFor(String name) {
  final normalized = name.toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.gif')) return 'image/gif';
  if (normalized.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String chatMessageDisplayText(AiMessage message) => switch (message.kind) {
      'image' => '[图片]',
      'sticker' => '[表情包]',
      'audio' => '[语音]',
      'file' => message.fileName ?? '[文件]',
      'redpacket' => '[红包]',
      'transfer' => '[转账]',
      _ => message.content,
    };

String chatTimeLabel(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final hm =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (isSameCalendarDay(time, current)) return hm;
  if (isSameCalendarDay(time, current.subtract(const Duration(days: 1)))) {
    return '昨天 $hm';
  }
  if (time.year == current.year) return '${time.month}月${time.day}日 $hm';
  return '${time.year}年${time.month}月${time.day}日 $hm';
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
