import '../entities/study_resource.dart';
import '../entities/study_session.dart';
import 'life_repository.dart'; // ActiveTimer（计时复用 LifeHabits 的 ActiveSessions 表）

/// 学习模块仓储接口（干净架构：feature/logic 依赖此接口，不直连 DB）。
abstract class StudyRepository {
  Future<List<StudyResource>> getResources();

  Future<StudyResource> addResource({
    required String name,
    required String category,
    required String iconName,
    required int colorArgb,
    required double goalAmount,
    required String goalUnit,
  });

  /// 删除资源并级联删除其全部学习记录（同步 delete 事件）。
  Future<void> deleteResource(String resourceId);

  Future<List<StudySession>> getSessions(String resourceId);

  /// 计时（复用全局唯一计时器 ActiveSessions；life/study 同一时刻只能有一个在进行）。
  Future<ActiveTimer?> getActiveSession();
  Future<void> startTimer(String resourceId);
  Future<int> stopTimer(String resourceId); // 返回时长秒；结算为一笔学习记录
  Future<void> cancelActiveSession(String resourceId);

  /// 记一笔（不计时）：直接写入一次学习记录。
  Future<void> addSession({
    required String resourceId,
    required int durationSeconds,
    required double amount,
    String? note,
  });

  /// 编辑一条学习记录（改时长/完成量，入 update 同步事件）。
  Future<void> updateSession({
    required String sessionId,
    required int durationSeconds,
    required double amount,
  });
}
