import 'package:flutter/material.dart';

class ChatMoreAction {
  const ChatMoreAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Shared two-row WeChat-style action panel.
class ChatMorePanel extends StatelessWidget {
  const ChatMorePanel({
    super.key,
    required this.actions,
    required this.firstRowCount,
  });

  final List<ChatMoreAction> actions;
  final int firstRowCount;

  @override
  Widget build(BuildContext context) {
    final split = firstRowCount.clamp(0, actions.length);
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        children: [
          Expanded(child: _ActionRow(actions: actions.sublist(0, split))),
          const SizedBox(height: 6),
          Expanded(child: _ActionRow(actions: actions.sublist(split))),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions});

  final List<ChatMoreAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _ActionTile(action: actions[index])),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final ChatMoreAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: action.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(action.icon, color: const Color(0xFF333333), size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}
