import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/life_habit.dart';
import '../../../domain/entities/life_habit_event.dart';
import '../logic/life_notifier.dart';
import 'habit_format.dart';

/// 习惯详情面板（DetailSheet 内容）：30 天热度条 + 选中日事件列表。
/// 无 Scaffold/AppBar，由 DetailSheet 承载。
class HabitDetailPanel extends ConsumerStatefulWidget {
  const HabitDetailPanel({super.key, required this.habitId});
  final String habitId;

  @override
  ConsumerState<HabitDetailPanel> createState() => _HabitDetailPanelState();
}

class _HabitDetailPanelState extends ConsumerState<HabitDetailPanel> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedDay = DateTime(n.year, n.month, n.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final habitAsync = ref.watch(habitProvider(widget.habitId));
    return habitAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (habit) {
        final eventsAsync = ref.watch(habitHistoryProvider(widget.habitId));
        return eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (events) => _buildBody(habit, events),
        );
      },
    );
  }

  Widget _buildBody(LifeHabit habit, List<LifeHabitEvent> events) {
    final now = DateTime.now();
    final days = List.generate(
      30,
      (i) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 29 - i)),
    );
    final selectedEvents = events
        .where((e) => _sameDay(e.effectiveDay, _selectedDay))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    double dayProgress(DateTime day) {
      final evs = events.where((e) => _sameDay(e.effectiveDay, day));
      if (habit.isTimer) {
        final secs = evs.fold(0, (s, e) => s + e.amount);
        return (secs / 60) / habit.dailyTarget;
      }
      return evs.length / habit.dailyTarget;
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: days.map((d) {
            final ratio = dayProgress(d).clamp(0.0, 1.0);
            final isSel = _sameDay(d, _selectedDay);
            return GestureDetector(
              onTap: () => setState(() => _selectedDay = d),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: isSel
                      ? Border.all(color: AppColors.accent, width: 2)
                      : null,
                  color: Color(habit.colorArgb).withAlpha(
                      (40 + ratio * 180).clamp(0, 255).toInt()),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('${_selectedDay.month}月${_selectedDay.day}日', style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        if (selectedEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text('当天暂无记录', style: AppTypography.caption),
            ),
          )
        else
          ...selectedEvents.map((e) => _EventRow(
                habit: habit,
                event: e,
                onChanged: () {
                  ref.invalidate(habitHistoryProvider(widget.habitId));
                  ref.read(lifeNotifierProvider.notifier).refresh();
                },
              )),
      ],
    );
  }
}

/// 习惯实体读取 Provider（DetailSheet 从 habitId 反查实体）。
final habitProvider = FutureProvider.family<LifeHabit, String>(
  (ref, habitId) async {
    final repo = ref.watch(lifeRepositoryProvider);
    final habits = await repo.getHabits();
    return habits.firstWhere((h) => h.id == habitId);
  },
);

class _EventRow extends ConsumerWidget {
  const _EventRow({
    required this.habit,
    required this.event,
    required this.onChanged,
  });
  final LifeHabit habit;
  final LifeHabitEvent event;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time =
        '${event.occurredAt.hour.toString().padLeft(2, '0')}:${event.occurredAt.minute.toString().padLeft(2, '0')}';
    final valueText = habit.isTimer
        ? formatHmSeconds(event.amount)
        : '${event.amount} ${habit.unit}';
    return ListTile(
      leading: Icon(habitIcon(habit.iconName), color: Color(habit.colorArgb)),
      title: Text(time),
      subtitle: Text(valueText),
      // 明确的操作按钮：timer 可编辑时长，所有行可删除（长按也可删）
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (habit.isTimer)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
              tooltip: '修改时长',
              onPressed: () => _editDuration(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  Future<void> _editDuration(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: (event.amount / 60).round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改时长（分钟）'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '例如 45'),
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
    final minutes = int.tryParse(controller.text);
    if (ok == true && minutes != null && minutes > 0) {
      await ref
          .read(lifeRepositoryProvider)
          .updateEventDuration(event.id, minutes * 60);
      onChanged();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该记录'),
        content: const Text('确定删除这条记录？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(lifeRepositoryProvider).deleteEvent(event.id);
      onChanged();
    }
  }
}
