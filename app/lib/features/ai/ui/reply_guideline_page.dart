import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// 全局回复规范（R2）：用户设定的跨角色硬性回复要求（禁用句式/符号/词语）。
/// 存后端 AppSetting（跨设备）；单聊/群聊所有角色共同遵守，chat() 注入在最前。
class ReplyGuidelinePage extends ConsumerStatefulWidget {
  const ReplyGuidelinePage({super.key});

  @override
  ConsumerState<ReplyGuidelinePage> createState() =>
      _ReplyGuidelinePageState();
}

class _ReplyGuidelinePageState extends ConsumerState<ReplyGuidelinePage> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/ai/reply-guideline')
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _ctrl.text = (body['guideline'] as String?) ?? '';
            _loading = false;
            _error = null;
          });
        }
        return;
      }
      if (mounted) setState(() => _error = '加载失败 (${resp.statusCode})');
    } on Object catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .put('/ai/reply-guideline', {'guideline': text})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        if (mounted) setState(() => _saved = text.isEmpty ? '已清除规范' : '已保存，所有角色生效');
      } else {
        Map body;
        try {
          body = jsonDecode(resp.body) as Map<String, dynamic>;
        } on Object {
          body = {};
        }
        final err = (body['error'] as Map?)?['message'] ?? '保存失败 (${resp.statusCode})';
        if (mounted) setState(() => _error = '$err');
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFEDEDED),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F7),
          foregroundColor: AppTheme.onBg,
          elevation: 0,
          titleSpacing: 0,
          shape: const Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('全局回复规范',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _loading || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 10,
                      minLines: 6,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        hintText: '例如：\n'
                            '不要使用颜文字（~、^^）\n'
                            '不要每句都加「～」\n'
                            '不要自称「本宫」\n'
                            '禁止使用网络流行语',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '规范对所有角色生效（单聊/群聊），置于每次回复上下文最前。'
                      '可填写禁止使用的句式、符号、词语，或要求保持的回复风格。'
                      '空内容保存 = 清除规范。',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.redAccent)),
                  ],
                  if (_saved != null) ...[
                    const SizedBox(height: 12),
                    Text(_saved!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.green)),
                  ],
                ],
              ),
      );
}
