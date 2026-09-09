/// AI 长期记忆（记忆层，与后端 memory 表对齐）。
/// 每角色独立：characterId 区分，手机可增删改。
class AiMemory {
  const AiMemory({
    required this.id,
    required this.type,
    required this.content,
    this.characterId,
    this.createdAt,
    this.status = 'active',
    this.supersededBy,
    this.refinedAt,
  });

  final String id;
  final String type; // event | fact | preference
  final String content;
  final String? characterId;
  final DateTime? createdAt;
  // 提炼状态（012）：active | superseded（已并入他条）| archived（已归档）
  final String status;
  final String? supersededBy;
  final DateTime? refinedAt;

  bool get isInactive => status != 'active';

  factory AiMemory.fromJson(Map<String, dynamic> json) {
    return AiMemory(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'fact',
      content: json['content'] as String? ?? '',
      characterId: json['character_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      status: json['status'] as String? ?? 'active',
      supersededBy: json['superseded_by'] as String?,
      refinedAt: DateTime.tryParse(json['refined_at'] as String? ?? ''),
    );
  }
}
