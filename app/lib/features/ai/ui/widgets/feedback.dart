import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../models/ai_chat_message.dart';

/// 一个可选原因（多选 chip）：code 与后端 FEEDBACK_REASONS 严格对齐（改动需两侧同步）。
class FeedbackReason {
  const FeedbackReason(this.code, this.label);

  final String code;
  final String label;
}

/// 点踩多选原因（与后端 FEEDBACK_REASONS 严格对齐，改动需两侧同步）。
/// 用户定稿：码而非中文串；「其他」改为自由填写 custom_feedback（黄金信息）。
const kFeedbackReasons = [
  FeedbackReason('too_formal', '太官方'),
  FeedbackReason('too_verbose', '太啰嗦'),
  FeedbackReason('too_cold', '太冷淡'),
  FeedbackReason('preachy', '太说教'),
  FeedbackReason('misunderstood', '没理解我'),
  FeedbackReason('out_of_character', '不像这个角色'),
  FeedbackReason('wrong_emotion', '情绪不对'),
];

/// 原因码 → 中文标签；未知（旧数据/未知码）回退原样。
String feedbackReasonLabel(String code) {
  for (final r in kFeedbackReasons) {
    if (r.code == code) return r.label;
  }
  return code;
}

/// 兼容旧数据：037 时代存的是中文串（「说教感」等），读侧归一化为新码，
/// 让「编辑」预选芯片、展示标签都能对上。
String normalizeFeedbackReason(String r) => switch (r) {
      '太官方' => 'too_formal',
      '太啰嗦' => 'too_verbose',
      '太冷淡' => 'too_cold',
      '说教感' || '太说教' => 'preachy',
      '没理解我' => 'misunderstood',
      '不像这个角色' => 'out_of_character',
      '情绪不对' => 'wrong_emotion',
      _ => r,
    };

/// 自动生成候选原因（V3 AI 分析可能覆盖，故称「候选」）。
///
/// 点踩打开面板时预选：由规则按「用户消息 + AI 回复」判定候选原因，
/// 命中 0 条返回空数组（面板不预选，快照照旧落库，V3 深挖）。
///
/// 输入含 user_message —— 只有结合用户语境，「节哀，你要坚强。」这类
/// 短回复才能被识别为说教感（用户评审补充：我妈去世了 → 节哀，你要坚强）。
/// 产出与后端一致的原因码。
List<String> analyzeFeedbackReason(String userMessage, String aiMessage) {
  final reasons = <String>{};
  final aiVisible = aiMessage.replaceAll(RegExp(r'\s+'), '');
  // 用户倾诉 / 难过信号。
  final distress = RegExp(
      r'难过|伤心|去世|死了|失败|分手|离婚|哭|崩溃|难受|绝望|失去|撑不住|好累');
  // 硬说教词：明显说教腔。
  final preachy = RegExp(
      r'你应该|你要|你必须|必须|记住|总之|作为|明白吗|要坚强|要勇敢|振作|别难过|想开点');
  // 软建议词：仅在倾诉语境下才算说教（不含「现在」这类共情句常见词，
  // 避免「我理解你现在很难受」误判）。
  final advice = RegExp(r'建议|不如|试着|先别|先休息|下次|以后|看开|想开|坚强|振作|别难过');
  // 共情词：用于判断「太冷淡」。
  final empathy = RegExp(r'没事|我在|抱抱|理解|心疼|陪你|别怕|怎么|说说|节哀');

  // 太啰嗦：长回复。
  if (aiVisible.length > 250) reasons.add('too_verbose');
  // 太说教：命中硬说教词；或用户在倾诉时仍在给建议（软说教）。
  if (preachy.hasMatch(aiMessage) ||
      (distress.hasMatch(userMessage) && advice.hasMatch(aiMessage))) {
    reasons.add('preachy');
  }
  // 太冷淡：用户倾诉时只回了个极短且无共情的消息。
  if (distress.hasMatch(userMessage) &&
      aiVisible.length < 10 &&
      !empathy.hasMatch(aiMessage)) {
    reasons.add('too_cold');
  }
  return reasons.toList();
}

/// 反馈原因分析用：取 [messages] 中 [target] 之前最近一条用户文字消息正文。
/// 找不到返回空串（规则分析会因此放宽，快照照旧落库）。
String precedingUserMessage(List<AiMessage> messages, AiMessage target) {
  final idx = messages.indexWhere((x) => x.id == target.id);
  if (idx < 0) return '';
  for (var i = idx - 1; i >= 0; i--) {
    final x = messages[i];
    if (x.role == 'user' && x.kind == 'text') return x.content;
  }
  return '';
}

