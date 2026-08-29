// 应用壳冒烟测试：验证根组件可构建并渲染侧边栏导航与日历页静态骨架。
// 说明：事件流被覆写为空流，widget 测试不触碰 drift 后台 isolate——
// 避免 FakeAsync 下流取消/数据库关闭产生的挂起定时器（pending timer 失败）。
import 'package:calendar/app/app.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders sidebar navigation and calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
          dayEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // 侧边栏导航
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    // 月视图静态骨架：顶栏「今天」按钮与星期表头（周一起始）
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
  });
}
