import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 微信消息操作。真实功能与占位功能使用同一视觉，
/// 点击后由聊天页决定执行或显示“暂未实现”。
class BubbleActionItem {
  const BubbleActionItem(this.id, this.icon, this.label);

  final String id;
  final IconData icon;
  final String label;
}

/// 非文字消息（图片、语音、表情）的长按菜单。
/// 文字消息使用 [WeChatSelectionMenu]，以便选区手柄留在原气泡内。
class BubbleActionMenu extends StatefulWidget {
  const BubbleActionMenu({
    super.key,
    required this.bubbleRect,
    required this.items,
    required this.onSelect,
    required this.onDismiss,
    this.feedbackEdge,
  });

  final Rect bubbleRect;
  final List<BubbleActionItem> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  /// 可选：浮在气泡右下（白框外）的小图标（如 👍/👎）。与菜单同框出现/消失，
  /// 点它不会触发遮罩 dismiss，由上层在回调里关闭菜单。
  final Widget? feedbackEdge;

  @override
  State<BubbleActionMenu> createState() => _BubbleActionMenuState();
}

class _BubbleActionMenuState extends State<BubbleActionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final menuSize = _menuSize(screen.width, widget.items.length);
    final above = widget.bubbleRect.top >= menuSize.height + 20;
    final centerX = widget.bubbleRect.center.dx.clamp(
      menuSize.width / 2 + 12,
      screen.width - menuSize.width / 2 - 12,
    );
    final left = centerX - menuSize.width / 2;
    final top = above
        ? widget.bubbleRect.top - menuSize.height - 10
        : widget.bubbleRect.bottom + 10;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onDismiss,
        ),
        Positioned(
          left: left,
          top: top,
          width: menuSize.width,
          child: FadeTransition(
            opacity: _ctrl,
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
              ),
              child: _WeChatMenuSurface(
                items: widget.items,
                onSelect: widget.onSelect,
                arrowAlignment:
                    ((widget.bubbleRect.center.dx - left) / menuSize.width)
                        .clamp(.12, .88),
                arrowOnTop: !above,
              ),
            ),
          ),
        ),
        // 气泡右下（白框外）的轻量 👍/👎：与菜单同框，菜单关闭即消失。
        // 用 Align 把图标压到气泡底部线（高度自适应横/竖排，不写死 rail 高度）。
        if (widget.feedbackEdge != null)
          Positioned(
            left: widget.bubbleRect.right + 3,
            top: widget.bubbleRect.top,
            height: widget.bubbleRect.height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: widget.feedbackEdge!,
            ),
          ),
      ],
    );
  }
}

/// SelectableText 的定制上下文菜单。
/// 微信的文字长按会同时出现原地选区手柄和两行操作菜单。
class WeChatSelectionMenu extends StatelessWidget {
  const WeChatSelectionMenu({
    super.key,
    required this.anchors,
    required this.items,
    required this.onSelect,
    this.bubbleRect,
    this.feedbackEdge,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<BubbleActionItem> items;
  final ValueChanged<String> onSelect;

  /// 文字气泡全局矩形（聊天页由 EditableText 推算），用于把白框外的
  /// 轻量 👍/👎 锚定到气泡右下。null 则不渲染 feedbackEdge。
  final Rect? bubbleRect;
  final Widget? feedbackEdge;

  @override
  Widget build(BuildContext context) {
    // TextSelectionToolbar 内部把首屏工具栏固定为 44px 高，不能承载微信
    // 两行菜单；直接复用它公开的定位 delegate，保留避让选区能力而不再溢出。
    final menuSize = _menuSize(MediaQuery.sizeOf(context).width, items.length);
    final padding = MediaQuery.paddingOf(context);
    const screenPadding = 8.0;
    const anchorGap = 10.0;
    final anchorAbove = anchors.primaryAnchor - const Offset(0, anchorGap);
    final anchorBelow = (anchors.secondaryAnchor ?? anchors.primaryAnchor) +
        const Offset(0, 20);
    final availableAbove = anchorAbove.dy - padding.top - screenPadding;
    final fitsAbove = menuSize.height <= availableAbove;
    final localAdjustment = Offset(screenPadding, padding.top + screenPadding);

    // 上下文菜单整体铺满 overlay（TextSelectionToolbarLayoutDelegate 以全局
    // 坐标定位），用 Stack 承载菜单 + 白框外小图标，一处关闭全部消失。
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            screenPadding,
            padding.top + screenPadding,
            screenPadding,
            padding.bottom + screenPadding,
          ),
          child: CustomSingleChildLayout(
            delegate: TextSelectionToolbarLayoutDelegate(
              anchorAbove: anchorAbove - localAdjustment,
              anchorBelow: anchorBelow - localAdjustment,
              fitsAbove: fitsAbove,
            ),
            child: _WeChatMenuSurface(
              items: items,
              onSelect: onSelect,
              arrowAlignment: .5,
              arrowOnTop: !fitsAbove,
            ),
          ),
        ),
        if (feedbackEdge != null && bubbleRect != null)
          Positioned(
            left: bubbleRect!.right + 3,
            top: bubbleRect!.top,
            height: bubbleRect!.height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: feedbackEdge!,
            ),
          ),
      ],
    );
  }
}

const _itemsPerRow = 5;
const _itemWidth = 61.0;
const _itemHeight = 67.0;
const _surfacePadding = 10.0;

Size _menuSize(double screenWidth, int count) {
  final columns = math.min(_itemsPerRow, count);
  final rows = (count / _itemsPerRow).ceil();
  return Size(
    math.min(screenWidth - 24, columns * _itemWidth + _surfacePadding * 2),
    rows * _itemHeight + _surfacePadding * 2 + (rows > 1 ? 1 : 0) + 10,
  );
}

class _WeChatMenuSurface extends StatelessWidget {
  const _WeChatMenuSurface({
    required this.items,
    required this.onSelect,
    required this.arrowAlignment,
    required this.arrowOnTop,
  });

  final List<BubbleActionItem> items;
  final ValueChanged<String> onSelect;
  final double arrowAlignment;
  final bool arrowOnTop;

  @override
  Widget build(BuildContext context) {
    final width =
        _menuSize(MediaQuery.sizeOf(context).width, items.length).width;
    final rows = <List<BubbleActionItem>>[
      for (var start = 0; start < items.length; start += _itemsPerRow)
        items.sublist(start, math.min(start + _itemsPerRow, items.length)),
    ];
    final cellWidth =
        (width - _surfacePadding * 2) / math.min(_itemsPerRow, items.length);
    final arrow = Align(
      alignment: Alignment(arrowAlignment * 2 - 1, 0),
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 10,
          height: 10,
          color: const Color(0xF24B4B4B),
        ),
      ),
    );
    final panel = Material(
      color: const Color(0xF24B4B4B),
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(_surfacePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                if (rowIndex > 0)
                  const Divider(
                    height: 1,
                    thickness: .5,
                    color: Color(0xFF666666),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    for (final item in rows[rowIndex])
                      _MenuItem(
                        item: item,
                        width: cellWidth,
                        onTap: () => onSelect(item.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: arrowOnTop ? [arrow, panel] : [panel, arrow],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final BubbleActionItem item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: _itemHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: Colors.white, size: 24),
            const SizedBox(height: 7),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
