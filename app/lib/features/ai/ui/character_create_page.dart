import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../ai_providers.dart';
import '../models/character.dart';

/// 通讯录新增人物：只要基础公开资料即可建立，详细角色卡后补。
class CharacterCreatePage extends ConsumerStatefulWidget {
  const CharacterCreatePage({super.key});

  @override
  ConsumerState<CharacterCreatePage> createState() =>
      _CharacterCreatePageState();
}

class _CharacterCreatePageState extends ConsumerState<CharacterCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identity = TextEditingController();
  final _tagline = TextEditingController();
  final _welcome = TextEditingController();
  bool _inheritUserProfile = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _identity.dispose();
    _tagline.dispose();
    _welcome.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'origin_identity': _identity.text.trim(),
        'tagline': _tagline.text.trim(),
        'inherit_user_profile': _inheritUserProfile,
      };
      if (_welcome.text.trim().isNotEmpty) {
        body['welcome_message'] = _welcome.text.trim();
      }
      final response = await ref
          .read(apiProvider)
          .post('/ai/characters', body)
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw StateError('创建失败（${response.statusCode}）');
      }
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final character = Character.fromJson(
        Map<String, dynamic>.from(root['character'] as Map),
      );
      ref.read(charactersProvider.notifier).applyLocal(character);
      if (mounted) Navigator.of(context).pop(character);
    } on Object catch (error) {
      if (mounted) showAppToast(context, '创建人物失败：$error');
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
        title: const Text('添加人物',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '完成'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 36),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '基础公开资料',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _field(
                    controller: _name,
                    label: '姓名',
                hint: '例如：Nova',
                    required: true,
                    maxLength: 40,
                  ),
                  const Divider(height: 1),
                  _field(
                    controller: _identity,
                    label: '公开身份',
                    hint: '她是谁、来自哪里、现实职业等基础信息',
                    required: true,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 7,
                  ),
                  const Divider(height: 1),
                  _field(
                    controller: _tagline,
                    label: '签名',
                    hint: '可选，通讯录里的一句简介',
                    maxLength: 120,
                  ),
                  const Divider(height: 1),
                  _field(
                    controller: _welcome,
                    label: '首次招呼',
                    hint: '可选，留空使用自然默认语',
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ColoredBox(
              color: Colors.white,
              child: SwitchListTile(
                title: const Text('允许她读取我的基本信息'),
                subtitle: const Text(
                  '默认关闭。开启后可读取“现实世界中的我”；不包含你与其他角色的关系、剧情和记忆。',
                ),
                value: _inheritUserProfile,
                activeThumbColor: const Color(0xFF07C160),
                onChanged: (value) =>
                    setState(() => _inheritUserProfile = value),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '创建后可在该人物的“个人信息 → 公开资料 → 角色档案”继续填写人格、说话方式、历史和世界观。',
                style: TextStyle(
                    fontSize: 12, height: 1.45, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    required int maxLength,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: InputBorder.none,
          counterText: '',
        ),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? '请填写$label' : null
            : null,
      ),
    );
  }
}
