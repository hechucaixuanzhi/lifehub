import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/panels/detail_panel_controller.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/app_fab.dart';
import '../../core/widgets/bottom_nav.dart';
import '../../core/widgets/detail_sheet.dart';
import '../../core/widgets/top_bar.dart';
import '../capture/capture_sheet.dart';
import '../exercise/ui/exercise_detail_panel.dart';
import '../exercise/ui/exercise_page.dart';
import '../life/ui/habit_detail_panel.dart';
import '../life/ui/life_page.dart';
import '../pet/ui/pet_page.dart';
import '../settings/ui/settings_page.dart';
import '../study/ui/study_detail_panel.dart';
import '../study/ui/study_page.dart';
import '../wechat/wechat_shell.dart';

/// App Shell：顶部固定栏（我的/宠物常驻）+ 四 Tab 内容区 + 底部导航 + 全局 FAB。
/// 详情页用内容区底部面板（DetailSheet），不遮顶栏/底导航。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;
  static const _titles = ['生活', '学习', '运动', 'AI'];
  late final List<Widget> _tabs;

  /// 系统边缘返回手势是否已被排除（面板打开期间为 true，防右滑被系统劫持回桌面）。
  bool _edgeExcluded = false;

  @override
  void initState() {
    super.initState();
    _restoreTab();
    // AI 不是常驻 Tab：点击 AI 走 _openAi 全屏进微信模式
    _tabs = const [
      LifePage(),
      StudyPage(),
      ExercisePage(),
    ];
  }

  /// 恢复上次停留的 Tab（AI(3) 不是常驻页，回落生活页）。
  Future<void> _restoreTab() async {
    final t = await AppPrefs.lastTab();
    if (!mounted || t == _tab) return;
    setState(() => _tab = (t >= 0 && t < 3) ? t : 0);
  }

  void _openMe() => Navigator.of(context).push(
        AppPageRoute(builder: (_) => const MyPanel()),
      );

  void _openPet() => Navigator.of(context).push(
        AppPageRoute(builder: (_) => const PetPage()),
      );

  void _openCapture() {
    // v0.3 最简：全局「记一笔」→ 收件箱（分类语义后置，待用户确认后续需求）
    showCaptureSheet(context);
  }

  /// 点 AI Tab → 全屏进入微信模式，并把 Tab 切回生活页（AI 不再是常驻页）。
  void _openAi() {
    setState(() => _tab = 0);
    AppPrefs.saveLastTab(0);
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const WeChatShell()),
    );
  }

  /// 首页按系统返回键 → 退到后台不退出（像微信）；二次进入即原位。
  Future<void> _moveTaskToBack() async {
    try {
      await const MethodChannel('lifehub/nav').invokeMethod('moveTaskToBack');
    } on Object {
      // 原生未接（如桌面/测试）：退化为默认退出行为
      await SystemNavigator.pop();
    }
  }

  /// 面板打开期间排除屏幕左右缘的系统边缘返回手势区域：
  /// 否则右滑（从左缘起）被 MIUI/Android 系统劫持成「返回」→ 根路由退后台回桌面。
  /// 排除后边缘滑动交回应用，由 SwipeBackDismiss 跟手处理；关面板时恢复。
  /// Flutter 3.41.5 已移除 SystemChrome.setSystemGestureExclusion → 走原生 MethodChannel。
  Future<void> _updateEdgeExclusion(bool active) async {
    if (_edgeExcluded == active) return;
    _edgeExcluded = active;
    List<List<double>> rects = const [];
    if (active) {
      final size = MediaQuery.of(context).size;
      final top = MediaQuery.of(context).padding.top + 52;
      final bottom = size.height - 64 - MediaQuery.of(context).padding.bottom;
      if (bottom > top + 60) {
        const edge = 60.0; // 覆盖 MIUI 较大的返回手势感应区
        rects = [
          [0, top, edge, bottom],
          [size.width - edge, top, size.width, bottom],
        ];
      }
    }
    // 失败忽略：PopScope 兜底（面板开着关面板）；原生未接则恢复默认系统行为。
    try {
      await const MethodChannel('lifehub/nav')
          .invokeMethod('setEdgeExclusion', {'rects': rects});
    } on Object {
      // 原生侧未实现时忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(detailPanelProvider);
    // 面板开 → 排除边缘手势（应用跟手接管）；关 → 恢复系统手势
    _updateEdgeExclusion(request != null);

    // 根页 PopScope：系统返回（键或边缘手势）→ 面板开着先关面板，否则退后台不退出
    // （像微信，进程活着原位恢复）。二级页在各自路由栈上正常 pop，不经过这里。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ref.read(detailPanelProvider) != null) {
          ref.read(detailPanelProvider.notifier).close();
        } else {
          _moveTaskToBack();
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopBar(
                title: _titles[_tab],
                onMe: _openMe,
                onPet: _openPet,
              ),
              Expanded(
                child: IndexedStack(index: _tab, children: _tabs),
              ),
              BottomNav(
                current: _tab,
                onSelect: (i) {
                  if (i == 3) {
                    // AI Tab → 全屏微信模式
                    _openAi();
                  } else {
                    setState(() => _tab = i);
                    AppPrefs.saveLastTab(i);
                  }
                },
              ),
            ],
          ),
          // 全局「记一笔」FAB：手动定位在 BottomNav 之上（右下），避免重叠
          Positioned(
            right: 18,
            bottom: 64 + MediaQuery.of(context).padding.bottom + 14,
            child: AppFab(onPressed: _openCapture),
          ),
          if (request != null)
            // DetailSheet 不遮顶部固定栏/底部导航：top = 状态栏 + TopBar(52)，bottom = BottomNav(64)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).padding.top + 52,
              bottom: 64 + MediaQuery.of(context).padding.bottom,
              child: DetailSheet(
                onClose: () => ref.read(detailPanelProvider.notifier).close(),
                child: _buildPanel(request),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildPanel(PanelRequest request) {
    return switch (request) {
      HabitPanelRequest(:final habitId) =>
        HabitDetailPanel(habitId: habitId),
      StudyPanelRequest(:final resourceId) =>
        StudyDetailPanel(resourceId: resourceId),
      ExercisePanelRequest(:final typeId) =>
        ExerciseDetailPanel(typeId: typeId),
    };
  }
}
