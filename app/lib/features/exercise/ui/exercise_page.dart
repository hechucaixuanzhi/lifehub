import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/panels/detail_panel_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../core/widgets/progress_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/section_label.dart';
import '../logic/exercise_notifier.dart';
import '../logic/mi_fitness_service.dart';

/// 运动页（对齐原型：自动记录只读占位 + 健身动作 ProgressIcon 网格）。
/// 作为 AppShell 的 Tab 内容 widget，不带自己的 Scaffold/AppBar/FAB。
class ExercisePage extends ConsumerWidget {
  const ExercisePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseNotifierProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child:
            Text(state.error!, style: const TextStyle(color: AppColors.danger)),
      );
    }
    if (state.summaries.isEmpty) {
      return const EmptyState(icon: AppNavIcons.exercise, message: '还没有运动记录');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(exerciseNotifierProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SectionLabel('自动记录'),
          _AutoPlaceholder(),
          const SectionLabel('健身动作'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: state.summaries.length,
            itemBuilder: (context, i) => _TypeCell(summary: state.summaries[i]),
          ),
        ],
      ),
    );
  }
}

/// 自动记录区（小米运动健康自动同步：今日步数 + 最近运动记录）。
class _AutoPlaceholder extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AutoPlaceholder> createState() => _AutoPlaceholderState();
}

