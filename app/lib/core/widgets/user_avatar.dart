import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/logic/user_profile_notifier.dart';
import '../providers.dart';

/// 用户刚裁剪好的头像先走内存预览，避免等待上传和后端同步后才刷新界面。
/// 上传成功后会切回带本地媒体缓存的正式 mediaId，视觉上不会闪回旧头像。
final userAvatarPreviewProvider = StateProvider<Uint8List?>((ref) => null);

class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.size = 40, this.radius = 6});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(userAvatarPreviewProvider);
    if (preview != null && preview.isNotEmpty) {
      return _memoryAvatar(context, preview);
    }
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final mediaId = profile?.avatarMediaId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final bytes = ref.watch(mediaBytesProvider(mediaId)).valueOrNull?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        return _memoryAvatar(context, bytes);
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF576B95),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: size * .62, color: Colors.white),
    );
  }

  Widget _memoryAvatar(BuildContext context, Uint8List bytes) {
    final decodeWidth =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 4096);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
      ),
    );
  }
}
