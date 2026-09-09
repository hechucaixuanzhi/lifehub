/// 运动模块：一次运动记录（次数/时长/距离，按需；健身可含组数/重量）。领域实体，与 Drift 解耦。
class ExerciseSession {
  const ExerciseSession({
    required this.id,
    required this.typeId,
    required this.occurredAt,
    required this.count,
    required this.durationSeconds,
    required this.distanceMeters,
    this.sets,
    this.weightKg,
    this.note,
  });

  final String id;
  final String typeId;
  final DateTime occurredAt;
  final int count;
  final double durationSeconds; // 秒
  final double distanceMeters;
  final int? sets; // 健身：组数（v0.4-3）
  final double? weightKg; // 健身：重量 kg（v0.4-3）
  final String? note;

  Duration get duration => Duration(seconds: durationSeconds.toInt());
  double get distanceKm => distanceMeters / 1000;
}
