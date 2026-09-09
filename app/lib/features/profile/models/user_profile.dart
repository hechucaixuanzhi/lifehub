class UserProfileData {
  const UserProfileData({
    this.displayName = '我的',
    this.lifehubId = 'lifehub_user',
    this.avatarMediaId,
    this.signature = '',
    this.realityProfile = const {},
  });

  final String displayName;
  final String lifehubId;
  final String? avatarMediaId;
  final String signature;
  final Map<String, String> realityProfile;

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['reality_profile'];
    final reality = <String, String>{};
    if (rawProfile is Map) {
      for (final entry in rawProfile.entries) {
        if (entry.key is String && entry.value is String) {
          reality[entry.key as String] = entry.value as String;
        }
      }
    }
    final avatar = json['avatar_media_id'];
    return UserProfileData(
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['display_name'] as String).trim()
          : '我的',
      lifehubId: (json['lifehub_id'] as String?)?.trim().isNotEmpty == true
          ? (json['lifehub_id'] as String).trim()
          : 'lifehub_user',
      avatarMediaId: avatar is String && avatar.isNotEmpty ? avatar : null,
      signature: json['signature'] as String? ?? '',
      realityProfile: Map.unmodifiable(reality),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'lifehub_id': lifehubId,
        // 头像由 saveAvatar 独立更新；普通资料保存不携带 null，避免旧页面快照
        // 把刚上传成功的服务端头像意外清空。
        if (avatarMediaId != null) 'avatar_media_id': avatarMediaId,
        'signature': signature,
        'reality_profile': realityProfile,
      };

  UserProfileData copyWith({
    String? displayName,
    String? lifehubId,
    String? avatarMediaId,
    String? signature,
    Map<String, String>? realityProfile,
  }) =>
      UserProfileData(
        displayName: displayName ?? this.displayName,
        lifehubId: lifehubId ?? this.lifehubId,
        avatarMediaId: avatarMediaId ?? this.avatarMediaId,
        signature: signature ?? this.signature,
        realityProfile: realityProfile ?? this.realityProfile,
      );
}
