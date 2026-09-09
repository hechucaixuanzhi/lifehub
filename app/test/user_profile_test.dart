import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/features/profile/models/user_profile.dart';

void main() {
  test('user profile round-trips reality identity and avatar', () {
    const original = UserProfileData(
      displayName: 'John',
      lifehubId: 'john-lifehub',
      avatarMediaId: 'media-avatar',
      signature: '保持真实',
      realityProfile: {
        'character_call_name': '小威',
        'occupation': '独立开发者',
      },
    );

    final restored = UserProfileData.fromJson(original.toJson());
    expect(restored.displayName, 'John');
    expect(restored.lifehubId, 'john-lifehub');
    expect(restored.avatarMediaId, 'media-avatar');
    expect(restored.signature, '保持真实');
    expect(restored.realityProfile['character_call_name'], '小威');
    expect(restored.realityProfile['occupation'], '独立开发者');
  });

  test('invalid or blank identity fields fall back safely', () {
    final profile = UserProfileData.fromJson({
      'display_name': ' ',
      'lifehub_id': null,
      'avatar_media_id': '',
      'reality_profile': {'occupation': 42, 'notes': '保留'},
    });

    expect(profile.displayName, '我的');
    expect(profile.lifehubId, 'lifehub_user');
    expect(profile.avatarMediaId, isNull);
    expect(profile.realityProfile, {'notes': '保留'});
  });

  test('ordinary profile save does not clear an absent avatar', () {
    const profile = UserProfileData(displayName: 'John');
    expect(profile.toJson().containsKey('avatar_media_id'), isFalse);
  });
}
