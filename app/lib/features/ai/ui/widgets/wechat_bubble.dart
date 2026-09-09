import 'package:flutter/material.dart';

import '../../models/ai_chat_message.dart';

/// 微信私聊气泡：对方白色、己方 #95EC69，双方每条都显示头像。
/// 图片和表情可通过 [transparent] 关闭气泡底与尾巴。
class WeChatBubble extends StatelessWidget {
  const WeChatBubble({
    super.key,
    required this.isMe,
    required this.child,
    this.avatar,
    this.meAvatar,
    this.onLongPress,
    this.quote,
    this.status = AiMsgStatus.sent,
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.transparent = false,
  });

  final bool isMe;
  final Widget child;
  final Widget? avatar;
  final Widget? meAvatar;
  final void Function(Rect rect)? onLongPress;
  final String? quote;
  final AiMsgStatus status;
  final VoidCallback? onRetry;
  final EdgeInsets padding;
  final bool transparent;

  static const double maxWidthRatio = 0.68;
  static const Color meColor = Color(0xFF95EC69);
  static const Color aiColor = Color(0xFFFFFFFF);
  static const Color _textColor = Color(0xFF111111);

  Color get _color => isMe ? meColor : aiColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isMe ? _meRow(context) : _otherRow(context),
      ),
    );
  }

  List<Widget> _meRow(BuildContext context) => [
        _StatusSlot(status: status, onRetry: onRetry),
        const SizedBox(width: 6),
        Flexible(child: _body(context)),
        const SizedBox(width: 8),
        meAvatar ?? const _FallbackAvatar(label: '我'),
      ];

  List<Widget> _otherRow(BuildContext context) => [
        avatar ?? const _FallbackAvatar(label: '她'),
        const SizedBox(width: 8),
        Flexible(child: _body(context)),
      ];

  Widget _body(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * maxWidthRatio,
      ),
      padding: transparent ? EdgeInsets.zero : padding,
      decoration: transparent
          ? null
          : BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(5),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote != null && quote!.isNotEmpty) ...[
            _QuoteBlock(text: quote!),
            const SizedBox(height: 5),
          ],
          child,
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!transparent)
          Positioned(
            top: 12,
            left: isMe ? null : -6,
            right: isMe ? -6 : null,
            child: CustomPaint(
              size: const Size(7, 12),
              painter: _BubbleTailPainter(isMe: isMe, color: _color),
            ),
          ),
        if (onLongPress == null)
          content
        else
          Builder(
            builder: (bubbleContext) => GestureDetector(
              onLongPress: () {
                final box = bubbleContext.findRenderObject() as RenderBox?;
                if (box == null || !box.attached || !box.hasSize) return;
                onLongPress?.call(
                  box.localToGlobal(Offset.zero) & box.size,
                );
              },
              child: content,
            ),
          ),
      ],
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF576B95),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.isMe, required this.color});

  final bool isMe;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isMe) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.isMe != isMe || oldDelegate.color != color;
}

/// 引用摘要：左灰线 + 单行文字。被引用消息为媒体时（quote_content 前缀
/// `[图片]/[表情包]/[语音]/[文件：名]`）渲染小图标，提示引用的是媒体而非文本。
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.text});

  final String text;

  IconData? get _mediaIcon {
    if (text.startsWith('[图片]')) return Icons.image_outlined;
    if (text.startsWith('[表情包]')) return Icons.emoji_emotions_outlined;
    if (text.startsWith('[语音]')) return Icons.graphic_eq;
    if (text.startsWith('[文件：')) return Icons.insert_drive_file_outlined;
    return null;
  }

  /// 媒体前缀剥离后只显示内容；内容为空（纯图片/表情被引用）保留前缀标签。
  String get _display {
    if (text.startsWith('[文件：')) {
      final rest = text.substring('[文件：'.length).trim();
      return rest.isEmpty ? text : rest;
    }
    for (final p in const ['[图片]', '[表情包]', '[语音]']) {
      if (text.startsWith(p)) {
        final rest = text.substring(p.length).trim();
        return rest.isEmpty ? p : rest;
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _mediaIcon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(3),
        border: const Border(
          left: BorderSide(color: Color(0xFFC6C6C6), width: 3),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: const Color(0xFF777777)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              _display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF777777)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSlot extends StatelessWidget {
  const _StatusSlot({required this.status, this.onRetry});

  final AiMsgStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final slot = switch (status) {
      // 微信式乐观发送：发送中不显示圆圈；只有确认失败后才出现红色感叹号。
      AiMsgStatus.sending => const SizedBox.shrink(),
      AiMsgStatus.failed => GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.error, size: 19, color: Color(0xFFFA5151)),
        ),
      AiMsgStatus.sent => const SizedBox.shrink(),
    };
    return SizedBox(width: 19, child: Center(child: slot));
  }
}

/// 气泡正文始终可选。长按时由 [contextMenuBuilder] 渲染微信菜单，
/// 选区与绿色手柄保留在原气泡，不再跳底部面板。
class WeChatText extends StatefulWidget {
  const WeChatText(
    this.text, {
    super.key,
    this.style,
    this.contextMenuBuilder,
  });

  final String text;
  final TextStyle? style;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  @override
  State<WeChatText> createState() => _WeChatTextState();
}

class _WeChatTextState extends State<WeChatText> {
  bool _selectAllOnNextMenu = false;

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    // 微信：第一次长按默认选中整条消息；随后拖动绿色手柄可自行截短。
    if (cause == SelectionChangedCause.longPress) {
      _selectAllOnNextMenu = true;
    }
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    if (_selectAllOnNextMenu) {
      _selectAllOnNextMenu = false;
      final value = editableTextState.textEditingValue;
      final all = TextSelection(baseOffset: 0, extentOffset: value.text.length);
      if (value.selection != all) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !editableTextState.mounted) return;
          editableTextState.widget.controller.selection = all;
          editableTextState.showToolbar();
        });
      }
    }
    return widget.contextMenuBuilder!(context, editableTextState);
  }

  @override
  Widget build(BuildContext context) {
    // 验收批3②：选中色/手柄色不再由每个气泡各自提供（每个气泡一个
    // TextSelectionTheme 就是 N 个 InheritedWidget 拆解面）。由消息列表页在
    // ListView 外层统一包一个 TextSelectionTheme，气泡只保留纯 SelectableText。
    return SelectableText(
      widget.text,
      onSelectionChanged: _handleSelectionChanged,
      contextMenuBuilder:
          widget.contextMenuBuilder == null ? null : _buildContextMenu,
      style: widget.style ??
          const TextStyle(
            fontSize: 17,
            color: WeChatBubble._textColor,
            height: 1.42,
          ),
    );
  }
}
