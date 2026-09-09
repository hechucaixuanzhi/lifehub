import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 全屏右滑返回路由（微信安卓新版手感）：
/// 页面内容任意位置按住右拖跟手，松手超过阈值/速度 → 滑出返回上一级，否则回弹。
/// `opaque:false` 让拖动时下层页面可见。
/// 含 InteractiveViewer 的页面（媒体查看/图片预览）传 [swipeBackGate]：
/// 返回 bool 的守卫——false 时本次拖动让出竞技场（放大中的图片平移/捏合优先），
/// true 时正常右滑返回（未放大时，微信同款）。
class AppPageRoute<T> extends PageRoute<T> {
  AppPageRoute({
    required this.builder,
    this.enableSwipeBack = true,
    this.swipeBackGate,
  });

  final WidgetBuilder builder;
  final bool enableSwipeBack;

  /// 可选右滑守卫：为 false 时本次拖动不触发返回（让给页面内手势，如放大的图片）。
  final bool Function()? swipeBackGate;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  bool get opaque => false; // 拖动/滑出时下层页面透出

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _SwipeBackHost(
      enabled: enableSwipeBack,
      onBack: () => Navigator.of(context).maybePop(),
      gate: swipeBackGate,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // 右滑入 + 轻淡入（对齐原 Material 手感；退出时反向滑出）
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // RepaintBoundary：页面内容缓存为图层，push/pop 平移只做合成、不整树重绘
    //（聊天页含背景图/长列表，无此边界则过渡每帧重绘整页 → 卡顿）。
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
          .animate(curved),
      child: FadeTransition(
          opacity: curved, child: RepaintBoundary(child: child)),
    );
  }
}

/// 拖动宿主：横向 GestureDetector 跟手位移，松手回弹/滑出。
class _SwipeBackHost extends StatefulWidget {
  const _SwipeBackHost({
    required this.enabled,
    required this.onBack,
    required this.child,
    this.gate,
  });

  final bool enabled;
  final VoidCallback onBack;
  final Widget child;

  /// 可选守卫：false 时水平识别器放弃竞技场，把手势让给页面内容（如放大后的图片平移）。
  final bool Function()? gate;

  @override
  State<_SwipeBackHost> createState() => _SwipeBackHostState();
}

class _SwipeBackHostState extends State<_SwipeBackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  double _dx = 0;
  double _width = 0;
  static const double _thresholdRatio = 0.35;
  static const double _exitVelocity = 700; // px/s

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _anim.addStatusListener((s) {
        // 滑出动画结束 → 触发返回
        if (s == AnimationStatus.completed) widget.onBack();
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails d) {
    _width = MediaQuery.of(context).size.width;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_width == 0) return;
    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _width));
  }

  void _onEnd(DragEndDetails d) {
    if (_width == 0) return;
    final v = d.primaryVelocity ?? 0;
    // 右滑超阈值或速度够快 → 滑出返回；否则回弹
    if (_dx > _width * _thresholdRatio || v > _exitVelocity) {
      _anim.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _anim.animateBack(0, curve: Curves.easeOutCubic);
    }
  }

  void _onCancel() {
    _anim.animateBack(0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    Widget page = widget.child;
    if (widget.enabled) {
      // _dx 跟手位移；_anim 0→1 时再推到位（_anim.value*宽），让滑出动画连续
      final dragDx = _dx + _anim.value * _width;
      final content = Stack(
        children: [
          // 拖动时左侧淡出阴影，提示可返回
          if (dragDx > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.12 * (dragDx / _width).clamp(0, 1)),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(dragDx, 0),
            // 拖动每帧位移时 RepaintBoundary 让页面只重合成不整树重绘（右滑跟手不卡）
            child: RepaintBoundary(child: page),
          ),
        ],
      );
      final gate = widget.gate;
      page = gate != null
          // InteractiveViewer 页面：自定义识别器在 gate=false（放大）时让出手势
          ? RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: {
                _GatedSwipeBackRecognizer: GestureRecognizerFactoryWithHandlers<
                    _GatedSwipeBackRecognizer>(
                  () => _GatedSwipeBackRecognizer(gate: gate),
                  (r) {
                    r.onStart = _onStart;
                    r.onUpdate = _onUpdate;
                    r.onEnd = _onEnd;
                    r.onCancel = _onCancel;
                  },
                ),
              },
              child: content,
            )
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onStart,
              onHorizontalDragUpdate: _onUpdate,
              onHorizontalDragEnd: _onEnd,
              onHorizontalDragCancel: _onCancel,
              child: content,
            );
    }
    return page;
  }
}

/// 可让出的水平拖动识别器：gate 返回 false（如图片已放大）时不声明胜利，
/// 把竞技场让给页面内 InteractiveViewer 的 Scale 识别器（平移/捏合优先），
/// 避免右滑返回抢走放大图的拖动。
class _GatedSwipeBackRecognizer extends HorizontalDragGestureRecognizer {
  _GatedSwipeBackRecognizer({required this.gate});

  final bool Function() gate;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!gate()) return false;
    return super.hasSufficientGlobalDistanceToAccept(
        pointerDeviceKind, deviceTouchSlop);
  }
}
