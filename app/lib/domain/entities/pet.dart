/// 宠物模块：宠物档案（猫优先）。领域实体，与 Drift 解耦。
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.avatarPath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String species; // cat/dog/…
  final String? avatarPath; // 本地文档目录路径
  final DateTime createdAt;
}
