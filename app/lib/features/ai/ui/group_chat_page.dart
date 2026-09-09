import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/media_bubble.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/widgets/user_avatar.dart';
import '../ai_providers.dart';
import '../models/ai_chat_message.dart';
import '../models/character.dart';
import '../models/group_chat.dart';
import '../models/sticker.dart';
import '../services/face_identity_service.dart';
import '../services/chat_cache_store.dart';
import '../services/chat_message_session.dart';
import '../services/chat_voice_session.dart';
import 'chat_message_utils.dart';
import 'group_settings_sheet.dart';
import 'profile_page.dart';
import 'widgets/bubble_action_menu.dart';
import 'widgets/chat_emoji_panel.dart';
import 'widgets/chat_more_panel.dart';
import 'widgets/collect_memory_dialog.dart';
import 'widgets/dislike_reason_sheet.dart';
import 'widgets/feedback.dart';
import 'widgets/file_bubble.dart';
import 'widgets/media_preview_page.dart';
import 'widgets/redpacket_bubble.dart';
import 'widgets/redpacket_input_dialog.dart';
import 'widgets/voice_bubble.dart';
import 'widgets/wechat_bubble.dart';

/// 输入栏面板（无 / 表情 / 加号）。
enum _GroupPanel { none, emoji, more }

/// 群聊页（032）：多角色群聊 + 世界书穿越。气泡复用微信样式，AI 成员白色
/// 气泡带成员头像 + 顶部发言者名字；用户右侧绿色。MVP 不含语音/TTS、
/// 不含引用与长按菜单（文字选区仍原生可用）。
class GroupChatPage extends ConsumerStatefulWidget {
  const GroupChatPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  static const int _groupThresholdMinutes = 5;

