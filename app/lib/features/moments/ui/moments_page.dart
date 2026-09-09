import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../ai/ai_providers.dart';
import '../../ai/models/character.dart';
import '../../ai/ui/profile_page.dart';
import '../../profile/logic/user_profile_notifier.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/ui/user_profile_page.dart';

class MomentActor {
  const MomentActor({
    required this.type,
    required this.id,
    required this.name,
    this.avatarMediaId,
    this.avatarText = '角',
    this.avatarColor = '#576B95',
  });

  final String type;
  final String id;
  final String name;
  final String? avatarMediaId;
  final String avatarText;
  final String avatarColor;

  factory MomentActor.fromJson(Map<String, dynamic> json) => MomentActor(
        type: json['type'] as String? ?? 'user',
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '我的',
        avatarMediaId: json['avatar_media_id'] as String?,
        avatarText: json['avatar_text'] as String? ?? '角',
        avatarColor: json['avatar_color'] as String? ?? '#576B95',
      );
}

class MomentMediaData {
  const MomentMediaData({this.mediaAssetId, this.remoteUrl});

  final String? mediaAssetId;
  final String? remoteUrl;

  factory MomentMediaData.fromJson(Map<String, dynamic> json) =>
      MomentMediaData(
        mediaAssetId: json['media_asset_id'] as String?,
        remoteUrl: json['remote_url'] as String?,
      );
}

class MomentCommentData {
  const MomentCommentData({
    required this.id,
    required this.actor,
    required this.content,
    this.replyToId,
  });

  final String id;
  final MomentActor actor;
  final String content;
  final String? replyToId;

  factory MomentCommentData.fromJson(Map<String, dynamic> json) =>
      MomentCommentData(
        id: json['id'] as String? ?? '',
        actor: MomentActor.fromJson(
          json['actor'] as Map<String, dynamic>? ?? const {},
        ),
        content: json['content'] as String? ?? '',
        replyToId: json['reply_to_id'] as String?,
      );
}

class MomentPost {
  const MomentPost({
    required this.id,
    required this.author,
    required this.content,
    required this.publishedAt,
    required this.media,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    this.location,
    this.sourcePlatform,
    this.sourceUrl,
    this.publishedPrecision = 'datetime',
  });

  final String id;
  final MomentActor author;
  final String content;
  final DateTime publishedAt;
  final List<MomentMediaData> media;
  final List<MomentActor> likes;
  final List<MomentCommentData> comments;
  final bool likedByMe;
  final String? location;
  final String? sourcePlatform;
  final String? sourceUrl;
  final String publishedPrecision;

  factory MomentPost.fromJson(Map<String, dynamic> json) => MomentPost(
        id: json['id'] as String? ?? '',
        author: MomentActor.fromJson(
          json['author'] as Map<String, dynamic>? ?? const {},
        ),
        content: json['content'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        media: [
          for (final item in json['media'] as List? ?? const [])
            MomentMediaData.fromJson(item as Map<String, dynamic>),
        ],
        likes: [
          for (final item in json['likes'] as List? ?? const [])
            MomentActor.fromJson(
              (item as Map<String, dynamic>)['actor']
                      as Map<String, dynamic>? ??
                  const {},
            ),
        ],
        comments: [
          for (final item in json['comments'] as List? ?? const [])
            MomentCommentData.fromJson(item as Map<String, dynamic>),
        ],
        likedByMe: json['liked_by_me'] as bool? ?? false,
        location: json['location'] as String?,
        sourcePlatform: json['source_platform'] as String?,
        sourceUrl: json['source_url'] as String?,
        publishedPrecision:
            json['published_precision'] as String? ?? 'datetime',
      );
}

/// 微信式朋友圈。无筛选时是总动态；[characterId] / [userOnly] 用于个人资料页。
class MomentsPage extends ConsumerStatefulWidget {
  const MomentsPage({super.key, this.characterId, this.userOnly = false});

  final String? characterId;
  final bool userOnly;

