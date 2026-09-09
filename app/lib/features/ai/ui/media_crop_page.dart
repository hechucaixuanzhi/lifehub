import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// 头像/背景裁切页：黑底 + 固定比例裁切框。
/// 头像是微信式 1:1 方图；背景是手机聊天页 9:16 竖图。用户平移/缩放图片，
/// 不直接拖坏裁切比例；内部手势优先，路由禁右滑返回。
/// 由聊天页 ⋯ 菜单 / 聊天信息页「设置当前聊天背景」「更换头像」共用。
class MediaCropPage extends StatefulWidget {
  const MediaCropPage({
    super.key,
    required this.bytes,
    required this.isAvatar,
    required this.fileName,
    required this.mime,
  });

  final Uint8List bytes;
  final bool isAvatar;
  final String fileName;
  final String mime;

  @override
  State<MediaCropPage> createState() => _MediaCropPageState();
}

class _MediaCropPageState extends State<MediaCropPage> {
  final CropController _ctrl = CropController();
  bool _cropping = false;
  String? _error;

  void _confirm() {
    if (_cropping) return;
    setState(() {
      _cropping = true;
      _error = null;
    });
    // 两种图片都输出矩形字节。头像的圆角只属于 UI 展示，不写进素材本身。
    _ctrl.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.isAvatar ? '裁剪头像' : '裁剪背景',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.bytes,
              controller: _ctrl,
              withCircleUi: false,
              aspectRatio: widget.isAvatar ? 1 : 9 / 16,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                size: 0.9,
                aspectRatio: widget.isAvatar ? 1 : 9 / 16,
              ),
              interactive: true,
              fixCropRect: true,
              progressIndicator: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              onCropped: (result) {
                // sealed CropResult：成功返回裁切字节；失败保持本页（不吞用户操作）
                if (result is CropSuccess) {
                  Navigator.of(context).pop(result.croppedImage);
                } else if (result is CropFailure && mounted) {
                  setState(() {
                    _cropping = false;
                    _error = '无法裁剪这张图片，请换一张重试';
                  });
                }
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFFA5151))),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: _cropping ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 10),
                    ),
                    child: Text(_cropping ? '处理中…' : '保存',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
