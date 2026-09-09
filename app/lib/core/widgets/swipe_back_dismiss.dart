import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 带右滑返回的模态底部弹层（对齐页面右滑手感）：builder 内容右拖超阈值 → pop 关闭。
/// 用法与 showModalBottomSheet 一致，仅函数名替换。
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  double? elevation,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: shape,
    elevation: elevation,
    builder: (ctx) => SwipeBackDismiss(child: builder(ctx)),
  );
}

/// 非路由滑动面的右滑返回（对齐 AppPageRoute 手感）：
/// 内容任意位置按住右拖跟手，超过阈值/速度 → [onDismiss]，否则回弹。
/// 用于 DetailSheet 面板与 showModalBottomSheet 弹层，让「整个应用」都能右滑退出。
/// 默认 [onDismiss] = Navigator.pop（弹层路由）；面板类传显式回调。
class SwipeBackDismiss extends StatefulWidget {
  const SwipeBackDismiss({super.key, required this.child, this.onDismiss});

  final Widget child;
  final VoidCallback? onDismiss;

  @override
  State<SwipeBackDismiss> createState() => _SwipeBackDismissState();
}

class _SwipeBackDismissState extends State<SwipeBackDismiss> {
  double _dx = 0;
  double _width = 0;
  static const double _thresholdRatio = 0.3;
  static const double _exitVelocity = 600; // px/s

  void _onStart(DragStartDetails d) {
    _width = MediaQuery.of(context).size.width;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_width == 0) return;
    // 左右双向：右拖 dx 正、左拖 dx 负，面板跟手
    setState(() => _dx = (_dx + d.delta.dx).clamp(-_width, _width));
  }

  void _onEnd(DragEndDetails d) {
    if (_width == 0) return;
    final v = d.primaryVelocity ?? 0;
    // 任一方向拖超阈值 / 甩速够快 → 关闭（沿滑动方向滑出）
    if (_dx.abs() > _width * _thresholdRatio || v.abs() > _exitVelocity) {
      (widget.onDismiss ?? () => Navigator.of(context).pop())();
    } else {
      setState(() => _dx = 0);
    }
  }

  void _onCancel() {
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final dragDx = _dx;
    final content = Stack(
      children: [
        // 拖动时淡出阴影（面板移开露出的那侧），让跟手更明显
        if (dragDx != 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(
                    alpha: 0.10 *
                        (dragDx.abs() / (_width == 0 ? 1 : _width))
                            .clamp(0, 1)),
              ),
            ),
          ),
        Transform.translate(
          offset: Offset(dragDx, 0),
          child: widget.child,
        ),
      ],
    );
    // 自定义识别器：右移过 _PanelSwipeBackRecognizer._acceptSlop 即声明胜利，
    // 抢在内层垂直识别器（列表滚动/下滑关闭）之前接受，解决「右滑带轻微向下
    // 分量被内层抢走」——否则竞技场叶子优先，内层先过 18px slop 胜出。
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _PanelSwipeBackRecognizer: GestureRecognizerFactoryWithHandlers<
            _PanelSwipeBackRecognizer>(
          _PanelSwipeBackRecognizer.new,
          (r) {
            r.onStart = _onStart;
            r.onUpdate = _onUpdate;
            r.onEnd = _onEnd;
            r.onCancel = _onCancel;
          },
        ),
      },
      child: content,
    );
  }
}

/// 面板左右滑识别器：水平为主（|dx| 超过 [acceptSlop] 且 ≥ 向下分量一半）即声明
/// 胜利，抢在内层垂直识别器（列表滚动/下滑关闭）之前接受。真机右滑常带向下弧线，
/// 纯 18px 阈值时 dy/dx ≥ 1.5 会被内层先抢走；主方向判断覆盖到 dy/dx ≤ 2。
/// 纯垂直 / 陡峭向下（|dx| 不足）不声明胜利，让给内层滚动或下滑关闭。
class _PanelSwipeBackRecognizer extends HorizontalDragGestureRecognizer {
  static const double acceptSlop = 8;

  double _netDx = 0;
  double _netDy = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _netDx = 0;
    _netDy = 0;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _netDx += event.delta.dx;
      _netDy += event.delta.dy;
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
      PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return _netDx.abs() > acceptSlop && _netDx.abs() * 2 >= _netDy.abs();
  }
}
