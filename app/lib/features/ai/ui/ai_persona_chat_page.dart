import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/widgets/media_bubble.dart';
import '../../../core/widgets/user_avatar.dart';
import '../ai_providers.dart';
import '../models/ai_chat_message.dart';
import '../models/character.dart';
import '../models/sticker.dart';
import '../services/face_identity_service.dart';
import '../services/chat_cache_store.dart';
import '../services/chat_message_session.dart';
import '../services/chat_voice_session.dart';
import '../services/voice_player.dart';
import '../../profile/ui/user_profile_page.dart';
import 'chat_message_utils.dart';
import 'chat_info_page.dart';
import 'profile_page.dart';
import 'widgets/bubble_action_menu.dart';
import 'widgets/chat_emoji_panel.dart';
import 'widgets/chat_more_panel.dart';
import 'widgets/collect_memory_dialog.dart';
import 'widgets/dislike_reason_sheet.dart';
import 'widgets/feedback.dart';
import 'widgets/media_preview_page.dart';
import 'widgets/redpacket_bubble.dart';
import 'widgets/redpacket_input_dialog.dart';
import 'widgets/voice_bubble.dart';
import 'widgets/wechat_bubble.dart';

const _storage = FlutterSecureStorage();

/// 输入栏下方内联面板：无 / 表情 / 加号（键盘协调，微信式）。
enum _Panel { none, emoji, more }

/// AI 聊天页（微信式视觉与交互，数据驱动）：标题、头像、欢迎语和会话 key
/// 全部来自 [Character]，加角色零硬编码。
/// - 气泡：微信气泡（尾巴/状态/引用），每条都显示双方头像；
/// - 长按：文字原地选区，图片/语音/表情使用整条消息菜单；
/// - 输入栏：话筒/输入框/表情/加号 ↔ 发送，表情与加号面板内联弹出，键盘协调；
/// - 发送状态：乐观回显 sending → 成功 sent / 失败 failed（红!点击重发）。
class AiPersonaChatPage extends ConsumerStatefulWidget {
  const AiPersonaChatPage({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<AiPersonaChatPage> createState() => _AiPersonaChatPageState();
}

class _AiPersonaChatPageState extends ConsumerState<AiPersonaChatPage> {
  /// 同发件人相邻消息并入一组的最大间隔（分钟）；也用作时间分隔条阈值。
  static const int _groupThresholdMinutes = 5;

  final _ctrl = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _busy = false;
  bool _noban = false;
  bool _voiceMode = false;
  bool _voiceReplyRequested = false;
  bool _loadingHistory = true;
  bool _hasInput = false; // 输入框是否有文字（加号 ↔ 发送切换）
  String? _conversationId;
  String _replyMode = 'realtime';
  int _realtimeReplyChars = 180;
  int _roleplayReplyChars = 1000;
  int _realtimeReplyCount = 3;
  String? _quoteText;
  String? _quoteMessageId;
  String? _quoteRole;
  final Set<String> _revealedVoiceTranscripts = {};
  final Set<String> _watchedPendingIds = {};

  /// AI 消息反馈态（037）：message_id → 'positive' | 'negative'。驱动气泡右下角小图标。
  final Map<String, String> _messageFeedback = {};
  Timer? _draftTimer; // 草稿防抖保存

  // ---- 输入栏面板与键盘协调（微信式）----
  final FocusNode _inputFocus = FocusNode();
  _Panel _panel = _Panel.none;

  final _messageSession = ChatMessageSession();

  // ---- AI 语音消息（S2）：按住说话真实录音 + 离线 ASR ----
  final _voiceSession = ChatVoiceSession();
  // ---- 自我识别（#133）：图片消息 → 本地检测+embedding → 后端三态 → chat 注入 ----
  FaceIdentityService? _faceIdentity;
  FaceIdentityService get _faceIdentitySvc =>
      _faceIdentity ??= FaceIdentityService(ref.read(apiProvider));
  bool _recording = false;
  bool _cancelArmed = false; // 上滑超过阈值 → 松手取消
  int _recordSecs = 0;
  String? _recordPath;
  Timer? _recordTimer;
  int _pressToken = 0; // 按压令牌：开始录音期间已松手 → 丢弃本次录音（防"没人按还在录"）
  // 长按菜单 OverlayEntry：页面 dispose 时若未关闭会遗留 overlay（验收批3②修复）
  OverlayEntry? _menuEntry;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onDraftChanged);
    _restoreDraft();
    _clearChatFlags();
    _init();
  }

  /// 打开聊天即清除「标为未读 + 不显示该聊天」标记（微信语义）：
  /// 未读徽标消失；被隐藏的聊天从会话列表重新出现（恢复路径）。
  Future<void> _clearChatFlags() async {
    await AppPrefs.setChatUnread(widget.character.id, false);
    await AppPrefs.setChatHidden(widget.character.id, false);
  }

  /// 取当前角色最新数据（换头像/背景后 charactersProvider 已 invalidate）：
  /// 用 live 角色渲染标题头像/气泡头像/背景；兜底构造时的 widget.character。
  Character _liveCharacter() {
    final chars = ref.watch(charactersProvider).valueOrNull;
    if (chars != null) {
      for (final c in chars) {
        if (c.id == widget.character.id) return c;
      }
    }
    return widget.character;
  }

  /// 恢复本角色上次未发送的草稿（微信式：退出聊天后重进仍在）。
  Future<void> _restoreDraft() async {
    final draft = await AppPrefs.chatDraft(widget.character.id);
    if (!mounted || draft.isEmpty) return;
    if (_ctrl.text.isEmpty) {
      _ctrl.text = draft;
      setState(() => _hasInput = true); // 程序赋值不触发 onChanged，需手动同步
    }
  }

