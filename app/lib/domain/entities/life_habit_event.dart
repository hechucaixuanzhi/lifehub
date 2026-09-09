/// 生活模块：一次「记一笔」事件（领域实体，与 Drift 的 LifeHabitEventRow 解耦）。
class LifeHabitEvent {
  const LifeHabitEvent({
    required this.id,
    required this.habitId,
    required this.occurredAt,
    required this.value,
    required this.behavior,
    this.note,
  });

  final String id;
  final String habitId;
  final DateTime occurredAt;
  final double value;
  final String behavior; // normal | overnight（决定归属日）
  final String? note;

  /// 该事件归属的「日」（本地零点）。overnight 行为按结束日（开始+时长）归属。
  DateTime get effectiveDay {
    final base = isOvernight
        ? occurredAt.add(Duration(seconds: value.toInt()))
        : occurredAt;
    return DateTime(base.year, base.month, base.day);
  }

  bool get isOvernight => behavior == 'overnight';

  /// 事件数值：counter 为次数（1），timer 为时长（秒）。
  int get amount => value.toInt();
}