  @override
  ConsumerState<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends ConsumerState<MomentsPage> {
  var _posts = <MomentPost>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  String get _query {
    if (widget.characterId != null) {
      return '?author_type=character&character_id=${Uri.encodeQueryComponent(widget.characterId!)}';
    }
    if (widget.userOnly) return '?author_type=user';
    return '';
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final response = await ref
          .read(apiProvider)
          .get('/moments$_query')
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final posts = [
        for (final item in root['moments'] as List? ?? const [])
          MomentPost.fromJson(item as Map<String, dynamic>),
      ];
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '朋友圈加载失败，请下拉重试';
        _loading = false;
      });
      debugPrint('[moments] load failed: $error');
    }
  }

  void _replace(MomentPost post) {
    setState(() {
      _posts = [
        for (final item in _posts)
          if (item.id == post.id) post else item
      ];
    });
  }

  Future<void> _toggleLike(MomentPost post) async {
    try {
      final response = await ref.read(apiProvider).post(
        '/moments/${post.id}/like',
        const {},
      );
      if (response.statusCode != 200) throw Exception(response.body);
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      _replace(MomentPost.fromJson(root['moment'] as Map<String, dynamic>));
    } on Object catch (error) {
      debugPrint('[moments] like failed: $error');
      if (mounted) showAppToast(context, '点赞失败，请重试');
    }
  }

  Future<void> _comment(MomentPost post, {MomentCommentData? replyTo}) async {
    final controller = TextEditingController();
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F7F7),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  hintText: replyTo == null ? '评论' : '回复 @${replyTo.actor.name}',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.of(sheetContext).pop(value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                minimumSize: const Size(62, 46),
              ),
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (content == null || !mounted) return;
    showAppToast(context, '评论已发送，等待她回复…');
    try {
      final response = await ref.read(apiProvider).post(
        '/moments/${post.id}/comments',
        {
          'content': content,
          if (replyTo != null) 'reply_to_id': replyTo.id,
        },
      );
      if (response.statusCode != 200) throw Exception(response.body);
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      _replace(MomentPost.fromJson(root['moment'] as Map<String, dynamic>));
    } on Object catch (error) {
      debugPrint('[moments] comment failed: $error');
      if (mounted) showAppToast(context, '评论发送失败，请重试');
    }
  }

  Future<void> _compose() async {
    final created = await Navigator.of(context).push<bool>(
      AppPageRoute(builder: (_) => const MomentComposerPage()),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final chars =
        ref.watch(charactersProvider).valueOrNull ?? defaultCharacters;
    Character? character;
    for (final item in chars) {
      if (item.id == widget.characterId) character = item;
    }
    final profile =
        ref.watch(userProfileProvider).valueOrNull ?? const UserProfileData();
    final canPublish = widget.characterId == null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFF07C160),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _MomentsHeader(
              character: character,
              profile: profile,
              onCamera: canPublish ? _compose : null,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(44),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFF888888))),
                ),
              )
            else if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(44),
                child: Center(
                  child: Text('还没有朋友圈',
                      style: TextStyle(color: Color(0xFF888888))),
                ),
              )
            else
              for (final post in _posts)
                _MomentTile(
                  post: post,
                  characters: chars,
                  onLike: () => _toggleLike(post),
                  onComment: () => _comment(post),
                  onReplyComment: (comment) => _comment(post, replyTo: comment),
                ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

class _MomentsHeader extends StatelessWidget {
  const _MomentsHeader({
    required this.character,
    required this.profile,
    required this.onCamera,
  });

  final Character? character;
  final UserProfileData profile;
  final VoidCallback? onCamera;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 345,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: 40,
            child: character?.backgroundMediaId == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B2638), Color(0xFF111111)],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.landscape_outlined,
                          size: 94, color: Color(0x33FFFFFF)),
                    ),
                  )
                : CharacterChatBackground(character: character!),
          ),
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 26),
                ),
                const Spacer(),
                if (onCamera != null)
                  IconButton(
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 29),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  character?.name ?? profile.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: character == null
                      ? const UserAvatar(size: 72, radius: 6)
                      : CharacterAvatar(
                          character: character!, size: 72, radius: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentTile extends StatelessWidget {
  const _MomentTile({
    required this.post,
    required this.characters,
    required this.onLike,
    required this.onComment,
    this.onReplyComment,
  });

  final MomentPost post;
  final List<Character> characters;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final void Function(MomentCommentData comment)? onReplyComment;

  Character? get character {
    for (final item in characters) {
      if (item.id == post.author.id) return item;
    }
    return null;
  }

  void _openActor(BuildContext context) {
    if (post.author.type == 'user') {
      Navigator.of(context).push(
        AppPageRoute(builder: (_) => const UserProfilePage()),
      );
    } else if (character != null) {
      Navigator.of(context).push(
        AppPageRoute(builder: (_) => ProfilePage(character: character!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSocial = post.likes.isNotEmpty || post.comments.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: .5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openActor(context),
            child: _ActorAvatar(actor: post.author, character: character),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openActor(context),
                  child: Text(
                    post.author.name,
                    style: const TextStyle(
                      color: Color(0xFF576B95),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (post.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(post.content,
                      style: const TextStyle(fontSize: 16, height: 1.35)),
                ],
                if (post.media.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _MomentMediaGrid(media: post.media),
                ],
                if (post.location?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  Text(post.location!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF576B95))),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                        _timeLabel(
                          post.publishedAt,
                          precision: post.publishedPrecision,
                        ),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF999999))),
                    if (post.sourcePlatform == 'instagram') ...[
                      const SizedBox(width: 8),
                      const Text('来自 Instagram',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF576B95))),
                    ],
                    const Spacer(),
                    _SocialMenu(
                      liked: post.likedByMe,
                      onLike: onLike,
                      onComment: onComment,
                    ),
                  ],
                ),
                if (hasSocial) ...[
                  const SizedBox(height: 7),
                  _SocialBox(post: post, onReplyComment: onReplyComment),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.actor, required this.character});

  final MomentActor actor;
  final Character? character;

  @override
  Widget build(BuildContext context) {
    if (actor.type == 'user') return const UserAvatar(size: 44, radius: 5);
    if (character != null) {
      return CharacterAvatar(character: character!, size: 44, radius: 5);
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: parseHexColor(actor.avatarColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(actor.avatarText,
          style: const TextStyle(color: Colors.white, fontSize: 18)),
    );
  }
}

