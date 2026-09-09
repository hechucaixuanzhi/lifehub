import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 状态式填充图标核（对齐原型 `.hicon` + `.fill`）。
///
/// 渲染逻辑：
/// - 底层：Phosphor 线稿灰图标（未达标的中性底）。
/// - 覆盖层：同图标实体色，经 ClipRect + Align(heightFactor=progress)
///   从底部按比例升起填充。
/// - 达标（progress >= 1）：整图标切实体色 + 轻脉冲。
/// - 进行中（running）：外圈实体色环 + 呼吸透明度。
///
/// 单击/长按/双击手势不进组件，由页面网格装配。
class StatusIcon extends StatelessWidget {
  const StatusIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.progress,
    this.fillIcon,
    this.running = false,
    this.reached = false,
    this.badge,
    this.size = 42,
    this.onAnimatedReached,
  });

  final IconData icon;
  final Color color;
  final double progress; // 0~1
  final IconData? fillIcon; // Fill 实心版（覆盖层用），默认用 icon
  final bool running;
  final bool reached;
  final String? badge;
  final double size;
  final VoidCallback? onAnimatedReached;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + 16,
          height: size + 16,
          child: Center(
            child: _FilledIcon(
              icon: icon,
              fillIcon: fillIcon ?? icon,
              color: color,
              progress: progress,
              running: running,
              reached: reached,
              size: size,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: 2),
          _AutoBadge(color: color, label: badge!),
        ],
      ],
    );
  }
}

class _FilledIcon extends StatelessWidget {
  const _FilledIcon({
    required this.icon,
    required this.fillIcon,
    required this.color,
    required this.progress,
    required this.running,
    required this.reached,
    required this.size,
  });

  final IconData icon;
  final IconData fillIcon;
  final Color color;
  final double progress;
  final bool running;
  final bool reached;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final shown = reached ? color : AppColors.iconBase;

    Widget core = Stack(
      alignment: Alignment.center,
      children: [
        // 底：线稿灰（全尺寸）
        SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size, color: AppColors.iconBase),
        ),
        // 覆盖：Fill 实心图标从底部按比例升起填充。
        // 关键：图标保持全尺寸，用 Align(heightFactor) 收缩【裁剪窗口】而非压缩图标本身。
        // Align 高度 = 图标高 × progress，图标底部对齐窗口，ClipRect 裁掉窗口以上部分 → 底部填充。
        if (!reached)
          SizedBox(
            width: size,
            height: size,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: clamped,
                child: Icon(fillIcon, size: size, color: color),
              ),
            ),
          ),
      ],
    );

    // 达标：整图标变色 + 轻脉冲
    if (reached) {
      core = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Icon(icon, size: size, color: shown),
      );
    }

    // 进行中：外圈色环 + 呼吸
    if (running) {
      core = _BreathingRing(child: core, color: color, size: size);
    }

    return core;
  }
}

/// 进行中色环 + 呼吸动效（对齐「计时进行中加色环+呼吸」）。
class _BreathingRing extends StatefulWidget {
  const _BreathingRing({required this.child, required this.color, required this.size});
  final Widget child;
  final Color color;
  final double size;

  @override
  State<_BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<_BreathingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 16,
      height: widget.size + 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.5 + 0.5 * _controller.value),
              width: 2,
            ),
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _AutoBadge extends StatelessWidget {
  const _AutoBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: Colors.white, height: 1.4),
      ),
    );
  }
}
