/// 学习模块：学习资源（小说/论文/数学课程/英语/日语…）。领域实体，与 Drift 解耦。
class StudyResource {
  const StudyResource({
    required this.id,
    required this.name,
    required this.category,
    required this.iconName,
    required this.colorArgb,
    required this.goalAmount,
    required this.goalUnit,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String category; // 小说/论文/数学/英语/日语/其他
  final String iconName;
  final int colorArgb;
  final double goalAmount; // 目标量（进度分母）；0 = 不量化进度
  final String goalUnit; // 页/章/小时/词…

  final DateTime createdAt;

  bool get hasGoal => goalAmount > 0;
}
