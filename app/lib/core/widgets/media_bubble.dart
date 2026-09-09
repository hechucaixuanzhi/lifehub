import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/ui/image_viewer_page.dart';
import '../nav/app_page_route.dart';
import '../providers.dart';

/// 消息图片（微信缩略图气泡）：签名通道下载 → 解码原图宽高 → 按比例自适应大小，
/// 点击进全屏 [ImageViewerPage]。单次下载即渲染（Image.memory），不二次请求。
class MediaImageView extends ConsumerStatefulWidget {
  const MediaImageView(
      {super.key, required this.mediaAssetId, this.previewBytes});

  final String mediaAssetId;

  /// 本地预览字节（发送中回显用）：非空时优先内存渲染，不上网络。
  final Uint8List? previewBytes;

  @override
  ConsumerState<MediaImageView> createState() => _MediaImageViewState();
}

class _MediaImageViewState extends ConsumerState<MediaImageView> {
  static const double _maxW = 180;
  static const double _maxH = 240;
  static const double _placeholderW = 140;
  static const double _placeholderH = 100;

  /// 本地预览（发送中回显）解码的宽高比；网络图走 [mediaBytesProvider] 缓存。
  double? _previewAspect;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewBytes;
    if (preview != null) _decodePreview(preview);
  }

  /// 解码本地预览字节算宽高比（无需网络）。
  Future<void> _decodePreview(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final aspect = img.width / img.height;
      img.dispose();
      if (!mounted) return;
      setState(() => _previewAspect = aspect);
    } on Object {
      // 解码失败：用占位尺寸
    }
  }

  Size _sizeFor(double? aspect) {
    if (aspect == null || aspect <= 0) {
      return const Size(_placeholderW, _placeholderH);
    }
    var w = _maxW;
    var h = w / aspect;
    if (h > _maxH) {
      h = _maxH;
      w = h * aspect;
    }
    return Size(w, h);
  }

  /// 显示宽度 × 设备像素比 = 解码宽度（Image.memory 按此尺寸解码并缓存）。
  int _decodeCacheWidth(BuildContext context, double displayWidth) {
    final decodeW =
        (displayWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return decodeW < 1 ? 1 : decodeW;
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewBytes;
    // 预览字节优先；否则走共享缓存 provider（同一 mediaId 只下载一次）
    final net = preview != null
        ? null
        : ref.watch(mediaBytesProvider(widget.mediaAssetId)).valueOrNull;
    final bytes = preview ?? net?.bytes;
    final aspect = preview != null ? _previewAspect : net?.aspect;
    final size = _sizeFor(aspect);
    final failed = bytes == null && widget.mediaAssetId.isNotEmpty;
    return GestureDetector(
      onTap: () {
        // 控制器与页面共用：路由按当前缩放决定是否让右滑返回让位给捏合/平移
        final tc = TransformationController();
        Navigator.of(context).push(
          AppPageRoute(
            builder: (_) => ImageViewerPage(
                mediaAssetId: widget.mediaAssetId, controller: tc),
            // 未放大可右滑返回；放大后让给 InteractiveViewer（微信同款）
            swipeBackGate: () => tc.value.getMaxScaleOnAxis() <= 1.02,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: bytes != null
              ? Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  // 缩略图按气泡实际显示宽度解码（≤180 逻辑像素），别解码原图
                  // 全分辨率——消息流滚动 / 打开聊天首帧不卡。
                  cacheWidth: _decodeCacheWidth(context, size.width),
                )
              : Container(
                  color: const Color(0xFFE4E4E4),
                  alignment: Alignment.center,
                  child: failed
                      ? const Icon(Icons.broken_image_outlined,
                          color: Color(0xFF999999), size: 28)
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
        ),
      ),
    );
  }
}
