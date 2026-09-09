import '../entities/life_habit.dart';
import '../entities/life_habit_event.dart';

/// 进行中的计时（仅携带 habitId + 开始时刻，持久化在本地，可跨 App 重启恢复）。
class ActiveTimer {
  const ActiveTimer(this.habitId, this.startedAt);
  final String habitId;
  final DateTime startedAt;
}

/// 生活模块仓储接口（干净架构：feature/logic 依赖此接口，不直连 DB）。
abstract class LifeRepository {
  Future<List<LifeHabit>> getHabits();

  /// 各习惯「今日进度」，单位与 dailyTarget 一致：counter=次数，timer=分钟。
  Future<Map<String, double>> getTodayProgress();

  /// counter 型：记一笔 +1。
  Future<void> recordTap(String habitId);

  /// timer 型：开始计时（写入 active session；若已有别的在进行则先结算它）。
  Future<void> startTimer(String habitId);

  /// timer 型：结束计时，结算时长（秒），写入事件并入同步队列。返回时长秒。
  Future<int> stopTimer(String habitId);

  /// 当前进行中的计时（全局唯一），无则 null。
  Future<ActiveTimer?> getActiveSession();

  /// 取消进行中的计时（不结算，长按纠错用）。
  Future<void> cancelActiveSession(String habitId);

  /// 长按纠错：删除该习惯「今日」最近一条事件，入同步队列（delete）。
  Future<void> deleteLastEventToday(String habitId);

  /// 历史明细：最近 [days] 天该习惯的全部事件（含行为，供归属日分桶）。
  Future<List<LifeHabitEvent>> getHistory(String habitId, {int days = 30});

  /// 详情页改时长：更新某 timer 事件的值为 [seconds] 秒，入同步队列（update）。
  Future<void> updateEventDuration(String eventId, int seconds);

  /// 详情页删除指定事件（按 id），入同步队列（delete）。
  Future<void> deleteEvent(String eventId);
}
