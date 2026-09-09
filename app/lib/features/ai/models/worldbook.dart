/// 世界书（032_group_worldbook）：通讯录「标签」里的独立世界设定实体。
/// 群聊可选引用（GroupChat.worldbookId）；不选 = 现实世界。
/// 与后端 worldbook 表对齐；summary=世界简介，rules=世界规则/社会背景。
class Worldbook {
  const Worldbook({
    required this.id,
    required this.name,
    this.summary = '',
    this.rules = '',
    this.cards = const [],
    this.sort = 0,
  });

  final String id;
  final String name;
  final String summary;
  final String rules;

  /// R6 世界卡（protagonist/supporting/faction/location/plotline）。
  final List<WorldbookCard> cards;
  final int sort;

  factory Worldbook.fromJson(Map<String, dynamic> json) {
    return Worldbook(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      rules: json['rules'] as String? ?? '',
      cards: [
        for (final c in (json['cards'] as List? ?? const []))
          WorldbookCard.fromJson(c as Map<String, dynamic>),
      ],
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'summary': summary,
        'rules': rules,
        'cards': [for (final c in cards) c.toJson()],
        'sort': sort,
      };

  Worldbook copyWith({
    String? name,
    String? summary,
    String? rules,
    List<WorldbookCard>? cards,
    int? sort,
  }) =>
      Worldbook(
        id: id,
        name: name ?? this.name,
        summary: summary ?? this.summary,
        rules: rules ?? this.rules,
        cards: cards ?? this.cards,
        sort: sort ?? this.sort,
      );
}

/// 世界卡（R6）：kind = protagonist（主角）| supporting（配角）| faction（势力）
/// | location（地点）| plotline（情节线）。角色卡转成 Character 后 characterId
/// 回填；前端据此把已入群的角色卡标为「已入群」。
class WorldbookCard {
  const WorldbookCard({
    required this.id,
    required this.kind,
    required this.name,
    this.description = '',
    this.avatarText = '',
    this.avatarColor = '',
    this.characterId,
    this.roleRank,
    this.premise,
    this.progress,
    this.direction,
    this.nodes = const [],
  });

  final String id;
  final String kind;
  final String name;
  final String description;
  final String avatarText;
  final String avatarColor;

  /// 角色卡转成 Character 后回填；null = 尚未转角色。
  final String? characterId;

  /// 角色卡：地位/辈分（如「掌门」）。
  final String? roleRank;

  // 情节线卡字段
  final String? premise;
  final String? progress;
  final String? direction;
  final List<Map<String, dynamic>> nodes;

  bool get isCharacter => kind == 'protagonist' || kind == 'supporting';
  bool get isPlotline => kind == 'plotline';

  factory WorldbookCard.fromJson(Map<String, dynamic> json) => WorldbookCard(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        avatarText: json['avatar_text'] as String? ?? '',
        avatarColor: json['avatar_color'] as String? ?? '',
        characterId: json['character_id'] as String?,
        roleRank: json['role_rank'] as String?,
        premise: json['premise'] as String?,
        progress: json['progress'] as String?,
        direction: json['direction'] as String?,
        nodes: [
          for (final n in (json['nodes'] as List? ?? const []))
            if (n is Map<String, dynamic>) n,
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'name': name,
        'description': description,
        'avatar_text': avatarText,
        'avatar_color': avatarColor,
        'character_id': characterId,
        'role_rank': roleRank,
        'premise': premise,
        'progress': progress,
        'direction': direction,
        'nodes': nodes,
      };

  WorldbookCard copyWith({
    String? kind,
    String? name,
    String? description,
    String? avatarText,
    String? avatarColor,
    String? characterId,
    Object? roleRank = _unset,
    Object? premise = _unset,
    Object? progress = _unset,
    Object? direction = _unset,
    List<Map<String, dynamic>>? nodes,
  }) =>
      WorldbookCard(
        id: id,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        description: description ?? this.description,
        avatarText: avatarText ?? this.avatarText,
        avatarColor: avatarColor ?? this.avatarColor,
        characterId: characterId ?? this.characterId,
        roleRank: roleRank == _unset ? this.roleRank : roleRank as String?,
        premise: premise == _unset ? this.premise : premise as String?,
        progress: progress == _unset ? this.progress : progress as String?,
        direction: direction == _unset ? this.direction : direction as String?,
        nodes: nodes ?? this.nodes,
      );

  static const Object _unset = Object();
}
