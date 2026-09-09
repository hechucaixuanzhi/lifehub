import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/features/life/ui/habit_format.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/mini_trend_chart.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../domain/entities/exercise_type.dart';
import '../../../domain/entities/exercise_session.dart';
import '../logic/exercise_notifier.dart';

/// 运动详情面板（DetailSheet 内容）：今日统计 + 记一笔 + 历史。
/// 无 Scaffold/AppBar，由 DetailSheet 承载。
class ExerciseDetailPanel extends ConsumerWidget {
  const ExerciseDetailPanel({super.key, required this.typeId});
  final String typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(exerciseNotifierProvider.notifier);
    final state = ref.watch(exerciseNotifierProvider);
    final summary = state.summaries.where((s) => s.type.id == typeId).isEmpty
        ? null
        : state.summaries.firstWhere((s) => s.type.id == typeId);
    final type = summary?.type;
    final sessionsAsync = ref.watch(exerciseSessionsProvider(typeId));

    if (type == null || summary == null) {
      return const Center(child: Text('类型不存在', style: AppTypography.caption));
    }
    final t = type;
    final s = summary;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            StatTile(label: '今日次数', value: '${s.todayCount}${t.countUnit}'),
            StatTile(
                label: '今日时长', value: formatHmSeconds(s.todaySeconds.toInt())),
            StatTile(
                label: '今日距离',
                value: _fmtDistance(s.todayDistance, t.distanceUnit)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => _record(context, ref, notifier, t),
          icon: const Icon(Icons.add),
          label: const Text('记一笔'),
        ),
        const SizedBox(height: AppSpacing.md),
        // 近 7 天趋势
        sessionsAsync.when(
          data: (sessions) => _buildTrend(sessions, t),
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
                    for (final session in sessions) _SessionTile(session, t),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载失败: $e'),
        ),
      ],
    );
  }

  /// 近 7 天每日趋势（优先里程，无距离则按时长）。
  Widget _buildTrend(List<ExerciseSession> sessions, ExerciseType type) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final days = List.generate(
        7,
        (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    final values = <double>[];
    final labels = <String>[];
    final useDistance = type.hasDistance && type.distanceUnit == 'km';
    for (final d in days) {
      double dayV = 0;
      for (final s in sessions) {
        if (s.occurredAt.year == d.year &&
            s.occurredAt.month == d.month &&
            s.occurredAt.day == d.day) {
          dayV += useDistance
              ? s.distanceMeters / 1000.0
              : s.durationSeconds / 60.0;
        }
      }
      values.add(dayV);
      labels.add('${d.month}/${d.day}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('近 7 天（${useDistance ? 'km/天' : '分钟/天'}）',
            style: AppTypography.sectionLabel),
        const SizedBox(height: AppSpacing.sm),
        MiniTrendChart(
            values: values, color: Color(type.colorArgb), labels: labels),
      ],
    );
  }

  void _record(BuildContext context, WidgetRef ref, ExerciseNotifier notifier,
      ExerciseType type) {
    final countCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('记一笔', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            if (type.hasCount)
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: '次数(${type.countUnit})',
                    border: const OutlineInputBorder()),
              ),
            if (type.hasCount) const SizedBox(height: AppSpacing.md),
            if (type.hasTime)
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: '时长(分钟)', border: OutlineInputBorder()),
              ),
            if (type.hasTime) const SizedBox(height: AppSpacing.md),
            if (type.hasDistance)
              TextField(
                controller: kmCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '距离(${type.distanceUnit})',
                    border: const OutlineInputBorder()),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(countCtrl.text) ?? 0;
                final minutes = int.tryParse(minCtrl.text) ?? 0;
                final km = double.tryParse(kmCtrl.text) ?? 0;
                final meters = type.distanceUnit == 'km'
                    ? (km * 1000).toInt()
                    : km.toInt();
                notifier.addSession(
                  typeId: type.id,
                  count: count,
                  durationSeconds: minutes * 60,
                  distanceMeters: meters.toDouble(),
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
  const _SessionTile(this.session, this.type);
  final ExerciseSession session;
  final ExerciseType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = session.occurredAt;
    final when =
        '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final parts = <String>[];
    if (type.hasCount) parts.add('${session.count}${type.countUnit}');
    if (session.sets != null && session.sets! > 0)
      parts.add('${session.sets}组');
    if (session.weightKg != null && session.weightKg! > 0)
      parts.add('${session.weightKg}kg');
    if (type.hasTime)
      parts.add(formatHmSeconds(session.durationSeconds.toInt()));
    if (type.hasDistance) {
      parts.add(_fmtDistance(session.distanceMeters, type.distanceUnit));
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_outlined, color: AppColors.muted),
      title: Text(when),
      subtitle: Text(parts.isEmpty ? '记录' : parts.join(' · ')),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
        tooltip: '编辑',
        onPressed: () => _edit(context, ref),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final countCtrl = TextEditingController(text: '${session.count}');
    final minCtrl = TextEditingController(
        text: (session.durationSeconds / 60).round().toString());
    final kmCtrl = TextEditingController(
        text: session.distanceMeters <= 0
            ? ''
            : type.distanceUnit == 'km'
                ? (session.distanceMeters / 1000).toStringAsFixed(2)
                : session.distanceMeters.toString());
    final setsCtrl = TextEditingController(
        text: session.sets != null ? '${session.sets}' : '');
    final weightCtrl = TextEditingController(
        text: session.weightKg != null ? '${session.weightKg}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type.hasCount)
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '次数(${type.countUnit})'),
              ),
            if (type.hasCount) const SizedBox(height: 12),
            if (type.hasTime)
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '时长(分钟)'),
              ),
            if (type.hasTime) const SizedBox(height: 12),
            if (type.hasDistance)
              TextField(
                controller: kmCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: '距离(${type.distanceUnit})'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '组数(可选)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '重量kg(可选)'),
                  ),
                ),
              ],
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
    if (ok == true) {
      final count = int.tryParse(countCtrl.text) ?? session.count;
      final minutes =
          int.tryParse(minCtrl.text) ?? (session.durationSeconds / 60).round();
      final km = double.tryParse(kmCtrl.text) ?? 0;
      final meters =
          type.distanceUnit == 'km' ? (km * 1000).toInt() : km.toInt();
      final sets = int.tryParse(setsCtrl.text);
      final weight = double.tryParse(weightCtrl.text);
      await ref.read(exerciseNotifierProvider.notifier).updateSession(
            sessionId: session.id,
            count: count,
            durationSeconds: minutes * 60,
            distanceMeters: meters.toDouble(),
            sets: sets,
            weightKg: weight,
          );
      ref.invalidate(exerciseSessionsProvider(type.id));
    }
  }
}

String _fmtDistance(double meters, String unit) {
  if (unit == 'km') {
    final km = meters / 1000;
    return km == km.roundToDouble()
        ? '${km.toInt()}km'
        : '${km.toStringAsFixed(2)}km';
  }
  return '${meters.toInt()}$unit';
}
