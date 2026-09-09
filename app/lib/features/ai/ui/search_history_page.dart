import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/providers.dart';
import '../models/ai_chat_message.dart';
import '../models/character.dart';
import '../models/group_chat.dart';

/// 查找聊天记录（微信「查找聊天记录」）：拉全量历史 → 本地按关键词过滤。
/// 结果按天分组（最新在前），点击某条弹详情（发送者/时间/完整内容）。
///
/// 群聊复用（验收批2）：传 `groupMembers` 后非我消息按 `senderCharacterId`
/// 找对应群成员渲染头像/名字（sender 多样），否则走单聊单角色逻辑。
class SearchHistoryPage extends ConsumerStatefulWidget {
  const SearchHistoryPage({
    super.key,
    this.character,
    required this.conversationId,
    this.groupMembers,
  });

  /// 单聊时渲染角色头像/名字；群聊传 null（按 senderCharacterId 走成员，未知兜底）。
  final Character? character;
  final String conversationId;
  final List<GroupMember>? groupMembers;

  @override
  ConsumerState<SearchHistoryPage> createState() => _SearchHistoryPageState();
}

class _SearchHistoryPageState extends ConsumerState<SearchHistoryPage> {
  final _ctrl = TextEditingController();
  List<AiMessage> _messages = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/history?conversation_id=${widget.conversationId}&limit=1000')
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msgs = (body['messages'] as List?) ?? [];
        if (!mounted) return;
        setState(() {
          _messages = [
            for (final m in msgs)
              AiMessage.fromJson(m as Map<String, dynamic>),
          ];
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = '加载失败 (${resp.statusCode})';
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  /// 可搜索文本（与聊天页 _displayText 口径一致）。
  String _displayText(AiMessage m) => switch (m.kind) {
        'image' => '[图片]',
        'sticker' => '[表情包]',
        'file' => m.fileName ?? '[文件]',
        'redpacket' => '[红包]',
        'transfer' => '[转账]',
        _ => m.content,
      };

  List<AiMessage> get _results {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final m in _messages.reversed)
        if (_displayText(m).toLowerCase().contains(q) ||
            (m.fileName?.toLowerCase().contains(q) ?? false))
          m,
    ];
  }

  /// 按天分组（同一天一个日期头，最新在前）。
  List<(DateTime, List<AiMessage>)> get _groups {
    final groups = <(DateTime, List<AiMessage>)>[];
    for (final m in _results) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (groups.isNotEmpty && groups.last.$1 == day) {
        groups[groups.length - 1].$2.add(m);
      } else {
        groups.add((day, [m]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        titleSpacing: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('查找聊天记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 顶部搜索框（白底，微信样式）
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '搜索聊天记录',
                        isDense: true,
                        border: InputBorder.none,
                        hintStyle:
                            TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {});
                      },
                      child: const Icon(Icons.cancel,
                          size: 16, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: const TextStyle(fontSize: 13, color: AppColors.danger)),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('暂无聊天记录',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    if (_ctrl.text.trim().isEmpty) {
      return const Center(
        child: Text('输入关键词查找聊天记录',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    final groups = _groups;
    if (groups.isEmpty) {
      return const Center(
        child: Text('未找到相关内容',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    return ListView(
      children: [
        for (final (day, msgs) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(_fmtDay(day),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted)),
          ),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                for (final m in msgs)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    leading: _rowAvatar(m),
                    title: Text(
                      _displayText(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(_fmtTime(m.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    onTap: () => _preview(m),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 群聊：按 senderCharacterId 找群成员；找不到（角色已删/未知）返回 null。
  GroupMember? _memberOf(AiMessage m) {
    final members = widget.groupMembers;
    if (members == null || m.senderCharacterId == null) return null;
    for (final gm in members) {
      if (gm.id == m.senderCharacterId) return gm;
    }
    return null;
  }

  Widget _rowAvatar(AiMessage m) {
    if (m.isMe) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF95EC69),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('我',
            style: TextStyle(
                fontSize: 14, color: AppColors.onBg, fontWeight: FontWeight.w500)),
      );
    }
    final gm = _memberOf(m);
    if (gm != null) {
      final hex = gm.avatarColor;
      Color bg = const Color(0xFF576B95);
      if (hex != null && hex.isNotEmpty) {
        final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
        if (v != null) bg = Color(0xFF000000 | v);
      }
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          gm.avatarText?.isNotEmpty == true ? gm.avatarText! : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    }
    // 未知发送者（群聊角色已删/单聊无角色）→ 中性灰块兜底
    final c = widget.character;
    if (c != null) {
      return CharacterAvatar(character: c, size: 32, radius: 4);
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF9A9A9A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('?',
          style: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  /// 点击结果：底部弹层看完整内容（发送者/时间/内容）。
  void _preview(AiMessage m) {
    showAppModalSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                      m.isMe
                          ? '我'
                          : (_memberOf(m)?.name ??
                              widget.character?.name ??
                              '群成员'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_fmtFullTime(m.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_displayText(m),
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDay(DateTime d) {
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '今天';
    }
    if (d.year == yest.year && d.month == yest.month && d.day == yest.day) {
      return '昨天';
    }
    return '${d.month}月${d.day}日';
  }

  String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _fmtFullTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} $hh:$mm';
  }
}
