import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/timeline_card.dart';
import '../../../domain/entities/life_habit.dart' show LifeHabit;
import '../../../features/exercise/logic/exercise_notifier.dart';
import '../../../features/life/logic/life_notifier.dart';
import '../../../features/study/logic/study_notifier.dart';
import '../models/timeline_item.dart';

/// 时间线页：跨模块（学习/习惯/运动/宠物）统一按时间排序的记录流。
/// 数据来自后端 GET /timeline（与 AI 读库问答同源），label 用本地类型表映射。
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  List<TimelineItem> _items = [];
  bool _loading = true;
  String? _error;

  // 本地 label 表（seed 数据，供 ref_id → 中文名）
  Map<String, LifeHabit> _habits = {};
  Map<String, String> _resources = {};
  Map<String, String> _exercises = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // label 表查不到不致命：ref_id 兜底显示
    await _loadLookups();
    try {
      final api = ref.read(apiProvider);
      final resp = await api
          .get('/timeline?days=14')
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _items = [
            for (final m in (body['items'] as List? ?? []))
              TimelineItem.fromJson(m as Map<String, dynamic>),
          ];
        });
      } else {
        setState(() => _error = '加载失败 (${resp.statusCode})');
      }
    } on Object {
      setState(() => _error = '家庭服务器未连接');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLookups() async {
    try {
      final life = ref.read(lifeRepositoryProvider);
      final study = ref.read(studyRepositoryProvider);
      final ex = ref.read(exerciseRepositoryProvider);
      final results = await Future.wait([life.getHabits(), study.getResources(), ex.getTypes()]);
      _habits = {for (final h in results[0] as List<LifeHabit>) h.id: h};
      _resources = {
        for (final r in results[1] as List)
          (r as dynamic).id as String: r.name as String,
      };
      _exercises = {
        for (final t in results[2] as List)
          (t as dynamic).id as String: t.name as String,
      };
    } on Object {
      // ignore：label 缺失时前端用 ref_id 兜底
    }
  }

  /// 条目 → (类型 chip, 内容文本)。
  (String, String) _describe(TimelineItem it) {
    final x = it.count > 1 ? ' ×${it.count}' : '';
    switch (it.type) {
      case 'life_habit_event':
        final h = _habits[it.refId];
        final name = h?.name ?? it.refId ?? '习惯';
        if (it.count > 1) return (name, '打卡$x');
        final v = it.value;
        if (v != null && v > 0) {
          final unit = (h != null && h.unit.isNotEmpty) ? h.unit : '';
          final num =
              v.truncateToDouble() == v ? v.toInt().toString() : v.toString();
          return (name, unit.isNotEmpty ? '$num $unit' : '打卡');
        }
        return (name, '打卡');
      case 'study_session':
        final name = _resources[it.refId] ?? it.refId ?? '学习';
        final d = it.durationSeconds ?? 0;
        if (d >= 60) return (name, '${(d / 60).round()} 分钟');
        return (name, '');
      case 'exercise_session':
        final name = _exercises[it.refId] ?? it.refId ?? '运动';
        final parts = <String>[];
        if (it.distanceMeters != null && it.distanceMeters! > 0) {
          parts.add('${(it.distanceMeters! / 1000).toStringAsFixed(2)} 公里');
        }
        final d = it.durationSeconds ?? 0;
        if (d >= 60) parts.add('${(d / 60).round()} 分钟');
        return (name, parts.join(' · '));
      case 'pet_log':
        if (it.kind == 'photo') return ('宠物', '拍了照片');
        final c = it.content;
        return ('宠物', (c == null || c.isEmpty) ? '记录' : c);
      case 'pet':
        return ('新宠物', it.content ?? '');
    }
    return (it.type, '');
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    return '${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('时间线')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                )
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      message: '还没有记录，开始记一笔吧',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        children: _buildRows(),
                      ),
                    ),
    );
  }

  List<Widget> _buildRows() {
    final rows = <Widget>[];
    String? lastDay;
    for (final it in _items) {
      final day = _dayLabel(it.at);
      if (day != lastDay) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
          child: Text(day,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
        ));
        lastDay = day;
      }
      final (chip, content) = _describe(it);
      rows.add(TimelineCard(
        chip: chip,
        content: content,
        time: _fmtTime(it.at),
      ));
    }
    return rows;
  }
}
