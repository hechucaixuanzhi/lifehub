import 'package:shared_preferences/shared_preferences.dart';

/// 轻量本地偏好 / 草稿存储（shared_preferences 封装）。
/// 草稿按角色分 key：每个角色的草稿都严格隔离。
/// 会话列表有草稿时优先显示「草稿：xxx」（微信语义，见 wechat_home_page）。
class AppPrefs {
  static const _kDraftPrefix = 'chat_draft_';
  static const _kPinPrefix = 'chat_pin_';
  static const _kUnreadPrefix = 'chat_unread_';
  static const _kHiddenPrefix = 'chat_hidden_';
  static const _kReplyModePrefix = 'chat_reply_mode_';
  static const _kRealtimeReplyCharsPrefix = 'chat_realtime_reply_chars_';
  static const _kRoleplayReplyCharsPrefix = 'chat_roleplay_reply_chars_';
  static const _kRealtimeReplyCountPrefix = 'chat_realtime_reply_count_';
  static const _kNobanPrefix = 'chat_noban_';
  static const _kGroupNobanPrefix = 'chat_noban_group_';
  static const _kVoiceReplyPrefix = 'chat_voice_reply_';
  static const _kPendingChatPrefix = 'chat_pending_';
  // R1 群聊草稿/pending：按群隔离（chat_draft_group_{id} / chat_pending_group_{id}），
  // 与单聊完全分开，符合「私聊/群聊每会话独立」。
  static const _kGroupDraftPrefix = 'chat_draft_group_';
  static const _kGroupPendingPrefix = 'chat_pending_group_';
  static const _kLastTab = 'last_tab';
  static const _kLastWechatTab = 'last_wechat_tab';

  static String _draftKey(String characterId) => '$_kDraftPrefix$characterId';
  static String _pinKey(String characterId) => '$_kPinPrefix$characterId';
  static String _unreadKey(String characterId) => '$_kUnreadPrefix$characterId';
  static String _hiddenKey(String characterId) => '$_kHiddenPrefix$characterId';
  static String _replyModeKey(String characterId) =>
      '$_kReplyModePrefix$characterId';
  static String _realtimeReplyCharsKey(String characterId) =>
      '$_kRealtimeReplyCharsPrefix$characterId';
  static String _roleplayReplyCharsKey(String characterId) =>
      '$_kRoleplayReplyCharsPrefix$characterId';
  static String _realtimeReplyCountKey(String characterId) =>
      '$_kRealtimeReplyCountPrefix$characterId';
  static String _nobanKey(String characterId) => '$_kNobanPrefix$characterId';
  static String _groupNobanKey(String groupId) => '$_kGroupNobanPrefix$groupId';
  static String _voiceReplyKey(String characterId) =>
      '$_kVoiceReplyPrefix$characterId';
  static String _pendingChatKey(String characterId) =>
      '$_kPendingChatPrefix$characterId';
  static String _groupDraftKey(String groupId) =>
      '$_kGroupDraftPrefix$groupId';
  static String _groupPendingKey(String groupId) =>
      '$_kGroupPendingPrefix$groupId';

