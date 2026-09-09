import 'package:flutter/material.dart';

/// 文件消息卡片（R1 新增，群聊）：微信式蓝图标 + 文件名 + 大小。
/// 点击暂不实现（仅展示；后端 file 消息在 history 中可见）。
class FileBubble extends StatelessWidget {
  const FileBubble({super.key, required this.fileName, this.fileSize});

  final String fileName;
  final int? fileSize;

  String _sizeText(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final sizeText = _sizeText(fileSize);
    return Container(
      width: 214,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF576B95),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.insert_drive_file_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, color: Color(0xFF111111)),
                ),
                if (sizeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sizeText,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.more_horiz, color: Color(0xFF999999), size: 18),
        ],
      ),
    );
  }
}
