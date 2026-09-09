import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/nav/app_page_route.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_toast.dart';
import '../ai/ai_providers.dart';
import '../ai/models/character.dart';
import '../ai/ui/ai_persona_chat_page.dart';
import '../ai/ui/group_create_page.dart';
import 'wechat_contacts_page.dart';
import 'wechat_discover_page.dart';
import 'wechat_me_page.dart';
import 'wechat_home_page.dart';

/// 微信模式全屏壳（点 AI Tab 进入）：微信首页 / 通讯录 / 发现 / 我 四 Tab。
/// 顶栏按微信根页面定制：首页/通讯录/发现均为居中标题且无返回键，
/// 「我」由页面自身绘制顶部个人资料区。底部四导航保持微信尺寸与配色。
class WeChatShell extends ConsumerStatefulWidget {
  const WeChatShell({super.key});

  @override
  ConsumerState<WeChatShell> createState() => _WeChatShellState();
}

class _WeChatShellState extends ConsumerState<WeChatShell> {
  int _tab = 0;
  static const _titles = ['聊天', '通讯录', '发现', '我'];
  late final List<Widget> _tabs;

  /// 顶栏加号按钮（showMenu 锚点）。
  final GlobalKey _plusKey = GlobalKey();

  static const _plusItems = [
    (PhosphorIconsRegular.usersThree, 'group', '发起群聊'),
    (PhosphorIconsRegular.userPlus, 'friend', '添加朋友'),
    (PhosphorIconsRegular.scan, 'scan', '扫一扫'),
    (PhosphorIconsRegular.qrCode, 'pay', '收付款'),
  ];

  @override
  void initState() {
    super.initState();
    _restoreTab();
    _tabs = const [
      WeChatHomePage(),
      WeChatContactsPage(),
      WeChatDiscoverPage(),
      WeChatMePage(),
    ];
  }

  /// 恢复上次微信内层 Tab（shared_preferences）。
  Future<void> _restoreTab() async {
    final t = await AppPrefs.lastWechatTab();
    if (!mounted || t == _tab) return;
    setState(() => _tab = (t >= 0 && t < _tabs.length) ? t : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: Column(
        children: [
          if (_tab != 3) _buildTopBar(context),
          // 内容区
          Expanded(
            child: IndexedStack(index: _tab, children: _tabs),
          ),
          // 底部导航（微信风格四 Tab）
          _WeChatBottomNav(
            current: _tab,
            onSelect: (i) {
              setState(() => _tab = i);
              AppPrefs.saveLastWechatTab(i);
            },
          ),
        ],
      ),
    );
  }

  /// 微信三个根页面都不显示返回键。首页保留搜索和加号，其他页用等宽占位
  /// 保证标题真正居中，而不是视觉近似居中。
  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: 56 + topPadding,
      padding: EdgeInsets.only(top: topPadding),
      decoration: const BoxDecoration(
        color: Color(0xFFEDEDED),
        border: Border(bottom: BorderSide(color: Color(0xFFD8D8D8), width: .5)),
      ),
      child: Row(
        children: [
          // 首页左上角：小迹 AI 助手使用纯图标入口，不占联系人会话列表。
          if (_tab == 0)
            SizedBox(
              width: 104,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _openAssistant,
                  icon: const Icon(
                    PhosphorIconsRegular.sparkle,
                    size: 27,
                    color: Color(0xFF111111),
                  ),
                  tooltip: 'AI 助手',
                ),
              ),
            )
          else
            const SizedBox(width: 104),
          Expanded(
            child: Text(
              _titles[_tab],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
          ),
          if (_tab == 0)
            SizedBox(
              width: 104,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _snack('搜索（暂未实现）'),
                    icon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                        size: 27, color: Color(0xFF111111)),
                    tooltip: '搜索',
                  ),
                  IconButton(
                    key: _plusKey,
                    onPressed: _showPlusMenu,
                    icon: const Icon(PhosphorIconsRegular.plus,
                        size: 28, color: Color(0xFF111111)),
                    tooltip: '更多',
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 104),
        ],
      ),
    );
  }

  void _openAssistant() {
    final characters =
        ref.read(charactersProvider).valueOrNull ?? defaultCharacters;
    final assistant = characters.firstWhere(
      (character) => character.id == 'assistant',
      orElse: () => defaultCharacters.firstWhere(
        (character) => character.id == 'assistant',
      ),
    );
    Navigator.of(context)
        .push(
      AppPageRoute(
        builder: (_) => AiPersonaChatPage(character: assistant),
      ),
    )
        .then((_) {
      ref.read(conversationsProvider.notifier).reload();
    });
  }

  /// 顶栏加号菜单：发起群聊 / 添加朋友 / 扫一扫 / 收付款（复杂功能占位 toast）。
  void _showPlusMenu() {
    final box = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    showMenu<String>(
      context: context,
      position:
          RelativeRect.fromRect(rect, Offset.zero & MediaQuery.sizeOf(context)),
      color: const Color(0xFF4C4C4C),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: [
        for (final (icon, id, label) in _plusItems)
          PopupMenuItem(
            value: id,
            child: Row(
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(width: 16),
                Text(label,
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
              ],
            ),
          ),
      ],
    ).then((id) {
      if (id == null) return;
      if (id == 'group') {
        _openCreateGroup();
        return;
      }
      final label = _plusItems
          .firstWhere((e) => e.$2 == id,
              orElse: () => (PhosphorIconsRegular.plus, '', ''))
          .$3;
      _snack('$label（暂未实现）');
    });
  }

  void _openCreateGroup() {
    Navigator.of(context)
        .push(
      AppPageRoute(builder: (_) => const GroupCreatePage()),
    )
        .then((_) {
      if (!mounted) return;
      ref.read(conversationsProvider.notifier).reload();
      ref.read(groupsProvider.notifier).reload();
    });
  }

  void _snack(String msg) => showAppToast(context, msg);
}

/// 微信式底部导航：微信/通讯录/发现/我。
/// 激活 tab = 图标填充实心 + 微信绿，未选中 = 黑色线稿。
class _WeChatBottomNav extends StatelessWidget {
  const _WeChatBottomNav({required this.current, required this.onSelect});
  final int current;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    (PhosphorIconsRegular.chatCircle, PhosphorIconsFill.chatCircle, '聊天'),
    (PhosphorIconsRegular.addressBook, PhosphorIconsFill.addressBook, '通讯录'),
    (PhosphorIconsRegular.compass, PhosphorIconsFill.compass, '发现'),
    (PhosphorIconsRegular.user, PhosphorIconsFill.user, '我'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Color(0xFFD8D8D8), width: .5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 5, 0, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(i == current ? _tabs[i].$2 : _tabs[i].$1,
                            size: 27,
                            color: i == current
                                ? AppColors.wechatGreen
                                : const Color(0xFF111111)),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$3,
                          style: TextStyle(
                            fontSize: 12,
                            color: i == current
                                ? AppColors.wechatGreen
                                : const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
