import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../ai_providers.dart';
import '../services/character_archive_service.dart';

class CharacterArchiveEditorPage extends ConsumerStatefulWidget {
  const CharacterArchiveEditorPage({super.key, required this.archive});

  final CharacterArchiveData archive;

  @override
  ConsumerState<CharacterArchiveEditorPage> createState() =>
      _CharacterArchiveEditorPageState();
}

class _CharacterArchiveEditorPageState
    extends ConsumerState<CharacterArchiveEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late bool _originEnabled;
  late bool _inheritUserProfile;
  bool _saving = false;

  Map<String, dynamic> get _persona => widget.archive.persona;

  Map<String, dynamic> get _realWorld {
    for (final world in widget.archive.worldviews) {
      if (world['key'] == 'real') return world;
    }
    return widget.archive.worldviews.isEmpty
        ? <String, dynamic>{}
        : widget.archive.worldviews.first;
  }

  @override
  void initState() {
    super.initState();
    _originEnabled = _persona['origin_world_enabled'] as bool? ?? true;
    _inheritUserProfile =
        widget.archive.knownUser['inherit_profile'] as bool? ?? false;
    final knownOverrides = _map(widget.archive.knownUser['field_overrides']);
    _add('name', widget.archive.name);
    _add('tagline', widget.archive.tagline);
    _add('welcome_message', widget.archive.welcomeMessage);
    _add('origin_identity', _text(_persona, 'origin_identity'));
    _add('origin_history', _text(_persona, 'origin_history'));
    _add('core_personality', _text(_persona, 'core_personality'));
    _add('speech_style', _text(_persona, 'speech_style'));
    _add('appearance', _text(_persona, 'appearance'));
    _add('interests', _text(_persona, 'interests'));
    _add('boundaries', _text(_persona, 'boundaries'));
    _add('catchphrases', _text(_persona, 'catchphrases'));
    _add('example_dialogue', _text(_persona, 'example_dialogue'));
    _add(
      'relationship_principles',
      _text(_persona, 'relationship_principles'),
    );
    _add('world_name', _text(_realWorld, 'name', fallback: '现实世界'));
    _add('world_identity', _text(_realWorld, 'identity'));
    _add('world_backstory', _text(_realWorld, 'backstory'));
    _add('world_rules', _text(_realWorld, 'rules'));
    _add('world_preferences', _text(_realWorld, 'preferences'));
    _add('known_call_name', _text(knownOverrides, 'character_call_name'));
    _add('known_meeting_story', _text(knownOverrides, 'meeting_story'));
    _add('known_notes', _text(knownOverrides, 'notes'));
  }

  void _add(String key, String value) {
    _controllers[key] = TextEditingController(text: value);
  }

  String _value(String key) => _controllers[key]!.text.trim();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(characterArchiveProvider(widget.archive.characterId).notifier)
          .saveDefinition({
        'name': _value('name'),
        'tagline': _value('tagline'),
        'welcome_message': _value('welcome_message'),
        'persona': {
          'origin_world_enabled': _originEnabled,
          'origin_identity': _value('origin_identity'),
          'origin_history': _value('origin_history'),
          'core_personality': _value('core_personality'),
          'speech_style': _value('speech_style'),
          'appearance': _value('appearance'),
          'interests': _value('interests'),
          'boundaries': _value('boundaries'),
          'catchphrases': _value('catchphrases'),
          'example_dialogue': _value('example_dialogue'),
          'relationship_principles': _value('relationship_principles'),
        },
        'worldview': {
          'name': _value('world_name'),
          'identity': _value('world_identity'),
          'backstory': _value('world_backstory'),
          'rules': _value('world_rules'),
          'preferences': _value('world_preferences'),
        },
        'known_user': {
          'inherit_profile': _inheritUserProfile,
          'fields': {
            'character_call_name': _value('known_call_name'),
            'meeting_story': _value('known_meeting_story'),
            'notes': _value('known_notes'),
          },
        },
      });
      await ref.read(charactersProvider.notifier).reload();
      if (mounted) {
        showAppToast(context, '角色档案已保存');
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) showAppToast(context, '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: AppColors.onBg,
        elevation: 0,
        title: const Text('编辑角色档案',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            _section(
              title: '基础公开资料',
              subtitle: '姓名、签名与第一句话',
              children: [
                _field('name', '姓名', required: true, maxLines: 1),
                _field('tagline', '签名', maxLines: 2),
                _field('welcome_message', '首次招呼', maxLines: 3),
                _field('origin_identity', '公开现实身份'),
              ],
            ),
            _section(
              title: '人格与表达',
              subtitle: '长期稳定的性格、语气和边界',
              children: [
                _field('core_personality', '核心人格'),
                _field('speech_style', '说话方式'),
                _field('appearance', '外貌与视觉锚点'),
                _field('interests', '兴趣与习惯'),
                _field('boundaries', '原则与边界'),
                _field('catchphrases', '典型表达'),
                _field('example_dialogue', '示例对话', minLines: 5),
              ],
            ),
            _section(
              title: '历史与关系',
              subtitle: '她如何理解自己的经历与关系发展',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用现实历史'),
                  subtitle: const Text('关闭后聊天不注入原世界身份与经历'),
                  value: _originEnabled,
                  onChanged: (value) => setState(() => _originEnabled = value),
                ),
                _field('origin_history', '人生历史主线', minLines: 6),
                _field(
                  'relationship_principles',
                  '关系发展原则',
                  minLines: 5,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '公开活动时间线仍保留来源与日期；这里改写的是角色对自己人生的连续叙述。',
                    style: TextStyle(
                        fontSize: 12, height: 1.45, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            _section(
              title: '现实世界观',
              subtitle: '现实身份、背景、规则与偏好',
              children: [
                _field('world_name', '世界名称', required: true, maxLines: 1),
                _field('world_identity', '在该世界的身份'),
                _field('world_backstory', '背景经历', minLines: 5),
                _field('world_rules', '世界规则', minLines: 4),
                _field('world_preferences', '偏好与习惯', minLines: 4),
              ],
            ),
            _section(
              title: '她所知道的你',
              subtitle: '只属于这个角色，不与其他人物共享',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许她读取我的基本信息'),
                  subtitle: const Text(
                    '关闭时默认对你一无所知；下方单独填写的内容仍只供她知道。',
                  ),
                  value: _inheritUserProfile,
                  onChanged: (value) =>
                      setState(() => _inheritUserProfile = value),
                ),
                _field('known_call_name', '她如何称呼你', maxLines: 2),
                _field('known_meeting_story', '你们如何认识', minLines: 4),
                _field('known_notes', '只希望她知道的补充信息', minLines: 5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: ExpansionTile(
        initiallyExpanded: title == '基础公开资料',
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int minLines = 3,
    int maxLines = 10,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: _controllers[key],
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          alignLabelWithHint: maxLines > 1,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? '请填写$label' : null
            : null,
      ),
    );
  }
}

String _text(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  return value is String && value.isNotEmpty ? value : fallback;
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