/// 提交一条反馈（037）。后端 message_id 唯一 upsert，改主意覆盖。
/// 返回是否成功；网络/非 200 一律 false，由调用方提示。
Future<bool> submitFeedback(
  ApiClient api, {
  required String characterId,
  required String conversationId,
  required String messageId,
  required String rating,
  List<String> reasons = const [],
  String? preferredReply,
  String customFeedback = '',
}) async {
  try {
    final resp = await api.post('/ai/feedback', {
      'character_id': characterId,
      'conversation_id': conversationId,
      'message_id': messageId,
      'rating': rating,
      'reasons': reasons,
      if (customFeedback.isNotEmpty) 'custom_feedback': customFeedback,
      if (preferredReply != null && preferredReply.isNotEmpty)
        'preferred_reply': preferredReply,
    });
    return resp.statusCode == 200;
  } on Object {
    return false;
  }
}

/// 拉取某角色/会话已提交的反馈（message_id → rating），恢复已评价态
/// （改主意切换/取消入口需要——重进聊天图标仍高亮）。
/// 单聊传 [characterId]；群聊只传 [conversationId]（写入侧已按角色隔离）。
/// 网络/非 200 一律返回空表（失败静默，不阻塞聊天加载）。
Future<Map<String, String>> fetchFeedbackRatings(
  ApiClient api, {
  String? characterId,
  String? conversationId,
}) async {
  try {
    final query = <String>[
      if (characterId != null && characterId.isNotEmpty)
        'character_id=$characterId',
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id=$conversationId',
    ].join('&');
    final resp = await api.get('/ai/feedback?$query');
    if (resp.statusCode != 200) return const {};
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = data['items'];
    if (items is! List) return const {};
    return {
      for (final it in items)
        if (it is Map<String, dynamic>)
          if (it['message_id'] is String && it['rating'] is String)
            it['message_id'] as String: it['rating'] as String,
    };
  } on Object {
    return const {};
  }
}

/// 一条反馈记录（列表页展示 / 改主意重提交用）。
class FeedbackRecord {
  const FeedbackRecord({
    required this.messageId,
    required this.rating,
    required this.conversationId,
    this.userMessage,
    this.aiMessage,
    this.reasons = const [],
    this.customFeedback = '',
    this.createdAt,
  });

  final String messageId;

  /// 'positive' | 'negative'。
  final String rating;
  final String conversationId;
  final String? userMessage;
  final String? aiMessage;

  /// 已归一化为原因码（旧中文串由 fromJson 归一）。
  final List<String> reasons;

  /// 点踩自由填写文本（「其他」的黄金信息）。
  final String customFeedback;
  final DateTime? createdAt;

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) {
    return FeedbackRecord(
      messageId: json['message_id'] as String? ?? '',
      rating: json['rating'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      userMessage: json['user_message'] as String?,
      aiMessage: json['ai_message'] as String?,
      reasons: (json['reasons'] as List? ?? const [])
          .whereType<String>()
          .map(normalizeFeedbackReason)
          .toList(),
      customFeedback: json['custom_feedback'] as String? ?? '',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// 拉取某角色的完整反馈记录（列表页展示/改主意）。失败返回空表。
Future<List<FeedbackRecord>> fetchFeedbackRecords(
  ApiClient api, {
  required String characterId,
}) async {
  try {
    final resp = await api.get('/ai/feedback?character_id=$characterId');
    if (resp.statusCode != 200) return const [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = data['items'];
    if (items is! List) return const [];
    return [
      for (final it in items)
        if (it is Map<String, dynamic>) FeedbackRecord.fromJson(it),
    ];
  } on Object {
    return const [];
  }
}

/// 长按 AI 消息时浮在气泡右侧（白框外）的轻量 👍/👎 小图标。
/// 与长按菜单同框出现/消失（由聊天页把本组件传给菜单的 feedbackEdge 槽位），
/// 点击一步提交、不弹窗（037 交互返工）；[rated] 为内存态高亮（重进由 GET 恢复）。
/// 气泡只有一行时用 [horizontal] 横排贴合高度，多行/媒体竖排。
class BubbleFeedbackRail extends StatelessWidget {
  const BubbleFeedbackRail({
    super.key,
    required this.onLike,
    required this.onDislike,
    this.rated,
    this.horizontal = false,
  });

  final VoidCallback onLike;
  final VoidCallback onDislike;

  /// 'positive' | 'negative' | null（已评价态高亮对应图标）。
  final String? rated;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final like = _RailButton(
      icon: Icons.thumb_up_alt_outlined,
      iconActive: Icons.thumb_up_alt,
      active: rated == 'positive',
      label: '点赞',
      onTap: onLike,
    );
    final dislike = _RailButton(
      icon: Icons.thumb_down_alt_outlined,
      iconActive: Icons.thumb_down_alt,
      active: rated == 'negative',
      label: '点踩',
      onTap: onDislike,
    );
    return horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [like, const SizedBox(width: 6), dislike],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [like, const SizedBox(height: 6), dislike],
          );
  }
}

/// 无圆圈无底色的纯小图标按钮（用户要求：不要白色圆圈图库风格）。
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.iconActive,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconActive;
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            active ? iconActive : icon,
            size: 22,
            color: active ? const Color(0xFF576B95) : const Color(0xFF9A9A9A),
          ),
        ),
      ),
    );
  }
}
