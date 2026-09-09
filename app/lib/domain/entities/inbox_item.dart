/// 随手记收件箱条目（领域实体，与 Drift 的 InboxItemRow 解耦）。
class InboxItem {
  const InboxItem({
    required this.id,
    required this.content,
    required this.kind,
    required this.createdAt,
    required this.synced,
  });

  final String id;
  final String content;
  final String kind;
  final DateTime createdAt;
  final int synced;
}
