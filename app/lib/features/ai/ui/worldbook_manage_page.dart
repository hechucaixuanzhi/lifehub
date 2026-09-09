import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../ai_providers.dart';
import '../models/worldbook.dart';
import 'worldbook_detail_page.dart';

/// 世界书库（通讯录「标签」）：独立的世界设定实体，建群时可选引用。
/// 列表 + 新建/删除；点行进详情页（世界信息编辑 + 卡片分区）。
class WorldbookManagePage extends ConsumerWidget {
  const WorldbookManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(worldbooksProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: const Text('世界书',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _create(context),
            tooltip: '新建世界书',
          ),
        ],
      ),
      body: books.isEmpty ? const _WorldbookEmpty() : _buildList(context, ref, books),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Worldbook> books,
  ) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 36),
      children: [
        Container(
          color: Colors.white,
          child: Column(
            children: [
              for (var i = 0; i < books.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                _WorldbookRow(
                  book: books[i],
                  onTap: () => _open(context, ref, books[i]),
                  onDelete: () => _delete(context, ref, books[i]),
                ),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '群聊可引用一本世界书：群成员会在本体人格之上叠加「从现实穿越到这个世界」的认知。不选 = 现实世界。',
            style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  /// 新建：进详情页（先填世界信息创建，再在里面加卡片）。
  static void _create(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const WorldbookDetailPage()),
    );
  }

  static void _open(BuildContext context, WidgetRef ref, Worldbook book) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => WorldbookDetailPage(bookId: book.id)),
    );
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Worldbook book,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除世界书'),
        content: Text(
          '确定删除「${book.name}」吗？\n引用它的群聊会切回现实世界，群聊本身不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFE64340)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final response = await ref
          .read(apiProvider)
          .delete('/worldbooks/${book.id}')
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError('delete failed: ${response.statusCode}');
      }
      ref.read(worldbooksProvider.notifier).removeLocal(book.id);
      if (context.mounted) showAppToast(context, '已删除「${book.name}」');
    } on Object {
      if (context.mounted) showAppToast(context, '删除失败，请重试');
    }
  }
}

class _WorldbookEmpty extends StatelessWidget {
  const _WorldbookEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, size: 56, color: Color(0xFFC8C8C8)),
          const SizedBox(height: 12),
          Text(
            '还没有世界书',
            style: TextStyle(fontSize: 16, color: Color(0xFF737373)),
          ),
          const SizedBox(height: 6),
          Text(
            '点右上角 + 新建一本，建群时就能让角色穿越进去',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _WorldbookRow extends StatelessWidget {
  const _WorldbookRow({
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  final Worldbook book;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.public, size: 22, color: Color(0xFF2782D7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, color: Color(0xFF111111)),
                  ),
                  if (book.summary.isNotEmpty)
                    Text(
                      book.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (book.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${book.cards.length} 张卡',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
              ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: Color(0xFF9A9A9A)),
              tooltip: '删除',
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC8C8C8)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
