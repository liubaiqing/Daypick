// 日历点击回归测试（真实引擎 + 真实文件数据库）：快速点击多个日期不应挂起。
// 用户报告：在日历不同日期点击多次后灰屏无响应。此测试模拟该操作序列。
import 'package:calendar/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('快速点击多个日期/翻页/今天 不应挂起', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalendarApp()));
    // 等待首帧与数据库流就绪（真实时间下有限等待）
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final now = DateTime.now();

    // 1) 快速点击当月各日期（含补白跨月日期附近的格子）
    for (var d = 1; d <= 28; d++) {
      final key = ValueKey('day-${now.year}-${now.month}-$d');
      if (tester.any(find.byKey(key))) {
        await tester.tap(find.byKey(key), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // 2) 翻页（左/右箭头）+ 今天，反复数次
    for (var i = 0; i < 3; i++) {
      final arrows = find.byIcon(Icons.chevron_left);
      final right = find.byIcon(Icons.chevron_right);
      if (tester.any(arrows)) {
        await tester.tap(arrows.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (tester.any(right)) {
        await tester.tap(right.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.tap(find.text('今天'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 3) 双击某日期（打开新建事件表单）再关闭
    final dblKey = ValueKey('day-${now.year}-${now.month}-15');
    if (tester.any(find.byKey(dblKey))) {
      await tester.tap(find.byKey(dblKey));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(dblKey));
      await tester.pump(const Duration(milliseconds: 200));
      // 回归断言：弹层必须能正常渲染（曾因 DSTokensScope 不在 Navigator 之上而崩溃灰屏）
      expect(find.text('新建事件'), findsOneWidget);
      // 关闭表单
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('新建事件'), findsNothing);
    }

    // 4) 最后：界面仍正常渲染（未灰屏）
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);

    // 再等一帧确认无异常
    await tester.pump(const Duration(milliseconds: 100));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
