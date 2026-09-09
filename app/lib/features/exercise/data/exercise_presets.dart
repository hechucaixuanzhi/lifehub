/// 运动预设（固定 ID，首次启动 seed 进 exerciseTypes）。
class ExercisePreset {
  const ExercisePreset(
    this.id,
    this.name,
    this.iconName,
    this.metrics,
    this.countUnit,
    this.distanceUnit,
    this.colorArgb,
  );
  final String id;
  final String name;
  final String iconName;
  final String metrics; // 逗号分隔：count|time|distance
  final String countUnit;
  final String distanceUnit;
  final int colorArgb;
}

const List<ExercisePreset> exercisePresets = [
  ExercisePreset('ex_run', '跑步', 'directions_run', 'time,distance', '次', 'km',
      0xFFE53935),
  ExercisePreset('ex_walk', '散步', 'walk', 'time,distance', '次', 'km',
      0xFF43A047),
  ExercisePreset(
      'ex_pushup', '俯卧撑', 'fitness_center', 'count', '个', 'm', 0xFFFB8C00),
  ExercisePreset(
      'ex_squat', '深蹲', 'squat', 'count', '个', 'm', 0xFF8E24AA),
  ExercisePreset(
      'ex_plank', '平板', 'plank', 'time', '次', 'm', 0xFF00ACC1),
  ExercisePreset(
      'ex_crunch', '卷腹', 'crunches', 'count', '个', 'm', 0xFF3949AB),
];
