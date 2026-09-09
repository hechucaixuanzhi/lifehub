import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../ai_providers.dart';
import '../models/character.dart';
import '../services/media_image_normalizer.dart';
import 'media_crop_page.dart';

/// 角色头像/聊天背景 换图统一入口（聊天页 ⋯ 菜单 / 聊天信息页共用）。
/// 相册选图 → 方向/格式归一化 → 裁切页（方形头像 / 9:16 背景）→
/// 生成标准 PNG/JPEG → 上传 → PATCH → 本地持久化并刷新全局。
///
/// 返回：null=取消；'ok'=已更新；'fail'=上传/PATCH 失败（保留原值）。
Future<String?> pickAndPatchCharacterMedia(
  BuildContext context,
  WidgetRef ref,
  Character character, {
  required bool isAvatar,
}) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
    if (picked == null || !context.mounted) return null;
    final sourceBytes = await picked.readAsBytes();
    final cropBytes = await prepareImageForCropping(sourceBytes);
    if (!context.mounted) return null;
    final cropped = await Navigator.of(context).push<Uint8List>(
      AppPageRoute(
        builder: (_) => MediaCropPage(
          bytes: cropBytes,
          isAvatar: isAvatar,
          fileName: isAvatar ? 'character-avatar.png' : 'chat-background.png',
          mime: 'image/png',
        ),
        // 裁切页内平移/缩放/捏合优先，禁右滑返回防止误触发
        enableSwipeBack: false,
      ),
    );
    if (cropped == null || !context.mounted) return null;
    final normalized = normalizeCroppedMedia(cropped, isAvatar: isAvatar);
    final api = ref.read(apiProvider);
    final mediaId = await api.uploadAsset(
      normalized.bytes,
      normalized.fileName,
      normalized.mimeType,
    );
    // 只 PATCH 被修改的字段（省略 = 不改，避免换背景把头像重置回默认）
    final response = isAvatar
        ? await api.patchCharacter(character.id, avatarMediaId: mediaId)
        : await api.patchCharacter(character.id, backgroundMediaId: mediaId);
    final rawCharacter = response['character'];
    if (rawCharacter is! Map) {
      throw const FormatException('PATCH character response is missing data');
    }
    // 服务端返回的是合并后的完整角色。必须以它为准，不能拿打开页面时的旧
    // character.copyWith：新角色连续换头像/背景时，旧对象会把另一个字段在本地
    // 覆盖回去，表现为“上传成功但不显示”。
    final updated = Character.fromJson(
      Map<String, dynamic>.from(rawCharacter),
    );
    // 服务端确认后立即把裁切成品写入手机 Drift；即使随后断网/重启，头像和背景
    // 也不需要重新下载。
    await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
          mediaId: mediaId,
          bytes: normalized.bytes,
          aspect: normalized.aspect,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
    // 若同一 mediaId 曾经短暂读取失败，清掉 FutureProvider 的空结果；下一次渲染
    // 会直接命中刚写入的 Drift 字节，不需要等待网络下载。
    ref.invalidate(mediaBytesProvider(mediaId));
    // 写穿本地缓存 + 立即生效（不依赖随后的网络刷新，慢隧道下也即时更新）。
    ref.read(charactersProvider.notifier).applyLocal(updated);
    return 'ok';
  } on Object catch (error, stackTrace) {
    debugPrint('[character-media] import failed: $error\n$stackTrace');
    return 'fail';
  }
}

/// 恢复默认头像 + 背景（PATCH 显式 null）。成功 → true，失败 → false。
Future<bool> resetCharacterMedia(
  BuildContext context,
  WidgetRef ref,
  Character character,
) async {
  try {
    final api = ref.read(apiProvider);
    final response = await api.patchCharacter(
      character.id,
      avatarMediaId: null,
      backgroundMediaId: null,
    );
    final rawCharacter = response['character'];
    if (rawCharacter is! Map) {
      throw const FormatException('PATCH character response is missing data');
    }
    ref.read(charactersProvider.notifier).applyLocal(
          Character.fromJson(Map<String, dynamic>.from(rawCharacter)),
        );
    return true;
  } on Object {
    return false;
  }
}
