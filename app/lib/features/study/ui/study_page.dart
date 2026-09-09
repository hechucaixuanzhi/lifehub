import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/features/life/ui/habit_format.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/panels/detail_panel_controller.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/widgets/color_picker_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/section_label.dart';
import '../logic/study_notifier.dart';

/// 学习页（对齐原型：按分类分「在读 / 语言」两节 + ProgressIcon 网格）。
/// 作为 AppShell 的 Tab 内容 widget，不带自己的 Scaffold/AppBar/FAB。
class StudyPage extends ConsumerWidget {
  const StudyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyNotifierProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child:
            Text(state.error!, style: const TextStyle(color: AppColors.danger)),
      );
    }
    if (state.summaries.isEmpty) {
      return const EmptyState(icon: AppNavIcons.study, message: '还没有学习资源');
    }

    final inProgress = state.summaries
        .where(
            (s) => s.resource.category != '英语' && s.resource.category != '日语')
        .toList();
    final languages = state.summaries
        .where(
            (s) => s.resource.category == '英语' || s.resource.category == '日语')
        .toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(studyNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 顶部：新增资源入口
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _addResource(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          if (inProgress.isNotEmpty) ...[
            const SectionLabel('在读'),
            _grid(inProgress),
          ],
          if (languages.isNotEmpty) ...[
            const SectionLabel('语言'),
            _grid(languages),
          ],
        ],
      ),
    );
  }

  void _addResource(BuildContext context, WidgetRef ref) {
    var name = '';
    var category = studyCategories.first;
    var iconName = studyIconNames.first;
    var color = AppPalette.choices.first;
    final goalCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    showAppModalSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('新增学习资源', style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '名称', border: OutlineInputBorder()),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                    labelText: '分类', border: OutlineInputBorder()),
                items: [
                  for (final c in studyCategories)
                    DropdownMenuItem(value: c, child: Text(c))
                ],
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: iconName,
                decoration: const InputDecoration(
                    labelText: '图标', border: OutlineInputBorder()),
                items: [
                  for (final n in studyIconNames)
                    DropdownMenuItem(
                      value: n,
                      child: Row(children: [
                        Icon(studyIcon(n)),
                        const SizedBox(width: 8),
                        Text(n),
                      ]),
                    )
                ],
                onChanged: (v) => setState(() => iconName = v!),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: goalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '目标量', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                        labelText: '单位(页/章/…)', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('颜色', style: AppTypography.sectionLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              ColorPickerRow(
                selected: color,
                onSelect: (c) => setState(() => color = c),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final goal = double.tryParse(goalCtrl.text) ?? 0;
                  if (name.trim().isNotEmpty) {
                    ref.read(studyNotifierProvider.notifier).addResource(
                          name: name.trim(),
                          category: category,
                          iconName: iconName,
                          colorArgb: color.toARGB32(),
                          goalAmount: goal,
                          goalUnit: unitCtrl.text.trim(),
                        );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(List<ResourceSummary> list) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => _ResourceCell(summary: list[i]),
    );
  }
}

class _ResourceCell extends ConsumerWidget {
  const _ResourceCell({required this.summary});
  final ResourceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = summary.resource;
    final state = ref.watch(studyNotifierProvider);
    final isActive = state.activeResourceId == r.id;
    final progress = summary.progress == null ? 0.0 : summary.progress! / 100.0;
    final notifier = ref.read(studyNotifierProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // 单点：开始/停止计时（与生活页一致的状态反馈）
        if (isActive) {
          final secs = await notifier.stopTimer(r.id);
          if (context.mounted) {
            showAppToast(context, '${r.name} 结束 · ${formatHmSeconds(secs)}');
          }
        } else {
          await notifier.startTimer(r.id);
          if (context.mounted) {
            showAppToast(context, '${r.name} 开始计时');
          }
        }
      },
      onDoubleTap: () =>
          ref.read(detailPanelProvider.notifier).open(StudyPanelRequest(r.id)),
      onLongPress: () => _manualLog(context, ref, r.name),
      child: Center(
        child: ProgressIcon(
          icon: studyIcon(r.iconName),
          fillIcon: studyIconFill(r.iconName),
          color: Color(r.colorArgb),
          progress: progress,
          running: isActive,
          name: r.name,
          subtitle: summary.todayAmount > 0
              ? '今日 ${_fmt(summary.todayAmount)}${r.goalUnit}'
              : null,
        ),
      ),
    );
  }

  /// 长按补录：手动输入时长(分钟) 记录一笔。
  Future<void> _manualLog(
      BuildContext context, WidgetRef ref, String name) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('补录 $name'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '时长（分钟）'),
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
    final mins = int.tryParse(ctrl.text);
    if (ok == true && mins != null && mins > 0) {
      await ref.read(studyNotifierProvider.notifier).addSession(
            resourceId: summary.resource.id,
            durationSeconds: mins * 60,
            amount: 0,
          );
      if (context.mounted) {
        showAppToast(context, '已补录 $name $mins 分钟');
      }
    }
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
