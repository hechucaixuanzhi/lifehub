import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// AI 聊天角色（人格层，与后端 character 表对齐）。
/// 数据驱动：会话列表 / 通讯录 / 聊天页 / 记忆页都靠它渲染，加角色零硬编码。
class Character {
  const Character({
    required this.id,
    required this.name,
    this.tagline,
    required this.avatarText,
    required this.avatarColor,
    this.avatarMediaId,
    this.backgroundMediaId,
    this.welcomeMessage,
    this.memoryEnabled = false,
    this.hasNoban = false,
    this.sort = 0,
  });

  final String id; // slug: assistant | companion | ...
  final String name;
  final String? tagline;
  final String avatarText;
  final Color avatarColor;
  // 010：自定义头像/聊天背景图（media_asset.id，NULL=用默认 glyph/灰底）
  final String? avatarMediaId;
  final String? backgroundMediaId;
  final String? welcomeMessage;
  final bool memoryEnabled; // 该角色是否启用记忆注入 + 自动提取
  final bool hasNoban; // 是否支持无违禁模式（爱心 toggle）
  final int sort;

  /// 会话 key（与老版 chat_conv_assistant / chat_conv_companion 完全一致，老会话续上）。
  String get convKey => 'chat_conv_$id';

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String?,
      avatarText: json['avatar_text'] as String? ?? '?',
      avatarColor: parseHexColor(json['avatar_color'] as String?),
      avatarMediaId: json['avatar_media_id'] as String?,
      backgroundMediaId: json['background_media_id'] as String?,
      welcomeMessage: json['welcome_message'] as String?,
      memoryEnabled: json['memory_enabled'] as bool? ?? false,
      hasNoban: json['has_noban'] as bool? ?? false,
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }

  /// 序列化（写本地缓存用；字段与 fromJson 对齐）。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'avatar_text': avatarText,
      'avatar_color': _colorToHex(avatarColor),
      'avatar_media_id': avatarMediaId,
      'background_media_id': backgroundMediaId,
      'welcome_message': welcomeMessage,
      'memory_enabled': memoryEnabled,
      'has_noban': hasNoban,
      'sort': sort,
    };
  }

  /// 复制并替换媒体字段：传非 null 用新值；[clearMedia] 为 true 时两个都显式置
  /// null（恢复默认头像背景）。
  Character copyWith({
    String? avatarMediaId,
    String? backgroundMediaId,
    bool clearMedia = false,
  }) {
    return Character(
      id: id,
      name: name,
      tagline: tagline,
      avatarText: avatarText,
      avatarColor: avatarColor,
      avatarMediaId: clearMedia ? null : (avatarMediaId ?? this.avatarMediaId),
      backgroundMediaId:
          clearMedia ? null : (backgroundMediaId ?? this.backgroundMediaId),
      welcomeMessage: welcomeMessage,
      memoryEnabled: memoryEnabled,
      hasNoban: hasNoban,
      sort: sort,
    );
  }
}

/// Color → `#RRGGBB`（与 parseHexColor 互逆，供 toJson 写缓存）。
String _colorToHex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// `#RRGGBB` → Color；解析失败兜底强调色。
Color parseHexColor(String? hex) {
  if (hex == null) return AppColors.accent;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return AppColors.accent;
  final v = int.tryParse(cleaned, radix: 16);
  if (v == null) return AppColors.accent;
  return Color(0xFF000000 | v);
}

/// 离线兜底角色（后端不可达时仍可进聊天；数据与 character_seeds.py 一致）。
const defaultCharacters = [
  Character(
    id: 'companion',
    name: 'Nova',
    tagline: '示例陪伴角色 · 可自由编辑',
    avatarText: 'N',
    avatarColor: Color(0xFF7C6CF2),
    welcomeMessage: '嗨，我是 Nova。我们从这里慢慢认识吧。',
    memoryEnabled: true,
    hasNoban: true,
    sort: 0,
  ),
  Character(
    id: 'assistant',
    name: 'Lumi',
    tagline: '生活助手 · 本地数据优先',
    avatarText: 'L',
    avatarColor: Color(0xFF4CAF50),
    welcomeMessage: '我是 Lumi。需要整理记录或回顾计划时可以叫我。',
    memoryEnabled: false,
    hasNoban: false,
    sort: 99,
  ),
];
