import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/inbox_item.dart';
import '../../../domain/repositories/inbox_repository.dart';

final inboxRepositoryProvider =
    Provider<InboxRepository>((ref) => throw UnimplementedError());

final inboxNotifierProvider =
    NotifierProvider<InboxNotifier, List<InboxItem>>(InboxNotifier.new);

class InboxNotifier extends Notifier<List<InboxItem>> {
  @override
  List<InboxItem> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await ref.read(inboxRepositoryProvider).getItems();
  }

  Future<void> add(String content, {String kind = 'note'}) async {
    await ref.read(inboxRepositoryProvider).add(content, kind: kind);
    await _load();
  }

  Future<void> refresh() => _load();
}
