// 日历交互回归测试（真实引擎 + 真实文件数据库）：
// 1) 单击日期应立即选中（无 300ms 双击判定延迟）
// 2) 翻页/今天按钮正常
// 3) "＋"按钮新建事件表单正常弹出（替代原双击新建）
import 'package:calendar/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('单击日期即时选中/翻页/新建表单 不应挂起', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalendarApp()));
    // 等待首帧与数据库流就绪（真实时间下有限等待）
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final now = DateTime.now();

    // 1) 单击日期 → 16ms 内列表标题即更新（远小于 300ms，验证无双击判定延迟）
    final day15Key = ValueKey('day-${now.year}-${now.month}-15');
    if (tester.any(find.byKey(day15Key))) {
      await tester.tap(find.byKey(day15Key));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.textContaining('${now.month}月15日'),
        findsOneWidget,
        reason: '单击后应即时选中，不应有 300ms 双击判定延迟',
      );
    }

    // 2) 快速点击多个日期/翻页/今天
    for (var d = 1; d <= 28; d++) {
      final key = ValueKey('day-${now.year}-${now.month}-$d');
      if (tester.any(find.byKey(key))) {
        await tester.tap(find.byKey(key), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    for (var i = 0; i < 3; i++) {
      if (tester.any(find.byIcon(Icons.chevron_left))) {
        await tester.tap(find.byIcon(Icons.chevron_left).first,
            warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (tester.any(find.byIcon(Icons.chevron_right))) {
        await tester.tap(find.byIcon(Icons.chevron_right).first,
            warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.tap(find.text('跳回今天'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
    }

    // 3) 通过"＋"按钮新建事件（回归：弹层必须能正常渲染）
    await tester.tap(find.byIcon(Icons.add).last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('新建事件'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('新建事件'), findsNothing);

    // 4) 主界面输入条：输入文本 → 发送 → 结果面板 → 关闭（丢弃草稿）
    // 显式切回本地模式：parseMode 持久化在真实数据库中，用户可能切过 AI
    await tester.tap(find.text('本地'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextField).last,
      '明天上午10点开会',
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.arrow_upward).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('待确认事件'), findsOneWidget);
    // 面板关闭 → 未保存草稿确认 → 丢弃
    await tester.tap(find.byKey(const ValueKey('panel-close')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('关闭并丢弃'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('待确认事件'), findsNothing);

    // 5) 最后：界面仍正常渲染（未灰屏）；无侧边栏，设置圆钮在左下角
    expect(find.text('跳回今天'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // 等待选中聚焦动画完成，避免测试结束时动画仍在运行
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
