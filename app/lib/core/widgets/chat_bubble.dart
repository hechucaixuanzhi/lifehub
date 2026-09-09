import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 微信风格聊天气泡（对齐原型 ChatBubble）：
/// 对方白底左 + 头像左；自己微信绿底右 + 头像右；气泡尖角方向随角色。
/// 支持引用回复条（quoteText 非空时显示在气泡内顶部）。
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.avatarText,
    this.avatarColor,
    this.avatar,
    this.onLongPress,
    this.quoteText,
    this.child,
  });

  final String text;
  final bool isMe;
  final String avatarText;
  final Color? avatarColor;

  /// 非空时替换默认 glyph 头像（换头像后气泡内渲染 CharacterAvatar）。
  final Widget? avatar;
  final VoidCallback? onLongPress;
  final String? quoteText;

  /// 非空时替换气泡内文本（图片缩略图 / 文件卡片），[text] 仍作菜单回退。
  final Widget? child;

  static const Color _meAvatar = Color(0xFF4A90D9);

  @override
  Widget build(BuildContext context) {
    final row = <Widget>[
      avatar ??
          _Avatar(text: avatarText, color: avatarColor ?? (isMe ? _meAvatar : AppColors.heart)),
      const SizedBox(width: 8),
      Flexible(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Stack(
            clipBehavior: Clip.none, // 允许尖角溢出到气泡外（不裁剪）
            children: [
              Container(
                // 媒体（图片/文件）紧贴气泡边缘，去掉内边距；文本保留微信留白
                padding: child == null
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
                    : const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.bubbleMe : AppColors.bubbleAi,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: isMe
                      ? null
                      : const [BoxShadow(color: Color(0x0A000000), blurRadius: 1)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (quoteText != null && quoteText!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: const Border(
                            left: BorderSide(color: Color(0xFFC8C8C8), width: 3),
                          ),
                        ),
                        child: Text(
                          '引用：$quoteText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    // 文本气泡：显式 softWrap，长段落/长串换行、气泡随内容长高（微信式）
                    if (child != null)
                      child!
                    else
                      Text(text, softWrap: true, style: AppTypography.body),
                  ],
                ),
              ),
              // 尖角
              Positioned(
                left: isMe ? null : -5,
                right: isMe ? -5 : null,
                top: 13,
                child: CustomPaint(
                  size: const Size(5, 10),
                  painter: _BubbleTipPainter(isMe: isMe),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        // 头像与气泡首行顶部对齐（微信风格）
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isMe ? row.reversed.toList() : row,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BubbleTipPainter extends CustomPainter {
  const _BubbleTipPainter({required this.isMe});
  final bool isMe;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMe ? AppColors.bubbleMe : AppColors.bubbleAi
      ..style = PaintingStyle.fill;
    final path = Path();
    // 尖角三角：尖点朝气泡外侧（对方左泡尖角朝左，自己右泡尖角朝右）
    if (isMe) {
      // 自己（气泡在右）：尖点在右侧 (w, h/2)，宽边在左
      path.moveTo(size.width, size.height / 2);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else {
      // 对方（气泡在左）：尖点在左侧 (0, h/2)，宽边在右
      path.moveTo(0, size.height / 2);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTipPainter oldDelegate) =>
      oldDelegate.isMe != isMe;
}
