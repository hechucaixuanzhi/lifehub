/// 生活模块：习惯定义（领域实体，与 Drift 的 LifeHabitRow 解耦）。
class LifeHabit {
  const LifeHabit({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorArgb,
    required this.dailyTarget,
    required this.unit,
    required this.type,
    required this.behavior,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String iconName;
  final int colorArgb;
  final int dailyTarget;
  final String unit;
  final String type; // HabitMode：counter（计数）| timer（计时）
  final String behavior; // 计时行为：normal（当日）| overnight（跨午夜，按结束日归属）
  final DateTime createdAt;

  bool get isTimer => type == 'timer';
  bool get isOvernight => behavior == 'overnight';
}
