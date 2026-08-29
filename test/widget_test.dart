// 应用壳冒烟测试：验证根组件可构建并渲染侧边栏导航与日历页静态骨架。
// 说明：事件流被覆写为空流，widget 测试不触碰 drift 后台 isolate——
// 避免 FakeAsync 下流取消/数据库关闭产生的挂起定时器（pending timer 失败）。
import 'dart:io';

import 'package:calendar/app/app.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // 侧边栏导航（"新建"入口已移除）
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('新建'), findsNothing);
    // 主界面底部输入条：模式分段控件（本地|AI）
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    // 月视图静态骨架：顶栏「今天」按钮与星期表头（周一起始）
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
  });

  testWidgets('侧边栏把手悬停浮现，点击可收起与展开', (tester) async {
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

    expect(find.text('日历'), findsOneWidget);

    // 模拟鼠标移入把手触发区（按钮浮现）
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    final toggleFinder = find.byKey(const ValueKey('sidebar-toggle'));
    await gesture.moveTo(tester.getCenter(toggleFinder));
    await tester.pump(const Duration(milliseconds: 200));

    // 点击收起：导航项消失
    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('日历'), findsNothing);

    // 收起后把手左移，鼠标移到新位置再次浮现并展开
    await gesture.moveTo(tester.getCenter(toggleFinder));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(toggleFinder);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('日历'), findsOneWidget);
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
}
