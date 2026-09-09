import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/panels/detail_panel_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/widgets/habit_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/section_label.dart';
import '../logic/life_notifier.dart';
import 'habit_format.dart';

/// 生活页（对齐原型：纯图标状态填充网格，无数字）。
/// 作为 AppShell 的 Tab 内容 widget，不带自己的 Scaffold/AppBar/FAB。
class LifePage extends ConsumerWidget {
  const LifePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lifeNotifierProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
          child: Text(state.error!,
              style: const TextStyle(color: AppColors.danger)));
    }
    if (state.summaries.isEmpty) {
      return const EmptyState(
          icon: PhosphorIconsRegular.house, message: '还没有习惯');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(lifeNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SectionLabel('今天'),
          // 3 列图标网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: state.summaries.length,
            itemBuilder: (context, i) => _HabitCell(
              summary: state.summaries[i],
              isActive: state.activeHabitId == state.summaries[i].habit.id,
              notifier: ref.read(lifeNotifierProvider.notifier),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCell extends ConsumerWidget {
  const _HabitCell({
    required this.summary,
    required this.isActive,
    required this.notifier,
  });
  final HabitSummary summary;
  final bool isActive;
  final LifeNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = summary.habit;
    final progress = habit.dailyTarget > 0
        ? (summary.progressValue / habit.dailyTarget).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(context),
      onDoubleTap: () {
        // 打开详情前先失效历史缓存，确保显示最新记录（点完立即进详情能看到）
        ref.invalidate(habitHistoryProvider(habit.id));
        ref
            .read(detailPanelProvider.notifier)
            .open(HabitPanelRequest(habit.id));
      },
      onLongPress: () => _longPress(context, ref),
      child: Center(
        child: HabitIcon(
          icon: habitIcon(habit.iconName),
          fillIcon: habitIconFill(habit.iconName),
          color: Color(habit.colorArgb),
          progress: progress,
          running: isActive,
          reached: summary.reached,
          name: habit.name,
        ),
      ),
    );
  }

  Future<void> _tap(BuildContext context) async {
    final habit = summary.habit;
    final String? msg;
    if (isActive) {
      final secs = await notifier.stopTimer(habit.id);
      msg = '${habit.name} 结束 · ${formatHmSeconds(secs)}';
    } else if (habit.isTimer) {
      await notifier.startTimer(habit.id);
      msg = '${habit.name} 开始计时';
    } else {
      await notifier.recordTap(habit.id);
      msg = '${habit.name} +1';
    }
    if (context.mounted) {
      showAppToast(context, msg);
    }
  }

  Future<void> _longPress(BuildContext context, WidgetRef ref) async {
    // 长按菜单：历史（进详情）/ 删除今日记录。
    final habit = summary.habit;
    final action = await showAppModalSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('查看历史'),
              onTap: () => Navigator.of(ctx).pop('history'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除今日记录',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'history') {
      ref.read(detailPanelProvider.notifier).open(HabitPanelRequest(habit.id));
    } else if (action == 'delete') {
      await notifier.deleteLastEventToday(habit.id);
      if (context.mounted) {
        showAppToast(context, '已删除今日记录');
      }
    }
  }
}
