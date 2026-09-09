import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/face_identity_service.dart';

/// 自我识别设置页（017，设计稿 M1）：身份库导入 / 阈值校准 / 状态。
///
  /// 核心：LLM 不负责认脸。这里管理的是角色自己的参考图（正样本）
/// 经本地检测+embedding 入库（face_gallery），再拿他人照片（负样本）校准阈值。
/// 之后聊天里发图，AI 才能用人格认出"自己"。数据不出手机+自有服务器。
class SelfIdentityPage extends ConsumerStatefulWidget {
  const SelfIdentityPage({super.key});

  @override
  ConsumerState<SelfIdentityPage> createState() => _SelfIdentityPageState();
}

class _SelfIdentityPageState extends ConsumerState<SelfIdentityPage> {
  static const Map<String, String> _subLabels = {
    'natural_daily': '日常淡妆',
    'stage_makeup': '舞台/浓妆',
    'selfie': '自拍',
    'side_profile': '侧脸',
  };

  final _picker = ImagePicker();
  late final FaceIdentityService _svc;
  bool _busy = false;

  // 状态（GET /ai/self-identity/status）
  int _gallerySize = 0;
  bool _calibrated = false;
  double _selfTh = 0, _possibleTh = 0;

  // 待导入批次（每批 = 一次多选图 + 一个子身份簇）
  final List<_PendingBatch> _pending = [];
  // 待校准负样本 embedding（他人照片）
  final List<List<double>> _negs = [];
  // 上次导入成功张数（状态卡内持久显示 6s，替代一闪而过的 toast）
  int? _lastImported;
  Timer? _lastImportedTimer;

  @override
  void initState() {
    super.initState();
    _svc = FaceIdentityService(ref.read(apiProvider));
    _refreshStatus();
  }

