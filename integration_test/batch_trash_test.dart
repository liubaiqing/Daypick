// 批量删除与回收站窗口集成回归（真实引擎 + 真实文件数据库）：
// 1) 设置 → 批量删除窗口可打开、月份切换器正常
// 2) 设置 → 回收站窗口可打开（空态或列表均正常渲染）、关闭正常
import 'package:calendar/app/app.dart';
import 'package:calendar/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批量删除/回收站窗口 打开关闭不应挂起', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalendarApp()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 打开设置
    await tester.tap(find.byIcon(Icons.settings_outlined), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 滚动到数据管理区（列表懒加载）
    final listView = find.descendant(
      of: find.byType(SettingsDialogBody),
      matching: find.byType(ListView),
    );
    for (var i = 0;
        i < 8 &&
            tester.any(find.byKey(const ValueKey('settings-batch-delete'))) ==
                false;
        i++) {
      await tester.drag(listView, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 批量删除窗口：月份切换器与列表渲染
    await tester.tap(
      find.byKey(const ValueKey('settings-batch-delete')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('batch-month-label')), findsOneWidget);
    expect(find.text('已选 0 个'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right).last,
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('batch-month-label')), findsOneWidget);

    // 关闭批量删除窗口
    await tester.tap(find.text('取消').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('batch-month-label')), findsNothing);

    // 回收站窗口：可打开（空态或列表均正常）
    await tester.tap(
      find.byKey(const ValueKey('settings-trash')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.any(find.byKey(const ValueKey('trash-empty'))) ||
          tester.any(find.textContaining('已删除事件')),
      isTrue,
      reason: '回收站窗口应渲染空态或事件列表',
    );
    await tester.tap(find.byKey(const ValueKey('trash-close')),
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // 关闭设置
    await tester.tap(find.byKey(const ValueKey('settings-close')),
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('跳回今天'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
