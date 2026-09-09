import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../ai/services/media_image_normalizer.dart';
import '../../ai/ui/media_crop_page.dart';
import '../logic/user_profile_notifier.dart';
import '../models/user_profile.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    UserProfileData value,
  ) async {
    final synced = await ref.read(userProfileProvider.notifier).save(value);
    if (!context.mounted) return;
    showAppToast(context, synced ? '已保存' : '已保存在手机，联网后自动同步');
  }

  Future<String?> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    int maxLength = 60,
    bool required = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          minLines: title == '个性签名' ? 2 : 1,
          maxLines: title == '个性签名' ? 4 : 1,
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF07C160)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('保存', style: TextStyle(color: Color(0xFF07C160))),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickAvatar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null || !context.mounted) return;
      final source = await picked.readAsBytes();
      final prepared = await prepareImageForCropping(source);
      if (!context.mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        AppPageRoute(
          builder: (_) => MediaCropPage(
            bytes: prepared,
            isAvatar: true,
            fileName: 'user-avatar.png',
            mime: 'image/png',
          ),
          enableSwipeBack: false,
        ),
      );
      if (cropped == null || !context.mounted) return;
      final normalized = normalizeCroppedMedia(cropped, isAvatar: true);
      // 先本地预览，再完成上传与资料同步。用户不再需要盯着旧头像等待网络。
      ref.read(userAvatarPreviewProvider.notifier).state = normalized.bytes;
      final mediaId = await ref.read(apiProvider).uploadAsset(
            normalized.bytes,
            'user-avatar.png',
            normalized.mimeType,
          );
      await ref.read(dbProvider).upsertMediaCache(
            MediaCacheRow(
              mediaId: mediaId,
              bytes: normalized.bytes,
              aspect: normalized.aspect,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      ref.invalidate(mediaBytesProvider(mediaId));
      if (!context.mounted) return;
      final synced =
          await ref.read(userProfileProvider.notifier).saveAvatar(mediaId);
      ref.read(userAvatarPreviewProvider.notifier).state = null;
      if (!context.mounted) return;
      showAppToast(
        context,
        synced ? '头像已保存' : '头像已保存在手机，联网后自动同步',
      );
    } on Object catch (error) {
      debugPrint('[user-avatar] import failed: $error');
      if (context.mounted) {
        showAppToast(context, '头像已立即预览，但上传失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(userProfileProvider).valueOrNull ?? const UserProfileData();
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        title: const Text('个人信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          ColoredBox(
            color: Colors.white,
            child: Column(
              children: [
                _InfoRow(
                  label: '头像',
                  customValue: const UserAvatar(size: 52, radius: 6),
                  onTap: () => _pickAvatar(context, ref),
                ),
                const Divider(height: 1, indent: 16),
                _InfoRow(
                  label: '昵称',
                  value: profile.displayName,
                  onTap: () async {
                    final value = await _editText(
                      context,
                      title: '昵称',
                      initial: profile.displayName,
                      maxLength: 40,
                      required: true,
                    );
                    if (value != null && context.mounted) {
                      await _save(
                          context, ref, profile.copyWith(displayName: value));
                    }
                  },
                ),
                const Divider(height: 1, indent: 16),
                _InfoRow(
                  label: 'LifeHub号',
                  value: profile.lifehubId,
                  onTap: () async {
                    final value = await _editText(
                      context,
                      title: 'LifeHub号',
                      initial: profile.lifehubId,
                      maxLength: 64,
                      required: true,
                    );
                    if (value != null && context.mounted) {
                      await _save(
                          context, ref, profile.copyWith(lifehubId: value));
                    }
                  },
                ),
                const Divider(height: 1, indent: 16),
                _InfoRow(
                  label: '个性签名',
                  value: profile.signature.isEmpty ? '未填写' : profile.signature,
                  onTap: () async {
                    final value = await _editText(
                      context,
                      title: '个性签名',
                      initial: profile.signature,
                      maxLength: 240,
                    );
                    if (value != null && context.mounted) {
                      await _save(
                          context, ref, profile.copyWith(signature: value));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ColoredBox(
            color: Colors.white,
            child: _InfoRow(
              label: '现实世界中的我',
              value: profile.realityProfile.isEmpty ? '未填写' : '已填写',
              onTap: () => Navigator.of(context).push(
                AppPageRoute(
                  builder: (_) => RealityProfilePage(profile: profile),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Text(
              '现实身份会作为 AI 认识你的主资料；其他世界的身份以后随对应世界观单独设置。',
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}

class RealityProfilePage extends ConsumerStatefulWidget {
  const RealityProfilePage({super.key, required this.profile});

  final UserProfileData profile;

  @override
  ConsumerState<RealityProfilePage> createState() => _RealityProfilePageState();
}

class _RealityProfilePageState extends ConsumerState<RealityProfilePage> {
  static const _fields = <(String, String, int)>[
    ('preferred_name', '姓名或角色名', 1),
    ('gender', '性别或称谓', 1),
    ('birthday', '生日', 1),
    ('location', '所在城市', 1),
    ('occupation', '职业', 1),
    ('appearance', '外貌与身体特征', 3),
    ('personality', '性格', 3),
    ('family_background', '家庭与成长背景', 4),
    ('current_situation', '当前生活状态', 4),
    ('important_experiences', '重要经历', 5),
  ];

  late final Map<String, TextEditingController> _controllers = {
    for (final field in _fields)
      field.$1: TextEditingController(
        text: widget.profile.realityProfile[field.$1] ?? '',
      ),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final values = <String, String>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) values[entry.key] = value;
    }
    final updated = widget.profile.copyWith(realityProfile: values);
    final synced = await ref.read(userProfileProvider.notifier).save(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppToast(context, synced ? '现实身份已保存' : '已保存在手机，联网后自动同步');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        title: const Text('现实世界中的我',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '保存',
                style: const TextStyle(color: Color(0xFF07C160))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const Text(
            '这里只保存你的全局基础资料。角色如何称呼你、如何认识以及她专属知道的信息，放在对应人物的角色档案里。',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 12),
          for (final field in _fields) ...[
            Text(field.$2,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
            const SizedBox(height: 6),
            TextField(
              controller: _controllers[field.$1],
              minLines: field.$3,
              maxLines: field.$3 + 2,
              maxLength: 2000,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.value,
    this.customValue,
    required this.onTap,
  });

  final String label;
  final String? value;
  final Widget? customValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customValue != null) customValue!,
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Color(0xFF888888)),
              ),
            ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, color: Color(0xFFB2B2B2)),
        ],
      ),
      onTap: onTap,
    );
  }
}
