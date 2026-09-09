/// 学习模块：一次学习记录。领域实体，与 Drift 解耦。
class StudySession {
  const StudySession({
    required this.id,
    required this.resourceId,
    required this.startedAt,
    required this.durationSeconds,
    required this.amount,
    this.note,
  });

  final String id;
  final String resourceId;
  final DateTime startedAt;
  final double durationSeconds; // 秒
  final double amount; // 页/词/…
  final String? note;

  Duration get duration => Duration(seconds: durationSeconds.toInt());
}