  /// 读某角色输入框草稿（无则空串）。
  static Future<String> chatDraft(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_draftKey(characterId)) ?? '';
  }

  /// 写某角色草稿；空串则清除。
  static Future<void> saveChatDraft(String characterId, String text) async {
    final p = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await p.remove(_draftKey(characterId));
    } else {
      await p.setString(_draftKey(characterId), text);
    }
  }

  /// 置顶聊天（微信「置顶聊天」）：按角色存 bool，会话列表置顶排前。
  static Future<bool> isChatPinned(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_pinKey(characterId)) ?? false;
  }

  static Future<void> setChatPinned(String characterId, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_pinKey(characterId), v);
  }

  /// 标为未读（微信会话列表红徽标）：长按菜单切换，打开聊天时清除。
  static Future<bool> isChatUnread(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_unreadKey(characterId)) ?? false;
  }

  static Future<void> setChatUnread(String characterId, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_unreadKey(characterId), v);
  }

  /// 不显示该聊天（微信语义）：从会话列表隐藏，保留记录；
  /// 恢复路径 = 通讯录→主页→发消息 打开聊天时清除隐藏标记。
  static Future<bool> isChatHidden(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_hiddenKey(characterId)) ?? false;
  }

  static Future<void> setChatHidden(String characterId, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_hiddenKey(characterId), v);
  }

  /// 回复形态：realtime=真实回复微信多气泡；roleplay=剧情回复长回复。
  static Future<String> chatReplyMode(String characterId) async {
    final p = await SharedPreferences.getInstance();
    final value = p.getString(_replyModeKey(characterId));
    return value == 'roleplay' ? 'roleplay' : 'realtime';
  }

  static Future<void> setChatReplyMode(String characterId, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _replyModeKey(characterId),
      value == 'roleplay' ? 'roleplay' : 'realtime',
    );
  }

  /// 各角色独立保存两种聊天模式的目标字数。目标值用于控制生成节奏，
  /// 不是生硬截断上限，避免把一句话从中间切断。
  static Future<int> realtimeReplyChars(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_realtimeReplyCharsKey(characterId)) ?? 180;
  }

  static Future<void> setRealtimeReplyChars(
    String characterId,
    int value,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_realtimeReplyCharsKey(characterId), value.clamp(60, 600));
  }

  static Future<int> roleplayReplyChars(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_roleplayReplyCharsKey(characterId)) ?? 1000;
  }

  static Future<void> setRoleplayReplyChars(
    String characterId,
    int value,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_roleplayReplyCharsKey(characterId), value.clamp(300, 3000));
  }

  /// 真实回复本轮目标生成多少个连续微信气泡；剧情回复始终为一条长回复。
  static Future<int> realtimeReplyCount(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_realtimeReplyCountKey(characterId)) ?? 3;
  }

  static Future<void> setRealtimeReplyCount(
    String characterId,
    int value,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_realtimeReplyCountKey(characterId), value.clamp(1, 5));
  }

  /// 角色支持时的无违禁模式。入口放在聊天信息页，避免破坏微信聊天顶栏。
  static Future<bool> isChatNoban(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_nobanKey(characterId)) ?? false;
  }

  static Future<void> setChatNoban(String characterId, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_nobanKey(characterId), value);
  }

  /// 群无违禁（按群隔离，key 前缀 chat_noban_group_，与单聊 chat_noban_ 互不干扰）。
  /// 只对群内支持无违禁（hasNoban）的成员生效，服务端 per-speaker 判定。
  static Future<bool> isGroupChatNoban(String groupId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_groupNobanKey(groupId)) ?? false;
  }

  static Future<void> setGroupChatNoban(String groupId, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_groupNobanKey(groupId), value);
  }

  /// 输入框右侧小话筒：仅控制“发送文字后是否要求对方回语音”。
  /// 用户自己发送语音时，后端始终语音回复，不受此开关影响。
  static Future<bool> chatVoiceReply(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_voiceReplyKey(characterId)) ?? false;
  }

  static Future<void> setChatVoiceReply(String characterId, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_voiceReplyKey(characterId), value);
  }

  /// 当前唯一一条在途/失败消息。退出聊天或页面销毁后仍可恢复，服务端确认后清除。
  static Future<String?> pendingChatMessage(String characterId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_pendingChatKey(characterId));
  }

  static Future<void> savePendingChatMessage(
    String characterId,
    String? json,
  ) async {
    final p = await SharedPreferences.getInstance();
    if (json == null || json.isEmpty) {
      await p.remove(_pendingChatKey(characterId));
    } else {
      await p.setString(_pendingChatKey(characterId), json);
    }
  }

  /// 群聊草稿（R1）：按群 id 存，key 前缀 chat_draft_group_，与单聊 chat_draft_ 隔离。
  /// 空串/纯空白清除。
  static Future<String> groupChatDraft(String groupId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_groupDraftKey(groupId)) ?? '';
  }

  static Future<void> saveGroupChatDraft(String groupId, String text) async {
    final p = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await p.remove(_groupDraftKey(groupId));
    } else {
      await p.setString(_groupDraftKey(groupId), text);
    }
  }

  /// 群聊在途/失败消息（R1）：镜像单聊 pending，发送成功（SSE 服务端确认）后清除。
  static Future<String?> pendingGroupMessage(String groupId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_groupPendingKey(groupId));
  }

  static Future<void> savePendingGroupMessage(
    String groupId,
    String? json,
  ) async {
    final p = await SharedPreferences.getInstance();
    if (json == null || json.isEmpty) {
      await p.remove(_groupPendingKey(groupId));
    } else {
      await p.setString(_groupPendingKey(groupId), json);
    }
  }

  /// 角色被删除后清理全部角色级轻量状态；聊天删除只应清草稿/未读/隐藏等会话态，
  /// 不要调用本方法误删用户保留的回复模式偏好。
  static Future<void> clearCharacterState(String characterId) async {
    final p = await SharedPreferences.getInstance();
    for (final key in <String>[
      _draftKey(characterId),
      _pinKey(characterId),
      _unreadKey(characterId),
      _hiddenKey(characterId),
      _replyModeKey(characterId),
      _realtimeReplyCharsKey(characterId),
      _roleplayReplyCharsKey(characterId),
      _realtimeReplyCountKey(characterId),
      _nobanKey(characterId),
      _voiceReplyKey(characterId),
      _pendingChatKey(characterId),
    ]) {
      await p.remove(key);
    }
  }

  /// 微信首页删除聊天：清除会话本身的本地痕迹，保留角色级聊天模式设置。
  static Future<void> clearConversationState(String characterId) async {
    final p = await SharedPreferences.getInstance();
    for (final key in <String>[
      _draftKey(characterId),
      _pinKey(characterId),
      _unreadKey(characterId),
      _pendingChatKey(characterId),
    ]) {
      await p.remove(key);
    }
  }

  static Future<int> lastTab() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kLastTab) ?? 0;
  }

  static Future<void> saveLastTab(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastTab, v);
  }

  static Future<int> lastWechatTab() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kLastWechatTab) ?? 0;
  }

  static Future<void> saveLastWechatTab(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastWechatTab, v);
  }
}
