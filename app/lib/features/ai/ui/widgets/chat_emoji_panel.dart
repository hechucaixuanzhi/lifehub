import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../ai_providers.dart';
import '../../models/sticker.dart';
import '../chat_message_utils.dart';

/// Shared emoji/sticker panel for single and group chat.
///
/// All dimensions and colors intentionally match the pre-extraction pages so
/// this module boundary does not alter the WeChat-like UI.
class ChatEmojiPanel extends ConsumerWidget {
  const ChatEmojiPanel({
    super.key,
    required this.onDelete,
    required this.onEmoji,
    required this.onSticker,
    required this.onSend,
  });

  final VoidCallback onDelete;
  final ValueChanged<String> onEmoji;
  final ValueChanged<Sticker> onSticker;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickers = ref.watch(stickersProvider).valueOrNull ?? defaultStickers;
    return Container(
      height: 264,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF333333),
              unselectedLabelColor: Color(0xFF999999),
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: AppColors.accent,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: [Tab(text: '表情'), Tab(text: '表情包')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EmojiGrid(
                    onDelete: onDelete,
                    onEmoji: onEmoji,
                    onSend: onSend,
                  ),
                  _StickerGrid(stickers: stickers, onSticker: onSticker),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({
    required this.onDelete,
    required this.onEmoji,
    required this.onSend,
  });

  final VoidCallback onDelete;
  final ValueChanged<String> onEmoji;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: chatEmojis.length + 1,
            itemBuilder: (_, index) {
              if (index == chatEmojis.length) {
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onDelete,
                  child: const Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: Color(0xFF666666),
                    ),
                  ),
                );
              }
              final emoji = chatEmojis[index];
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onEmoji(emoji),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
          child: Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: onSend,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D8D8),
                  disabledForegroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '发送',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickerGrid extends StatelessWidget {
  const _StickerGrid({required this.stickers, required this.onSticker});

  final List<Sticker> stickers;
  final ValueChanged<Sticker> onSticker;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (_, index) {
        final sticker = stickers[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSticker(sticker),
          child: Image.asset(
            'assets/stickers/${sticker.id}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: Text(
                sticker.name,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ),
          ),
        );
      },
    );
  }
}
