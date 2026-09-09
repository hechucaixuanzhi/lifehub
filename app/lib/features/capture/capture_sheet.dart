import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/swipe_back_dismiss.dart';
import '../inbox/logic/inbox_notifier.dart';

/// 全局「记一笔」捕获 Sheet（对齐原型捕获弹层）。
/// v0.3 最简形态：文字输入 → 写随手记收件箱。
/// 分类 chips（生活/学习/运动/宠物）语义后置——待用户想清与后续需求的关系再设计。
class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key});

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('记一笔', style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '此刻在想什么 / 做了什么',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                await ref.read(inboxNotifierProvider.notifier).add(text);
                if (!context.mounted) return;
                Navigator.pop(context);
                showAppToast(context, '已记录到收件箱');
              },
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 展示全局捕获 Sheet 的辅助函数。
Future<void> showCaptureSheet(BuildContext context) {
  return showAppModalSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    backgroundColor: AppColors.surface,
    builder: (_) => const CaptureSheet(),
  );
}
