import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/domain/entities/exercise_session.dart';
import 'package:lifehub/domain/entities/exercise_type.dart';
import 'package:lifehub/domain/repositories/exercise_repository.dart';

/// 类型摘要：今日 / 总计（次数 / 时长 / 距离）。
class TypeSummary {
  const TypeSummary(
    this.type,
    this.todayCount,
    this.todaySeconds,
    this.todayDistance,
    this.totalCount,
    this.totalSeconds,
    this.totalDistance,
  );
  final ExerciseType type;
  final int todayCount;
  final double todaySeconds;
  final double todayDistance;
  final int totalCount;
  final double totalSeconds;
  final double totalDistance;

  double get todayMinutes => todaySeconds / 60;
  double get totalKm => totalDistance / 1000;
}

class ExerciseState {
  const ExerciseState(this.summaries, {this.loading = false, this.error});
  final List<TypeSummary> summaries;
  final bool loading;
  final String? error;
}

final exerciseRepositoryProvider =
    Provider<ExerciseRepository>((ref) => throw UnimplementedError());

final exerciseNotifierProvider =
    NotifierProvider<ExerciseNotifier, ExerciseState>(ExerciseNotifier.new);

/// 某类型的全部运动记录（详情页用，可 ref.refresh 刷新）。
final exerciseSessionsProvider =
    FutureProvider.family<List<ExerciseSession>, String>(
  (ref, typeId) =>
      ref.watch(exerciseRepositoryProvider).getSessions(typeId),
);

class ExerciseNotifier extends Notifier<ExerciseState> {
  @override
  ExerciseState build() {
    _load();
    return const ExerciseState([], loading: true);
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(exerciseRepositoryProvider);
      final types = await repo.getTypes();
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final summaries = <TypeSummary>[];
      for (final t in types) {
        final sessions = await repo.getSessions(t.id);
        var tc = 0, ttC = 0;
        var ts = 0.0, td = 0.0, ttS = 0.0, ttD = 0.0;
        for (final s in sessions) {
          ttC += s.count;
          ttS += s.durationSeconds;
          ttD += s.distanceMeters;
          if (!s.occurredAt.isBefore(dayStart)) {
            tc += s.count;
            ts += s.durationSeconds;
            td += s.distanceMeters;
          }
        }
        summaries.add(TypeSummary(t, tc, ts, td, ttC, ttS, ttD));
      }
      state = ExerciseState(summaries);
    } catch (e) {
      // 加载失败不再卡在 loading：暴露错误，便于定位（不静默吞掉）。
      state = const ExerciseState([], error: '加载失败，请重试');
    }
  }

  Future<void> addType({
    required String name,
    required String iconName,
    required List<String> metrics,
    required String countUnit,
    required String distanceUnit,
    required int colorArgb,
  }) async {
    await ref.read(exerciseRepositoryProvider).addType(
          name: name,
          iconName: iconName,
          metrics: metrics,
          countUnit: countUnit,
          distanceUnit: distanceUnit,
          colorArgb: colorArgb,
        );
    await _load();
  }

  Future<void> deleteType(String typeId) async {
    await ref.read(exerciseRepositoryProvider).deleteType(typeId);
    await _load();
  }

  Future<void> addSession({
    required String typeId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
    String? note,
  }) async {
    await ref.read(exerciseRepositoryProvider).addSession(
          typeId: typeId,
          count: count,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
          sets: sets,
          weightKg: weightKg,
          note: note,
        );
    await _load();
  }

  Future<void> updateSession({
    required String sessionId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
  }) async {
    await ref.read(exerciseRepositoryProvider).updateSession(
          sessionId: sessionId,
          count: count,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
          sets: sets,
          weightKg: weightKg,
        );
    await _load();
  }

  Future<void> refresh() => _load();
}
