import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifehub/core/widgets/detail_sheet.dart';

/// 复现真机「详情面板右滑不生效」：DetailSheet 内是垂直 ListView + 下滑关闭，
/// 断言水平右滑能触发 onClose（或至少跟手位移）。
void main() {
  Widget harness({required VoidCallback onClose}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // 模拟 AppShell：DetailSheet 占中间内容区
            Positioned(
              left: 0,
              right: 0,
              top: 100,
              bottom: 0,
              child: DetailSheet(
                onClose: onClose,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(
                    30,
                    (i) => ListTile(title: Text('条目 $i')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('右滑超过阈值 → onClose', (tester) async {
    var closed = false;
    await tester.pumpWidget(harness(onClose: () => closed = true));
    await tester.pumpAndSettle();

    // 屏幕宽 800（测试默认），阈值 0.35 → 280px；向右拖 400px 远超
    await tester.drag(find.byType(DetailSheet), const Offset(400, 0));
    await tester.pumpAndSettle();

    debugPrint('>>> closed = $closed');
    expect(closed, isTrue);
  });

  testWidgets('慢速右移跟手后回弹（未达阈值不关闭）', (tester) async {
    var closed = false;
    await tester.pumpWidget(harness(onClose: () => closed = true));
    await tester.pumpAndSettle();

    // 慢速向右 100px（< 280 阈值）→ 回弹不关闭
    await tester.drag(find.byType(DetailSheet), const Offset(100, 0));
    await tester.pumpAndSettle();

    debugPrint('>>> closed(100px) = $closed');
    expect(closed, isFalse);
  });

  // 对角线右滑（真人手指 dx/dy 同步移动）：dy/dx = slope，应能关闭（右移为主）
  for (final slope in [0.3, 0.7, 1.0, 1.5, 2.0]) {
    testWidgets('右下滑（dy/dx=$slope）超过阈值 → onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(harness(onClose: () => closed = true));
      await tester.pumpAndSettle();

      final g = await tester
          .startGesture(tester.getCenter(find.byType(DetailSheet)));
      // 模拟真实手指 60Hz 小增量：3px/步，netDy 逐事件累积而非一步超阈值
      for (var i = 0; i < 100; i++) {
        await g.moveBy(Offset(3, 3 * slope));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();

      debugPrint('>>> closed(diag $slope) = $closed');
      expect(closed, isTrue);
    });
  }

  // 对角线左滑：dx 负值，dy/dx = slope（绝对值），应能关闭（左移为主）
  for (final slope in [0.5, 1.0, 1.5]) {
    testWidgets('左下滑（dy/|dx|=$slope）超过阈值 → onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(harness(onClose: () => closed = true));
      await tester.pumpAndSettle();

      final g = await tester
          .startGesture(tester.getCenter(find.byType(DetailSheet)));
      for (var i = 0; i < 100; i++) {
        await g.moveBy(Offset(-3, 3 * slope));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();

      debugPrint('>>> closed(left diag $slope) = $closed');
      expect(closed, isTrue);
    });
  }

  testWidgets('陡峭向下（dy/dx=3）不应当水平处理', (tester) async {
    var closed = false;
    await tester.pumpWidget(harness(onClose: () => closed = true));
    await tester.pumpAndSettle();

    final g = await tester
        .startGesture(tester.getCenter(find.byType(DetailSheet)));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(8, 24)); // dy/dx = 3，垂直为主
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    debugPrint('>>> closed(steep) = $closed');
    expect(closed, isFalse); // 垂直为主的拖动不触发水平关闭
  });

  testWidgets('向下拖仍可关闭（grip 上）', (tester) async {
    var closed = false;
    await tester.pumpWidget(harness(onClose: () => closed = true));
    await tester.pumpAndSettle();

    // 从 grip（面板顶部 40px 内）开始垂直下拉 → 下滑关闭
    final g = await tester.startGesture(
        tester.getTopLeft(find.byType(DetailSheet)) + const Offset(200, 20));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    debugPrint('>>> closed(down grip) = $closed');
    expect(closed, isTrue);
  });
}