class _MomentMediaGrid extends StatelessWidget {
  const _MomentMediaGrid({required this.media});

  final List<MomentMediaData> media;

  @override
  Widget build(BuildContext context) {
    final shown = media.take(9).toList();
    if (shown.length == 1) {
      return SizedBox(
        width: 210,
        height: 210,
        child: _MomentImage(media: shown.first),
      );
    }
    final width = MediaQuery.sizeOf(context).width - 92;
    final cell = (width - 6) / 3;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final item in shown)
          SizedBox(width: cell, height: cell, child: _MomentImage(media: item)),
      ],
    );
  }
}

class _MomentImage extends ConsumerWidget {
  const _MomentImage({required this.media});

  final MomentMediaData media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaId = media.mediaAssetId;
    if (mediaId != null && mediaId.isNotEmpty) {
      final value = ref.watch(mediaBytesProvider(mediaId));
      final bytes = value.valueOrNull?.bytes;
      if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      return const ColoredBox(
        color: Color(0xFFF0F0F0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      );
    }
    final url = media.remoteUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFF0F0F0),
          child: Center(
              child:
                  Icon(Icons.broken_image_outlined, color: Color(0xFFAAAAAA))),
        ),
      );
    }
    return const ColoredBox(color: Color(0xFFF0F0F0));
  }
}

class _SocialMenu extends StatelessWidget {
  const _SocialMenu({
    required this.liked,
    required this.onLike,
    required this.onComment,
  });

  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: '点赞或评论',
      color: const Color(0xFF4C4C4C),
      constraints: const BoxConstraints(minWidth: 188),
      onSelected: (value) => value == 'like' ? onLike() : onComment(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'like',
          child: Row(
            children: [
              Icon(liked ? Icons.favorite : Icons.favorite_border,
                  size: 21, color: Colors.white),
              const SizedBox(width: 8),
              Text(liked ? '取消' : '赞',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'comment',
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text('评论', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 34,
        height: 23,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.more_horiz, size: 21, color: Color(0xFF576B95)),
      ),
    );
  }
}

class _SocialBox extends StatelessWidget {
  const _SocialBox({required this.post, this.onReplyComment});

  final MomentPost post;
  final void Function(MomentCommentData comment)? onReplyComment;

