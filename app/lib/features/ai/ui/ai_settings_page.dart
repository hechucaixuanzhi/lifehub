import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/network/api_config.dart';
import '../../../core/theme/app_theme.dart';
import 'reply_guideline_page.dart';

/// AI 设置页（v0.2.2）：查看 AI 服务状态、测试连接。
/// **严格不含任何 API Key 输入框**——Key 仅在家庭服务器配置，手机永不持有。
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  bool _loading = false;
  String? _provider;
  String? _model;
  bool? _configured;
  String? _testReply;
  String? _error;

  Future<void> _editServer() async {
    var address = ApiConfig.baseUrl;
    String? error;
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('服务器地址'),
          content: TextFormField(
            initialValue: address,
            onChanged: (value) => address = value,
            enabled: !saving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://example.com',
              errorText: error,
              helperText: '填写你信任的 LifeHub 后端地址',
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                update(() { saving = true; error = null; });
                try {
                  await ApiConfig.saveBaseUrl(address);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) update(() {
                    error = e is FormatException ? e.message : '保存失败，请重试';
                    saving = false;
                  });
                }
              },
              child: Text(saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || saved != true) return;
    setState(() { _configured = null; _provider = null; _model = null; });
    try {
      await ref.read(apiProvider).register();
    } catch (_) {
      // Persist the address for retry; the connection check shows failures.
    }
    if (mounted) await _check();
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
      _testReply = null;
    });
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post('/ai/health', {});
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _configured = body['configured'] as bool? ?? false;
          _provider = body['provider'] as String?;
          _model = body['model'] as String?;
        });
      } else {
        setState(() => _error = '服务返回 ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendTest() async {
    setState(() {
      _loading = true;
      _error = null;
      _testReply = null;
    });
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post('/ai/chat', {'message': 'ping'});
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => _testReply = (body['reply'] as String?) ?? '(空回复)');
      } else {
        setState(() => _error = '服务返回 ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _statusChip() {
    if (_loading) {
      return const Chip(
        label: Text('检测中…'),
        avatar: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final ok = _configured == true;
    return Chip(
      label: Text(ok ? '已配置 · 可聊天' : '未配置服务端 Key'),
      avatar: Icon(
        ok ? Icons.check_circle : Icons.warning_amber,
        color: ok ? Colors.green : Colors.orange,
        size: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI 设置')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('服务器地址'),
              subtitle: Text(ApiConfig.baseUrl),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _loading ? null : _editServer,
            ),
            const Divider(),
            const Text('AI 服务',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _statusChip(),
            const SizedBox(height: 8),
            if (_provider != null)
              ListTile(
                title: const Text('Provider'),
                subtitle: Text('$_provider · ${_model ?? ''}'),
                dense: true,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.rule),
              title: const Text('全局回复规范'),
              subtitle: const Text('跨角色硬性回复要求（禁用句式/符号/词语）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReplyGuidelinePage()),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _check,
              icon: const Icon(Icons.refresh),
              label: const Text('测试连接'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _sendTest,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('发送测试消息'),
            ),
            if (_testReply != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(_testReply!, style: const TextStyle(color: AppTheme.onBg)),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'API Key 仅在家庭服务器（backend/.env）配置，手机不存储任何密钥。'
              '如需启用真实聊天，请在家用电脑的 backend/.env 填入 DEEPSEEK_API_KEY 后重启后端。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
}
