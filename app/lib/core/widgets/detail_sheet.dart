import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'swipe_back_dismiss.dart';

/// 内容区底部弹出面板（对齐原型 detailpanel）：
/// 只占中间内容区（不遮顶部固定栏与底部导航），顶部圆角 + 拖拽 grip，
/// 下滑 > 60px 关闭，也可点遮罩关闭。
class DetailSheet extends StatefulWidget {
  const DetailSheet({
    super.key,
    required this.child,
    required this.onClose,
    this.title = '',
    this.heightFactor = 0.85,
  });

  final Widget child;
  final VoidCallback onClose;
  final String title;
  final double heightFactor;

  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet> {
  double _offset = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _offset = (_offset + d.delta.dy).clamp(0.0, 600.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_offset > 60 || d.velocity.pixelsPerSecond.dy > 600) {
      _close();
    } else {
      setState(() => _offset = 0);
    }
  }

  void _close() {
    widget.onClose();
    _offset = 0;
  }

  @override
  Widget build(BuildContext context) {
    // 定位由调用方（AppShell）外层 Positioned 控制；本组件只填充其约束区域
    return IgnorePointer(
      ignoring: false,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 遮罩（点击关闭）
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(color: Colors.black26),
              ),
            ),
            // 面板
            Positioned.fill(
              child: SwipeBackDismiss(
                onDismiss: _close,
                child: Transform.translate(
                  offset: Offset(0, _offset),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg)),
                      boxShadow: AppElevation.e2,
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onVerticalDragUpdate: _onDragUpdate,
                          onVerticalDragEnd: _onDragEnd,
                          child: Container(
                            height: 40,
                            color: AppColors.surface,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD2D6CF),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: double.infinity,
                            // 内容区：滚动到顶后再下滑 → 关闭面板（不只是 grip）
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.pixels <= 0 &&
                                    n.metrics.axis == Axis.vertical) {
                                  // 已到顶部，交由外层拖拽手势处理关闭
                                  return false;
                                }
                                return false;
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragUpdate: _onDragUpdate,
                                onVerticalDragEnd: _onDragEnd,
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
