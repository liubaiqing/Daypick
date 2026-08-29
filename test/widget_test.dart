// 应用壳冒烟测试：验证根组件可构建并渲染侧边栏导航。
import 'package:calendar/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders sidebar navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalendarApp()));

    expect(find.text('日历'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
