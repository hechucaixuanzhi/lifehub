import '../entities/pet.dart';
import '../entities/pet_log.dart';

/// 宠物模块仓储接口（猫优先；照片存手机本地文档目录，仅记路径）。
abstract class PetRepository {
  Future<List<Pet>> getPets();

  Future<Pet> addPet({
    required String name,
    required String species,
    String? avatarPath,
  });

  /// 删除宠物并级联删除其全部记录（同步 delete 事件）。
  Future<void> deletePet(String petId);

  Future<List<PetLog>> getLogs(String petId, {int days = 30});

  /// 记一笔：kind = text|weight|health|photo。photo 时传 mediaAssetId。
  Future<void> addLog({
    required String petId,
    required String kind,
    required String content,
    double? value,
    String? mediaAssetId,
    String? note,
  });

  /// 编辑一条宠物记录（改内容/体重值，入 update 同步事件）。
  Future<void> updateLog({
    required String logId,
    required String content,
    double? value,
  });
}
