import '../entities/inbox_item.dart';

/// 随手记收件箱仓储接口。
abstract class InboxRepository {
  Future<List<InboxItem>> getItems();
  Future<void> add(String content, {String kind = 'note'});
}
