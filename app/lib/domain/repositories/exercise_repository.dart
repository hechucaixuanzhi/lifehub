import '../entities/exercise_type.dart';
import '../entities/exercise_session.dart';

/// 运动模块仓储接口（手动记录，无 Health Connect；Health Connect 属 v0.3）。
abstract class ExerciseRepository {
  Future<List<ExerciseType>> getTypes();

  Future<ExerciseType> addType({
    required String name,
    required String iconName,
    required List<String> metrics, // count|time|distance 子集
    required String countUnit,
    required String distanceUnit,
    required int colorArgb,
  });

  /// 删除类型并级联删除其全部运动记录（同步 delete 事件）。
  Future<void> deleteType(String typeId);

  Future<List<ExerciseSession>> getSessions(String typeId);

  /// 记一笔运动：次数 / 时长秒 / 距离米，按需填（按 metrics 决定可填字段）。
  /// 健身动作可传 sets（组数）/ weightKg（重量 kg）。
  Future<void> addSession({
    required String typeId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
    String? note,
  });

  /// 编辑一条运动记录（入 update 同步事件）。
  Future<void> updateSession({
    required String sessionId,
    required int count,
    required int durationSeconds,
    required double distanceMeters,
    int? sets,
    double? weightKg,
  });
}
