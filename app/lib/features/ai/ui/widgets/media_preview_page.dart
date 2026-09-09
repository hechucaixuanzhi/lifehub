import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 图片预览-发送页（仿微信）：黑底大图 + 底部「作为表情包发送」开关 +
/// 文字输入 + 发送。单聊/群聊共用（R1 从单聊抽出）。
class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.mime,
    this.controller,
  });

  final List<int> bytes;
  final String fileName;
  final String mime;
  final TransformationController? controller;

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  final _caption = TextEditingController();
  bool _asSticker = false; // 009：作为表情包发送（相册挑图当表情，MiMo 描述存档）
  late final TransformationController _tc =
      widget.controller ?? TransformationController();

  @override
  void dispose() {
    if (widget.controller == null) _tc.dispose();
    _caption.dispose();
    super.dispose();
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
        title: const Text('图片',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                transformationController: _tc,
                maxScale: 4,
                child: Image.memory(Uint8List.fromList(widget.bytes),
                    fit: BoxFit.contain),
              ),
            ),
          ),
          // 底部：作为表情包发送开关 + 文字输入 + 发送（仿微信预览发送）
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('作为表情包发送',
                        style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
                    const Spacer(),
                    Switch(
                      value: _asSticker,
                      activeTrackColor: const Color(0xFF07C160),
                      onChanged: (v) => setState(() => _asSticker = v),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caption,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: '写点什么…',
                          counterText: '',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(PendingMedia(
                        widget.bytes,
                        widget.fileName,
                        widget.mime,
                        _caption.text.trim().isEmpty
                            ? null
                            : _caption.text.trim(),
                        _asSticker,
                      )),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF07C160),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                      ),
                      child: const Text('发送',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 预览页返回的待发送媒体（图片可选附带文字；asSticker=作为表情包发送）。
class PendingMedia {
  const PendingMedia(this.bytes, this.fileName, this.mime, this.caption,
      [this.asSticker = false]);
  final List<int> bytes;
  final String fileName;
  final String mime;
  final String? caption;
  final bool asSticker;
}
