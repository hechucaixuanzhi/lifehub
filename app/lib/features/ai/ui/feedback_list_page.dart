import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import 'widgets/dislike_reason_sheet.dart';
import 'widgets/feedback.dart';

/// 「我的反馈」列表页（按角色绑定：单聊角色 / 群聊角色共用）。
/// 查看我对该角色各条 AI 回复的点赞/点踩与原因；每条可点击展开详情：
/// 聊天快照（我 + AI 回复）、时间、赞/踩、原因与自由填写；可编辑原因。
/// 改主意：点另一个图标=切换，点当前评价=取消该条，垃圾桶=删除。
class FeedbackListPage extends ConsumerStatefulWidget {
  const FeedbackListPage({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  ConsumerState<FeedbackListPage> createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends ConsumerState<FeedbackListPage> {
  List<FeedbackRecord>? _records; // null = 加载中
  final Set<String> _expanded = {}; // 展开详情卡片的 message_id
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await fetchFeedbackRecords(
      ref.read(apiProvider),
      characterId: widget.characterId,
    );
    if (!mounted) return;
    setState(() => _records = records);
  }

  Future<DislikeResult?> _openDislikeSheet({
    List<String> initialReasons = const [],
    String initialCustom = '',
  }) {
    return showAppModalSheet<DislikeResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DislikeReasonSheet(
        initialReasons: initialReasons,
        initialCustom: initialCustom,
      ),
    );
  }

  /// 底部 👍/👎：点另一个=切换，点当前评价=取消；切到 negative 先开面板收原因。
  Future<void> _applyRating(FeedbackRecord r, String rating) async {
    if (rating == 'negative' && r.rating != 'negative') {
      final result = await _openDislikeSheet(
        initialReasons: analyzeFeedbackReason(r.userMessage ?? '', r.aiMessage ?? ''),
      );
      if (result == null) return;
      await _submitRating(r, 'negative',
          reasons: result.reasons, customFeedback: result.customFeedback);
      return;
    }
    await _submitRating(r, rating);
  }

  /// 编辑原因/自由填写（negative 行）：面板预填既有 reasons + custom → 覆盖提交。
  Future<void> _editFeedback(FeedbackRecord r) async {
    final result = await _openDislikeSheet(
      initialReasons: r.reasons,
      initialCustom: r.customFeedback,
    );
    if (result == null) return;
    await _submitRating(r, 'negative',
        reasons: result.reasons, customFeedback: result.customFeedback);
  }

  /// 提交并刷新列表；'none' 删行，其余 upsert 覆盖（保留快照与首次时间）。
  Future<void> _submitRating(
    FeedbackRecord r,
    String rating, {
    List<String>? reasons,
    String customFeedback = '',
  }) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final ok = await submitFeedback(
      ref.read(apiProvider),
      characterId: widget.characterId,
      conversationId: r.conversationId,
      messageId: r.messageId,
      rating: rating,
      reasons: reasons ??
          (rating == 'negative'
              ? analyzeFeedbackReason(r.userMessage ?? '', r.aiMessage ?? '')
              : const <String>[]),
      customFeedback: customFeedback,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) return;
      if (rating == 'none') {
        _records?.removeWhere((x) => x.messageId == r.messageId);
      } else {
        final idx = _records?.indexWhere((x) => x.messageId == r.messageId);
        if (idx != null && idx >= 0) {
          _records![idx] = FeedbackRecord(
            messageId: r.messageId,
            rating: rating,
            conversationId: r.conversationId,
            userMessage: r.userMessage,
            aiMessage: r.aiMessage,
            reasons: reasons ?? const [],
            customFeedback: customFeedback,
            createdAt: r.createdAt,
          );
        }
      }
    });
    showAppToast(
      context,
      ok ? (rating == 'none' ? '已取消反馈' : '已反馈') : '操作失败，请重试',
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
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
        title: Text('「${widget.characterName}」的反馈',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: records == null
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: records.length,
                  itemBuilder: (context, i) => _FeedbackCard(
                    record: records[i],
                    expanded: _expanded.contains(records[i].messageId),
                    busy: _busy,
                    onTapToggle: (rating) =>
                        _applyRating(records[i], rating),
                    onEdit: () => _editFeedback(records[i]),
                    onDelete: () => _submitRating(records[i], 'none'),
                    onToggleExpand: () => setState(() {
                      if (!_expanded.add(records[i].messageId)) {
                        _expanded.remove(records[i].messageId);
                      }
                    }),
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feedback_outlined, size: 56, color: Color(0xFFC0C0C0)),
          SizedBox(height: 12),
          Text('还没有反馈记录',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
          SizedBox(height: 4),
          Text('长按 AI 消息 → 气泡右侧 👍/👎 提交',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// 一条反馈卡片：头部常显（赞/踩图标 + AI 回复预览 + 展开箭头），
/// 点击展开显示完整详情（赞/踩、聊天快照、原因、自由填写、时间）并可编辑。
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.record,
    required this.expanded,
    required this.busy,
    required this.onTapToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleExpand,
  });

  final FeedbackRecord record;
  final bool expanded;
  final bool busy;

  /// 底部赞/踩切换（rating='positive'|'negative'；取消由点当前评价触发）。
  final void Function(String rating) onTapToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;

  static const _activeColor = Color(0xFF576B95);
  static const _mutedColor = Color(0xFF9A9A9A);

  @override
  Widget build(BuildContext context) {
    final r = record;
    final isPositive = r.rating == 'positive';
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：赞/踩 + AI 回复预览 + 展开箭头（点击展开/收起）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleExpand,
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.thumb_up_alt : Icons.thumb_down_alt,
                  size: 18,
                  color: isPositive ? _activeColor : const Color(0xFFE64340),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.aiMessage ?? '[消息内容已清理]',
                    maxLines: expanded ? 0 : 1,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: AppColors.onBg),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _mutedColor,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // 赞/踩 + 时间
            Row(
              children: [
                Text(isPositive ? '点赞' : '点踩',
                    style: TextStyle(
                        fontSize: 13,
                        color: isPositive ? _activeColor : const Color(0xFFE64340),
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(_fmtTime(r.createdAt),
                    style: const TextStyle(fontSize: 12, color: _mutedColor)),
              ],
            ),
            const SizedBox(height: 8),
            // 聊天快照（我 + AI 回复全文）
            _SnapshotLine(label: '我', text: r.userMessage ?? '[无用户消息快照]'),
            const SizedBox(height: 6),
            _SnapshotLine(label: 'AI', text: r.aiMessage ?? '[无 AI 回复快照]'),
            // 原因 + 自由填写
            if (r.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in r.reasons)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(feedbackReasonLabel(code),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ),
                ],
              ),
            ],
            if (r.customFeedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('补充：${r.customFeedback}',
                  style: const TextStyle(fontSize: 13, color: AppColors.onBg)),
            ],
            // 编辑原因（仅 negative 有意义）
            if (!isPositive) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: busy ? null : onEdit,
                child: const Text('编辑原因',
                    style: TextStyle(fontSize: 13, color: _activeColor)),
              ),
            ],
            const SizedBox(height: 4),
          ],
          const Divider(height: 16),
          // 底部：改主意（点另一个=切换，点当前评价=取消）+ 删除
          Row(
            children: [
              _ToggleIcon(
                icon: Icons.thumb_up_alt_outlined,
                iconActive: Icons.thumb_up_alt,
                active: isPositive,
                label: '点赞',
                onTap: () => onTapToggle(isPositive ? 'none' : 'positive'),
              ),
              const SizedBox(width: 12),
              _ToggleIcon(
                icon: Icons.thumb_down_alt_outlined,
                iconActive: Icons.thumb_down_alt,
                active: !isPositive,
                label: '点踩',
                onTap: () => onTapToggle(isPositive ? 'negative' : 'none'),
              ),
              const Spacer(),
              IconButton(
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.muted),
                tooltip: '删除',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 快照行：灰色小标签 + 正文（换行完整显示）。
class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 14, color: AppColors.onBg)),
        ),
      ],
    );
  }
}

/// 无白圈的轻量图标钮（与气泡旁小图标同一视觉语言）。
class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
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
          padding: const EdgeInsets.all(6),
          child: Icon(
            active ? iconActive : icon,
            size: 22,
            color: active ? _FeedbackCard._activeColor : _FeedbackCard._mutedColor,
          ),
        ),
      ),
    );
  }
}

/// 反馈时间：今天 → 「今天 HH:mm」；今年 → 「M月d日 HH:mm」；往年 → 「yyyy年M月d日」。
String _fmtTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final local = t.toLocal();
  final hm =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '今天 $hm';
  }
  if (local.year == now.year) return '${local.month}月${local.day}日 $hm';
  return '${local.year}年${local.month}月${local.day}日';
}
