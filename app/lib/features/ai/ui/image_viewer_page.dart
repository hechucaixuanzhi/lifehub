import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// 微信风格全屏图片查看：黑底 + 签名通道下载 + InteractiveViewer（双击/双指缩放）。
/// 图片经 GET /media/{id}/content 取回，不经 Image.network（省一次签名头计算）。
/// [controller] 由调用方传入（供路由的 swipeBackGate 读取是否已放大）；缺省自建。
class ImageViewerPage extends ConsumerStatefulWidget {
  const ImageViewerPage(
      {super.key, required this.mediaAssetId, this.controller});

  final String mediaAssetId;
  final TransformationController? controller;

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  late final TransformationController _tc =
      widget.controller ?? TransformationController();
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .getBytes('/media/${widget.mediaAssetId}/content')
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        if (mounted) setState(() => _bytes = resp.bodyBytes);
      } else if (mounted) {
        setState(() => _failed = true);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('图片', style: TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: _bytes == null
            ? (_failed
                ? const Text('图片加载失败', style: TextStyle(color: Colors.white70))
                : const CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2))
            : InteractiveViewer(
                transformationController: _tc,
                maxScale: 4,
                child: Image.memory(_bytes!, fit: BoxFit.contain),
              ),
      ),
    );
  }
}