  /// 输入变化防抖保存草稿（300ms）；发送时 _ctrl.clear() 会触发本方法清掉草稿。
  void _onDraftChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      AppPrefs.saveChatDraft(widget.character.id, _ctrl.text);
    });
  }

  Future<void> _init() async {
    final results = await Future.wait<Object?>([
      _storage.read(key: widget.character.convKey),
      AppPrefs.chatReplyMode(widget.character.id),
      AppPrefs.isChatNoban(widget.character.id),
      AppPrefs.pendingChatMessage(widget.character.id),
      AppPrefs.chatVoiceReply(widget.character.id),
      AppPrefs.realtimeReplyChars(widget.character.id),
      AppPrefs.roleplayReplyChars(widget.character.id),
      AppPrefs.realtimeReplyCount(widget.character.id),
    ]);
    final id = results[0] as String?;
    final replyMode = results[1] as String;
    final noban = results[2] as bool;
    final pendingRaw = results[3] as String?;
    final voiceReplyRequested = results[4] as bool;
    final realtimeReplyChars = results[5] as int;
    final roleplayReplyChars = results[6] as int;
    final realtimeReplyCount = results[7] as int;
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _replyMode = replyMode;
      _noban = noban;
      _voiceReplyRequested = voiceReplyRequested;
      _realtimeReplyChars = realtimeReplyChars;
      _roleplayReplyChars = roleplayReplyChars;
      _realtimeReplyCount = realtimeReplyCount;
    });
    // 已有会话先恢复本地乐观消息，再拉缓存/网络。这样“发送后立即退出再进入”时，
    // 用户气泡不会等 AI 完成才出现。
    if (id != null && id.isNotEmpty) {
      await _restorePendingMessage(pendingRaw);
      await _loadHistory(id);
      // 037：重进聊天恢复已评价态（改主意切换/取消入口需要）。失败静默。
      await _loadFeedbackRatings(id);
    } else {
      setState(() {
        _loadingHistory = false;
        _messages.add(AiMessage(
          id: '',
          role: 'assistant',
          content: widget.character.welcomeMessage ?? '嗨～你好呀。',
          createdAt: DateTime.now(),
        ));
      });
      await _restorePendingMessage(pendingRaw);
    }
  }

  /// 037：拉取本角色已提交反馈（message_id → rating）并填充 _messageFeedback，
  /// 让长按气泡旁小图标恢复已评价态。失败静默（空表）。
  Future<void> _loadFeedbackRatings(String conversationId) async {
    if (!mounted || conversationId.isEmpty) return;
    final ratings = await fetchFeedbackRatings(
      ref.read(apiProvider),
      characterId: widget.character.id,
      conversationId: conversationId,
    );
    if (!mounted || ratings.isEmpty) return;
    setState(() => _messageFeedback.addAll(ratings));
  }

  Future<void> _restorePendingMessage(String? raw) async {
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final pending = AiMessage.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final alreadyConfirmed = _messages.any(
        (message) =>
            message.id != pending.id &&
            sameRecentOutgoingMessage(message, pending),
      );
      if (alreadyConfirmed) {
        await _deleteOptimisticMessage(pending);
        await _savePendingMessage(null);
        return;
      }
      final existingIndex =
          _messages.indexWhere((message) => message.id == pending.id);
      if (existingIndex < 0) {
        setState(() => _messages.add(pending));
      } else if (_messages[existingIndex].status != pending.status) {
        setState(() => _messages[existingIndex] = pending);
      }
      if (pending.status != AiMsgStatus.failed &&
          _watchedPendingIds.add(pending.id)) {
        unawaited(_watchPendingMessage(pending));
      }
    } on Object {
      await AppPrefs.savePendingChatMessage(widget.character.id, null);
    }
  }

  Future<void> _savePendingMessage(AiMessage? message) async {
    await AppPrefs.savePendingChatMessage(
      widget.character.id,
      message == null ? null : jsonEncode(message.toJson()),
    );
    final conversationId = _conversationId;
    if (message != null &&
        isOptimisticMessage(message) &&
        conversationId != null &&
        conversationId.isNotEmpty &&
        mounted) {
      await _cacheMessages(conversationId, [message]);
    }
  }

  Future<void> _deleteOptimisticMessage(
    AiMessage? message, {
    AppDatabase? database,
    String? conversationId,
  }) async {
    if (message == null || !isOptimisticMessage(message)) return;
    final id = conversationId ?? _conversationId;
    if (id == null || id.isEmpty) return;
    try {
      final AppDatabase target = database ?? ref.read(dbProvider);
      await target.deleteChatMessage(id, message.id);
    } on Object {
      // 下次服务端历史合并时仍会按正文和时间去重，不影响聊天使用。
    }
  }

  Future<bool> _syncPendingFromServer(AiMessage pending) async {
    final conversationId =
        _conversationId ?? await _storage.read(key: widget.character.convKey);
    if (conversationId == null || conversationId.isEmpty || !mounted) {
      return false;
    }
    try {
      final response = await ref
          .read(apiProvider)
          .get('/ai/history?conversation_id=$conversationId')
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || !mounted) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = [
        for (final item in (body['messages'] as List? ?? const []))
          AiMessage.fromJson(item as Map<String, dynamic>),
      ];
      final confirmed = parsed.any(
        (message) => sameRecentOutgoingMessage(message, pending),
      );
      final pendingRaw = await AppPrefs.pendingChatMessage(widget.character.id);
      if (!confirmed && pendingRaw != null) return false;
      await _savePendingMessage(null);
      await _deleteOptimisticMessage(
        pending,
        conversationId: conversationId,
      );
      await _cacheMessages(conversationId, parsed);
      if (!mounted) return true;
      setState(() {
        _conversationId = conversationId;
        _messages
          ..clear()
          ..addAll(parsed);
      });
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _watchPendingMessage(AiMessage pending) async {
    for (final seconds in const [2, 5, 10, 20, 40, 60]) {
      await Future<void>.delayed(Duration(seconds: seconds));
      if (!mounted) return;
      final raw = await AppPrefs.pendingChatMessage(widget.character.id);
      if (raw != null) {
        try {
          final latest =
              AiMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (latest.status == AiMsgStatus.failed) {
            _markStatus(pending.id, AiMsgStatus.failed);
            return;
          }
        } on Object {
          // 交给服务端历史确认恢复。
        }
      }
      if (await _syncPendingFromServer(pending)) return;
    }
    final failed = pending.withStatus(AiMsgStatus.failed);
    await _savePendingMessage(failed);
    if (mounted) _markStatus(pending.id, AiMsgStatus.failed);
  }

  Future<void> _loadHistory(String conversationId) async {
    // 1) 本地缓存秒开（需求2：先渲染本地，不等网络）
    List<ChatMessageRow> cached = const [];
    try {
      cached = await ref.read(dbProvider).getChatMessages(conversationId);
      if (mounted && cached.isNotEmpty) {
        final merged = _messageSession.deduplicateAndSort([
          ..._messages,
          for (final row in cached) messageFromCacheRow(row),
        ]);
        setState(() {
          _messages
            ..clear()
            ..addAll(merged);
          _loadingHistory = false;
        });
      }
    } on Object {
      // 缓存读失败：忽略，走网络
    }
    // 2) 网络拉全量；服务端最后一条与本地一致 → 跳过重建（避免打开聊天时列表在
    //    输入/阅读间隙重建造成卡顿），不一致才替换 + 更新缓存（服务端为权威）。
    //    本地缓存已秒开，把网络请求推迟 400ms 让出进入动画窗口（过渡帧不做网络
    //    decode/build，动画更顺）。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/history?conversation_id=$conversationId')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final serverReplyMode = body['reply_mode'] as String?;
        if (serverReplyMode == 'realtime' || serverReplyMode == 'roleplay') {
          _replyMode = serverReplyMode!;
          unawaited(
              AppPrefs.setChatReplyMode(widget.character.id, serverReplyMode));
        }
        final msgs = (body['messages'] as List?) ?? [];
        final parsed = [
          for (final m in msgs) AiMessage.fromJson(m as Map<String, dynamic>),
        ];
        final cachedLastId = cached.isEmpty ? null : cached.last.id;
        final serverLastId = parsed.isEmpty ? null : parsed.last.id;
        if (!mounted) return;
        if (cachedLastId != null && cachedLastId == serverLastId) {
          // 本地缓存即最新：不重排列表，仅关 loading。
          setState(() => _loadingHistory = false);
        } else {
          final reconciled = _messageSession.mergeServerHistory(
            current: _messages,
            server: parsed,
            sameOutgoing: sameRecentOutgoingMessage,
          );
          setState(() {
            _messages
              ..clear()
              ..addAll(reconciled);
            _loadingHistory = false;
          });
          // 服务端可能因“删除聊天 / 剔除无违禁 / 数据纠偏”少于本地缓存。
          // 先清空再写入权威全量，不能只 upsert，否则已删除消息会在下次冷启动复活。
          await ref.read(dbProvider).deleteChatMessages(conversationId);
          await _cacheMessages(conversationId, parsed);
        }
      }
    } on Object {
      // 离线 / 超时：已有缓存则保留；无缓存+失败 → 欢迎语兜底
      if (mounted) {
        setState(() => _loadingHistory = false);
        if (_messages.isEmpty) {
          _messages.add(AiMessage(
            id: '',
            role: 'assistant',
            content: widget.character.welcomeMessage ?? '嗨～你好呀。',
            createdAt: DateTime.now(),
          ));
        }
      }
    }
  }

  /// 聊天消息写入本地缓存；服务端消息用 UUID，乐观消息用 local-* 临时 id。
  Future<void> _cacheMessages(
    String conversationId,
    List<AiMessage> msgs, {
    AppDatabase? database,
  }) async {
    try {
      final AppDatabase target = database ?? ref.read(dbProvider);
      await ChatCacheStore(target).upsert(conversationId, msgs);
    } on Object {
      // 缓存写失败：静默（在线照常显示）
    }
  }

  /// 发送成功后后台刷新缓存（/ai/chat 不返回消息 id，重拉历史最稳妥）。
  Future<void> _refreshCache() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/history?conversation_id=$conversationId')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msgs = (body['messages'] as List?) ?? [];
        await _cacheMessages(conversationId, [
          for (final m in msgs) AiMessage.fromJson(m as Map<String, dynamic>),
        ]);
      }
    } on Object {
      // 后台刷新失败：静默（下次进聊天再同步）
    }
  }

  // --------------------------------------------------------------------------- #
  // 发送（乐观回显 + 状态机：sending → sent / failed 红!可重发）
  // --------------------------------------------------------------------------- #

  /// 按本地/服务端 id 定位消息并替换状态（其余字段全保留）。
  void _markStatus(String id, AiMsgStatus s) {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    setState(() => _messages[idx] = _messages[idx].withStatus(s));
  }

  /// R4：用户点「开心收下」本地领取（假钱无真实支付；AI 领取由后端必回落库）。
  /// 领取人 character_id=NULL = 用户（name='你'）。
  void _claimLocal(String id) {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final cur = _messages[idx];
    if (cur.claimers.any((c) => c.characterId == null)) return; // 已领取过
    setState(() {
      _messages[idx] = cur.withClaimed(
        claimers: [...cur.claimers, const RedPacketClaimer(name: '你')],
      );
    });
    unawaited(_cacheMessages(
      _conversationId ?? '',
      [_messages[idx]],
    ));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final quote = _quoteText;
    final quoteMessageId = _quoteMessageId;
    final quoteRole = _quoteRole;
    _ctrl.clear();
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
      quote: quote,
      quoteMessageId: quoteMessageId,
      quoteRole: quoteRole,
      status: AiMsgStatus.sent,
    );
    setState(() {
      _quoteText = null;
      _quoteMessageId = null;
      _quoteRole = null;
      _hasInput = false; // 发送后输入框清空，加号变回
      _busy = true;
      _messages.add(msg);
    });
    await _savePendingMessage(msg);
    try {
      await _postChat(pendingMsg: msg, text: text);
      if (mounted) _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache()); // 发送成功后台刷新本地缓存
    } on Object catch (e) {
      debugPrint('[send] failed: $e');
      final failed = msg.withStatus(AiMsgStatus.failed);
      await _savePendingMessage(failed);
      if (mounted) _markStatus(msg.id, AiMsgStatus.failed); // 红!可重发
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 媒体发送：本地回显（图片内存预览 / 文件"发送中"卡片）→ 两步上传 →
  /// POST /ai/chat → 回显补 mediaAssetId → 渲染回复。失败 → 本条红!可重发。
  Future<void> _sendMedia({
    required String kind,
    required Uint8List bytes,
    required String fileName,
    required String mime,
    String? caption,
  }) async {
    if (_busy) return;
    final quote = _quoteText;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: kind,
      content: caption ?? '',
      mediaAssetId: '',
      fileName: fileName,
      fileSize: bytes.length,
      createdAt: DateTime.now(),
      previewBytes: (kind == 'image' || kind == 'sticker') ? bytes : null,
      quote: quote,
      quoteMessageId: _quoteMessageId,
      quoteRole: _quoteRole,
      status: AiMsgStatus.sent,
    );
    setState(() {
      _quoteText = null;
      _quoteMessageId = null;
      _quoteRole = null;
      _busy = true;
      _messages.add(msg);
    });
    await _savePendingMessage(msg);
    try {
      final api = ref.read(apiProvider);
      // 图片消息并行做自我识别（本地检测+embedding+后端三态），不上传时发得慢：
      // 结果无 → 降级普通图片描述；有 → 注入 /ai/chat 让 LLM 用人格认出"自己"。
      final uploadFuture = api.uploadAsset(bytes, fileName, mime);
      final identityFuture = kind == 'image'
          ? _faceIdentitySvc.analyze(bytes)
          : Future<Map<String, dynamic>?>.value(null);
      final mediaId = await uploadFuture;
      final selfIdentity = await identityFuture;
      await _postChat(
          pendingMsg: msg,
          mediaId: mediaId,
          kind: kind,
          fileName: fileName,
          text: caption,
          selfIdentity: selfIdentity);
      if (mounted) _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[sendMedia] failed: $e');
      await _savePendingMessage(msg.withStatus(AiMsgStatus.failed));
      if (mounted) _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 统一 POST /ai/chat：文本/图片/表情/语音共用；成功后回显替换上传 id、追加 AI 回复。
  /// 非 200 → throw（由调用方把本条标 failed；不再插入"连接失败"错误气泡）。
  /// 新后端可返回 replies[]：真实回复按服务端语义分成多条，前端只负责逐条呈现；
  /// 没有 replies 时兼容旧 reply 单条响应。
  Future<void> _postChat({
    AiMessage? pendingMsg,
    String? mediaId,
    String kind = 'text',
    String? stickerId,
    String? fileName,
    String? text,
    int? audioDuration,
    double? redpacketAmount,
    Map<String, dynamic>? selfIdentity,
  }) async {
    final api = ref.read(apiProvider);
    // 页面退出后 ConsumerState.ref 不再可用；提前捕获数据库句柄，响应回来仍可落盘。
    final localDb = ref.read(dbProvider);
    final resp = await api.post('/ai/chat', {
      'message': text ?? '',
      'character_id': widget.character.id,
      'conversation_id': _conversationId,
      if (kind != 'text' && mediaId != null) 'media_asset_id': mediaId,
      if (kind != 'text') 'kind': kind,
      if (kind == 'sticker' && stickerId != null) 'sticker_id': stickerId,
      if (kind == 'audio') 'audio_duration': audioDuration,
      if (redpacketAmount != null) 'redpacket_amount': redpacketAmount,
      'reply_mode': _replyMode,
      'reply_max_chars':
          _replyMode == 'roleplay' ? _roleplayReplyChars : _realtimeReplyChars,
      if (_replyMode == 'realtime') 'reply_bubble_count': _realtimeReplyCount,
      if (pendingMsg?.quote != null && pendingMsg!.quote!.isNotEmpty)
        'quote': {
          'message_id': pendingMsg.quoteMessageId,
          'role': pendingMsg.quoteRole,
          'content': pendingMsg.quote,
        },
      // 自我识别（017）：图片消息携带三态结果，后端并入 user 消息上下文
      if (selfIdentity != null) 'self_identity': selfIdentity,
      'noban': _noban,
      // 输入框小话筒只控制文字消息；发送语音时后端始终语音回复。
      'force_voice_reply': _voiceReplyRequested,
    })
        // quick tunnel 偶发失联时不能让发送状态永久卡住；失败保留红叹号，
        // 用户可在链路恢复后手动重发，避免自动重试造成重复消息。
        // 字数或气泡不足时后端会自动完整重写一次；给两轮模型调用留出余量。
        // 用户消息已先本地持久化，等待期间退出/重进也不会丢失。
        .timeout(const Duration(seconds: 180));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_errorText(resp.statusCode, body));
    }
    final reply = body['reply'] as String? ?? '';
    final aiStickerId = body['sticker_id'] as String?;
    // AI 语音回复（S1）：语音聊天 → 回复带 audio_media_id + audio_duration
    final aiAudioId = body['audio_media_id'] as String?;
    final aiAudioDur = (body['audio_duration'] as num?)?.toInt();
    final responseMode = body['reply_mode'] as String?;
    if (responseMode == 'realtime' || responseMode == 'roleplay') {
      _replyMode = responseMode!;
      unawaited(AppPrefs.setChatReplyMode(widget.character.id, responseMode));
    }
    final replyItems = (body['replies'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['content'] as String? ?? '').isNotEmpty)
        .toList();
    final rawUserMessage = body['user_message'];
    final confirmedUser = rawUserMessage is Map
        ? AiMessage.fromJson(Map<String, dynamic>.from(rawUserMessage))
        : null;
    final newConvId = body['conversation_id'] as String?;
    if (newConvId != null) {
      _conversationId = newConvId;
      await _storage.write(key: widget.character.convKey, value: newConvId);
    }
    final assistantMessages = <AiMessage>[];
    if (replyItems.isNotEmpty) {
      for (final item in replyItems) {
        assistantMessages.add(AiMessage.fromJson({
          ...item,
          'role': 'assistant',
        }));
      }
    } else if (aiStickerId != null || aiAudioId != null) {
      assistantMessages.add(AiMessage(
        id: replyItems.isEmpty
            ? _messageSession.nextLocalId()
            : (replyItems.first['id'] as String? ??
                _messageSession.nextLocalId()),
        role: 'assistant',
        kind: aiStickerId != null ? 'sticker' : 'audio',
        content: reply,
        stickerId: aiStickerId,
        mediaAssetId: aiAudioId,
        audioDuration: aiAudioDur,
        createdAt: DateTime.now(),
      ));
    } else {
      final textReplies = reply.isEmpty
          ? <Map<String, dynamic>>[]
          : [
              <String, dynamic>{
                'id': _messageSession.nextLocalId(),
                'content': reply
              }
            ];
      for (final item in textReplies) {
        assistantMessages.add(AiMessage(
          id: item['id'] as String? ?? _messageSession.nextLocalId(),
          role: 'assistant',
          content: item['content'] as String? ?? '',
          createdAt: DateTime.tryParse(
                item['created_at'] as String? ?? '',
              ) ??
              DateTime.now(),
        ));
      }
    }
    final confirmedForCache = <AiMessage>[
      if (confirmedUser != null) confirmedUser,
      ...assistantMessages,
    ];
    final confirmedConversationId = newConvId ?? _conversationId;
    if (confirmedConversationId != null &&
        confirmedConversationId.isNotEmpty &&
        confirmedForCache.isNotEmpty) {
      await _cacheMessages(
        confirmedConversationId,
        confirmedForCache,
        database: localDb,
      );
      await _deleteOptimisticMessage(
        pendingMsg,
        database: localDb,
        conversationId: confirmedConversationId,
      );
    }
    await _savePendingMessage(null);
    if (!mounted) return;
    setState(() {
      // 按本地占位 id 定位，替换成服务端确认的真实用户消息。
      final pendingId = pendingMsg?.id;
      if (confirmedUser != null && pendingId != null) {
        final idx = _messages.indexWhere((x) => x.id == pendingId);
        if (idx >= 0) _messages[idx] = confirmedUser;
      } else if (kind != 'text' && mediaId != null && pendingId != null) {
        final idx = _messages.indexWhere((x) => x.id == pendingId);
        if (idx >= 0 &&
            _messages[idx].kind == kind &&
            (_messages[idx].mediaAssetId == null ||
                _messages[idx].mediaAssetId!.isEmpty)) {
          _messages[idx] = _messages[idx].withUploaded(mediaId);
        }
      }
    });
    for (var index = 0; index < assistantMessages.length; index++) {
      if (index > 0) {
        final previous = assistantMessages[index - 1].content;
        final delayMs = (420 + previous.runes.length * 18).clamp(500, 1300);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        if (!mounted) return;
      }
      setState(() => _messages.add(assistantMessages[index]));
    }
    // R4：红包/转账 → AI 必回并领取，发送方消息本地标记已领取 + 领取人。
    // （后端 /ai/chat 响应在领取落库前构建，claimed 恒 false；权威数据
    //  由 /ai/history 重进时刷新。）
    if (kind == 'redpacket' || kind == 'transfer') {
      final claimer = RedPacketClaimer(
        characterId: widget.character.id,
        name: widget.character.name,
      );
      setState(() {
        final pendingId = pendingMsg?.id;
        final idx = pendingId == null
            ? -1
            : _messages.indexWhere((x) => x.id == pendingId);
        if (idx >= 0) {
          final cur = _messages[idx];
          if (!cur.claimers.any((c) => c.name == claimer.name)) {
            _messages[idx] =
                cur.withClaimed(claimers: [...cur.claimers, claimer]);
          }
        }
      });
      final markIdx = pendingMsg?.id == null
          ? -1
          : _messages.indexWhere((x) => x.id == pendingMsg!.id);
      if (markIdx >= 0) {
        unawaited(_cacheMessages(
          confirmedConversationId ?? '',
          [_messages[markIdx]],
          database: localDb,
        ));
      }
    }
    // 发送成功 → 写穿会话预览（微信首页「最新会话」立即更新，不等网络刷新）。
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      ref.read(conversationsProvider.notifier).applyLocal(
            widget.character.id,
            ConversationPreview(
              characterId: widget.character.id,
              lastContent: chatMessageDisplayText(last),
              lastKind: last.kind,
              lastAt: last.createdAt,
            ),
          );
    }
  }

  String _errorText(int status, Map body) {
    if (status == 503) return 'AI 离线（家庭服务器未连接）';
    final err = body['error'];
    if (err is Map && err['message'] is String) return err['message'] as String;
    return '请求失败 ($status)';
  }

  /// 失败消息点击红!重发：按消息类型补全载荷（本地字节/语音文件还在则可重发）。
  Future<void> _retryMessage(AiMessage m) async {
    if (_busy) return;
    final optimistic = m.withStatus(AiMsgStatus.sent);
    _markStatus(m.id, AiMsgStatus.sent);
    await _savePendingMessage(optimistic);
    try {
      switch (m.kind) {
        case 'audio':
          await _retryAudio(m);
        case 'image':
        case 'sticker':
          await _retryMedia(m);
        case 'redpacket':
        case 'transfer':
          await _postChat(
              pendingMsg: m,
              kind: m.kind,
              text: m.content,
              redpacketAmount: m.amount);
        default:
          await _postChat(pendingMsg: m, text: m.content);
      }
      _markStatus(m.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[retry] failed: $e');
      await _savePendingMessage(m.withStatus(AiMsgStatus.failed));
      if (mounted) {
        _markStatus(m.id, AiMsgStatus.failed);
        _snack('重发失败：$e');
      }
    }
  }

  /// 语音重发：本地 wav 未清理 → 重传 + 重发；已清理无法重发。
  Future<void> _retryAudio(AiMessage m) async {
    final path = m.localAudioPath;
    if (path == null || path.isEmpty) {
      if (mounted) _snack('原语音文件已清理，无法重发');
      throw Exception('audio file gone');
    }
    final api = ref.read(apiProvider);
    final bytes = await File(path).readAsBytes();
    final mediaId = await api.uploadAsset(bytes, 'voice.wav', 'audio/wav');
    try {
      await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
            mediaId: mediaId,
            bytes: bytes,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
    } on Object {
      // 缓存失败不影响发送
    }
    await _postChat(
        pendingMsg: m,
        mediaId: mediaId,
        kind: 'audio',
        text: m.content,
        audioDuration: m.audioDuration);
    // 重发成功清理本地文件（字节已在 MediaCache）
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 图片/表情重发：网络 id / 内置表情 / 内存预览字节（三选一，有则可重发）。
  Future<void> _retryMedia(AiMessage m) async {
    final api = ref.read(apiProvider);
    if (m.mediaAssetId != null && m.mediaAssetId!.isNotEmpty) {
      await _postChat(
          pendingMsg: m,
          mediaId: m.mediaAssetId,
          kind: m.kind,
          stickerId: m.stickerId,
          fileName: m.fileName,
          text: m.content);
      return;
    }
    if (m.kind == 'sticker' && m.stickerId != null && m.stickerId!.isNotEmpty) {
      await _postChat(pendingMsg: m, kind: 'sticker', stickerId: m.stickerId);
      return;
    }
    if (m.previewBytes != null) {
      final name = m.fileName ?? 'image.jpg';
      final mediaId =
          await api.uploadAsset(m.previewBytes!, name, imageMimeFor(name));
      await _postChat(
          pendingMsg: m,
          kind: m.kind,
          mediaId: mediaId,
          fileName: m.fileName,
          text: m.content);
      return;
    }
    if (mounted) _snack('原文件已清理，无法重发');
    throw Exception('media gone');
  }

  // --------------------------------------------------------------------------- #
  // 相册 / 拍摄 / 文件
  // --------------------------------------------------------------------------- #

  /// 相册/拍摄选图 → 预览-发送页（可加文字，仿微信）。
  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final tc = TransformationController();
    final pending = await Navigator.of(context).push<PendingMedia>(
      AppPageRoute(
        builder: (_) => MediaPreviewPage(
          bytes: bytes,
          fileName: picked.name,
          mime: imageMimeFor(picked.name),
          controller: tc,
        ),
        // 未放大可右滑返回；放大后让给 InteractiveViewer（微信同款）
        swipeBackGate: () => tc.value.getMaxScaleOnAxis() <= 1.02,
      ),
    );
    if (pending == null || !mounted) return;
    await _sendMedia(
      kind: pending.asSticker ? 'sticker' : 'image',
      bytes: Uint8List.fromList(pending.bytes),
      fileName: pending.fileName,
      mime: pending.mime,
      caption: pending.caption,
    );
  }

  /// 内置表情包发送（009）：乐观插入本地素材气泡 → POST /ai/chat → 追加 AI 回复。
  Future<void> _sendStickerBundled(Sticker s) async {
    if (_busy) return;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: 'sticker',
      content: '',
      stickerId: s.id,
      createdAt: DateTime.now(),
      quote: _quoteText,
      quoteMessageId: _quoteMessageId,
      quoteRole: _quoteRole,
      status: AiMsgStatus.sent,
    );
    setState(() {
      _quoteText = null;
      _quoteMessageId = null;
      _quoteRole = null;
      _busy = true;
      _messages.add(msg);
    });
    await _savePendingMessage(msg);
    try {
      await _postChat(pendingMsg: msg, kind: 'sticker', stickerId: s.id);
      _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[sticker] failed: $e');
      await _savePendingMessage(msg.withStatus(AiMsgStatus.failed));
      if (mounted) _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 长按「按住说话」开始真实录音（wav 落 chat_audio/，60s 上限自动发）。
  Future<void> _startRecording() async {
    if (_recording) return;
    final ok = await _voiceSession.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      showAppToast(context, '需要麦克风权限才能发语音');
      return;
    }
    final token = ++_pressToken; // 本次按压令牌
    try {
      final path = await _voiceSession.start();
      if (!mounted) return;
      // 开始录音期间用户已松手（结束回调抢先触发）→ 丢弃本次录音
      if (token != _pressToken) {
        await _voiceSession.cancel(path: path);
        return;
      }
      setState(() {
        _recording = true;
        _cancelArmed = false;
        _recordSecs = 0;
        _recordPath = path;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSecs++);
        if (_recordSecs >= 60) _finishRecording(); // 60s 上限：自动松手发送
      });
    } on Object catch (e) {
      if (mounted) showAppToast(context, '录音启动失败：$e');
    }
  }

  /// 松手/取消：停止录音 → 上滑取消删除文件，否则 ASR + 发送。
  Future<void> _finishRecording() async {
    if (!_recording) return;
    // 验收批3②：可能由 60s 定时器触发，页面已 dispose 时 setState 会抛异常。
    if (!mounted) return;
    _pressToken++; // 使正在 start 中的按压令牌失效（松手先于录音就绪）
    _recordTimer?.cancel();
    _recordTimer = null;
    final path = _recordPath;
    final secs = _recordSecs;
    final cancel = _cancelArmed;
    setState(() {
      _recording = false;
      _cancelArmed = false;
      _recordSecs = 0;
      _recordPath = null;
    });
    if (path == null || path.isEmpty) return;
    if (cancel || secs < 1) {
      // 上滑取消 / 过短（<1s 视为误触）：丢弃录音，不发
      await _voiceSession.cancel(path: path);
      return;
    }
    try {
      await _voiceSession.stop();
    } on Object catch (e) {
      if (mounted) showAppToast(context, '录音结束失败：$e');
      return;
    }
    if (!mounted) return;
    await _finalizeVoice(path, secs);
  }

  /// 进入语音模式即后台预下载 ASR 模型（首次，hf-mirror ~65MB）：
  /// 与用户按住录音的时间重叠，尽量让首条语音发出前模型已就绪。
  Future<void> _preloadAsr() async {
    try {
      if (await _voiceSession.isAsrReady()) return;
      if (mounted) showAppToast(context, '首次使用：正在下载语音识别模型（后台）…');
      await _voiceSession.ensureAsrModel();
      if (mounted) showAppToast(context, '语音识别模型就绪 ✓');
    } on Object catch (e) {
      // 预载失败不打断：用户真正发语音时 _finalizeVoice 里再试一次
      debugPrint('[voice] ASR 预载失败（发送时重试）: $e');
    }
  }

  /// 语音发送全流程：离线 ASR（转写失败留空仍发）→ 乐观语音气泡（本地可播）
  /// → 上传 wav → 写 MediaCache（重进历史秒播）→ POST /ai/chat → 清理本地文件。
  /// 失败 → 本条标 failed（本地文件保留，红!可重发）。
  Future<void> _finalizeVoice(String path, int secs) async {
    // 1) 离线 ASR：模型首次需下载；识别失败不影响发语音（转写留空）
    String transcript = '';
    try {
      if (!await _voiceSession.isAsrReady() && mounted) {
        showAppToast(context, '首次使用：正在下载语音识别模型…');
      }
      await _voiceSession.ensureAsrModel();
      transcript = await _voiceSession.transcribe(path);
    } on Object catch (e) {
      debugPrint('[voice] ASR failed: $e');
    }
    if (!mounted) return;
    // 2) 乐观语音气泡（本地路径 → 即播；转写在气泡下方）
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: 'audio',
      content: transcript,
      mediaAssetId: '',
      localAudioPath: path,
      audioDuration: secs,
      createdAt: DateTime.now(),
      status: AiMsgStatus.sent,
    );
    setState(() {
      _messages.add(msg);
      _busy = true;
    });
    await _savePendingMessage(msg);
    // 3) 上传 + 发消息 + 缓存（期间 _busy 顶栏显示「对方正在输入...」）
    try {
      final api = ref.read(apiProvider);
      final bytes = await File(path).readAsBytes();
      final mediaId = await api.uploadAsset(bytes, 'voice.wav', 'audio/wav');
      // 写 MediaCache：气泡改走 mediaAssetId，重进历史也秒播（不重复下载）
      try {
        await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
              mediaId: mediaId,
              bytes: bytes,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
      } on Object {
        // 缓存失败：在线照常（下次播放走网络下载）
      }
      await _postChat(
        pendingMsg: msg,
        mediaId: mediaId,
        kind: 'audio',
        text: transcript,
        audioDuration: secs,
      );
      _markStatus(msg.id, AiMsgStatus.sent);
      // 4) 上传成功清理本地录音（字节已在 MediaCache）
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[voice] send failed: $e');
      // 失败：保留本条 + 本地文件 → 红!可重发（不再插入错误气泡）
      await _savePendingMessage(msg.withStatus(AiMsgStatus.failed));
      if (mounted) _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------------------------- #
  // 输入栏 + 内联面板（微信式键盘协调）
  // --------------------------------------------------------------------------- #

  void _insertEmoji(String e) {
    _ctrl.text += e;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  /// 删除最后一个字素簇（代理对/组合字符一次删一个）。
  void _deleteLastEmoji() {
    final t = _ctrl.text;
    if (t.isEmpty) return;
    final runes = t.runes.toList();
    _ctrl.text = String.fromCharCodes(runes.sublist(0, runes.length - 1));
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  /// 表情按钮：开/关表情面板。开 → 收键盘；关 → 回键盘（微信：图标在键盘与表情间切换）。
  void _toggleEmojiPanel() {
    if (_panel == _Panel.emoji) {
      _inputFocus.requestFocus();
      setState(() {
        _voiceMode = false;
        _panel = _Panel.none;
      });
    } else {
      _inputFocus.unfocus();
      setState(() {
        _voiceMode = false;
        _panel = _Panel.emoji;
      });
    }
  }

  /// 加号按钮：开/关加号面板。开 → 收键盘；关 → 回键盘。
  void _toggleMorePanel() {
    if (_panel == _Panel.more) {
      _inputFocus.requestFocus();
      setState(() {
        _voiceMode = false;
        _panel = _Panel.none;
      });
    } else {
      _inputFocus.unfocus();
      setState(() {
        _voiceMode = false;
        _panel = _Panel.more;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = _liveCharacter();
    final title = character.name;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      // 微信聊天顶栏：不放角色头像和 LifeHub 额外按钮。
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDEDED),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        titleSpacing: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDADADA), width: .5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _busy ? '对方正在输入...' : title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111111),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 29),
            tooltip: '更多',
            onPressed: () => _showMore(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // 自定义聊天背景（010）：有 background_media_id → 底层铺图，消息层透明；
            // 否则浅灰底 + 45° 极淡斜线纹理（CharacterChatBackground 兜底）。
            child: Stack(
              fit: StackFit.expand,
              children: [
                CharacterChatBackground(character: character),
                Container(
                  // 无背景图时消息层透明 → 露出灰底；加载历史时显示 loading
                  child: _loadingHistory
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : // 验收批3②：气泡内 TextSelectionTheme 上提到列表外层——每页仅一个
                      // InheritedWidget，消除带选中 dependent 的 InheritedElement 被逐个
                      // deactivate 引发的 _dependents.isEmpty 断言（拆解面 N→1）。
                      // 只包消息列表子树，不影响输入框等其它文本选中。
                      TextSelectionTheme(
                          data: const TextSelectionThemeData(
                            selectionColor: Color(0x664CD6A0),
                            selectionHandleColor: Color(0xFF07C160),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                            // reverse：微信式——最新在底部，打开即见最新消息；
                            // 存储仍最旧→最新，_buildRow 按原始索引处理分隔条天然正确。
                            reverse: true,
                            itemCount: _messages.length,
                            itemBuilder: (_, r) =>
                                _buildRow(_messages.length - 1 - r, character),
                          ),
                        ),
                ),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildRow(int i, Character character) {
    final m = _messages[i];
    final prev = i > 0 ? _messages[i - 1] : null;
    final gapMinutes =
        i == 0 ? 0 : m.createdAt.difference(prev!.createdAt).inMinutes;
    // 时间分隔条：首条 / 间隔超阈值 / 跨天（与发件人切换无关，微信行为）。
    final showSep = i == 0 ||
        gapMinutes > _groupThresholdMinutes ||
        !isSameCalendarDay(prev!.createdAt, m.createdAt);
    final avatarWidget = m.isMe
        ? null
        : Semantics(
            button: true,
            label: '查看${character.name}的个人信息',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                AppPageRoute(builder: (_) => ProfilePage(character: character)),
              ),
              child: CharacterAvatar(
                character: character,
                size: 40,
                radius: 5,
              ),
            ),
          );
    // 红包/转账卡片自带背景，无需气泡底（与图片/表情一致）。
    final isBareMedia = ((m.kind == 'image' ||
                m.kind == 'sticker' ||
                m.kind == 'redpacket' ||
                m.kind == 'transfer') &&
            (m.quote == null || m.quote!.isEmpty) &&
            m.content.trim().isEmpty) ||
        m.kind == 'redpacket' ||
        m.kind == 'transfer';

    final bubble = WeChatBubble(
      isMe: m.isMe,
      avatar: avatarWidget,
      meAvatar: m.isMe
          ? Semantics(
              button: true,
              label: '查看我的个人信息',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => const UserProfilePage()),
                ),
                child: const UserAvatar(size: 40, radius: 5),
              ),
            )
          : null,
      // 文字由 SelectableText 接管长按：原地选字 + 微信菜单。
      onLongPress: m.kind == 'text' ? null : (rect) => _showBubbleMenu(rect, m),
      quote: m.quote,
      status: m.status,
      onRetry: m.isMe && m.status == AiMsgStatus.failed
          ? () => _retryMessage(m)
          : null,
      padding: _bubblePadding(m.kind),
      child: _bubbleChild(m),
      transparent: isBareMedia,
    );
    return Column(
      children: [
        if (showSep)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFB2B2B2).withValues(alpha: .72),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                chatTimeLabel(m.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        bubble,
      ],
    );
  }

  /// 各消息类型的气泡内边距：文本 12/8（微信），媒体 3（紧贴）；
  /// 语音组件自己控制 44px 高度与左右留白，外层不再重复加边距。
  EdgeInsets _bubblePadding(String kind) => switch (kind) {
        'image' ||
        'sticker' =>
          const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        'audio' || 'redpacket' || 'transfer' => EdgeInsets.zero,
        _ => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      };

  /// 气泡内容：图片（缩略图+可选文字）/ 表情 / 语音 / 文本。
  Widget _bubbleChild(AiMessage m) => switch (m.kind) {
        'image' => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaImageView(
                mediaAssetId: m.mediaAssetId ?? '',
                previewBytes: m.previewBytes,
              ),
              if (m.content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
                  child: Text(m.content, style: AppTypography.body),
                ),
            ],
          ),
        // 表情包（009）：内置（sticker_id→本地素材）或相册（media_asset_id→网络图）。
        // 气泡下不显示 MiMo 描述（微信表情样式，caption 只服务 AI 上下文/历史）。
        'sticker' => _StickerAsset(
            stickerId: m.stickerId,
            mediaAssetId: m.mediaAssetId,
            previewBytes: m.previewBytes,
          ),
        // AI 语音消息（S2）：微信式语音气泡（宽度∝时长，可播，下方显示转写）。
        // 我的语音发送中用 localAudioPath 即播；已上传/AI 语音走 mediaAssetId。
        'audio' => VoiceBubble(
            audioId: (m.mediaAssetId == null || m.mediaAssetId!.isEmpty)
                ? 'local-${m.id}'
                : m.mediaAssetId!,
            localPath: m.localAudioPath,
            mediaAssetId: m.mediaAssetId,
            durationSeconds: m.audioDuration,
            transcript: m.content,
            showTranscript: _revealedVoiceTranscripts.contains(m.id),
            isMe: m.isMe,
          ),
        // 红包/转账（033+R4）：微信样式卡片，点开弹领取状态/金额（无真实支付）。
        'redpacket' || 'transfer' => RedPacketBubble(
            message: m,
            onClaim: () => _claimLocal(m.id),
          ),
        // 历史 file 消息（已砍文件传输助手后不再新建）以文本兜底展示
        _ => WeChatText(
            m.content,
            contextMenuBuilder: (context, editableTextState) =>
                _buildTextContextMenu(editableTextState, m),
          ),
      };

  Widget _buildTextContextMenu(
      EditableTextState editableTextState, AiMessage message) {
    ContextMenuButtonItem? nativeCopy;
    for (final item in editableTextState.contextMenuButtonItems) {
      if (item.type == ContextMenuButtonType.copy) {
        nativeCopy = item;
        break;
      }
    }
    final bubbleRect = _textBubbleRect(editableTextState);
    return WeChatSelectionMenu(
      anchors: editableTextState.contextMenuAnchors,
      items: _messageActionItems(
        includeCopy: true,
        messageKind: message.kind,
      ),
      bubbleRect: bubbleRect,
      feedbackEdge: _feedbackRailFor(message, bubbleRect: bubbleRect),
      onSelect: (id) {
        if (id == 'copy' && nativeCopy?.onPressed != null) {
          nativeCopy!.onPressed!();
          return;
        }
        final value = editableTextState.textEditingValue;
        final selectedText = value.selection.isCollapsed
            ? null
            : value.selection.textInside(value.text).trim();
        // 两行菜单超出 EditableText 自身区域，直接移除全局上下文菜单，
        // 确保第二行「引用」收到点击后不会被旧 overlay 吞掉。
        ContextMenuController.removeAny();
        unawaited(_onBubbleAction(
          id,
          message,
          selectedText: selectedText,
        ));
      },
    );
  }

  /// 长按入口：AI 消息才显示轻量 👍/👎（浮在气泡右侧白框外，不进操作菜单）。
  /// 改主意：点另一个=切换，点同一个=取消该条反馈（后端 rating=none 删行）。
  /// 一行气泡（rect 矮）横排贴合高度，多行/媒体竖排。
  /// 👍 一步提交；👎 未评 negative → 打开原因多选面板（预选规则候选）提交。
  Widget? _feedbackRailFor(AiMessage m, {Rect? bubbleRect}) {
    if (m.isMe) return null;
    final compact = bubbleRect != null && bubbleRect.height < 64;
    void submit(String rating) {
      _removeBubbleMenu();
      ContextMenuController.removeAny();
      unawaited(_sendFeedback(m, rating));
    }

    void like() =>
        submit(_messageFeedback[m.id] == 'positive' ? 'none' : 'positive');
    Future<void> dislike() async {
      if (_messageFeedback[m.id] == 'negative') {
        submit('none');
        return;
      }
      _removeBubbleMenu();
      ContextMenuController.removeAny();
      final result = await showAppModalSheet<DislikeResult>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => DislikeReasonSheet(
          initialReasons: analyzeFeedbackReason(
              precedingUserMessage(_messages, m), m.content),
        ),
      );
      if (result == null || !mounted) return;
      unawaited(_sendFeedback(m, 'negative',
          reasons: result.reasons, customFeedback: result.customFeedback));
    }

    return BubbleFeedbackRail(
      rated: _messageFeedback[m.id],
      horizontal: compact,
      onLike: like,
      onDislike: dislike,
    );
  }

  /// 文字气泡全局矩形：EditableText 只覆盖文本区，按文字气泡内边距（12/8，
  /// 见 [_bubblePadding]）外扩得到白框，供白框外的 👍/👎 锚定。
  Rect? _textBubbleRect(EditableTextState editableTextState) {
    final box = editableTextState.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final r = box.localToGlobal(Offset.zero) & box.size;
    return Rect.fromLTRB(r.left - 12, r.top - 8, r.right + 12, r.bottom + 8);
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 引用回复条
                  if (_quoteText != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('引用：$_quoteText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFF555555))),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _quoteText = null;
                              _quoteMessageId = null;
                              _quoteRole = null;
                            }),
                            child: const Icon(Icons.close,
                                size: 16, color: Color(0xFF999999)),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // 话筒：切换「按住说话」↔ 文字输入（微信图标：浅灰圆钮）
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          onPressed: () {
                            final enteringVoice = !_voiceMode;
                            setState(() {
                              _voiceMode = enteringVoice;
                              if (enteringVoice) _panel = _Panel.none;
                            });
                            if (enteringVoice) {
                              _inputFocus.unfocus();
                              unawaited(_preloadAsr());
                            }
                          },
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _voiceMode
                                ? Icons.keyboard_outlined
                                : Icons.mic_none,
                            color: const Color(0xFF333333),
                            size: 25,
                          ),
                          tooltip: '语音消息',
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 输入框：微信白底圆角；点按聚焦时收起表情/加号面板
                      Expanded(
                        child: _voiceMode
                            ? _buildHoldTalk()
                            : TextField(
                                controller: _ctrl,
                                focusNode: _inputFocus,
                                // 输入框多行：长文本自动换行撑高（微信行为），上限 4 行
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onTap: () =>
                                    setState(() => _panel = _Panel.none),
                                onChanged: (v) {
                                  final has = v.trim().isNotEmpty;
                                  if (has != _hasInput) {
                                    setState(() => _hasInput = has);
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 38,
                                    minHeight: 34,
                                  ),
                                  suffixIcon: Semantics(
                                    button: true,
                                    selected: _voiceReplyRequested,
                                    label: _voiceReplyRequested
                                        ? '已要求对方语音回复'
                                        : '要求对方语音回复',
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      tooltip: _voiceReplyRequested
                                          ? '语音回复：开'
                                          : '语音回复：关',
                                      onPressed: () {
                                        final next = !_voiceReplyRequested;
                                        setState(
                                            () => _voiceReplyRequested = next);
                                        unawaited(
                                          AppPrefs.setChatVoiceReply(
                                            widget.character.id,
                                            next,
                                          ),
                                        );
                                      },
                                      icon: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: _voiceReplyRequested
                                              ? const Color(0x1F07C160)
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.mic_none_rounded,
                                          size: 21,
                                          color: _voiceReplyRequested
                                              ? const Color(0xFF07C160)
                                              : const Color(0xFF9A9A9A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                      ),
                      const SizedBox(width: 4),
                      // 表情：笑脸（开/关表情面板）
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          onPressed: _toggleEmojiPanel,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.emoji_emotions_outlined,
                              color: Color(0xFF111111), size: 28),
                          tooltip: '表情',
                        ),
                      ),
                      // 右侧：输入框有字 → 发送按钮；否则加号（微信行为）
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: _hasInput
                            ? TextButton(
                                onPressed: _busy ? null : _send,
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFC8E6C9),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(40, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text('发送',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              )
                            : IconButton(
                                onPressed: _toggleMorePanel,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Color(0xFF111111), size: 28),
                                tooltip: '更多功能',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 表情 / 加号 内联面板（AnimatedSize 平滑弹出）
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (_panel) {
                _Panel.emoji => _buildEmojiPanel(),
                _Panel.more => _buildMorePanel(),
                _Panel.none => const SizedBox(width: double.infinity),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 按住说话（微信式）：长按开始录音，上滑 >60px 进入取消区（松手取消），
  /// 60s 上限自动发送；实时显示已录秒数。
  Widget _buildHoldTalk() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
        // 以按下位置为原点，向上滑超过 60px → 松开取消
        final armed = d.offsetFromOrigin.dy < -60;
        if (armed != _cancelArmed) setState(() => _cancelArmed = armed);
      },
      onLongPressEnd: (_) => _finishRecording(),
      onLongPressCancel: () => _finishRecording(),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _recording
              ? (_cancelArmed
                  ? const Color(0xFFFBE9E7)
                  : const Color(0xFFD9F2E3))
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _recording
              ? (_cancelArmed ? '松开 取消' : '松开 发送 · $_recordSecs"')
              : '按住 说话',
          style: TextStyle(
            fontSize: 15,
            color: _recording
                ? (_cancelArmed
                    ? const Color(0xFFC62828)
                    : const Color(0xFF07C160))
                : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  /// 表情面板（微信式）：表情→点按插入输入框 + 底栏删除/发送；表情包→点按即发。
  Widget _buildEmojiPanel() => ChatEmojiPanel(
        onDelete: _deleteLastEmoji,
        onEmoji: _insertEmoji,
        onSticker: _sendStickerBundled,
        onSend: _hasInput && !_busy ? _send : null,
      );

  /// 加号面板（仿微信 4×2）：相册/拍摄转真；其余占位。
  Widget _buildMorePanel() => ChatMorePanel(
        firstRowCount: 4,
        actions: [
          ChatMoreAction(
            icon: Icons.photo_outlined,
            label: '相册',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          ChatMoreAction(
            icon: Icons.camera_alt_outlined,
            label: '拍摄',
            onTap: () => _pickImage(ImageSource.camera),
          ),
          ChatMoreAction(
            icon: Icons.videocam_outlined,
            label: '视频通话',
            onTap: () => _demo('视频通话（暂未实现）'),
          ),
          ChatMoreAction(
            icon: Icons.location_on_outlined,
            label: '位置',
            onTap: () => _demo('位置（暂未实现）'),
          ),
          ChatMoreAction(
            icon: Icons.redeem_outlined,
            label: '红包',
            onTap: () => _sendRedPacket('redpacket'),
          ),
          ChatMoreAction(
            icon: Icons.swap_horiz,
            label: '转账',
            onTap: () => _sendRedPacket('transfer'),
          ),
          ChatMoreAction(
            icon: Icons.mic_none,
            label: '语音输入',
            onTap: () => _demo('语音输入（暂未实现；按住说话已可用）'),
          ),
        ],
      );

  /// 发送红包/转账（033，假钱）：弹金额+留言输入层 → 乐观卡片气泡 → POST /ai/chat。
  /// kind：redpacket | transfer。AI 仅当收到社交信号感知（无真实支付）。
  Future<void> _sendRedPacket(String kind) async {
    if (_busy) return;
    final isTransfer = kind == 'transfer';
    // 验收批3②：对话框自持控制器并整体返回 (金额, 附言)，不再在 pop 后读已销毁的 noteCtrl。
    final result = await showDialog<(double, String)?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => RedPacketInputDialog(
        title: isTransfer ? '转账给 ${widget.character.name}' : '发红包',
        amountHint: isTransfer ? '输入金额' : '金额',
        noteHint: isTransfer ? '添加附言' : '恭喜发财，大吉大利',
      ),
    );
    if (result == null || !mounted) return;
    final (amount, note) = result;
    if (amount <= 0) return;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: kind,
      content: note,
      amount: amount,
      createdAt: DateTime.now(),
      status: AiMsgStatus.sent,
    );
    setState(() {
      _busy = true;
      _messages.add(msg);
    });
    await _savePendingMessage(msg);
    try {
      await _postChat(
        pendingMsg: msg,
        kind: kind,
        text: note,
        redpacketAmount: amount,
      );
      if (mounted) _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[redpacket] failed: $e');
      final failed = msg.withStatus(AiMsgStatus.failed);
      await _savePendingMessage(failed);
      if (mounted) _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------------------------- #
  // 长按气泡菜单（微信五列两行）
  // --------------------------------------------------------------------------- #

  List<BubbleActionItem> _messageActionItems({
    required bool includeCopy,
    required String messageKind,
  }) =>
      [
        if (includeCopy)
          const BubbleActionItem(
              'copy', Icons.insert_drive_file_outlined, '复制'),
        const BubbleActionItem('forward', Icons.reply_rounded, '转发'),
        const BubbleActionItem('collect', Icons.inventory_2_outlined, '收藏'),
        const BubbleActionItem('delete', Icons.delete_outline, '删除'),
        const BubbleActionItem('multi', Icons.playlist_add_check, '多选'),
        const BubbleActionItem('quote', Icons.format_quote_rounded, '引用'),
        const BubbleActionItem('remind', Icons.notifications_none, '提醒'),
        if (messageKind == 'audio')
          const BubbleActionItem('transcribe', Icons.text_fields, '转文字'),
        if (includeCopy)
          const BubbleActionItem('translate', Icons.translate, '翻译'),
        const BubbleActionItem('search', Icons.auto_awesome, '搜一搜'),
      ];

  /// 图片、语音和表情仍用气泡锚定菜单；文字由 SelectableText
  /// 直接提供原地选区与 [WeChatSelectionMenu]。
  void _showBubbleMenu(Rect rect, AiMessage m) {
    final overlay = Overlay.of(context);
    // 验收批3②：上次未关的菜单先关（防叠开）；入口统一走 _removeBubbleMenu，
    // 置空 _menuEntry 避免 dispose 二次 remove 触发断言。
    _removeBubbleMenu();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => BubbleActionMenu(
        bubbleRect: rect,
        items: _messageActionItems(
          includeCopy: false,
          messageKind: m.kind,
        ),
        feedbackEdge: _feedbackRailFor(m, bubbleRect: rect),
        onSelect: (id) {
          _removeBubbleMenu();
          _onBubbleAction(id, m);
        },
        onDismiss: _removeBubbleMenu,
      ),
    );
    _menuEntry = entry;
    overlay.insert(entry);
  }

  Future<void> _onBubbleAction(
    String id,
    AiMessage m, {
    String? selectedText,
  }) async {
    // 验收批3②：菜单可能在页面销毁后才回调（如 dispose 竞态），先判 mounted。
    if (!mounted) return;
    switch (id) {
      case 'copy':
        // 文字选区菜单会优先调用 Flutter 原生 copySelection，
        // 这里只是非选区路径的安全兜底。
        if (m.kind == 'text' && m.content.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: m.content));
          if (mounted) _snack('已复制');
        } else if (mounted) {
          _snack('仅文字消息可复制');
        }
        break;
      case 'forward':
        if (mounted) _snack('转发（暂未实现）');
        break;
      case 'collect':
        await _collectMessage(m);
        break;
      case 'delete':
        if (mounted) _snack('删除（暂未实现）');
        break;
      case 'multi':
        if (mounted) _snack('多选（暂未实现）');
        break;
      case 'quote':
        if (mounted) {
          setState(() {
            _quoteText = selectedText?.isNotEmpty == true
                ? selectedText
                : chatMessageDisplayText(m);
            _quoteMessageId = m.id;
            _quoteRole = m.role;
            _panel = _Panel.none;
            _voiceMode = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _inputFocus.requestFocus();
          });
        }
        break;
      case 'remind':
        if (mounted) _snack('提醒（暂未实现）');
        break;
      case 'transcribe':
        if (m.kind != 'audio' || m.content.trim().isEmpty) {
          if (mounted) _snack('这条语音暂无可显示的文字');
          break;
        }
        if (mounted) {
          setState(() {
            if (!_revealedVoiceTranscripts.add(m.id)) {
              _revealedVoiceTranscripts.remove(m.id);
            }
          });
        }
        break;
      case 'translate':
        if (mounted) _snack('翻译（暂未实现）');
        break;
      case 'search':
        if (mounted) _snack('搜一搜（暂未实现）');
        break;
    }
  }

  /// 037+038：提交 👍/👎 反馈。👍 一步提交；👎 面板多选原因 + 自由填写。
  /// 未显式传 reasons 时点踩回退规则候选（V3 AI 分析可覆盖）。成功 toast「已反馈」。
  Future<void> _sendFeedback(AiMessage m, String rating,
      {List<String>? reasons, String customFeedback = ''}) async {
    if (!mounted) return;
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    final characterId = widget.character.id;

    final finalReasons = rating == 'negative'
        ? (reasons ??
            analyzeFeedbackReason(
                precedingUserMessage(_messages, m), m.content))
        : const <String>[];
    final ok = await submitFeedback(
      ref.read(apiProvider),
      characterId: characterId,
      conversationId: conversationId,
      messageId: m.id,
      rating: rating,
      reasons: finalReasons,
      customFeedback: customFeedback,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (rating == 'none') {
          _messageFeedback.remove(m.id);
        } else {
          _messageFeedback[m.id] = rating;
        }
      });
      _snack(rating == 'none' ? '已取消反馈' : '已反馈');
    } else {
      _snack('反馈提交失败，请重试');
    }
  }

  /// R7 收藏：单聊目标角色锁定当前角色；内容预填（媒体给占位标签，文字给原文）。
  Future<void> _collectMessage(AiMessage m) async {
    if (!mounted) return;
    await showAppModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CollectMemoryDialog(
        initialContent: chatMessageDisplayText(m),
        fixedCharacterId: widget.character.id,
        fixedCharacterName: widget.character.name,
      ),
    );
  }

  void _snack(String msg) => showAppToast(context, msg);

  void _demo(String msg) => _snack(msg);

  /// 右上角「⋯」→ 聊天信息页（微信聊天信息）：头像→个人主页 / 查找聊天记录 /
  /// 置顶聊天 / 提醒 / 设置当前聊天背景 / 更换头像 / 恢复默认 / 清空聊天记录。
  /// 清空聊天记录成功返回 'cleared' → 清空内存消息 + 恢复欢迎语（微信空聊天语义）。
  void _showMore() {
    Navigator.of(context)
        .push(
      AppPageRoute(builder: (_) => ChatInfoPage(character: _liveCharacter())),
    )
        .then((result) async {
      final savedMode = await AppPrefs.chatReplyMode(widget.character.id);
      final savedNoban = await AppPrefs.isChatNoban(widget.character.id);
      final savedRealtimeChars =
          await AppPrefs.realtimeReplyChars(widget.character.id);
      final savedRoleplayChars =
          await AppPrefs.roleplayReplyChars(widget.character.id);
      final savedRealtimeCount =
          await AppPrefs.realtimeReplyCount(widget.character.id);
      if (mounted) {
        setState(() {
          _replyMode = savedMode;
          _noban = savedNoban;
          _realtimeReplyChars = savedRealtimeChars;
          _roleplayReplyChars = savedRoleplayChars;
          _realtimeReplyCount = savedRealtimeCount;
        });
      }
      if (result == 'cleared' && mounted) {
        setState(() {
          _messages
            ..clear()
            ..add(AiMessage(
              id: '',
              role: 'assistant',
              content: _liveCharacter().welcomeMessage ?? '嗨～你好呀。',
              createdAt: DateTime.now(),
            ));
        });
      } else if (result == 'noban_purged' && mounted) {
        final conversationId = _conversationId;
        setState(() {
          _messages.clear();
          _loadingHistory = true;
        });
        if (conversationId != null && conversationId.isNotEmpty) {
          await _loadHistory(conversationId);
        }
        if (!mounted) return;
        if (_messages.isEmpty) {
          ref
              .read(conversationsProvider.notifier)
              .removeLocal(widget.character.id);
        } else {
          final last = _messages.last;
          ref.read(conversationsProvider.notifier).applyLocal(
                widget.character.id,
                ConversationPreview(
                  characterId: widget.character.id,
                  lastContent: chatMessageDisplayText(last),
                  lastKind: last.kind,
                  lastAt: last.createdAt,
                ),
              );
        }
        unawaited(ref.read(conversationsProvider.notifier).reload());
      }
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _recordTimer?.cancel();
    // 验收批3②：关闭长按菜单 overlay，避免页面销毁后遗留可命中已拆解子树的面板。
    _removeBubbleMenu();
    _inputFocus.dispose();
    // 退出聊天立即落盘草稿（防抖可能尚未触发）
    AppPrefs.saveChatDraft(widget.character.id, _ctrl.text);
    // 释放录音资源 + 停播语音（切走不残留声音）
    _voiceSession.dispose();
    voicePlayer.stopAll();
    // 释放人脸检测/embedding 原生资源（懒加载，可能未初始化）
    _faceIdentity?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _removeBubbleMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }
}

class _StickerAsset extends StatelessWidget {
  const _StickerAsset({
    required this.stickerId,
    required this.mediaAssetId,
    this.previewBytes,
  });

  final String? stickerId;
  final String? mediaAssetId;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    if (stickerId != null && stickerId!.isNotEmpty) {
      // 内置表情：打包素材，离线可渲染；缺素材兜底显示名
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/stickers/$stickerId.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.black12,
            alignment: Alignment.center,
            child: Text(stickerId!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ),
        ),
      );
    }
    // 相册表情：上传后走网络图，发送中/失败回退预览字节
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: MediaImageView(
        mediaAssetId: mediaAssetId ?? '',
        previewBytes: previewBytes,
      ),
    );
  }
}
