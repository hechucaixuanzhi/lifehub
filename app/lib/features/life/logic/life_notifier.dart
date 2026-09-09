import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/domain/entities/life_habit.dart';
import 'package:lifehub/domain/entities/life_habit_event.dart';
import 'package:lifehub/domain/repositories/life_repository.dart';

/// 习惯今日进度摘要（progressValue 单位与 dailyTarget 一致：counter=次数，timer=分钟）。
class HabitSummary {
  const HabitSummary(this.habit, this.progressValue);
  final LifeHabit habit;
  final double progressValue;
  bool get reached => progressValue >= habit.dailyTarget;
}

/// 生活页状态：习惯摘要列表 + 当前进行中的计时（全局唯一）+ 加载/错误态。
class LifeState {
  const LifeState(
    this.summaries,
    this.activeHabitId,
    this.activeStartedAt, {
    this.loading = false,
    this.error,
  });
  final List<HabitSummary> summaries;
  final String? activeHabitId;
  final DateTime? activeStartedAt;
  final bool loading;
  final String? error;
}

final lifeRepositoryProvider =
    Provider<LifeRepository>((ref) => throw UnimplementedError());

final lifeNotifierProvider =
    NotifierProvider<LifeNotifier, LifeState>(LifeNotifier.new);

/// 某习惯的历史事件（详情页用，可 ref.refresh 刷新）。
final habitHistoryProvider = FutureProvider.family<List<LifeHabitEvent>, String>(
  (ref, habitId) => ref.watch(lifeRepositoryProvider).getHistory(habitId),
);

class LifeNotifier extends Notifier<LifeState> {
  @override
  LifeState build() {
    _load();
    return const LifeState([], null, null, loading: true);
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(lifeRepositoryProvider);
      final habits = await repo.getHabits();
      final progress = await repo.getTodayProgress();
      final active = await repo.getActiveSession();
      state = LifeState(
        habits.map((h) => HabitSummary(h, progress[h.id] ?? 0)).toList(),
        active?.habitId,
        active?.startedAt,
      );
    } catch (e) {
      // 加载失败不再卡在 loading：暴露错误，便于定位（不静默吞掉）。
      state = const LifeState([], null, null, error: '加载失败，请重试');
    }
  }

  Future<void> recordTap(String habitId) async {
    await ref.read(lifeRepositoryProvider).recordTap(habitId);
    await _load();
  }

  Future<void> startTimer(String habitId) async {
    await ref.read(lifeRepositoryProvider).startTimer(habitId);
    await _load();
  }

  Future<int> stopTimer(String habitId) async {
    final secs = await ref.read(lifeRepositoryProvider).stopTimer(habitId);
    await _load();
    return secs;
  }

  Future<void> cancelTimer(String habitId) async {
    await ref.read(lifeRepositoryProvider).cancelActiveSession(habitId);
    await _load();
  }

  Future<void> deleteLastEventToday(String habitId) async {
    await ref.read(lifeRepositoryProvider).deleteLastEventToday(habitId);
    await _load();
  }

  Future<void> refresh() => _load();
}
