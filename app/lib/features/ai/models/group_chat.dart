import 'worldbook.dart';

/// 群成员（032_group_worldbook）：拉进群聊的 AI 角色。
/// avatar_color 为 '#RRGGBB' 字符串，渲染时用 parseHexColor 转 Color。
class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.avatarText,
    this.avatarColor,
    this.tagline,
    this.worldIdentity,
    this.temporary = false,
  });

  final String id;
  final String name;
  final String? avatarText;
  final String? avatarColor;
  final String? tagline;
  final String? worldIdentity; // 预留：成员级世界身份预设（MVP 不写）

  /// R6 配角临时加入：群设置可移除（永久成员移除即离群），角标「临时」。
  final bool temporary;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarText: json['avatar_text'] as String?,
      avatarColor: json['avatar_color'] as String?,
      tagline: json['tagline'] as String?,
      worldIdentity: json['world_identity'] as String?,
      temporary: json['temporary'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_text': avatarText,
        'avatar_color': avatarColor,
        'tagline': tagline,
        'world_identity': worldIdentity,
        'temporary': temporary,
      };
}

/// 群聊（032）：id = conversation_id。Drift 本地聊天缓存按 conversationId 组织，
/// 故群聊消息走与单聊同一张 ChatMessages 表，零结构改动。
class GroupChat {
  const GroupChat({
    required this.id,
    required this.name,
    this.members = const [],
    this.memberIds = const [],
    this.memberCount = 0,
    this.worldbookId,
    this.worldbook,
    this.speakerMode = 'auto',
    this.replyMode = 'realtime',
    this.backgroundMediaId,
    this.replyCharsRealtime = 180,
    this.replyCharsRoleplay = 1000,
    this.replyCount = 1,
  });

  final String id;
  final String name;
  final List<GroupMember> members;
  final List<String> memberIds;
  final int memberCount;
  final String? worldbookId;
  final Worldbook? worldbook;
  final String speakerMode; // auto | all | mention
  final String replyMode; // realtime | roleplay

  /// 群聊聊天背景（036）：指向 media_asset.id，null=默认纹理。
  final String? backgroundMediaId;

  /// 群聊回复「字数/条数」限制（036）：按 reply_mode 取用，群设置可调。
  final int replyCharsRealtime; // 60-600
  final int replyCharsRoleplay; // 300-3000
  final int replyCount; // 真实模式条数 1-5（剧情恒 1）

  /// 会话 key（AppPrefs 置顶/未读/隐藏字符串键；与单聊 chat_conv_<id> 区分）。
  String get convKey => 'group_conv_$id';

  /// 按发言人取成员（气泡头像渲染用）；角色已删除/未知 → null（前端兜底 glyph）。
  GroupMember? memberOf(String? characterId) {
    if (characterId == null || characterId.isEmpty) return null;
    for (final m in members) {
      if (m.id == characterId) return m;
    }
    return null;
  }

  /// 兼容两种来源：列表项（GET /ai/groups，只有 member_ids/member_count，无 members/worldbook）
  /// 与详情项（GET /ai/groups/{id}，含完整 members + worldbook）。
  factory GroupChat.fromJson(Map<String, dynamic> json) {
    final worldbookJson = json['worldbook'] as Map<String, dynamic>?;
    final members = [
      for (final m in (json['members'] as List? ?? []))
        GroupMember.fromJson(m as Map<String, dynamic>),
    ];
    return GroupChat(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '群聊',
      members: members,
      memberIds: [
        for (final cid in (json['member_ids'] as List? ?? [])) cid.toString(),
      ],
      memberCount: (json['member_count'] as num?)?.toInt() ?? members.length,
      worldbookId: json['worldbook_id'] as String?,
      worldbook: worldbookJson == null ? null : Worldbook.fromJson(worldbookJson),
      speakerMode: json['speaker_mode'] as String? ?? 'auto',
      replyMode: json['reply_mode'] as String? ?? 'realtime',
      backgroundMediaId: json['background_media_id'] as String?,
      replyCharsRealtime:
          (json['reply_chars_realtime'] as num?)?.toInt() ?? 180,
      replyCharsRoleplay:
          (json['reply_chars_roleplay'] as num?)?.toInt() ?? 1000,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': [for (final m in members) m.toJson()],
        'member_ids': memberIds,
        'member_count': memberCount,
        'worldbook_id': worldbookId,
        'worldbook': worldbook?.toJson(),
        'speaker_mode': speakerMode,
        'reply_mode': replyMode,
        'background_media_id': backgroundMediaId,
        'reply_chars_realtime': replyCharsRealtime,
        'reply_chars_roleplay': replyCharsRoleplay,
        'reply_count': replyCount,
      };
}
