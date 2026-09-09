import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/domain/entities/study_resource.dart';
import 'package:lifehub/domain/entities/study_session.dart';
import 'package:lifehub/domain/repositories/study_repository.dart';

/// 资源摘要：今日 / 总计（时长、完成量）+ 进度%。
class ResourceSummary {
  const ResourceSummary(
    this.resource,
    this.todaySeconds,
    this.todayAmount,
    this.totalSeconds,
    this.totalAmount,
  );
  final StudyResource resource;
  final double todaySeconds;
  final double todayAmount;
  final double totalSeconds;
  final double totalAmount;

  double get todayMinutes => todaySeconds / 60;
  double get totalHours => totalSeconds / 3600;

  /// 进度%：按目标量（goalAmount）。无目标返回 null（不显示进度环）。
  double? get progress {
    if (!resource.hasGoal || resource.goalAmount <= 0) return null;
    return (totalAmount / resource.goalAmount * 100).clamp(0, 100);
  }
}

class StudyState {
  const StudyState(this.summaries, this.activeResourceId, this.activeStartedAt,
      {this.loading = false, this.error});
  final List<ResourceSummary> summaries;
  final String? activeResourceId;
  final DateTime? activeStartedAt;
  final bool loading;
  final String? error;
}

final studyRepositoryProvider =
    Provider<StudyRepository>((ref) => throw UnimplementedError());

final studyNotifierProvider =
    NotifierProvider<StudyNotifier, StudyState>(StudyNotifier.new);

/// 某资源的全部学习记录（详情页用，可 ref.refresh 刷新）。
final studySessionsProvider = FutureProvider.family<List<StudySession>, String>(
  (ref, resourceId) =>
      ref.watch(studyRepositoryProvider).getSessions(resourceId),
);

class StudyNotifier extends Notifier<StudyState> {
  @override
  StudyState build() {
    _load();
    return const StudyState([], null, null, loading: true);
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(studyRepositoryProvider);
      final resources = await repo.getResources();
      final active = await repo.getActiveSession();
      final resourceIds = resources.map((r) => r.id).toSet();
      final summaries = <ResourceSummary>[];
      for (final r in resources) {
        final sessions = await repo.getSessions(r.id);
        final now = DateTime.now();
        final dayStart = DateTime(now.year, now.month, now.day);
        var todaySec = 0.0, todayAmt = 0.0, totalSec = 0.0, totalAmt = 0.0;
        for (final s in sessions) {
          totalSec += s.durationSeconds;
          totalAmt += s.amount;
          if (!s.startedAt.isBefore(dayStart)) {
            todaySec += s.durationSeconds;
            todayAmt += s.amount;
          }
        }
        summaries
            .add(ResourceSummary(r, todaySec, todayAmt, totalSec, totalAmt));
      }
      final activeId = active != null && resourceIds.contains(active.habitId)
          ? active.habitId
          : null;
      state = StudyState(
        summaries,
        activeId,
        activeId != null ? active!.startedAt : null,
      );
    } catch (e) {
      // 加载失败不再卡在 loading：暴露错误，便于定位（不静默吞掉）。
      state = const StudyState([], null, null, error: '加载失败，请重试');
      // 开发期排查：debugPrint('study _load error: $e');
    }
  }

  Future<void> addResource({
    required String name,
    required String category,
    required String iconName,
    required int colorArgb,
    required double goalAmount,
    required String goalUnit,
  }) async {
    await ref.read(studyRepositoryProvider).addResource(
          name: name,
          category: category,
          iconName: iconName,
          colorArgb: colorArgb,
          goalAmount: goalAmount,
          goalUnit: goalUnit,
        );
    await _load();
  }

  Future<void> deleteResource(String resourceId) async {
    await ref.read(studyRepositoryProvider).deleteResource(resourceId);
    await _load();
  }

  Future<void> startTimer(String resourceId) async {
    await ref.read(studyRepositoryProvider).startTimer(resourceId);
    await _load();
  }

  Future<int> stopTimer(String resourceId) async {
    final secs = await ref.read(studyRepositoryProvider).stopTimer(resourceId);
    await _load();
    return secs;
  }

  Future<void> cancelTimer(String resourceId) async {
    await ref.read(studyRepositoryProvider).cancelActiveSession(resourceId);
    await _load();
  }

  Future<void> addSession({
    required String resourceId,
    required int durationSeconds,
    required double amount,
    String? note,
  }) async {
    await ref.read(studyRepositoryProvider).addSession(
          resourceId: resourceId,
          durationSeconds: durationSeconds,
          amount: amount,
          note: note,
        );
    await _load();
  }

  Future<void> updateSession({
    required String sessionId,
    required int durationSeconds,
    required double amount,
  }) async {
    await ref.read(studyRepositoryProvider).updateSession(
          sessionId: sessionId,
          durationSeconds: durationSeconds,
          amount: amount,
        );
    await _load();
  }

  Future<void> refresh() => _load();
}