  /// 楼中楼（D）：解析被回复评论的作者名；查不到（评论已删）→ 显示本条作者名。
  String _replyTargetName(MomentCommentData comment) {
    final replyToId = comment.replyToId;
    if (replyToId == null) return comment.actor.name;
    for (final c in post.comments) {
      if (c.id == replyToId) return c.actor.name;
    }
    return comment.actor.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: const Color(0xFFF3F3F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.likes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite, size: 16, color: Color(0xFF576B95)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.likes.map((item) => item.name).join('，'),
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF576B95)),
                  ),
                ),
              ],
            ),
          if (post.likes.isNotEmpty && post.comments.isNotEmpty)
            const Divider(height: 8, color: Color(0xFFE2E2E4)),
          for (final comment in post.comments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: InkWell(
                // 点评论即回复（微信式楼中楼）
                onTap: onReplyComment == null
                    ? null
                    : () => onReplyComment!(comment),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: comment.replyToId != null ? 16 : 0,
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                          fontSize: 14, height: 1.35, color: Color(0xFF111111)),
                      children: [
                        TextSpan(
                          text: comment.actor.name,
                          style: const TextStyle(color: Color(0xFF576B95)),
                        ),
                        if (comment.replyToId != null) ...[
                          const TextSpan(text: ' 回复 '),
                          TextSpan(
                            text: _replyTargetName(comment),
                            style: const TextStyle(color: Color(0xFF576B95)),
                          ),
                        ],
                        TextSpan(text: '：${comment.content}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MomentComposerPage extends ConsumerStatefulWidget {
  const MomentComposerPage({super.key});

  @override
  ConsumerState<MomentComposerPage> createState() => _MomentComposerPageState();
}

class _MomentComposerPageState extends ConsumerState<MomentComposerPage> {
  final _controller = TextEditingController();
  final _images = <({XFile file, Uint8List bytes})>[];
  bool _publishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _images.length;
    if (remaining <= 0) return;
    final selected = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
      limit: remaining,
    );
    if (!mounted || selected.isEmpty) return;
    final additions = <({XFile file, Uint8List bytes})>[];
    for (final file in selected.take(remaining)) {
      additions.add((file: file, bytes: await file.readAsBytes()));
    }
    if (mounted) setState(() => _images.addAll(additions));
  }

  String _mime(XFile file) {
    if (file.mimeType?.isNotEmpty == true) return file.mimeType!;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final content = _controller.text.trim();
    if (content.isEmpty && _images.isEmpty) {
      showAppToast(context, '写点内容或选择图片');
      return;
    }
    setState(() => _publishing = true);
    try {
      final api = ref.read(apiProvider);
      final mediaIds = <String>[];
      for (final image in _images) {
        mediaIds.add(await api.uploadAsset(
          image.bytes,
          image.file.name,
          _mime(image.file),
        ));
      }
      final response = await api.post('/moments', {
        'content': content,
        'media_asset_ids': mediaIds,
      });
      if (response.statusCode != 200) throw Exception(response.body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      debugPrint('[moments] publish failed: $error');
      if (mounted) {
        setState(() => _publishing = false);
        showAppToast(context, '发布失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        title: const Text('发表朋友圈',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: FilledButton(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(_publishing ? '发布中' : '发表'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: '这一刻的想法…',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    Image.memory(_images[i].bytes,
                        width: 94, height: 94, fit: BoxFit.cover),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black54,
                          child:
                              Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < 9)
                InkWell(
                  onTap: _pickImages,
                  child: Container(
                    width: 94,
                    height: 94,
                    color: const Color(0xFFF1F1F1),
                    child: const Icon(Icons.add,
                        size: 35, color: Color(0xFF888888)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_on_outlined),
            title: Text('所在位置'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people_outline),
            title: Text('谁可以看'),
            subtitle: Text('仅 LifeHub 私人空间'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

String _timeLabel(DateTime time, {String precision = 'datetime'}) {
  final now = DateTime.now();
  if (precision == 'date') {
    return time.year == now.year
        ? '${time.month}月${time.day}日'
        : '${time.year}年${time.month}月${time.day}日';
  }
  final delta = now.difference(time);
  if (!delta.isNegative && delta.inMinutes < 1) return '刚刚';
  if (!delta.isNegative && delta.inHours < 1) return '${delta.inMinutes}分钟前';
  if (!delta.isNegative && delta.inDays < 1) return '${delta.inHours}小时前';
  if (time.year == now.year) {
    return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  return '${time.year}年${time.month}月${time.day}日';
}
