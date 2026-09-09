import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../models/user_profile.dart';

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfileData>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserProfileData> {
  static const _cacheKey = 'user_profile_v1';
  static const _pendingKey = 'user_profile_pending_v1';
  int _localRevision = 0;

  @override
  Future<UserProfileData> build() async {
    final cached = await ref.read(dbProvider).getKvRow(_cacheKey);
    final local = _decode(cached?.value);
    unawaited(_refreshOrRetryPending());
    return local ?? const UserProfileData();
  }

  /// 手机先持久化，再同步后端。false 表示本地已保存、等待下次自动补传。
  Future<bool> save(UserProfileData value) async {
    final revision = ++_localRevision;
    state = AsyncData(value);
    final raw = jsonEncode(value.toJson());
    await ref.read(dbProvider).upsertKv(_cacheKey, raw);
    await ref.read(dbProvider).upsertKv(_pendingKey, raw);
    return _push(value, revision: revision);
  }

  /// 头像使用独立 PATCH，避免同时提交一份旧的昵称/身份快照，或被初始化中的
  /// GET /profile 旧响应覆盖。上传成功后立即写本地，断网时也能正常显示。
  Future<bool> saveAvatar(String mediaId) async {
    final current = state.valueOrNull ?? const UserProfileData();
    final value = current.copyWith(avatarMediaId: mediaId);
    final revision = ++_localRevision;
    state = AsyncData(value);
    final raw = jsonEncode(value.toJson());
    final db = ref.read(dbProvider);
    await db.upsertKv(_cacheKey, raw);
    await db.upsertKv(_pendingKey, raw);
    try {
      final response = await ref.read(apiProvider).patch('/profile',
          {'avatar_media_id': mediaId}).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      return _acceptRemote(response.body, revision);
    } on Object catch (error) {
      debugPrint('[user-profile] avatar sync failed: $error');
      return false;
    }
  }

  Future<bool> _push(
    UserProfileData value, {
    int? revision,
  }) async {
    try {
      final response = await ref
          .read(apiProvider)
          .patch('/profile', value.toJson())
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return false;
      return _acceptRemote(response.body, revision);
    } on Object catch (error) {
      debugPrint('[user-profile] sync failed: $error');
      return false;
    }
  }

  Future<void> _refreshOrRetryPending() async {
    final revisionAtStart = _localRevision;
    try {
      final db = ref.read(dbProvider);
      final pending = _decode((await db.getKvRow(_pendingKey))?.value);
      if (pending != null) {
        await _push(pending, revision: revisionAtStart);
        return;
      }
      final response = await ref
          .read(apiProvider)
          .get('/profile')
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = UserProfileData.fromJson(
        root['profile'] as Map<String, dynamic>,
      );
      if (revisionAtStart != _localRevision) return;
      state = AsyncData(remote);
      await db.upsertKv(_cacheKey, jsonEncode(remote.toJson()));
    } on Object catch (error) {
      debugPrint('[user-profile] refresh failed: $error');
    }
  }

  Future<bool> _acceptRemote(String body, int? revision) async {
    // 请求发出后若用户又保存了更新资料，旧响应只能算同步成功，不能覆盖新本地态，
    // 也不能清掉新一轮 pending。
    if (revision != null && revision != _localRevision) return true;
    final root = jsonDecode(body) as Map<String, dynamic>;
    final profile = UserProfileData.fromJson(
      root['profile'] as Map<String, dynamic>,
    );
    state = AsyncData(profile);
    final db = ref.read(dbProvider);
    await db.upsertKv(_cacheKey, jsonEncode(profile.toJson()));
    await db.upsertKv(_pendingKey, '');
    return true;
  }

  UserProfileData? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfileData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