  final _ctrl = TextEditingController();
  final List<AiMessage> _messages = [];
  GroupChat? _group;
  bool _busy = false;
  bool _loadingHistory = true;
  bool _hasInput = false;
  final _messageSession = ChatMessageSession();
  final FocusNode _inputFocus = FocusNode();
  _GroupPanel _panel = _GroupPanel.none;
  // 输入 @ 联想（#7）：非空 = 输入框上方展示成员联想栏。
  List<GroupMember>? _mentionMatches;
  int _mentionAtOffset = 0;
  // 引用回复条（#C）：长按菜单「引用」设置，发送时随请求带上。
  String? _quoteText;
  String? _quoteMessageId;
  String? _quoteRole;
  // 语音「转文字」已展开的 message id（长按菜单切换）
  final Set<String> _revealedVoiceTranscripts = {};
  // AI 消息反馈态（037）：message_id → 'positive' | 'negative'。驱动气泡右下角小图标。
  final Map<String, String> _messageFeedback = {};
  // ---- R1 语音输入：按住说话真实录音 + 离线 ASR（移植自单聊）----
  bool _voiceMode = false;
  final _voiceSession = ChatVoiceSession();
  // ---- 自我识别（#133）：图片消息 → 本地检测+embedding → 后端三态 → 注入群聊 ----
  FaceIdentityService? _faceIdentity;
  FaceIdentityService get _faceIdentitySvc =>
      _faceIdentity ??= FaceIdentityService(ref.read(apiProvider));
  bool _recording = false;
  bool _cancelArmed = false; // 上滑超过阈值 → 松手取消
  int _recordSecs = 0;
  String? _recordPath;
  Timer? _recordTimer;
  int _pressToken = 0; // 按压令牌：开始录音期间已松手 → 丢弃本次录音
  // 长按菜单 OverlayEntry：页面 dispose 时若未关闭会遗留 overlay（验收批3②修复）
  OverlayEntry? _menuEntry;
  // ---- R1 草稿/pending：按群持久化（chat_draft_group_* / chat_pending_group_*）----
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onInputChanged);
    _restoreGroupDraft();
    _load();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onInputChanged);
    _recordTimer?.cancel();
    _draftTimer?.cancel();
    // 验收批3②：关闭长按菜单 overlay，避免页面销毁后遗留可命中已拆解子树的面板。
    _removeBubbleMenu();
    // 最后提交一次草稿（防抖可能尚未触发）；空则清除
    AppPrefs.saveGroupChatDraft(widget.groupId, _ctrl.text);
    _voiceSession.dispose();
    _ctrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _removeBubbleMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _onInputChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasInput) setState(() => _hasInput = has);
    _updateMentionSuggestions();
    _scheduleSaveDraft();
  }

  /// 恢复本群上次未发送的草稿（微信式：退出重进仍在）。
  Future<void> _restoreGroupDraft() async {
    final draft = await AppPrefs.groupChatDraft(widget.groupId);
    if (!mounted || draft.isEmpty) return;
    if (_ctrl.text.isEmpty) {
      _ctrl.text = draft;
      setState(() => _hasInput = true); // 程序赋值不触发 onChanged，需手动同步
    }
  }

  /// 输入变化防抖保存草稿（300ms）；发送时 _ctrl.clear() 会触发本方法清掉草稿。
  void _scheduleSaveDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      AppPrefs.saveGroupChatDraft(widget.groupId, _ctrl.text);
    });
  }

  /// 重进群聊恢复在途/失败消息（R1）：pending JSON → AiMessage，标 failed 可重发。
  /// 已确认（服务端已有同内容消息）则清理本地 pending。
  Future<void> _restoreGroupPending() async {
    final raw = await AppPrefs.pendingGroupMessage(widget.groupId);
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final pending =
          AiMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final alreadyConfirmed = _messages.any(
        (m) => m.id != pending.id && sameOutgoingMessage(m, pending),
      );
      if (alreadyConfirmed) {
        await AppPrefs.savePendingGroupMessage(widget.groupId, null);
        return;
      }
      if (_messages.any((m) => m.id == pending.id)) return;
      final restored = _messageSession.deduplicateAndSort([
        ..._messages,
        pending.withStatus(AiMsgStatus.failed),
      ]);
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
      });
    } on Object {
      await AppPrefs.savePendingGroupMessage(widget.groupId, null);
    }
  }

  /// 输入 @ 联想（#7）：光标前最近一个 `@` 到光标之间无空格/换行 → 命中提及段，
  /// 按前缀过滤成员；点选把 `@前缀` 替换为 `@名字 ` 并收起。平时不出现。
  void _updateMentionSuggestions() {
    final group = _group;
    final members = group?.members;
    if (members == null || members.isEmpty) {
      _hideMentionBar();
      return;
    }
    final sel = _ctrl.selection;
    final cursor = sel.isValid ? sel.baseOffset : _ctrl.text.length;
    final before = _ctrl.text.substring(0, cursor.clamp(0, _ctrl.text.length));
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) {
      _hideMentionBar();
      return;
    }
    final seg = before.substring(atIdx + 1);
    if (seg.contains(' ') || seg.contains('\n')) {
      _hideMentionBar();
      return;
    }
    final prefix = seg.toLowerCase();
    final matches = [
      for (final m in members)
        if (m.name.toLowerCase().contains(prefix)) m,
    ];
    if (matches.isEmpty) {
      _hideMentionBar();
      return;
    }
    final changed = _mentionMatches == null ||
        _mentionAtOffset != atIdx ||
        _mentionMatches!.length != matches.length;
    if (changed) {
      setState(() {
        _mentionMatches = matches;
        _mentionAtOffset = atIdx;
      });
    }
  }

  void _hideMentionBar() {
    if (_mentionMatches != null) {
      setState(() => _mentionMatches = null);
    }
  }

  void _selectMention(GroupMember m) {
    final text = _ctrl.text;
    final start = _mentionAtOffset.clamp(0, text.length);
    var end = text.length;
    for (var i = start; i < text.length; i++) {
      if (text[i] == ' ' || text[i] == '\n') {
        end = i;
        break;
      }
    }
    final insert = '@${m.name} ';
    final replaced = text.substring(0, start) + insert + text.substring(end);
    _ctrl.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _hideMentionBar();
    _inputFocus.requestFocus();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    final detail = await fetchGroupDetail(api, widget.groupId);
    if (!mounted) return;
    GroupChat? group = detail;
    if (group == null) {
      final cached = ref
          .read(groupsProvider)
          .valueOrNull
          ?.where((g) => g.id == widget.groupId)
          .firstOrNull;
      if (cached != null) {
        group = cached;
      } else {
        final preview =
            ref.read(conversationsProvider).valueOrNull?['g:${widget.groupId}'];
        group = GroupChat(
          id: widget.groupId,
          name: preview?.groupName ?? '群聊',
        );
      }
    }
    setState(() => _group = group);
    if (detail != null) {
      ref.read(groupsProvider.notifier).applyLocal(detail);
    }
    await _loadHistory();
    await _restoreGroupPending();
    // 037：重进聊天恢复已评价态（改主意切换/取消入口需要）。失败静默。
    await _loadFeedbackRatings();
  }

  /// 037：拉取本群已提交反馈（message_id → rating）并填充 _messageFeedback，
  /// 让长按气泡旁小图标恢复已评价态（群聊按发送者角色隔离在写入侧）。
  Future<void> _loadFeedbackRatings() async {
    if (!mounted) return;
    final ratings = await fetchFeedbackRatings(
      ref.read(apiProvider),
      conversationId: widget.groupId,
    );
    if (!mounted || ratings.isEmpty) return;
    setState(() => _messageFeedback.addAll(ratings));
  }

  Future<void> _loadHistory() async {
    final conversationId = widget.groupId;
    // 1) 本地缓存秒开
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/history?conversation_id=$conversationId')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final parsed = [
          for (final m in (body['messages'] as List? ?? const []))
            AiMessage.fromJson(m as Map<String, dynamic>),
        ];
        final cachedLastId = cached.isEmpty ? null : cached.last.id;
        final serverLastId = parsed.isEmpty ? null : parsed.last.id;
        if (cachedLastId == serverLastId) {
          setState(() => _loadingHistory = false);
        } else {
          final reconciled = _messageSession.mergeServerHistory(
            current: _messages,
            server: parsed,
            sameOutgoing: sameOutgoingMessage,
          );
          setState(() {
            _messages
              ..clear()
              ..addAll(reconciled);
            _loadingHistory = false;
          });
          try {
            await ref.read(dbProvider).deleteChatMessages(conversationId);
            await _cacheMessages(parsed);
          } on Object {
            // 缓存写失败静默
          }
        }
      }
    } on Object {
      if (mounted) {
        setState(() => _loadingHistory = false);
        if (_messages.isEmpty) {
          _messages.add(AiMessage(
            id: '',
            role: 'assistant',
            content: '群聊已就绪，发送消息开始吧。',
            createdAt: DateTime.now(),
          ));
        }
      }
    }
  }

  Future<void> _cacheMessages(List<AiMessage> msgs) async {
    try {
      await ChatCacheStore(ref.read(dbProvider)).upsert(widget.groupId, msgs);
    } on Object {
      // 缓存写失败静默
    }
  }

  // --------------------------------------------------------------------------- #
  // 发送
  // --------------------------------------------------------------------------- #

  void _markStatus(String id, AiMsgStatus s) {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    setState(() => _messages[idx] = _messages[idx].withStatus(s));
  }

  /// R4：用户点「开心收下」本地领取（假钱无真实支付；AI 领取由后端必回落库）。
  void _claimGroupLocal(String id) {
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
    unawaited(_cacheMessages([_messages[idx]]));
  }

  GroupMember? _memberOf(String? characterId) {
    final group = _group;
    if (group == null || characterId == null || characterId.isEmpty)
      return null;
    return group.memberOf(characterId);
  }

  /// 扫描 @名字：命中群成员 → 返回该成员（点名模式/提权到该成员单答）。
  GroupMember? _mentionFromText(String text) {
    final group = _group;
    if (group == null) return null;
    for (final m in group.members) {
      if (m.name.isNotEmpty && text.contains('@${m.name}')) return m;
    }
    return null;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy || _group == null) return;
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
      _busy = true;
      _hasInput = false;
      _messages.add(msg);
    });
    await AppPrefs.savePendingGroupMessage(
        widget.groupId, jsonEncode(msg.toJson()));
    try {
      await _postGroupChat(pendingMsg: msg, text: text);
      _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[group send] failed: $e');
      _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendImage(ImageSource source) async {
    if (_busy) return;
    final quote = _quoteText;
    final quoteMessageId = _quoteMessageId;
    final quoteRole = _quoteRole;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    // 预览-发送页（R1 与单聊共用）：可附文字 / 作为表情包发送；未放大可右滑返回。
    final tc = TransformationController();
    final pending = await Navigator.of(context).push<PendingMedia>(
      AppPageRoute(
        builder: (_) => MediaPreviewPage(
          bytes: bytes,
          fileName: picked.name,
          mime: imageMimeFor(picked.name),
          controller: tc,
        ),
        swipeBackGate: () => tc.value.getMaxScaleOnAxis() <= 1.02,
      ),
    );
    if (pending == null || !mounted) return;
    await _sendGroupMedia(
      kind: pending.asSticker ? 'sticker' : 'image',
      bytes: pending.bytes,
      fileName: pending.fileName,
      mime: pending.mime,
      caption: pending.caption,
      quote: quote,
      quoteMessageId: quoteMessageId,
      quoteRole: quoteRole,
    );
  }

  /// 群聊媒体发送（图片 / 相册当表情 / 文件）：乐观回显 → 上传 → 图片并行自我识别
  /// → POST 群聊流。失败 → 本条红!可重发（本地字节保留）。
  Future<void> _sendGroupMedia({
    required String kind,
    required List<int> bytes,
    required String fileName,
    required String mime,
    String? caption,
    String? quote,
    String? quoteMessageId,
    String? quoteRole,
  }) async {
    if (_busy) return;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: kind,
      content: caption ?? '',
      mediaAssetId: '',
      stickerId: null,
      fileName: fileName,
      fileSize: bytes.length,
      createdAt: DateTime.now(),
      previewBytes: Uint8List.fromList(bytes),
      quote: quote,
      quoteMessageId: quoteMessageId,
      quoteRole: quoteRole,
      status: AiMsgStatus.sent,
    );
    setState(() {
      _busy = true;
      _quoteText = null;
      _quoteMessageId = null;
      _quoteRole = null;
      _messages.add(msg);
    });
    await AppPrefs.savePendingGroupMessage(
        widget.groupId, jsonEncode(msg.toJson()));
    try {
      final api = ref.read(apiProvider);
      // 图片消息并行做自我识别（本地检测+embedding+后端三态），不上传时发得慢；
      // 文件/表情跳过。
      final uploadFuture = api.uploadAsset(bytes, fileName, mime);
      final identityFuture = kind == 'image'
          ? _faceIdentitySvc.analyze(Uint8List.fromList(bytes))
          : Future<Map<String, dynamic>?>.value(null);
      final mediaId = await uploadFuture;
      final selfIdentity = await identityFuture;
      await _postGroupChat(
        pendingMsg: msg,
        kind: kind,
        mediaId: mediaId,
        fileName: fileName,
        text: caption,
        selfIdentity: selfIdentity,
      );
      _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[group media] failed: $e');
      _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendStickerBundled(Sticker s) async {
    if (_busy) return;
    final quote = _quoteText;
    final quoteMessageId = _quoteMessageId;
    final quoteRole = _quoteRole;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: 'sticker',
      content: '',
      stickerId: s.id,
      createdAt: DateTime.now(),
      quote: quote,
      quoteMessageId: quoteMessageId,
      quoteRole: quoteRole,
      status: AiMsgStatus.sent,
    );
    setState(() {
      _busy = true;
      _quoteText = null;
      _quoteMessageId = null;
      _quoteRole = null;
      _messages.add(msg);
    });
    await AppPrefs.savePendingGroupMessage(
        widget.groupId, jsonEncode(msg.toJson()));
    try {
      await _postGroupChat(pendingMsg: msg, kind: 'sticker', stickerId: s.id);
      _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[group sticker] failed: $e');
      _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 发群红包（033，假钱）：弹金额+留言 → 乐观卡片气泡 → SSE 全群感知。
  /// 群聊只做群红包（微信不支持群转账）；AI 成员在 history 中看到红包描述并可回应。
  Future<void> _sendRedPacket() async {
    if (_busy || _group == null) return;
    // 验收批3②：对话框自持控制器并整体返回 (金额, 附言)，不再在 pop 后读
    // 已销毁的 noteCtrl（use-after-dispose）。
    final result = await showDialog<(double, String)?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const RedPacketInputDialog(
        title: '发群红包',
        amountHint: '金额',
        noteHint: '恭喜发财，大吉大利',
      ),
    );
    if (result == null || !mounted) return;
    final (amount, note) = result;
    if (amount <= 0) return;
    final msg = AiMessage(
      id: _messageSession.nextLocalId(),
      role: 'user',
      kind: 'redpacket',
      content: note,
      amount: amount,
      createdAt: DateTime.now(),
      status: AiMsgStatus.sent,
    );
    setState(() {
      _busy = true;
      _messages.add(msg);
    });
    await AppPrefs.savePendingGroupMessage(
        widget.groupId, jsonEncode(msg.toJson()));
    try {
      await _postGroupChat(
        pendingMsg: msg,
        kind: 'redpacket',
        text: note,
        redpacketAmount: amount,
      );
      _markStatus(msg.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[group redpacket] failed: $e');
      _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------------------------- #
  // 语音输入（R1，移植自单聊）：按住说话真实录音（wav）→ 离线 ASR → 乐观语音
  // 气泡 → 上传 → POST 群聊流。AI 回复纯文字，不请求 TTS。
  // --------------------------------------------------------------------------- #

  Future<void> _startRecording() async {
    if (_recording) return;
    final ok = await _voiceSession.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      showAppToast(context, '需要麦克风权限才能发语音');
      return;
    }
    final token = ++_pressToken;
    try {
      final path = await _voiceSession.start();
      if (!mounted) return;
      // 开始录音期间用户已松手 → 丢弃本次录音（防"没人按还在录"）
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

  Future<void> _finishRecording() async {
    if (!_recording) return;
    // 验收批3②：可能由 60s 定时器触发，页面已 dispose 时 setState 会抛
    // “setState after dispose”；先判 mounted。
    if (!mounted) return;
    _pressToken++;
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

  /// 进入语音模式即后台预下载 ASR 模型（首次，hf-mirror ~65MB）。
  Future<void> _preloadAsr() async {
    try {
      if (await _voiceSession.isAsrReady()) return;
      if (mounted) showAppToast(context, '首次使用：正在下载语音识别模型（后台）…');
      await _voiceSession.ensureAsrModel();
      if (mounted) showAppToast(context, '语音识别模型就绪 ✓');
    } on Object catch (e) {
      debugPrint('[voice] ASR 预载失败（发送时重试）: $e');
    }
  }

  /// 语音发送全流程：离线 ASR（失败留空仍发）→ 乐观语音气泡（本地可播）→
  /// 上传 wav → 写 MediaCache → POST 群聊流 → 清理本地文件。
  Future<void> _finalizeVoice(String path, int secs) async {
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
    await AppPrefs.savePendingGroupMessage(
        widget.groupId, jsonEncode(msg.toJson()));
    try {
      final api = ref.read(apiProvider);
      final bytes = await File(path).readAsBytes();
      final mediaId = await api.uploadAsset(bytes, 'voice.wav', 'audio/wav');
      // 写 MediaCache：气泡改走 mediaAssetId，重进历史也秒播
      try {
        await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
              mediaId: mediaId,
              bytes: bytes,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
      } on Object {
        // 缓存失败：在线照常（下次播放走网络下载）
      }
      await _postGroupChat(
        pendingMsg: msg,
        mediaId: mediaId,
        kind: 'audio',
        text: transcript,
        audioDuration: secs,
      );
      _markStatus(msg.id, AiMsgStatus.sent);
      // 上传成功清理本地录音（字节已在 MediaCache）
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[voice] send failed: $e');
      // 失败：保留本条 + 本地文件 → 红!可重发
      _markStatus(msg.id, AiMsgStatus.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 群聊文件发送（R1 新增）：系统文件选择 → 乐观"发送中"卡片 → 上传 → POST 群聊流。
  Future<void> _pickFile() async {
    if (_busy) return;
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = await f.xFile.readAsBytes();
    if (!mounted) return;
    await _sendGroupMedia(
      kind: 'file',
      bytes: bytes,
      fileName: f.name,
      mime: 'application/octet-stream',
    );
  }

  /// 统一 POST /ai/group_chat/stream（#4）：SSE 逐条消费 reply，即时上屏 + 落库。
  /// 乐观用户消息保留展示（不再被替换）；回复服务端已落库，断线重进可恢复。
  Future<void> _postGroupChat({
    AiMessage? pendingMsg,
    String? mediaId,
    String kind = 'text',
    String? stickerId,
    String? fileName,
    String? text,
    double? redpacketAmount,
    int? audioDuration,
    Map<String, dynamic>? selfIdentity,
  }) async {
    final group = _group;
    if (group == null) return;
    final api = ref.read(apiProvider);
    final content = text ?? pendingMsg?.content ?? '';
    final mention = kind == 'text' ? _mentionFromText(content) : null;

    final received = <AiMessage>[];
    String eventType = '';
    final dataBuf = StringBuffer();
    String? streamError;
    bool? doneTransferAccepted; // 转账收/拒（验收批2）：done 事件携带首个有效回复的决定

    // SSE 事件：`event: reply/error/done` + `data: {json}`，空行结束事件块。
    void flushEvent() {
      final data = dataBuf.toString().trim();
      dataBuf.clear();
      final etype = eventType;
      eventType = '';
      if (data.isEmpty) return;
      if (etype == 'reply') {
        try {
          final payload = jsonDecode(data) as Map<String, dynamic>;
          final reply = AiMessage.fromJson({
            ...Map<String, dynamic>.from(payload),
            'role': 'assistant',
          });
          received.add(reply);
          if (!mounted) return;
          setState(() => _messages.add(reply));
          // persist-as-you-go：每条回复立即落本地库，断线也能恢复
          unawaited(_cacheMessages([reply]));
        } on Object catch (e) {
          debugPrint('[group stream] bad reply event: $e');
        }
      } else if (etype == 'error') {
        streamError = data;
      } else if (etype == 'done') {
        // 转账收/拒（验收批2）：done 事件携带首个有效回复成员的决定
        try {
          final payload = jsonDecode(data) as Map<String, dynamic>;
          final v = payload['transfer_accepted'];
          if (v is bool) doneTransferAccepted = v;
        } on Object {
          // done 事件解析失败忽略（循环正常结束即收尾）
        }
      }
    }

    void handleLine(String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushEvent();
      } else if (trimmed.startsWith('event:')) {
        eventType = trimmed.substring('event:'.length).trim();
      } else if (trimmed.startsWith('data:')) {
        dataBuf.write(trimmed.substring('data:'.length).trim());
      }
    }

    // 群回复模式取会话设置（server 端持久化）；回复字数由后端按模式默认
    // （realtime 180 / roleplay 1000），前端不再硬编码；无违禁为本地按群开关。
    final groupNoban = await AppPrefs.isGroupChatNoban(group.id);
    try {
      final stream = await api.streamPost('/ai/group_chat/stream', {
        'message': content,
        'conversation_id': group.id,
        if (kind != 'text' && mediaId != null) 'media_asset_id': mediaId,
        if (kind != 'text') 'kind': kind,
        if (kind == 'sticker' && stickerId != null) 'sticker_id': stickerId,
        if (redpacketAmount != null) 'redpacket_amount': redpacketAmount,
        if (audioDuration != null) 'audio_duration': audioDuration,
        if (selfIdentity != null) 'self_identity': selfIdentity,
        if (mention != null) 'mention_character_id': mention.id,
        'reply_mode': group.replyMode,
        if (groupNoban) 'noban': true,
        if (pendingMsg?.quote != null && pendingMsg!.quote!.isNotEmpty)
          'quote': {
            'message_id': pendingMsg.quoteMessageId,
            'role': pendingMsg.quoteRole,
            'content': pendingMsg.quote,
          },
      }).timeout(const Duration(seconds: 180));
      // 按 \n 切行并跨 chunk 缓冲，避免 UTF-8/SSE 事件被拆断。
      var buffer = StringBuffer();
      await for (final chunk in stream.timeout(const Duration(seconds: 180))) {
        // 验收批3②：页面已销毁 → 停止消费 SSE（避免 dispose 后继续写本地库/处理事件）。
        if (!mounted) break;
        buffer.write(chunk);
        var pending = buffer.toString();
        var nl = pending.indexOf('\n');
        while (nl >= 0) {
          handleLine(pending.substring(0, nl));
          pending = pending.substring(nl + 1);
          nl = pending.indexOf('\n');
        }
        buffer = StringBuffer(pending);
      }
      if (buffer.toString().trim().isNotEmpty) handleLine(buffer.toString());
      handleLine(''); // 冲刷最后一个事件块
    } on Object catch (e) {
      debugPrint('[group stream] failed: $e');
      if (e is ApiStreamError) {
        Map body;
        try {
          body = jsonDecode(e.body) as Map<String, dynamic>;
        } on Object {
          body = {};
        }
        throw Exception(_errorText(e.statusCode, body));
      }
      rethrow;
    }

    if (streamError != null) {
      throw Exception(streamError);
    }
    if (!mounted) return;
    // R1：SSE 正常完成 → 在途消息服务端已确认，清除 pending（失败路径保留，重进可恢复）
    await AppPrefs.savePendingGroupMessage(widget.groupId, null);
    // R4：红包/转账 → 群成员必回并领取，发送方消息标记已领取 + 群拆包人列表。
    // （后端 /ai/chat 类响应在领取落库前构建，claimed 恒 false；权威数据由
    //  /ai/history 重进时刷新，这里只是即时上屏。）
    if (kind == 'redpacket' || kind == 'transfer') {
      final seen = <String>{};
      final uniqueClaimers = <RedPacketClaimer>[
        for (final r in received)
          if (r.senderCharacterId != null &&
              r.senderCharacterId!.isNotEmpty &&
              seen.add(r.senderCharacterId!))
            RedPacketClaimer(
              characterId: r.senderCharacterId,
              name: _memberOf(r.senderCharacterId)?.name ?? '群成员',
            ),
      ];
      setState(() {
        final idx = pendingMsg?.id == null
            ? -1
            : _messages.indexWhere((x) => x.id == pendingMsg!.id);
        if (idx >= 0) {
          final cur = _messages[idx];
          final merged = <RedPacketClaimer>[
            for (final c in uniqueClaimers)
              if (!cur.claimers.any((x) => x.characterId == c.characterId)) c,
          ];
          if (merged.isNotEmpty) {
            _messages[idx] =
                cur.withClaimed(claimers: [...cur.claimers, ...merged]);
          }
        }
      });
      if (pendingMsg != null) {
        final markIdx = _messages.indexWhere((x) => x.id == pendingMsg.id);
        if (markIdx >= 0) unawaited(_cacheMessages([_messages[markIdx]]));
      }
    }
    // 转账收/拒（验收批2）：AI 回应后决定已知，即时翻转转账气泡状态栏。
    if (kind == 'transfer' && doneTransferAccepted != null) {
      setState(() {
        final idx = pendingMsg?.id == null
            ? -1
            : _messages.indexWhere((x) => x.id == pendingMsg!.id);
        if (idx >= 0) {
          _messages[idx] =
              _messages[idx].withTransferAccepted(doneTransferAccepted);
        }
      });
      if (pendingMsg != null) {
        final markIdx = _messages.indexWhere((x) => x.id == pendingMsg.id);
        if (markIdx >= 0) unawaited(_cacheMessages([_messages[markIdx]]));
      }
    }
    // 首页会话预览：user = 乐观消息（内容与服务端一致），replies 已即时上屏。
    _updateHomePreview(pendingMsg, received);
  }

  String _errorText(int status, Map body) {
    if (status == 503) return 'AI 离线（家庭服务器未连接）';
    final err = body['error'];
    if (err is Map && err['message'] is String) return err['message'] as String;
    return '请求失败 ($status)';
  }

  /// 失败消息点击红!重发（文本/图片/表情各自补全载荷）。
  Future<void> _retryMessage(AiMessage m) async {
    if (_busy) return;
    _markStatus(m.id, AiMsgStatus.sent);
    try {
      switch (m.kind) {
        case 'image':
          if (m.previewBytes != null) {
            final name = m.fileName ?? 'image.jpg';
            final api = ref.read(apiProvider);
            final mediaId = await api.uploadAsset(
                m.previewBytes!, name, imageMimeFor(name));
            await _postGroupChat(
                pendingMsg: m, kind: 'image', mediaId: mediaId, fileName: name);
          } else if (m.mediaAssetId != null && m.mediaAssetId!.isNotEmpty) {
            await _postGroupChat(
                pendingMsg: m,
                kind: 'image',
                mediaId: m.mediaAssetId,
                fileName: m.fileName);
          } else {
            if (mounted) showAppToast(context, '原图已清理，无法重发');
            throw Exception('media gone');
          }
        case 'sticker':
          if (m.stickerId != null && m.stickerId!.isNotEmpty) {
            await _postGroupChat(
                pendingMsg: m, kind: 'sticker', stickerId: m.stickerId);
          } else {
            if (mounted) showAppToast(context, '原表情已清理，无法重发');
            throw Exception('sticker gone');
          }
        case 'audio':
          if (m.localAudioPath != null && m.localAudioPath!.isNotEmpty) {
            // 本地录音文件仍在（发送失败未删）→ 重新上传重发
            final api = ref.read(apiProvider);
            final bytes = await File(m.localAudioPath!).readAsBytes();
            final mediaId =
                await api.uploadAsset(bytes, 'voice.wav', 'audio/wav');
            await _postGroupChat(
                pendingMsg: m,
                kind: 'audio',
                mediaId: mediaId,
                text: m.content,
                audioDuration: m.audioDuration);
          } else if (m.mediaAssetId != null && m.mediaAssetId!.isNotEmpty) {
            await _postGroupChat(
                pendingMsg: m,
                kind: 'audio',
                mediaId: m.mediaAssetId,
                text: m.content,
                audioDuration: m.audioDuration);
          } else {
            if (mounted) showAppToast(context, '原语音已清理，无法重发');
            throw Exception('audio gone');
          }
        case 'file':
          if (m.previewBytes != null) {
            final name = m.fileName ?? 'file';
            final api = ref.read(apiProvider);
            final mediaId = await api.uploadAsset(
                m.previewBytes!, name, 'application/octet-stream');
            await _postGroupChat(
                pendingMsg: m, kind: 'file', mediaId: mediaId, fileName: name);
          } else if (m.mediaAssetId != null && m.mediaAssetId!.isNotEmpty) {
            await _postGroupChat(
                pendingMsg: m,
                kind: 'file',
                mediaId: m.mediaAssetId,
                fileName: m.fileName);
          } else {
            if (mounted) showAppToast(context, '原文件已清理，无法重发');
            throw Exception('file gone');
          }
        case 'redpacket':
        case 'transfer':
          await _postGroupChat(
              pendingMsg: m,
              kind: m.kind,
              text: m.content,
              redpacketAmount: m.amount);
        default:
          await _postGroupChat(pendingMsg: m, text: m.content);
      }
      _markStatus(m.id, AiMsgStatus.sent);
      unawaited(_refreshCache());
    } on Object catch (e) {
      debugPrint('[group retry] failed: $e');
      _markStatus(m.id, AiMsgStatus.failed);
      if (mounted) showAppToast(context, '重发失败：$e');
    }
  }

  /// 发送成功后后台刷新缓存（/ai/group_chat 返回了消息 id，仍以历史为权威）。
  Future<void> _refreshCache() async {
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/history?conversation_id=${widget.groupId}')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final parsed = [
          for (final m in (body['messages'] as List? ?? const []))
            AiMessage.fromJson(m as Map<String, dynamic>),
        ];
        if (parsed.isNotEmpty) await _cacheMessages(parsed);
      }
    } on Object {
      // 后台刷新失败静默
    }
  }

  /// 写穿首页会话预览：群条目用 'g:<id>' 键，senderName = 最近 AI 发言者。
  void _updateHomePreview(AiMessage? user, List<AiMessage> replies) {
    final group = _group;
    if (group == null) return;
    AiMessage? last;
    if (replies.isNotEmpty) {
      last = replies.last;
    } else if (user != null) {
      last = user;
    }
    if (last == null) return;
    String? senderName;
    if (last.isGroupSpeaker) {
      senderName = _memberOf(last.senderCharacterId)?.name;
    }
    ref.read(conversationsProvider.notifier).applyGroupLocal(
          group.id,
          ConversationPreview(
            type: 'group',
            characterId: '',
            groupId: group.id,
            groupName: group.name,
            senderName: senderName,
            lastContent: chatMessageDisplayText(last),
            lastKind: last.kind,
            lastAt: last.createdAt,
          ),
        );
  }

  /// R7 收藏：群聊成员下拉选择目标；AI 成员消息默认归发言者本人（预填标注来源），
  /// 用户消息默认归首成员。内容可编辑、类型可选（事实/偏好/事件/禁止事项）。
  Future<void> _collectMessage(AiMessage m) async {
    if (!mounted) return;
    final members = _group?.members ?? const <GroupMember>[];
    if (members.isEmpty) {
      showAppToast(context, '群内还没有可收藏的成员');
      return;
    }
    final sender = _memberOf(m.senderCharacterId);
    final String content;
    final String defaultId;
    if (sender != null) {
      content = '（${sender.name} 说）${chatMessageDisplayText(m)}';
      defaultId = sender.id;
    } else {
      content = chatMessageDisplayText(m);
      defaultId = members.first.id;
    }
    await showAppModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CollectMemoryDialog(
        initialContent: content,
        members: members,
        defaultCharacterId: defaultId,
      ),
    );
  }

  // --------------------------------------------------------------------------- #
  // 长按气泡菜单（#C，微信五列两行，移植自单聊）
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

  /// 长按入口：群聊 AI 角色消息才显示轻量 👍/👎（浮在气泡右侧白框外，
  /// 不进操作菜单；反馈归属发出该消息的角色 m.senderCharacterId）。
  /// 改主意：点另一个=切换，点同一个=取消该条反馈（后端 rating=none 删行）。
  /// 一行气泡（rect 矮）横排贴合高度，多行/媒体竖排。
  /// 👍 一步提交；👎 未评 negative → 打开原因多选面板（预选规则候选）提交。
  Widget? _feedbackRailFor(AiMessage m, {Rect? bubbleRect}) {
    if (m.isMe || m.senderCharacterId == null || m.senderCharacterId!.isEmpty) {
      return null;
    }
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
          if (mounted) showAppToast(context, '已复制');
        } else if (mounted) {
          showAppToast(context, '仅文字消息可复制');
        }
        break;
      case 'forward':
        if (mounted) showAppToast(context, '转发（暂未实现）');
        break;
      case 'collect':
        await _collectMessage(m);
        break;
      case 'delete':
        if (mounted) showAppToast(context, '删除（暂未实现）');
        break;
      case 'multi':
        if (mounted) showAppToast(context, '多选（暂未实现）');
        break;
      case 'quote':
        if (mounted) {
          setState(() {
            _quoteText = selectedText?.isNotEmpty == true
                ? selectedText
                : chatMessageDisplayText(m);
            _quoteMessageId = m.id;
            _quoteRole = m.role;
            _panel = _GroupPanel.none;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _inputFocus.requestFocus();
          });
        }
        break;
      case 'remind':
        if (mounted) showAppToast(context, '提醒（暂未实现）');
        break;
      case 'transcribe':
        if (m.kind != 'audio' || m.content.trim().isEmpty) {
          if (mounted) showAppToast(context, '这条语音暂无可显示的文字');
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
        if (mounted) showAppToast(context, '翻译（暂未实现）');
        break;
      case 'search':
        if (mounted) showAppToast(context, '搜一搜（暂未实现）');
        break;
    }
  }

  /// 037+038：提交 👍/👎 反馈。群聊反馈归属发出该消息的角色（m.senderCharacterId）。
  /// 👍 一步提交；👎 面板多选原因 + 自由填写。未显式传 reasons 时回退规则候选。
  /// 成功 toast「已反馈」。
  Future<void> _sendFeedback(AiMessage m, String rating,
      {List<String>? reasons, String customFeedback = ''}) async {
    if (!mounted) return;
    final characterId = m.senderCharacterId;
    if (characterId == null || characterId.isEmpty) return;

    final finalReasons = rating == 'negative'
        ? (reasons ??
            analyzeFeedbackReason(
                precedingUserMessage(_messages, m), m.content))
        : const <String>[];
    final ok = await submitFeedback(
      ref.read(apiProvider),
      characterId: characterId,
      conversationId: widget.groupId,
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
      showAppToast(context, rating == 'none' ? '已取消反馈' : '已反馈');
    } else {
      showAppToast(context, '反馈提交失败，请重试');
    }
  }

  // --------------------------------------------------------------------------- #
  // 设置
  // --------------------------------------------------------------------------- #

  Future<void> _openSettings() async {
    // #3：右上角 ⋯ 进入全屏「群聊信息」页面（非弹窗）
    final result = await Navigator.of(context).push<String>(
      AppPageRoute(builder: (_) => GroupSettingsSheet(groupId: widget.groupId)),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      ref.read(conversationsProvider.notifier).removeGroupLocal(widget.groupId);
      Navigator.of(context).pop();
      return;
    }
    if (result == 'cleared') {
      // 聊天记录已清空：本地消息列表 + Drift 缓存同步清空
      setState(() => _messages.clear());
      try {
        await ref.read(dbProvider).deleteChatMessages(widget.groupId);
      } on Object {
        // 缓存清理失败静默
      }
    }
    if (result == 'noban_purged') {
      // 验收批3①：无违禁消息已剔除。本地消息/缓存清空后重拉剩余（standard）消息，
      // 否则 UI 会保留已被删除的无违禁气泡或空屏。
      setState(() => _messages.clear());
      try {
        await ref.read(dbProvider).deleteChatMessages(widget.groupId);
      } on Object {
        // 缓存清理失败静默
      }
      await _loadHistory();
    }
    // 重载群详情（改名/成员/模式/世界书可能已变）
    final api = ref.read(apiProvider);
    final detail = await fetchGroupDetail(api, widget.groupId);
    if (mounted && detail != null) {
      ref.read(groupsProvider.notifier).applyLocal(detail);
      setState(() => _group = detail);
    }
  }

  // --------------------------------------------------------------------------- #
  // 输入栏
  // --------------------------------------------------------------------------- #

  void _insertMention(GroupMember m) {
    final name = m.name;
    if (name.isEmpty) return;
    final pos = _ctrl.selection.baseOffset;
    final text = _ctrl.text;
    final insert = '@$name ';
    final next = text.substring(0, pos.clamp(0, text.length)) +
        insert +
        text.substring(pos.clamp(0, text.length));
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    _inputFocus.requestFocus();
  }

  void _toggleEmojiPanel() {
    if (_panel == _GroupPanel.emoji) {
      _inputFocus.requestFocus();
      setState(() => _panel = _GroupPanel.none);
    } else {
      _inputFocus.unfocus();
      setState(() => _panel = _GroupPanel.emoji);
    }
  }

  void _toggleMorePanel() {
    if (_panel == _GroupPanel.more) {
      _inputFocus.requestFocus();
      setState(() => _panel = _GroupPanel.none);
    } else {
      _inputFocus.unfocus();
      setState(() => _panel = _GroupPanel.more);
    }
  }

  /// 按住说话条（R1）：长按录音，上滑 60px 松手取消；录音中变色显示倒计时。
  Widget _buildHoldTalk() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
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

  void _insertEmoji(String e) {
    _ctrl.text += e;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  // --------------------------------------------------------------------------- #
  // 渲染
  // --------------------------------------------------------------------------- #

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final title = group?.name ?? '群聊';
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _busy ? '对方正在输入...' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
            if (group != null && group.members.isNotEmpty)
              Text(
                '${group.members.length}人',
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 29),
            tooltip: '群设置',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _chatBackground(),
                if (_loadingHistory)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else
                  // 验收批3②：气泡内 TextSelectionTheme 上提到列表外层——每页仅一个
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
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (_, r) =>
                          _buildRow(_messages.length - 1 - r),
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

  /// 聊天背景（036）：群绑定 backgroundMediaId → 铺满图（cacheWidth 按屏宽解码）；
  /// 否则微信默认浅灰底纹。
  Widget _chatBackground() {
    final mediaId = _group?.backgroundMediaId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final bytes = ref.watch(mediaBytesProvider(mediaId)).valueOrNull?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final screenW = MediaQuery.sizeOf(context).width;
        final decodeW = (screenW * dpr).round();
        return SizedBox.expand(
          child: Image.memory(bytes,
              fit: BoxFit.cover, cacheWidth: decodeW < 1 ? 1 : decodeW),
        );
      }
    }
    return const ColoredBox(
      color: AppColors.chatBg,
      child: CustomPaint(
        foregroundPainter: _GroupBgPatternPainter(),
      ),
    );
  }

  Widget _buildRow(int i) {
    final m = _messages[i];
    final prev = i > 0 ? _messages[i - 1] : null;
    final gapMinutes =
        i == 0 ? 0 : m.createdAt.difference(prev!.createdAt).inMinutes;
    final showSep = i == 0 ||
        gapMinutes > _groupThresholdMinutes ||
        !isSameCalendarDay(prev!.createdAt, m.createdAt);
    // 红包/转账卡片自带背景，无需气泡底（与图片/表情一致）；卡片内容即文案。
    final isBareMedia = (m.kind == 'image' ||
                m.kind == 'sticker' ||
                m.kind == 'redpacket' ||
                m.kind == 'transfer') &&
            m.content.trim().isEmpty ||
        m.kind == 'redpacket' ||
        m.kind == 'transfer';

    final Widget bubble;
    if (m.isMe) {
      bubble = WeChatBubble(
        isMe: true,
        meAvatar: const UserAvatar(size: 40, radius: 5),
        onRetry: m.status == AiMsgStatus.failed ? () => _retryMessage(m) : null,
        status: m.status,
        padding: _bubblePadding(m.kind),
        transparent: isBareMedia,
        quote: m.quote,
        onLongPress:
            m.kind == 'text' ? null : (rect) => _showBubbleMenu(rect, m),
        child: _bubbleChild(m),
      );
    } else {
      final member = _memberOf(m.senderCharacterId);
      bubble = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 2),
            child: Text(
              member?.name ?? '群成员',
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
          ),
          WeChatBubble(
            isMe: false,
            avatar: _memberAvatar(member),
            padding: _bubblePadding(m.kind),
            transparent: isBareMedia,
            quote: m.quote,
            onLongPress:
                m.kind == 'text' ? null : (rect) => _showBubbleMenu(rect, m),
            child: _bubbleChild(m),
          ),
        ],
      );
    }
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

  /// 成员 → 通讯录角色（真实头像来源）；找不到（角色已删/未加载）返回 null。
  Character? _characterOf(GroupMember? member) {
    if (member == null) return null;
    final chars = ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    for (final c in chars) {
      if (c.id == member.id) return c;
    }
    return null;
  }

  /// 成员头像（#1）：真实角色头像优先，角色已删 → 色块 glyph 兜底。
  /// 交互（#3）：点击 → 角色原生详情页；长按 → 插入 @名字。
  Widget _memberAvatar(GroupMember? member) {
    final c = _characterOf(member);
    if (c == null) return _memberAvatarFallback(member);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        AppPageRoute(builder: (_) => ProfilePage(character: c)),
      ),
      onLongPress: member == null ? null : () => _insertMention(member),
      child: CharacterAvatar(character: c, size: 40, radius: 5),
    );
  }

  Widget _memberAvatarFallback(GroupMember? member) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _parseMemberColor(member?.avatarColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        member?.avatarText?.isNotEmpty == true ? member!.avatarText! : '?',
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 联想条/小尺寸头像（无交互，仅展示）。
  Widget _memberAvatarMini(GroupMember m) {
    final c = _characterOf(m);
    if (c == null) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _parseMemberColor(m.avatarColor),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          m.avatarText?.isNotEmpty == true ? m.avatarText! : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    }
    return CharacterAvatar(character: c, size: 36, radius: 5);
  }

  /// 输入 @ 成员联想栏（#7，验收批2 改横框）：命中提及段时在输入框上方
  /// 横向排一排可滚动的成员 chip，点选把 `@前缀` 替换为 `@名字 `。
  Widget _buildMentionBar() {
    final matches = _mentionMatches ?? const <GroupMember>[];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = matches[i];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _selectMention(m),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _memberAvatarMini(m),
                  const SizedBox(width: 6),
                  Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF111111))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  EdgeInsets _bubblePadding(String kind) => switch (kind) {
        'image' ||
        'sticker' =>
          const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        'redpacket' || 'transfer' => EdgeInsets.zero,
        _ => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      };

  Color _parseMemberColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF576B95);
    var h = hex.replaceFirst('#', '');
    if (h.length != 6) return const Color(0xFF576B95);
    final v = int.tryParse(h, radix: 16);
    if (v == null) return const Color(0xFF576B95);
    return Color(0xFF000000 | v);
  }

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
        'sticker' => _GroupSticker(
            stickerId: m.stickerId,
            mediaAssetId: m.mediaAssetId,
            previewBytes: m.previewBytes,
          ),
        // 语音（R1）：微信式语音气泡（宽度∝时长，可播，下方显示转写）。
        // 我的语音 localAudioPath 即播；已上传/AI 语音走 mediaAssetId。
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
        // 文件（R1 新增）：文件名 + 大小卡片，点击暂不做（仅展示）。
        'file' => FileBubble(
            fileName: m.fileName ?? '文件',
            fileSize: m.fileSize,
          ),
        // 红包/转账（033+R4）：微信样式卡片，点开弹领取状态/金额（无真实支付）。
        'redpacket' || 'transfer' => RedPacketBubble(
            message: m,
            onClaim: () => _claimGroupLocal(m.id),
          ),
        _ => WeChatText(
            m.content,
            contextMenuBuilder: (context, editableTextState) =>
                _buildTextContextMenu(editableTextState, m),
          ),
      };

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
            // 输入 @ 联想栏（#7）：光标前命中提及段时出现在输入框上方
            if (_mentionMatches != null && _mentionMatches!.isNotEmpty)
              _buildMentionBar(),
            // 引用回复条（#C）：长按菜单「引用」后显示，发送即随请求带上
            if (_quoteText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  // R1 话筒：切换「按住说话」↔ 文字输入
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: IconButton(
                      onPressed: () {
                        final enteringVoice = !_voiceMode;
                        setState(() {
                          _voiceMode = enteringVoice;
                          if (enteringVoice) _panel = _GroupPanel.none;
                        });
                        if (enteringVoice) {
                          _inputFocus.unfocus();
                          unawaited(_preloadAsr());
                        }
                      },
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _voiceMode ? Icons.keyboard_outlined : Icons.mic_none,
                        color: const Color(0xFF333333),
                        size: 25,
                      ),
                      tooltip: '语音消息',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _voiceMode
                        ? _buildHoldTalk()
                        : TextField(
                            controller: _ctrl,
                            focusNode: _inputFocus,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onTap: () =>
                                setState(() => _panel = _GroupPanel.none),
                            onChanged: (_) => _onInputChanged(),
                            onSubmitted: (_) => _send(),
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
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
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
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: _hasInput
                        ? TextButton(
                            onPressed: _busy ? null : _send,
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFC8E6C9),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(40, 34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('发送',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
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
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (_panel) {
                _GroupPanel.emoji => _buildEmojiPanel(),
                _GroupPanel.more => _buildMorePanel(),
                _GroupPanel.none => const SizedBox(width: double.infinity),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPanel() => ChatEmojiPanel(
        onDelete: () {
          final text = _ctrl.text;
          if (text.isEmpty) return;
          final runes = text.runes.toList();
          _ctrl.text = String.fromCharCodes(runes.sublist(0, runes.length - 1));
        },
        onEmoji: _insertEmoji,
        onSticker: _sendStickerBundled,
        onSend: _hasInput && !_busy ? _send : null,
      );
  Widget _buildMorePanel() => ChatMorePanel(
        firstRowCount: 3,
        actions: [
          ChatMoreAction(
            icon: Icons.photo_outlined,
            label: '相册',
            onTap: () => _sendImage(ImageSource.gallery),
          ),
          ChatMoreAction(
            icon: Icons.camera_alt_outlined,
            label: '拍摄',
            onTap: () => _sendImage(ImageSource.camera),
          ),
          ChatMoreAction(
            icon: Icons.insert_drive_file_outlined,
            label: '文件',
            onTap: _pickFile,
          ),
          ChatMoreAction(
            icon: Icons.redeem_outlined,
            label: '红包',
            onTap: _sendRedPacket,
          ),
          ChatMoreAction(
            icon: Icons.swap_horiz,
            label: '转账',
            onTap: () => showAppToast(context, '群聊暂不支持转账'),
          ),
          ChatMoreAction(
            icon: Icons.location_on_outlined,
            label: '位置',
            onTap: () => showAppToast(context, '位置（暂未实现）'),
          ),
          ChatMoreAction(
            icon: Icons.mic_none,
            label: '语音',
            onTap: () {
              setState(() {
                _voiceMode = true;
                _panel = _GroupPanel.none;
              });
              _inputFocus.unfocus();
              unawaited(_preloadAsr());
            },
          ),
        ],
      );
}

/// 群聊背景：浅灰底 + 45° 极淡斜线纹理（与单聊同款）。
class _GroupBgPatternPainter extends CustomPainter {
  const _GroupBgPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A000000)
      ..strokeWidth = 1;
    const spacing = 5.0;
    for (var start = -size.height; start < size.width; start += spacing) {
      canvas.drawLine(
        Offset(start, 0),
        Offset(start + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GroupBgPatternPainter oldDelegate) => false;
}

/// 群表情包气泡（内置 stickerId / 相册 mediaAssetId）。
class _GroupSticker extends StatelessWidget {
  const _GroupSticker({
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: MediaImageView(
        mediaAssetId: mediaAssetId ?? '',
        previewBytes: previewBytes,
      ),
    );
  }
}