class _AutoPlaceholderState extends ConsumerState<_AutoPlaceholder> {
  bool _loading = true;
  bool _syncing = false;
  bool _configured = false;
  bool _autoSynced = false; // 本次页面生命周期内只自动同步一次，防失败重试死循环
  MiFitnessDaily? _today;
  List<MiFitnessWorkout> _workouts = const [];
  List<MiFitnessDaily> _week = const []; // 近 7 天（日期升序，缺日补 0）
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }

  Future<void> _load() async {
    final svc = ref.read(miFitnessServiceProvider);
    try {
      final st = await svc.status();
      final configured = st['configured'] == true;
      final now = DateTime.now();
      final days = await svc.fetchDaily(
          _fmtDate(now.subtract(const Duration(days: 6))), _fmtDate(now));
      final workouts = await svc.fetchWorkouts(limit: 5);
      if (!mounted) return;
      // 对齐自然日填 7 天，无数据日期补 0，保证柱状图每天一根柱子
      final byDate = {for (final d in days) d.date: d};
      final week = <MiFitnessDaily>[];
      for (var i = 6; i >= 0; i--) {
        final key = _fmtDate(now.subtract(Duration(days: i)));
        week.add(byDate[key] ?? MiFitnessDaily(date: key));
      }
      setState(() {
        _configured = configured;
        _today = week.last;
        _week = week;
        _workouts = workouts;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '读取失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
      _maybeAutoSync();
    }
  }

  /// 打开页面时若已配置且今日步数仍为 0（调度尚未跑到），静默触发一次同步，
  /// 让用户打开运动页即能看到最新步数。失败不重试（_autoSynced 置位）。
  Future<void> _maybeAutoSync() async {
    if (_autoSynced || _syncing || !_configured) return;
    _autoSynced = true;
    if (!mounted) return;
    if ((_today?.steps ?? 0) == 0) await _sync();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final svc = ref.read(miFitnessServiceProvider);
    try {
      await svc.sync();
      await _load();
      if (!mounted) return;
      showAppToast(context, '已同步小米运动数据');
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '同步失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppElevation.e1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProgressIcon(
                  icon: PhosphorIconsRegular.footprints,
                  color: AppColors.accent,
                  progress: (_today?.steps ?? 0) > 0 ? 1 : 0,
                  name: '今日步数',
                  badge: _configured ? '已同步' : '未连接',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _loading
                      ? const Text('加载中…',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.muted))
                      : _error != null
                          ? Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.danger))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_today?.steps ?? 0} 步',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _detailLine(),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted),
                                ),
                              ],
                            ),
                ),
              ],
            ),
            if (!_configured) ...[
              const SizedBox(height: 12),
              const Text(
                '未连接：在家庭服务器 backend/.env 配置 MI_FITNESS_USER_ID / '
                'MI_FITNESS_PASS_TOKEN 后启用自动同步',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (!_loading && _error == null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFECEEEA)),
              const SizedBox(height: 14),
              _StepsChart(days: _week, accent: AppColors.accent),
            ],
            if (_workouts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('最近运动',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
              const SizedBox(height: 6),
              ..._workouts.map((w) => _workoutTile(w)),
            ],
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: (_loading || _syncing || !_configured) ? null : _sync,
              child: Text(_syncing ? '同步中…' : '同步'),
            ),
          ],
        ),
      ),
    );
  }

  String _detailLine() {
    final t = _today;
    if (t == null) return '0 km · 0 kcal';
    final km = t.distanceM / 1000;
    final kmStr = km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
    return '$kmStr km · ${t.activeKcal.toStringAsFixed(0)} kcal';
  }

  Widget _workoutTile(MiFitnessWorkout w) {
    final mapped =
        miWorkoutTypeMap[w.activityType] ?? (w.activityType, w.activityType);
    final parts = <String>[
      if (w.durationMin > 0) '${w.durationMin}分',
      if (w.distanceM != null && w.distanceM! > 0)
        '${(w.distanceM! / 1000).toStringAsFixed(2)}km',
      if (w.caloriesKcal != null && w.caloriesKcal! > 0)
        '${w.caloriesKcal!.toStringAsFixed(0)}kcal',
    ];
    final when = w.startAt == null ? '' : _fmtWhen(w.startAt!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(exerciseIcon(mapped.$1), size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${mapped.$2}$when',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  String _fmtWhen(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    if (sameDay) return ' 今天 $hh:$mm';
    return ' ${t.month}/${t.day} $hh:$mm';
  }
}

/// 近 7 天步数柱状图（fl_chart）：日期升序，今天高亮，空数据给占位提示。
class _StepsChart extends StatelessWidget {
  const _StepsChart({required this.days, required this.accent});
  final List<MiFitnessDaily> days;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxSteps = days.fold<int>(0, (m, d) => d.steps > m ? d.steps : m);
    if (maxSteps <= 0) {
      return const Text('近 7 天还没有步数数据，点击下方「同步」拉取小米运动',
          style: TextStyle(fontSize: 12, color: AppColors.muted));
    }
    final maxY = _niceMax(maxSteps);
    final todayIdx = days.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('近 7 天步数',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 2,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0x14000000), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: maxY / 2,
                    getTitlesWidget: (v, _) => Text(
                      _fmtK(v),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = DateTime.tryParse(days[i].date);
                      final label = dt == null ? '' : '${dt.month}/${dt.day}';
                      final isToday = i == todayIdx;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? accent : AppColors.muted,
                            fontWeight:
                                isToday ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: const BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: days[i].steps.toDouble(),
                        width: 12,
                        color: i == todayIdx
                            ? accent
                            : accent.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }

  /// 步数纵轴的「好看」上限：向上取整到 1000（>1 万时 2000）的倍数，最小 1000。
  double _niceMax(int maxSteps) {
    final step = maxSteps <= 10000 ? 1000.0 : 2000.0;
    final v = (maxSteps / step).ceil() * step;
    return v < 1000 ? 1000 : v;
  }

  /// 1000→"1k"、10000→"10k"；不足 1000 显示原值。
  String _fmtK(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v.toInt().toString();
  }
}

class _TypeCell extends ConsumerWidget {
  const _TypeCell({required this.summary});
  final TypeSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = summary.type;
    final notifier = ref.read(exerciseNotifierProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _record(context, ref, notifier, t),
      onDoubleTap: () => ref
          .read(detailPanelProvider.notifier)
          .open(ExercisePanelRequest(t.id)),
      onLongPress: () => _record(context, ref, notifier, t),
      child: Center(
        child: ProgressIcon(
          icon: exerciseIcon(t.iconName),
          fillIcon: exerciseIconFill(t.iconName),
          color: Color(t.colorArgb),
          progress: 0, // 运动不按目标填充（手动记一笔），保持静态色
          name: t.name,
          subtitle: _subtitle(),
        ),
      ),
    );
  }

  /// 单击/长按：记一笔（按 metrics 弹字段）。
  void _record(BuildContext context, WidgetRef ref, ExerciseNotifier notifier,
      dynamic type) {
    final countCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final countUnit = type.countUnit ?? '次';
    final distUnit = type.distanceUnit ?? 'km';
    final hasCount = type.hasCount ?? false;
    final hasTime = type.hasTime ?? false;
    final hasDistance = type.hasDistance ?? false;
    showAppModalSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('记一笔 · ${type.name}', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            if (hasCount)
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: '次数($countUnit)',
                    border: const OutlineInputBorder()),
              ),
            if (hasCount) const SizedBox(height: AppSpacing.md),
            if (hasTime)
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: '时长(分钟)', border: OutlineInputBorder()),
              ),
            if (hasTime) const SizedBox(height: AppSpacing.md),
            if (hasDistance)
              TextField(
                controller: kmCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '距离($distUnit)',
                    border: const OutlineInputBorder()),
              ),
            if (hasDistance) const SizedBox(height: AppSpacing.md),
            // 健身深化：组数 / 重量（可选，跑步等不填）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '组数(可选)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '重量kg(可选)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(countCtrl.text) ?? 0;
                final minutes = int.tryParse(minCtrl.text) ?? 0;
                final km = double.tryParse(kmCtrl.text) ?? 0;
                final meters =
                    distUnit == 'km' ? (km * 1000).toInt() : km.toInt();
                final sets = int.tryParse(setsCtrl.text);
                final weight = double.tryParse(weightCtrl.text);
                notifier.addSession(
                  typeId: type.id,
                  count: count,
                  durationSeconds: minutes * 60,
                  distanceMeters: meters.toDouble(),
                  sets: sets,
                  weightKg: weight,
                );
                Navigator.pop(ctx);
                showAppToast(context, '已记录 ${type.name}');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  String? _subtitle() {
    final t = summary.type;
    final parts = <String>[];
    if (t.hasCount) parts.add('${summary.todayCount}${t.countUnit}');
    if (t.hasTime) parts.add('${summary.todaySeconds.toInt()}s');
    if (t.hasDistance) {
      parts.add(_fmtDistance(summary.todayDistance, t.distanceUnit));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _fmtDistance(double meters, String unit) {
    if (unit == 'km') {
      final km = meters / 1000;
      return km == km.roundToDouble()
          ? '${km.toInt()}km'
          : '${km.toStringAsFixed(2)}km';
    }
    return '${meters.toInt()}$unit';
  }
}
