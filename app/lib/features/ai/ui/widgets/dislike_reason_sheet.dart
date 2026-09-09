import 'package:flutter/material.dart';

import 'feedback.dart';

/// 点踩面板提交结果：多选原因码 + 自由填写文本。
class DislikeResult {
  const DislikeResult(this.reasons, this.customFeedback);

  final List<String> reasons;
  final String customFeedback;
}

/// 点踩原因多选面板（用户定稿设计）：
/// - 7 个多选 chip（不展开输入框，保持轻）
/// - 「+ 写点建议（可选）」点击展开 TextField（自由填写，替换「其他」的黄金信息）
/// - 提交 → Navigator.pop(DislikeResult)；下滑/取消返回 null。
///
/// 与 [showAppModalSheet] 搭配使用（isScrollControlled: true），
/// 键盘弹起时底部跟随上移。
class DislikeReasonSheet extends StatefulWidget {
  const DislikeReasonSheet({
    super.key,
    this.initialReasons = const [],
    this.initialCustom = '',
  });

  /// 预选原因码（改主意/编辑时传入既有原因；新点踩传 analyze 候选）。
  final List<String> initialReasons;

  /// 预填自由文本（编辑既有 custom_feedback 时）。
  final String initialCustom;

  @override
  State<DislikeReasonSheet> createState() => _DislikeReasonSheetState();
}

class _DislikeReasonSheetState extends State<DislikeReasonSheet> {
  late final Set<String> _selected = {...widget.initialReasons};
  late bool _showCustom = widget.initialCustom.isNotEmpty;
  late final TextEditingController _customCtrl =
      TextEditingController(text: widget.initialCustom);

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context)
        .pop(DislikeResult(_selected.toList(), _customCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹起时把面板顶上去，输入框不被遮挡。
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽把手
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('为什么不满意？',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F1F))),
              const SizedBox(height: 4),
              const Text('多选，告诉 AI 哪里不对',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A))),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in kFeedbackReasons)
                    _ReasonChip(
                      label: reason.label,
                      selected: _selected.contains(reason.code),
                      onTap: () => setState(() {
                        if (!_selected.add(reason.code)) {
                          _selected.remove(reason.code);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_showCustom)
                _AddSuggestionButton(
                  onTap: () => setState(() => _showCustom = true),
                )
              else
                TextField(
                  controller: _customCtrl,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: '还有其他想法吗？（可选）',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Color(0xFF9A9A9A)),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('提交',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 微信风多选 chip：选中绿底绿框 + ✓，未选中浅灰。
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F3EC) : const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF07C160) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Color(0xFF07C160)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color:
                    selected ? const Color(0xFF0A7A45) : const Color(0xFF333333),
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「+ 写点建议（可选）」：点击展开自由填写输入框，保持初始轻。
class _AddSuggestionButton extends StatelessWidget {
  const _AddSuggestionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF576B95)),
          SizedBox(width: 6),
          Text('写点建议（可选）',
              style: TextStyle(fontSize: 14, color: Color(0xFF576B95))),
        ],
      ),
    );
  }
}
