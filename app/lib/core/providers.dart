import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/device_key_pair.dart';
import 'database/app_database.dart';
import 'network/api_client.dart';
import 'sync/sync_manager.dart';

/// 基础设施 Provider（在 main.dart 用 overrideWithValue 注入真实实例）。
/// 默认抛错，强制在根部完成装配，避免散落的全局单例。
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());
final deviceProvider =
    Provider<DeviceKeyPair>((ref) => throw UnimplementedError());
final apiProvider = Provider<ApiClient>((ref) => throw UnimplementedError());
final syncManagerProvider =
    Provider<SyncManager>((ref) => throw UnimplementedError());

/// 媒体字节（含解码宽高比）：media_asset_id → 字节 + aspect(width/height)。
/// 磁盘优先（MediaCache 表，优化1）：命中即秒出，免走慢隧道；未命中才下载并写回。
/// 媒体内容不可变（上传后不改）→ 缓存无需过期。下载/解码失败 → null 兜底。
class MediaBytes {
  const MediaBytes(this.bytes, this.aspect);
  final Uint8List bytes;
  final double? aspect;
}

final mediaBytesProvider =
    FutureProvider.family<MediaBytes?, String>((ref, mediaId) async {
  // 1) 磁盘缓存优先：冷启动秒开，免走慢隧道。
  try {
    final cached = await ref.read(dbProvider).getMediaCache(mediaId);
    if (cached != null && cached.bytes.isNotEmpty) {
      return MediaBytes(cached.bytes, cached.aspect);
    }
  } on Object catch (e) {
    debugPrint('[media:$mediaId] cache read failed: $e');
  }
  // 2) 未命中 → 网络下载，成功回写磁盘缓存。
  try {
    final api = ref.read(apiProvider);
    final resp = await api.getBytes('/media/$mediaId/content');
    if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
      final bytes = resp.bodyBytes;
      double? aspect;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        aspect = img.width / img.height;
        img.dispose();
      } on Object {
        aspect = null; // 非图片 / 解码失败：占位尺寸
      }
      try {
        await ref.read(dbProvider).upsertMediaCache(MediaCacheRow(
              mediaId: mediaId,
              bytes: bytes,
              aspect: aspect,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
      } on Object catch (e) {
        debugPrint('[media:$mediaId] cache write failed: $e');
      }
      return MediaBytes(bytes, aspect);
    }
    // 诊断：媒体拉取非 200（401/404/5xx…），真机看 logcat 定位。
    final body = resp.body;
    debugPrint(
      '[media:$mediaId] HTTP ${resp.statusCode} '
      'body=${body.length > 200 ? body.substring(0, 200) : body}',
    );
  } on Object catch (e) {
    debugPrint('[media:$mediaId] fetch error: $e');
  }
  return null;
});
