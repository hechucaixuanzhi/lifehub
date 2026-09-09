import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../logic/inbox_notifier.dart';

/// 随手记收件箱（从「我的」进入的全屏页）。
/// 卡片列表 + 类型过滤 chips。
class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  String _filter = '全部';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inboxNotifierProvider);
    final kinds = {'全部', ...items.map((e) => e.kind)};
    final filtered = _filter == '全部'
        ? items
        : items.where((e) => e.kind == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('随手记收件箱')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final k in kinds)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(k),
                      selected: _filter == k,
                      onSelected: (_) => setState(() => _filter = k),
                      selectedColor: AppColors.accentSoft,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _filter == k ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: AppNavIcons.plus,
                    message: '还没有随手记',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = filtered[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppElevation.e1,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.content, style: AppTypography.body),
                            const SizedBox(height: 6),
                            Text(
                              '${it.kind} · ${_when(it.createdAt)}',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _when(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
