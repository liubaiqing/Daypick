// 应用壳冒烟测试：验证根组件可构建并渲染侧边栏导航与日历页静态骨架。
// 说明：事件流被覆写为空流，widget 测试不触碰 drift 后台 isolate——
// 避免 FakeAsync 下流取消/数据库关闭产生的挂起定时器（pending timer 失败）。
import 'dart:io';

import 'package:calendar/app/app.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:calendar/shared/design/ds_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders calendar and composer', (
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

    // 无侧边栏：界面直接是日历 + 输入条 + 设置圆钮
    expect(find.text('日历'), findsNothing);
    expect(find.text('新建'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    // 主界面底部输入条：模式分段控件（本地|AI）
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    // 月视图静态骨架：顶栏「跳回今天」按钮与星期表头（周一起始）
    expect(find.text('跳回今天'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
  });

  testWidgets('左下角设置按钮弹出设置小窗并可关闭', (tester) async {
    // 设置弹窗内容会读数据库设置，mock path_provider 避免真实目录异常
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

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

    // 点击左下角设置圆钮 → 弹窗出现
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('设置'), findsOneWidget);

    // 关闭弹窗
    await tester.tap(find.byKey(const ValueKey('settings-close')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('分段控件滑块滑动与动画开关控制', (tester) async {
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

    final slider = find.byWidgetPredicate((w) => w is AnimatedPositioned);
    expect(slider, findsOneWidget);

    AnimatedPositioned sliderWidget() =>
        tester.widget<AnimatedPositioned>(slider);

    // 动画开启：滑块时长 200ms，初始位于第一位
    expect(sliderWidget().duration, kDurationNormal);
    expect(sliderWidget().left, 0);

    // 切换到 AI：滑块滑向第二位（left > 0）
    await tester.tap(find.text('AI'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(sliderWidget().left, greaterThan(0));
  });

  testWidgets('动画关闭时分段滑块瞬间就位（duration=0）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
          dayEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
          animationsEnabledProvider.overrideWith((ref) async => false),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final slider = find.byWidgetPredicate((w) => w is AnimatedPositioned);
    expect(slider, findsOneWidget);
    expect(tester.widget<AnimatedPositioned>(slider).duration, Duration.zero);
  });

  testWidgets('日期选中聚焦动画：动画圆出现后消失', (tester) async {
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

    final now = DateTime.now();
    final key = ValueKey('day-${now.year}-${now.month}-15');
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 50)); // 动画进行中

    // 移动中的浅蓝选中圆可见（首次点击：从今天位置弹出）
    expect(find.byKey(const ValueKey('selection-anim')), findsOneWidget);

    // 动画完成后圆隐藏（由目标格自身选中态接管）
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-anim')), findsNothing);
  });

  testWidgets('快速连续点击时动画持续存在（不被中途取消隐藏）', (tester) async {
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

    final now = DateTime.now();
    final k1 = ValueKey('day-${now.year}-${now.month}-10');
    final k2 = ValueKey('day-${now.year}-${now.month}-20');
    await tester.tap(find.byKey(k1));
    await tester.pump(const Duration(milliseconds: 80)); // 动画播放中
    await tester.tap(find.byKey(k2));
    await tester.pump(const Duration(milliseconds: 50)); // 新动画进行中
    // 回归：动画圆必须仍可见（此前 reset 取消旧动画会把圆隐藏）
    expect(find.byKey(const ValueKey('selection-anim')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-anim')), findsNothing);
  });

  testWidgets('动画开关关闭时点击日期不产生动画圆', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
          dayEventsProvider.overrideWith(
            (ref, arg) => Stream.value(const <Event>[]),
          ),
          animationsEnabledProvider.overrideWith((ref) async => false),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final now = DateTime.now();
    final key = ValueKey('day-${now.year}-${now.month}-15');
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 100));
    // 关闭动画：无移动圆，选中态直接生效
    expect(find.byKey(const ValueKey('selection-anim')), findsNothing);
    expect(find.textContaining('${now.month}月15日'), findsOneWidget);
  });

  testWidgets('跨月点击（补白格）也播放聚焦动画', (tester) async {
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

    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    final key = ValueKey('day-${next.year}-${next.month}-${next.day}');
    if (!tester.any(find.byKey(key))) {
      return; // 当月无补白格（最后一天为周日）时跳过
    }
    await tester.tap(find.byKey(key));
    await tester.pump(const Duration(milliseconds: 50)); // 切月帧
    await tester.pump(const Duration(milliseconds: 50)); // postFrame 动画启动
    expect(find.byKey(const ValueKey('selection-anim')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-anim')), findsNothing);
  });

  testWidgets('Ctrl+V 粘贴图片为附件', (tester) async {
    // 放大测试视口：附件出现后输入条变高，避免月视图格子溢出
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final messenger = tester.binding.defaultBinaryMessenger;
    // Windows 上 Pasteboard.image 返回临时文件路径（内部读取后删除），
    // 先创建真实临时文件供其读取（FakeAsync 中须用同步 IO）
    final clipboardFile = File(
      '${Directory.systemTemp.path}/clipboard_test_'
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    clipboardFile.writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
    addTearDown(() {
      clipboardFile.existsSync() ? clipboardFile.deleteSync() : null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (call) async {
        if (call.method == 'image') return clipboardFile.path;
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory' ||
            call.method == 'getApplicationSupportDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

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

    // 聚焦输入框并 Ctrl+V（图片写入临时文件为真实 IO，须在 runAsync 中完成）
    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));

    // 图片附件缩略图出现
    expect(find.byKey(const ValueKey('attachment-0')), findsOneWidget);
  });

  testWidgets('Ctrl+V 剪贴板为文本时粘贴文本', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    // Pasteboard.text 内部走 Clipboard.getData（SystemChannels.platform）
    messenger.setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '明天上午10点开会'};
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('pasteboard'), null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

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

    await tester.tap(find.byType(TextField).last);
    await tester.pump(const Duration(milliseconds: 100));
    // 剪贴板通道调用与粘贴异步链须在真实事件循环（runAsync）中完成
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));

    // 文本被粘贴进输入框（无图片时不拦截文本粘贴）
    expect(find.text('明天上午10点开会'), findsOneWidget);
  });

  testWidgets('年月标题点击弹出年份选择器并可跨年跳转', (tester) async {
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

    final now = DateTime.now();
    final title = '${now.year}年${now.month}月';
    expect(find.text(title), findsOneWidget);

    // 点击年月标题 → 年份选择器弹出（含当前年与取消按钮）
    await tester.tap(find.text(title));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('选择年份'), findsOneWidget);
    expect(find.text('${now.year}'), findsWidgets);

    // 选择上一年 → 标题跨年更新（保持同月）
    final targetYear = now.year - 1;
    await tester.tap(find.text('$targetYear'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('选择年份'), findsNothing);
    expect(find.text('$targetYear年${now.month}月'), findsOneWidget);
  });
}
