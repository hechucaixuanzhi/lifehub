import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/voice_player.dart';

/// 角色专属声音：入口放在「朋友资料」深层，不占聊天主界面。
/// 默认推荐原创音色设计；声音复刻只接受本人或已取得明确授权的样本。
class CharacterVoicePage extends ConsumerStatefulWidget {
  const CharacterVoicePage({
    super.key,
    required this.characterId,
    required this.characterName,
  });

  final String characterId;
  final String characterName;

  @override
  ConsumerState<CharacterVoicePage> createState() => _CharacterVoicePageState();
}

class _CharacterVoicePageState extends ConsumerState<CharacterVoicePage> {
  final _designPrompt = TextEditingController(
    text: '年轻成年女性，声线偏低而清澈，语气自然克制、温柔中带一点冷感；'
        '日常聊天口吻，不要播音腔；中文流畅，韩语发音自然；情绪变化细腻，笑声轻，不夸张。'
        '必须是原创音色，不模仿任何真实人物。',
  );
  final _previewText = TextEditingController(
    text: '嗯，我在听。你慢慢说就好，今天发生了什么？',
  );

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _working = false;
  String? _previewMediaId;
  int _previewDuration = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _designPrompt.dispose();
    _previewText.dispose();
    voicePlayer.stopAll();
    super.dispose();
  }

  String get _base => '/ai/characters/${widget.characterId}/voice';

  Future<void> _load() async {
    try {
      final response = await ref.read(apiProvider).get(_base);
      if (response.statusCode != 200) throw Exception('load failed');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _profile = body;
        final savedPrompt = body['design_prompt'] as String?;
        if (savedPrompt != null && savedPrompt.trim().isNotEmpty) {
          _designPrompt.text = savedPrompt;
        }
      });
    } on Object {
      if (mounted) showAppToast(context, '声音设置加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(String raw, String fallback) {
    try {
      final body = jsonDecode(raw) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        final error = detail['error'];
        if (error is Map<String, dynamic>) {
          return error['message'] as String? ?? fallback;
        }
      }
    } on Object {
      // 非 JSON 错误使用统一提示。
    }
    return fallback;
  }

  Future<void> _patch(Map<String, dynamic> values) async {
    final previous = _profile;
    setState(() => _profile = {...?_profile, ...values});
    try {
      final response = await ref.read(apiProvider).patch(_base, values);
      if (response.statusCode != 200) throw Exception('update failed');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) setState(() => _profile = {...?_profile, ...body});
    } on Object {
      if (mounted) {
        setState(() => _profile = previous);
        showAppToast(context, '声音设置未能同步');
      }
    }
  }

  Future<void> _designVoice() async {
    if (_working) return;
    if (_designPrompt.text.trim().isEmpty || _previewText.text.trim().isEmpty) {
      showAppToast(context, '请填写声音描述和试听内容');
      return;
    }
    setState(() => _working = true);
    try {
      final response = await ref.read(apiProvider).post('$_base/design', {
        'prompt': _designPrompt.text.trim(),
        'preview_text': _previewText.text.trim(),
      }).timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(response.body, '生成声音失败'));
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, ...body};
        _previewMediaId = body['preview_media_id'] as String?;
        _previewDuration =
            ((body['preview_duration'] as num?)?.toInt() ?? 1).clamp(1, 60);
      });
      showAppToast(context, '专属声音已生成，可以试听');
    } on Object catch (e) {
      if (mounted) {
        showAppToast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmConsent() async {
    var checked = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('确认声音授权'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '只能导入你本人的声音，或声音本人已明确授权用于复刻的样本。'
                '采访、直播、歌曲等公开可听内容不等于获得复刻授权。',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                activeColor: const Color(0xFF07C160),
                title: const Text('我确认拥有这段声音的复刻授权'),
                onChanged: (value) =>
                    setDialogState(() => checked = value == true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed:
                  checked ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('继续导入'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _cloneAuthorizedVoice() async {
    if (_working || !await _confirmConsent()) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav'],
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      showAppToast(context, '无法读取声音文件');
      return;
    }
    if (bytes.length > 20 * 1024 * 1024) {
      showAppToast(context, '声音样本不能超过 20MB');
      return;
    }
    setState(() => _working = true);
    try {
      final ext = file.extension?.toLowerCase() ?? 'wav';
      final mime = switch (ext) {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        _ => 'audio/wav',
      };
      final mediaId =
          await ref.read(apiProvider).uploadAsset(bytes, file.name, mime);
      final response = await ref.read(apiProvider).post('$_base/clone', {
        'media_asset_id': mediaId,
        'consent_confirmed': true,
        'text': _previewText.text.trim(),
      }).timeout(const Duration(minutes: 4));
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(
            response.body, '复刻失败，请确认音频为 10 秒至 5 分钟、环境安静且只有一个人说话'));
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, ...body};
        _previewMediaId = body['preview_media_id'] as String?;
        _previewDuration =
            ((body['preview_duration'] as num?)?.toInt() ?? 1).clamp(1, 60);
      });
      showAppToast(context, '授权声音已导入，可以试听');
    } on Object catch (e) {
      if (mounted) {
        showAppToast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteCustomVoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复默认声音'),
        content: const Text('当前专属声音会被永久删除，之后使用系统默认女声。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFE64340))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      final response = await ref.read(apiProvider).delete(_base);
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(response.body, '删除声音失败'));
      }
      await voicePlayer.stopAll();
      if (!mounted) return;
      setState(() {
        _profile = {
          ...?_profile,
          'source_type': 'system',
          'voice_id': null,
          'has_custom_voice': false,
          'enabled': true,
        };
        _previewMediaId = null;
      });
      showAppToast(context, '已恢复系统默认声音');
    } on Object catch (e) {
      if (mounted) {
        showAppToast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String get _sourceLabel => switch (_profile?['source_type']) {
        'design' => '原创角色音色',
        'clone' => '授权复刻音色',
        _ => '系统默认女声',
      };

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final enabled = profile?['enabled'] as bool? ?? true;
    final hasCustom = profile?['has_custom_voice'] as bool? ?? false;
    final configured = profile?['configured'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: Text('${widget.characterName}的声音',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              children: [
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('角色语音'),
                        subtitle: Text(configured
                            ? '$_sourceLabel；文字回复由聊天输入框的小话筒控制，发送语音时自动语音回复'
                            : '后端语音服务尚未配置'),
                        trailing: Switch(
                          value: enabled,
                          activeTrackColor: const Color(0xFF07C160),
                          onChanged: configured && !_working
                              ? (value) => _patch({'enabled': value})
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_previewMediaId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        const Text('试听', style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        _PreviewButton(
                          mediaId: _previewMediaId!,
                          duration: _previewDuration,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('设计原创声音',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      const Text('推荐。保持角色辨识度，同时不复刻任何真实人物。',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _designPrompt,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '声音描述',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _previewText,
                        maxLength: 120,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '试听内容',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              configured && !_working ? _designVoice : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF07C160),
                          ),
                          child: Text(_working ? '处理中…' : '生成并试听'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    title: const Text('导入已获授权的声音'),
                    subtitle: const Text('mp3 / m4a / wav，10秒至5分钟，最大20MB'),
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap:
                        configured && !_working ? _cloneAuthorizedVoice : null,
                  ),
                ),
                if (hasCustom) ...[
                  const SizedBox(height: 8),
                  Container(
                    color: Colors.white,
                    child: ListTile(
                      title: const Center(
                        child: Text('恢复默认声音',
                            style: TextStyle(color: Color(0xFFE64340))),
                      ),
                      onTap: _working ? null : _deleteCustomVoice,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PreviewButton extends ConsumerStatefulWidget {
  const _PreviewButton({required this.mediaId, required this.duration});

  final String mediaId;
  final int duration;

  @override
  ConsumerState<_PreviewButton> createState() => _PreviewButtonState();
}

class _PreviewButtonState extends ConsumerState<_PreviewButton> {
  @override
  void initState() {
    super.initState();
    voicePlayer.addListener(_changed);
  }

  @override
  void dispose() {
    voicePlayer.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    try {
      final cached = ref.read(mediaBytesProvider(widget.mediaId)).valueOrNull;
      final media =
          cached ?? await ref.read(mediaBytesProvider(widget.mediaId).future);
      if (media == null || media.bytes.isEmpty) {
        throw Exception('preview unavailable');
      }
      await voicePlayer.toggle(widget.mediaId, media.bytes);
    } on Object {
      if (mounted) showAppToast(context, '试听加载失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = voicePlayer.isPlayingFor(widget.mediaId);
    return OutlinedButton.icon(
      onPressed: _play,
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      label: Text('${widget.duration}"'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF07C160),
      ),
    );
  }
}
