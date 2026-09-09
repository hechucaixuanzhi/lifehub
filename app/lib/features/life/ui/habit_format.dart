/// 时长格式化：分钟 → "7h12m" / "45m" / "8h"。
String formatHm(int totalMinutes) {
  if (totalMinutes <= 0) return '0m';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '${h}h${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

/// 秒 → 同上（用于计时进行中/事件时长）。
String formatHmSeconds(int seconds) => formatHm((seconds / 60).round());
