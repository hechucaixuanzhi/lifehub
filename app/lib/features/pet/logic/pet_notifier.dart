import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifehub/domain/entities/pet.dart';
import 'package:lifehub/domain/entities/pet_log.dart';
import 'package:lifehub/domain/repositories/pet_repository.dart';

class PetState {
  const PetState(this.pets, {this.loading = false, this.error});
  final List<Pet> pets;
  final bool loading;
  final String? error;
}

final petRepositoryProvider =
    Provider<PetRepository>((ref) => throw UnimplementedError());

final petNotifierProvider =
    NotifierProvider<PetNotifier, PetState>(PetNotifier.new);

/// 某宠物的全部记录（30 天，详情页用，可 ref.refresh 刷新）。
final petLogsProvider = FutureProvider.family<List<PetLog>, String>(
  (ref, petId) => ref.watch(petRepositoryProvider).getLogs(petId),
);

class PetNotifier extends Notifier<PetState> {
  @override
  PetState build() {
    _load();
    return const PetState([], loading: true);
  }

  Future<void> _load() async {
    try {
      state = PetState(await ref.read(petRepositoryProvider).getPets());
    } catch (e) {
      // 加载失败不再卡在 loading：暴露错误，便于定位（不静默吞掉）。
      state = const PetState([], error: '加载失败，请重试');
    }
  }

  Future<void> addPet({
    required String name,
    required String species,
    String? avatarPath,
  }) async {
    await ref
        .read(petRepositoryProvider)
        .addPet(name: name, species: species, avatarPath: avatarPath);
    await _load();
  }

  Future<void> deletePet(String petId) async {
    await ref.read(petRepositoryProvider).deletePet(petId);
    await _load();
  }

  Future<void> updateLog({
    required String logId,
    required String content,
    double? value,
  }) async {
    await ref.read(petRepositoryProvider).updateLog(
          logId: logId,
          content: content,
          value: value,
        );
  }

  Future<void> refresh() => _load();
}
