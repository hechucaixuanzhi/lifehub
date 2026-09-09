/// 运动模块：运动类型（跑步/散步/俯卧撑/深蹲/平板/卷腹…）。领域实体，与 Drift 解耦。
class ExerciseType {
  const ExerciseType({
    required this.id,
    required this.name,
    required this.iconName,
    required this.metrics,
    required this.countUnit,
    required this.distanceUnit,
    required this.colorArgb,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String iconName;
  final String metrics; // 逗号分隔能力集合：count|time|distance
  final String countUnit; // 次/个/组…
  final String distanceUnit; // m/km
  final int colorArgb;
  final DateTime createdAt;

  List<String> get metricList =>
      metrics.split(',').where((m) => m.trim().isNotEmpty).toList();
  bool get hasCount => metricList.contains('count');
  bool get hasTime => metricList.contains('time');
  bool get hasDistance => metricList.contains('distance');
}
