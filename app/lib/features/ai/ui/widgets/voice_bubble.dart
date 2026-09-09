import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../services/voice_player.dart';

/// 微信式语音消息：
/// - 气泡宽度随时长增加；
/// - 对方：声波图标在左、秒数在右；自己：秒数在左、声波图标在右；
/// - 点击播放/暂停，播放时声波按 1→2→3 段循环，不显示播放三角或进度条；
/// - 转写默认隐藏，只在长按菜单点击“转文字”后显示。
class VoiceBubble extends ConsumerStatefulWidget {
  const VoiceBubble({
    super.key,
    required this.audioId,
    required this.isMe,
    this.localPath,
    this.mediaAssetId,
    this.durationSeconds,
    this.transcript,
    this.showTranscript = false,
  });

  final String audioId;
  final bool isMe;
  final String? localPath;
  final String? mediaAssetId;
  final int? durationSeconds;
  final String? transcript;
  final bool showTranscript;

  @override
  ConsumerState<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends ConsumerState<VoiceBubble>
    with SingleTickerProviderStateMixin {
  Uint8List? _localBytes;
  late final AnimationController _voiceFrames = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    voicePlayer.addListener(_onPlayerChanged);
    _loadLocal();
  }

  @override
  void didUpdateWidget(covariant VoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath) _loadLocal();
  }

  Future<void> _loadLocal() async {
    final path = widget.localPath;
    if (path == null || path.isEmpty) return;
    try {
      final bytes = await File(path).readAsBytes();
      if (mounted && bytes.isNotEmpty) setState(() => _localBytes = bytes);
    } on Object {
      // 本地录音已清理时由 mediaAssetId 走持久缓存/网络。
    }
  }

  @override
  void dispose() {
    voicePlayer.removeListener(_onPlayerChanged);
    _voiceFrames.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final playing = voicePlayer.isPlayingFor(widget.audioId);
    if (playing && !_voiceFrames.isAnimating) {
      _voiceFrames.repeat();
    } else if (!playing && _voiceFrames.isAnimating) {
      _voiceFrames
        ..stop()
        ..value = 0;
    }
    setState(() {});
  }

  Future<Uint8List?> _resolveBytes() async {
    if (_localBytes != null) return _localBytes;
    final mediaId = widget.mediaAssetId;
    if (mediaId == null || mediaId.isEmpty) return null;
    var media = ref.read(mediaBytesProvider(mediaId)).valueOrNull;
    media ??= await ref.read(mediaBytesProvider(mediaId).future);
    return media?.bytes;
  }

  Future<void> _toggle() async {
    final bytes = await _resolveBytes();
    if (bytes == null || bytes.isEmpty) {
      if (mounted) showAppToast(context, '语音加载中，请稍后再试');
      return;
    }
    await voicePlayer.toggle(widget.audioId, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (widget.durationSeconds ?? 1).clamp(1, 60);
    final width = (92.0 + seconds * 2.45).clamp(104.0, 232.0);
    final transcript = widget.transcript?.trim() ?? '';
    const foreground = Color(0xFF111111);

    final icon = _AnimatedWechatVoiceIcon(
      key: const ValueKey('wechat_voice_icon'),
      controller: _voiceFrames,
      playing: voicePlayer.isPlayingFor(widget.audioId),
      pointRight: !widget.isMe,
      color: foreground,
    );
    final duration = Text(
      '$seconds″',
      key: const ValueKey('wechat_voice_duration'),
      style: const TextStyle(
        fontSize: 16,
        height: 1,
        color: foreground,
        fontWeight: FontWeight.w400,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: SizedBox(
            width: width,
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: widget.isMe
                    ? [
                        duration,
                        const Spacer(),
                        icon,
                      ]
                    : [
                        icon,
                        const SizedBox(width: 13),
                        duration,
                        const Spacer(),
                      ],
              ),
            ),
          ),
        ),
        if (widget.showTranscript && transcript.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxWidth: 224),
            margin: const EdgeInsets.fromLTRB(8, 2, 8, 7),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              transcript,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF555555),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedWechatVoiceIcon extends StatelessWidget {
  const _AnimatedWechatVoiceIcon({
    super.key,
    required this.controller,
    required this.playing,
    required this.pointRight,
    required this.color,
  });

  final AnimationController controller;
  final bool playing;
  final bool pointRight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final arcs =
            playing ? math.min(3, (controller.value * 3).floor() + 1) : 3;
        return CustomPaint(
          size: const Size(25, 25),
          painter: _WechatVoicePainter(
            arcs: arcs,
            pointRight: pointRight,
            color: color,
          ),
        );
      },
    );
  }
}

class _WechatVoicePainter extends CustomPainter {
  const _WechatVoicePainter({
    required this.arcs,
    required this.pointRight,
    required this.color,
  });

  final int arcs;
  final bool pointRight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (!pointRight) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final center = Offset(3.5, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < arcs; index++) {
      final radius = 3.4 + index * 4.2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 3.2,
        math.pi / 1.6,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WechatVoicePainter oldDelegate) =>
      oldDelegate.arcs != arcs ||
      oldDelegate.pointRight != pointRight ||
      oldDelegate.color != color;
}
