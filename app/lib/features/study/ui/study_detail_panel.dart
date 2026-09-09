import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/features/life/ui/habit_format.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/mini_trend_chart.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../domain/entities/study_resource.dart';
import '../../../domain/entities/study_session.dart';
import '../logic/study_notifier.dart';

/// 学习详情面板（DetailSheet 内容）：进度 + 今日/总计 + 计时 + 记一笔 + 历史。
/// 无 Scaffold/AppBar，由 DetailSheet 承载。
class StudyDetailPanel extends ConsumerWidget {
  const StudyDetailPanel({super.key, required this.resourceId});
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(studyNotifierProvider.notifier);
    final state = ref.watch(studyNotifierProvider);
    final resource =
        state.summaries.where((s) => s.resource.id == resourceId).isEmpty
            ? null
            : state.summaries
                .firstWhere((s) => s.resource.id == resourceId)
                .resource;
    final summary =
        state.summaries.where((s) => s.resource.id == resourceId).isEmpty
            ? null
            : state.summaries.firstWhere((s) => s.resource.id == resourceId);
    final active = state.activeResourceId == resourceId;
    final sessionsAsync = ref.watch(studySessionsProvider(resourceId));

    if (resource == null) {
      return const Center(child: Text('资源不存在', style: AppTypography.caption));
    }
    final color = Color(resource.colorArgb);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (summary?.progress != null) ...[
          LinearProgressIndicator(
            value: (summary!.progress!) / 100,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '进度 ${(summary.progress!).toInt()}% · 总计 ${_fmt(summary.totalAmount)}${resource.goalUnit} / 目标 ${resource.goalAmount.toInt()}${resource.goalUnit}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            StatTile(
                label: '今日时长',
                value: formatHmSeconds(summary?.todaySeconds.toInt() ?? 0)),
            StatTile(
                label: '今日量',
                value:
                    '${_fmt(summary?.todayAmount ?? 0)}${resource.goalUnit}'),
            StatTile(
                label: '总时长',
                value: formatHmSeconds(summary?.totalSeconds.toInt() ?? 0)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (active)
          FilledButton.icon(
            onPressed: () async {
              final secs = await notifier.stopTimer(resource.id);
              if (context.mounted) {
                showAppToast(context, '结束 · ${formatHmSeconds(secs)}');
              }
            },
            icon: const Icon(Icons.stop),
            label: const Text('结束计时'),
          )
        else
          FilledButton.icon(
            onPressed: () => notifier.startTimer(resource.id),
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始计时'),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _addQuick(context, ref, notifier, resource),
          icon: const Icon(Icons.edit),
          label: const Text('记一笔（时长 / 量）'),
        ),
        const SizedBox(height: AppSpacing.md),
        // 近 7 天趋势
        sessionsAsync.when(
          data: (sessions) => _buildTrend(sessions, color),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('记录', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        sessionsAsync.when(
          data: (sessions) => sessions.isEmpty
              ? const Text('还没有记录', style: AppTypography.caption)
              : Column(
                  children: [
                    for (final s in sessions) _SessionTile(s, resource),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载失败: $e'),
        ),
      ],
    );
  }

  /// 近 7 天每日学习时长趋势。
  Widget _buildTrend(List<StudySession> sessions, Color color) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final days = List.generate(
        7,
        (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    final values = <double>[];
    final labels = <String>[];
    for (final d in days) {
      final daySec = sessions
          .where((s) =>
              s.startedAt.year == d.year &&
              s.startedAt.month == d.month &&
              s.startedAt.day == d.day)
          .fold<double>(0, (sum, s) => sum + s.durationSeconds);
      values.add(daySec / 60.0); // 分钟
      labels.add('${d.month}/${d.day}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('近 7 天（分钟/天）', style: AppTypography.sectionLabel),
        const SizedBox(height: AppSpacing.sm),
        MiniTrendChart(values: values, color: color, labels: labels),
      ],
    );
  }

  void _addQuick(BuildContext context, WidgetRef ref, StudyNotifier notifier,
      StudyResource resource) {
    final minCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showAppModalSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('记一笔', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '时长(分钟)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: '完成量(${resource.goalUnit})',
                      border: const OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final mins = int.tryParse(minCtrl.text) ?? 0;
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                notifier.addSession(
                  resourceId: resource.id,
                  durationSeconds: mins * 60,
                  amount: amt,
                );
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile(this.session, this.resource);
  final StudySession session;
  final StudyResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = session.startedAt;
    final when =
        '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_outlined, color: AppColors.muted),
      title: Text(when),
      subtitle: Text(
        '${formatHmSeconds(session.durationSeconds.toInt())}'
        '${session.amount > 0 ? ' · ${session.amount}${resource.goalUnit}' : ''}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
        tooltip: '编辑',
        onPressed: () => _edit(context, ref),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final minCtrl = TextEditingController(
        text: (session.durationSeconds / 60).round().toString());
    final amtCtrl = TextEditingController(
        text: session.amount == session.amount.roundToDouble()
            ? session.amount.toInt().toString()
            : session.amount.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '时长(分钟)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: '完成量(${resource.goalUnit})'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存')),
        ],
      ),
    );
    final mins = int.tryParse(minCtrl.text);
    final amt = double.tryParse(amtCtrl.text);
    if (ok == true && mins != null && amt != null && mins > 0) {
      await ref.read(studyNotifierProvider.notifier).updateSession(
            sessionId: session.id,
            durationSeconds: mins * 60,
            amount: amt,
          );
      // 刷新详情面板数据
      ref.invalidate(studySessionsProvider(resource.id));
    }
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
