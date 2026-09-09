import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/models/character.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';

/// 角色头像：有 [Character.avatarMediaId] → 拉图渲染（Image.memory 圆角/圆形）；
/// 否则 glyph + 色底兜底。会话列表（圆）/ 通讯录（圆）/ 聊天气泡（小圆角）复用。
class CharacterAvatar extends ConsumerWidget {
  const CharacterAvatar({
    super.key,
    required this.character,
    this.size = 38,
    this.shape = BoxShape.rectangle,
    this.radius = 6,
  });

  final Character character;
  final double size;

  /// circle → 圆形（通讯录/会话列表）；rectangle → 小圆角方形（聊天气泡，微信风）。
  final BoxShape shape;
  final double radius; // rectangle 时的圆角

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaId = character.avatarMediaId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final bytes = ref.watch(mediaBytesProvider(mediaId)).valueOrNull?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        // cacheWidth：按显示尺寸解码（头像 ≤48 逻辑像素），避免解码原图全分辨率
        // 大图每帧上传 GPU —— 冷启动/会话列表滚动不卡。
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final decodeW = (size * dpr).round();
        final img = Image.memory(bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: decodeW < 1 ? 1 : decodeW);
        return shape == BoxShape.circle
            ? ClipOval(child: img)
            : ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  // 旧头像素材可能自带透明圆角；先铺方形底，保证微信头像模板
                  // 始终呈现为圆角方框。后续新增角色自动复用同一规则。
                  color: const Color(0xFFF2F2F2),
                  child: SizedBox(width: size, height: size, child: img),
                ),
              );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: character.avatarColor,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        character.avatarText,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 聊天背景（010）：有 [Character.backgroundMediaId] → 铺满图；否则纯灰底。
class CharacterChatBackground extends ConsumerWidget {
  const CharacterChatBackground({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaId = character.backgroundMediaId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final bytes = ref.watch(mediaBytesProvider(mediaId)).valueOrNull?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        // cacheWidth：聊天背景按屏幕宽度解码（1920×1080 下是手机屏分辨率而非原图全尺寸），
        // 进入/右滑退出聊天页时不再每帧对全分辨率背景重采样 → 过渡不卡。
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final screenW = MediaQuery.sizeOf(context).width;
        final decodeW = (screenW * dpr).round();
        return SizedBox.expand(
          child: Image.memory(bytes,
              fit: BoxFit.cover, cacheWidth: decodeW < 1 ? 1 : decodeW),
        );
      }
    }
    // 无背景图 → 微信默认底：浅灰 + 45° 极淡斜线纹理（CustomPaint 前景层）
    return const CustomPaint(
      foregroundPainter: _ChatBgPatternPainter(),
      child: SizedBox.expand(
        child: ColoredBox(color: AppColors.chatBg),
      ),
    );
  }
}

/// 微信默认聊天底纹：45° 斜向细线，间距 5px、仅 4% 黑，几乎不可见但"有纹理"。
class _ChatBgPatternPainter extends CustomPainter {
  const _ChatBgPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A000000)
      ..strokeWidth = 1;
    const spacing = 5.0;
    // 从画布左外开始逐条画「↘」斜线，覆盖整块（含负区起点，避免右下角缺线）
    for (var start = -size.height; start < size.width; start += spacing) {
      canvas.drawLine(
        Offset(start, 0),
        Offset(start + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBgPatternPainter oldDelegate) => false;
}
