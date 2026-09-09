import 'dart:convert';
import 'dart:typed_data';

/// 消息发送状态（微信式）：发送中 → 已发送 →（失败红!点击重发）
enum AiMsgStatus { sending, sent, failed }

/// 红包领取人（R4）：`{character_id, name, claimed_at}`。
/// character_id 为空 = 用户领取（name='你'）；非空 = 对应 AI 角色领取。
class RedPacketClaimer {
  const RedPacketClaimer({this.characterId, required this.name, this.claimedAt});

  final String? characterId;
  final String name;
  final DateTime? claimedAt;

  factory RedPacketClaimer.fromJson(Map<String, dynamic> json) =>
      RedPacketClaimer(
        characterId: json['character_id'] as String?,
        name: json['name'] as String? ?? '',
        claimedAt: DateTime.tryParse(json['claimed_at'] as String? ?? ''),
      );
}

/// 真实聊天消息（对齐后端 /ai/history 返回）。
/// 取代聊天页私有 `_ChatMsg`：带 kind 区分 text | image | file，媒体消息
/// 关联 media_asset_id/file_name/file_size，据此渲染缩略图 / 文件卡片。
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    this.kind = 'text',
    required this.content,
    this.mediaAssetId,
    this.stickerId,
    this.caption,
    this.fileName,
    this.fileSize,
    required this.createdAt,
    this.audioDuration,
    this.localAudioPath,
    this.previewBytes,
    this.quote,
    this.quoteMessageId,
    this.quoteRole,
    this.senderCharacterId,
    this.amount,
    this.claimed = false,
    this.claimers = const [],
    this.transferAccepted,
    this.status = AiMsgStatus.sent,
  });

  final String id;
  final String role; // user | assistant
  final String kind; // text | image | file | sticker | audio
  final String content;
  final String? mediaAssetId;
  final String? stickerId;
  final String? caption;
  final String? fileName;
  final int? fileSize;
  final DateTime createdAt;

  /// 语音时长（秒，kind=audio）：后端 audio_duration；本地录音回显也用。
  final int? audioDuration;

  /// 本地录音 wav 路径（kind=audio，前端发送中回显用；服务端数据里没有）。
  /// 上传成功写 MediaCache 后气泡改走 mediaAssetId，此字段不再依赖。
  final String? localAudioPath;

  /// 前端本地回显用（发送中：图片以内存字节先渲染），服务端数据里没有。
  final Uint8List? previewBytes;

  /// 引用回复：正文用于气泡显示，来源 id/role 用于服务端校验和 LLM 上下文。
  final String? quote;
  final String? quoteMessageId;
  final String? quoteRole;

  /// 群聊（032）：发言人 character_id；NULL=用户消息（单聊恒 NULL）。
  /// 群消息据此渲染逐发言人头像。
  final String? senderCharacterId;

  /// 红包/转账金额（033，kind=redpacket|transfer）：后端 redpacket_amount，假钱。
  final double? amount;

  /// R4 红包领取：claimed 是否已被领取（AI 收到必回即领取）；claimers 领取人列表
  /// （群红包多人拆；用户领取 name='你'）。
  final bool claimed;
  final List<RedPacketClaimer> claimers;

  /// 转账收/拒（验收批2，kind=transfer）：null=待回应 / true=AI 收下 / false=AI 婉拒。
  final bool? transferAccepted;

  /// 发送状态：乐观回显 sending；发送成功/历史加载 sent；失败 failed（红!重发）。
  final AiMsgStatus status;

  bool get isMe => role == 'user';

  /// 群聊：AI 成员发的消息（senderCharacterId 非空）。用户消息/单聊恒 false。
  bool get isGroupSpeaker =>
      role == 'assistant' && senderCharacterId != null && senderCharacterId!.isNotEmpty;

  /// 发送完成回显替换：本地预览 → 网络图（mediaAssetId 就位、清空 previewBytes）。
  /// 语音：保留 audioDuration，上传后 localAudioPath 不再需要（字节已进 MediaCache）。
  AiMessage withUploaded(String assetId) => AiMessage(
        id: id,
        role: role,
        kind: kind,
        content: content,
        mediaAssetId: assetId,
        stickerId: stickerId,
        caption: caption,
        fileName: fileName,
        fileSize: fileSize,
        createdAt: createdAt,
        audioDuration: audioDuration,
        quote: quote,
        quoteMessageId: quoteMessageId,
        quoteRole: quoteRole,
        senderCharacterId: senderCharacterId,
        amount: amount,
        claimed: claimed,
        claimers: claimers,
        transferAccepted: transferAccepted,
        status: status,
      );

  /// R4：红包被领取后标记（AI 收到红包必回 → 前端置已领取并追加领取人）。
  AiMessage withClaimed({List<RedPacketClaimer>? claimers}) => AiMessage(
        id: id,
        role: role,
        kind: kind,
        content: content,
        mediaAssetId: mediaAssetId,
        stickerId: stickerId,
        caption: caption,
        fileName: fileName,
        fileSize: fileSize,
        createdAt: createdAt,
        audioDuration: audioDuration,
        localAudioPath: localAudioPath,
        previewBytes: previewBytes,
        quote: quote,
        quoteMessageId: quoteMessageId,
        quoteRole: quoteRole,
        senderCharacterId: senderCharacterId,
        amount: amount,
        claimed: true,
        claimers: claimers ?? this.claimers,
        transferAccepted: transferAccepted,
        status: status,
      );

  /// 转账收/拒（验收批2）：AI 回应后决定已知，前端即时翻转气泡状态。
  AiMessage withTransferAccepted(bool? accepted) => AiMessage(
        id: id,
        role: role,
        kind: kind,
        content: content,
        mediaAssetId: mediaAssetId,
        stickerId: stickerId,
        caption: caption,
        fileName: fileName,
        fileSize: fileSize,
        createdAt: createdAt,
        audioDuration: audioDuration,
        localAudioPath: localAudioPath,
        previewBytes: previewBytes,
        quote: quote,
        quoteMessageId: quoteMessageId,
        quoteRole: quoteRole,
        senderCharacterId: senderCharacterId,
        amount: amount,
        claimed: claimed,
        claimers: claimers,
        transferAccepted: accepted,
        status: status,
      );

  /// Drift claimers 列（Text JSON）与内存 List 互转。格式对齐后端
  /// /ai/history 的 redpacket_claimers：`[{character_id,name,claimed_at}]`。
  static List<RedPacketClaimer> claimersFromDb(Object? json) => [
        for (final c in (json as List? ?? const []))
          RedPacketClaimer.fromJson(c as Map<String, dynamic>),
      ];

  static String? claimersToDb(List<RedPacketClaimer> claimers) =>
      claimers.isEmpty
          ? null
          : jsonEncode([
              for (final c in claimers)
                {
                  'character_id': c.characterId,
                  'name': c.name,
                  'claimed_at': c.claimedAt?.toIso8601String(),
                },
            ]);

  /// 仅替换发送状态（sending → sent / failed），其余字段全保留。
  AiMessage withStatus(AiMsgStatus s) => AiMessage(
        id: id,
        role: role,
        kind: kind,
        content: content,
        mediaAssetId: mediaAssetId,
        stickerId: stickerId,
        caption: caption,
        fileName: fileName,
        fileSize: fileSize,
        createdAt: createdAt,
        audioDuration: audioDuration,
        localAudioPath: localAudioPath,
        previewBytes: previewBytes,
        quote: quote,
        quoteMessageId: quoteMessageId,
        quoteRole: quoteRole,
        senderCharacterId: senderCharacterId,
        amount: amount,
        claimed: claimed,
        claimers: claimers,
        transferAccepted: transferAccepted,
        status: s,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'kind': kind,
        'content': content,
        'media_asset_id': mediaAssetId,
        'sticker_id': stickerId,
        'caption': caption,
        'file_name': fileName,
        'file_size': fileSize,
        'audio_duration': audioDuration,
        'local_audio_path': localAudioPath,
        'quote_content': quote,
        'quote_message_id': quoteMessageId,
        'quote_role': quoteRole,
        'sender_character_id': senderCharacterId,
        'redpacket_amount': amount,
        'redpacket_claimed': claimed,
        'redpacket_claimers': [
          for (final c in claimers)
            {
              'character_id': c.characterId,
              'name': c.name,
              'claimed_at': c.claimedAt?.toIso8601String(),
            },
        ],
        'transfer_accepted': transferAccepted,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    return AiMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      kind: json['kind'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      mediaAssetId: json['media_asset_id'] as String?,
      stickerId: json['sticker_id'] as String?,
      caption: json['caption'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      audioDuration: (json['audio_duration'] as num?)?.toInt(),
      localAudioPath: json['local_audio_path'] as String?,
      quote: json['quote_content'] as String?,
      quoteMessageId: json['quote_message_id'] as String?,
      quoteRole: json['quote_role'] as String?,
      senderCharacterId: json['sender_character_id'] as String?,
      amount: (json['redpacket_amount'] as num?)?.toDouble(),
      claimed: json['redpacket_claimed'] as bool? ?? false,
      claimers: [
        for (final c in (json['redpacket_claimers'] as List? ?? const []))
          RedPacketClaimer.fromJson(c as Map<String, dynamic>),
      ],
      transferAccepted: json['transfer_accepted'] as bool?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      status: switch (statusName) {
        'sending' => AiMsgStatus.sending,
        'failed' => AiMsgStatus.failed,
        _ => AiMsgStatus.sent,
      },
    );
  }
}
