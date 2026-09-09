/// 宠物模块：一次宠物记录（文字/体重/健康/照片）。领域实体，与 Drift 解耦。
class PetLog {
  const PetLog({
    required this.id,
    required this.petId,
    required this.kind,
    required this.content,
    this.value,
    this.mediaAssetId,
    this.note,
    required this.occurredAt,
  });

  final String id;
  final String petId;
  final String kind; // text | weight | health | photo
  final String content;
  final double? value; // weight 时为 kg
  final String? mediaAssetId; // photo 时关联 MediaAsset
  final String? note;
  final DateTime occurredAt;
}