  @override
  void dispose() {
    _lastImportedTimer?.cancel();
    _svc.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final api = ref.read(apiProvider);
      final resp = await api.get('/ai/self-identity/status');
      if (resp.statusCode != 200 || !mounted) return;
      final s = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        _gallerySize = (s['gallery_size'] as num? ?? 0).toInt();
        _calibrated = s['calibrated'] == true;
        final th = s['thresholds'] as Map<String, dynamic>? ?? {};
        _selfTh = (th['self'] as num? ?? 0).toDouble();
        _possibleTh = (th['possible'] as num? ?? 0).toDouble();
      });
    } on Object catch (e) {
      debugPrint('[self-identity] status failed: $e');
    }
  }

  /// 选一批本人参考图 → 本地提取 embedding → 入待导入批次。
  Future<void> _pickReference() async {
    final picked = await _picker.pickMultiImage(maxWidth: 2048, imageQuality: 88);
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final all = <List<double>>[];
      for (final f in picked) {
        final emb = await _svc.embedFaces(await f.readAsBytes());
        if (emb != null && emb.isNotEmpty) all.addAll(emb);
      }
      if (all.isEmpty) {
        showAppToast(context, '未检测到人脸，请换更清晰的照片');
        return;
      }
      setState(() {
        _pending.add(_PendingBatch('natural_daily', all));
      });
      showAppToast(context, '已提取 ${all.length} 张人脸 embedding，选好标签后导入');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 导入全部待提交批次（POST /ai/self-identity/import）。
  Future<void> _importAll() async {
    if (_pending.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final entries = <Map<String, dynamic>>[];
      for (final b in _pending) {
        for (final e in b.embeddings) {
          entries.add({'embedding': e, 'sub_identity': b.subIdentity});
        }
      }
      final resp = await api.post('/ai/self-identity/import', {'entries': entries});
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        showAppToast(context, '导入失败（${resp.statusCode}）');
        return;
      }
      final imported = (body['imported'] as num? ?? 0).toInt();
      setState(() {
        _pending.clear();
        _lastImported = imported;
      });
      _lastImportedTimer?.cancel();
      _lastImportedTimer = Timer(const Duration(seconds: 6),
          () => mounted ? setState(() => _lastImported = null) : null);
      showAppToast(context, '✓ 已导入 $imported 张到身份库', duration: const Duration(milliseconds: 2500));
      await _refreshStatus();
    } on Object catch (e) {
      debugPrint('[self-identity] import failed: $e');
      showAppToast(context, '导入失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 选一批他人照片作负样本（校准阈值用）。
  Future<void> _pickNegatives() async {
    final picked = await _picker.pickMultiImage(maxWidth: 2048, imageQuality: 88);
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      var added = 0;
      for (final f in picked) {
        final emb = await _svc.embedFaces(await f.readAsBytes());
        if (emb != null && emb.isNotEmpty) {
          _negs.addAll(emb);
          added += emb.length;
        }
      }
      if (added == 0) {
        showAppToast(context, '未检测到人脸，请换更清晰的照片');
        return;
      }
      setState(() {});
      showAppToast(context, '已收集 $added 张负样本');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 校准阈值（POST /ai/self-identity/calibrate）：正分布=身份库自相似，
  /// 负分布=他人 embedding 对库的 max 相似度。SELF=最高负样本+margin。
  Future<void> _calibrate() async {
    if (_gallerySize == 0) {
      showAppToast(context, '身份库为空：先导入本人参考图再校准');
      return;
    }
    if (_negs.isEmpty) {
      showAppToast(context, '先选几张他人照片作负样本');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final resp = await api.post('/ai/self-identity/calibrate',
          {'neg_embeddings': _negs, 'margin': 0.08});
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        showAppToast(context, '校准失败（${resp.statusCode}）');
        return;
      }
      final th = body;
      setState(() => _negs.clear());
      showAppToast(context,
          '已校准：SELF≥${th['self_threshold']}，POSSIBLE≥${th['possible_threshold']}');
      await _refreshStatus();
    } on Object catch (e) {
      debugPrint('[self-identity] calibrate failed: $e');
      showAppToast(context, '校准失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearGallery() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空身份库？'),
        content: Text('删除全部 $_gallerySize 张参考图 embedding，需要重新导入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空', style: TextStyle(color: Color(0xFFE64340))),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final resp = await api.delete('/ai/self-identity/gallery');
      if (resp.statusCode == 200) {
        setState(() {
          _pending.clear();
          _negs.clear();
        });
        showAppToast(context, '身份库已清空');
      }
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setBatchSub(int idx, String sub) {
    setState(() => _pending[idx] = _PendingBatch(sub, _pending[idx].embeddings));
  }

  int get _pendingCount =>
      _pending.fold(0, (n, b) => n + b.embeddings.length);

  @override
  Widget build(BuildContext context) {
    final importing = _pendingCount > 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.onBg),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('自我识别', style: TextStyle(fontSize: 17, color: AppColors.onBg)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 说明
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
                '导入该角色已获授权的参考照，再选几张他人照片校准阈值。之后发图，'
              '她会用人格认出"图里是不是自己"。图片不出手机、不识别算法。',
              style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
          ),
          // 身份库状态
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_outlined, size: 20, color: AppColors.onBg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('身份库：$_gallerySize 张参考图',
                          style: const TextStyle(fontSize: 15, color: AppColors.onBg)),
                      const SizedBox(height: 2),
                      if (_lastImported != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('✓ 刚导入 $_lastImported 张（成功）',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF07C160),
                                  fontWeight: FontWeight.w500)),
                        ),
                      Text(
                        _calibrated
                            ? '已校准 · SELF≥${_selfTh.toStringAsFixed(2)} · POSSIBLE≥${_possibleTh.toStringAsFixed(2)}'
                            : '未校准（默认保守阈值，先导入参考图再选他人照片校准）',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _clearGallery,
                  child: const Text('清空', style: TextStyle(color: Color(0xFFE64340))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 导入本人参考图
          Container(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text('本人参考图',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onBg)),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _pickReference,
                        child: const Text('选择照片'),
                      ),
                    ],
                  ),
                ),
                if (_pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text('从相册选择已获授权的角色参考照，覆盖日常/自拍/侧脸等不同角度，10~30 张更好。',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < _pending.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text('${_pending[i].embeddings.length} 张人脸',
                                    style: const TextStyle(fontSize: 13, color: AppColors.onBg)),
                              ),
                              DropdownButton<String>(
                                value: _pending[i].subIdentity,
                                underline: const SizedBox.shrink(),
                                isDense: true,
                                items: [
                                  for (final e in _subLabels.entries)
                                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => v != null ? _setBatchSub(i, v) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _pending.removeAt(i)),
                              ),
                            ],
                          ),
                          const Divider(height: 1, indent: 0),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                if (importing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF07C160),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF07C160).withValues(alpha: 0.5),
                        ),
                        onPressed: _busy ? null : _importAll,
                        child: Text('导入 $_pendingCount 张到身份库'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 校准阈值
          Container(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text('校准阈值',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onBg)),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _pickNegatives,
                        child: const Text('选他人照片'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _negs.isEmpty
                              ? '选几张不是该角色的照片作负样本，用于划定"一定不是她"的边界。'
                            : '已收集 $_negs.length 张负样本',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF07C160),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF07C160).withValues(alpha: 0.5),
                          ),
                          onPressed: _busy ? null : _calibrate,
                          child: const Text('按当前身份库校准阈值'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 待导入批次：一次多选图提取的人脸 embedding + 子身份簇标签。
class _PendingBatch {
  _PendingBatch(this.subIdentity, this.embeddings);
  String subIdentity;
  final List<List<double>> embeddings;
}
