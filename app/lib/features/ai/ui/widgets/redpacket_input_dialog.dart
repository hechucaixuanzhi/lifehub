import 'package:flutter/material.dart';

/// Shared WeChat-style amount input used by single-chat transfers/red packets
/// and group red packets. The dialog owns its controllers and returns the
/// immutable result before disposal.
class RedPacketInputDialog extends StatefulWidget {
  const RedPacketInputDialog({
    super.key,
    required this.title,
    required this.amountHint,
    required this.noteHint,
  });

  final String title;
  final String amountHint;
  final String noteHint;

  @override
  State<RedPacketInputDialog> createState() => _RedPacketInputDialogState();
}

class _RedPacketInputDialogState extends State<RedPacketInputDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController(text: widget.noteHint);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的金额')),
      );
      return;
    }
    Navigator.of(context).pop((amount, _noteController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.amountHint,
              prefixText: '¥ ',
              border: const UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: widget.noteHint,
              border: const UnderlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF07C160),
          ),
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
