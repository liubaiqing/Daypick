// 批量删除窗口与回收站窗口的 Widget 测试（文档 15.2 节）。
// 使用内存 drift 库注入，验证：月份列表/勾选/全选/已选计数/删除进回收站、
// 回收站恢复与彻底清理、空态。
import 'package:calendar/app/app.dart';
import 'package:calendar/core/constants.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/event_dao.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:calendar/data/db/settings_dao.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:calendar/features/settings/settings_page.dart';
import 'package:calendar/features/shell/app_shell.dart';
import 'package:calendar/shared/design/ds_button.dart';
import 'package:calendar/shared/design/ds_glass_surface.dart';
import 'package:calendar/shared/design/ds_tokens.dart';
import 'package:calendar/shared/design/dstokens_scope.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = EventDao(db);
  });

  tearDown(() {
    // FakeAsync 下 drift watch 流 + close 会挂起：不 await，
    // 内存库随测试进程退出释放（纯 dart 数据层测试仍 await close）
    db.close();
  });

  Future<int> seed(String title, DateTime start) {
    return dao.insertEvent(
      EventsCompanion(
        title: Value(title),
        start: Value(start),
        allDay: const Value(false),
        sourceType: const Value(EventSourceType.manual),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
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
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    // 设置内容从数据库异步加载（真实 IO），须在 runAsync 中等待
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 设置弹窗 ListView 懒加载：滚动到数据管理区（拖拽直至目标可见，
  /// 再 ensureVisible 确保完全进入视口，避免边缘遮挡）
  Future<void> scrollSettingsTo(WidgetTester tester, Finder target) async {
    final listView = find.descendant(
      of: find.byType(SettingsDialogBody),
      matching: find.byType(ListView),
    );
    for (var i = 0; i < 10 && target.evaluate().isEmpty; i++) {
      await tester.drag(listView, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 80));
    }
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openBatchDelete(WidgetTester tester) async {
    await scrollSettingsTo(
      tester,
      find.byKey(const ValueKey('settings-batch-delete')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-batch-delete')));
    await tester.pump(const Duration(milliseconds: 200));
    // 月份事件从数据库异步加载
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openTrash(WidgetTester tester) async {
    await scrollSettingsTo(
      tester,
      find.byKey(const ValueKey('settings-trash')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-trash')));
    await tester.pump(const Duration(milliseconds: 200));
    // 回收站事件流首帧
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('批量删除：勾选/全选/删除后事件进入回收站', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await seed('早会', DateTime(now.year, now.month, 1, 9));
      await seed('午会', DateTime(now.year, now.month, 5, 12));
      await seed('晚会', DateTime(now.year, now.month, 20, 18));
    });

    await pumpApp(tester);
    await openSettings(tester);

    // 打开批量删除窗口
    await openBatchDelete(tester);

    // 月份标题与三行事件
    expect(find.byKey(const ValueKey('batch-month-label')), findsOneWidget);
    expect(find.text('早会'), findsOneWidget);
    expect(find.text('午会'), findsOneWidget);
    expect(find.text('晚会'), findsOneWidget);

    // 未勾选时删除按钮禁用（onPressed == null）
    final deleteBtn = tester.widget<DSButton>(
      find.byKey(const ValueKey('batch-delete-confirm')),
    );
    expect(deleteBtn.onPressed, isNull);

    // 逐条勾选一条 → 计数 1（勾选第一行事件的勾选框）
    final firstEventId = (await tester.runAsync(
      () => dao.getMonth(DateTime(now.year, now.month)),
    ))!
        .first
        .id;
    await tester.tap(find.byKey(ValueKey('batch-check-$firstEventId')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('已选 1 个'), findsOneWidget);

    // 全选 → 计数 3
    await tester.tap(find.byKey(const ValueKey('batch-select-all')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('已选 3 个'), findsOneWidget);

    // 删除按钮随选中启用
    expect(
      tester
          .widget<DSButton>(find.byKey(const ValueKey('batch-delete-confirm')))
          .onPressed,
      isNot(null),
    );

    // 删除 → 确认框 → 确认
    await tester.tap(find.byKey(const ValueKey('batch-delete-confirm')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('批量删除'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('batch-delete-confirm-dialog')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    // pop 批量窗口的 route 退出动画（kDurationQuick 150ms）须完整 pump
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // 窗口关闭（月份切换器随窗口消失），事件进回收站
    expect(find.byKey(const ValueKey('batch-month-label')), findsNothing);
    final trashCount = await tester.runAsync(() => dao.getTrashCount());
    expect(trashCount, 3);

    // 收尾：关闭设置弹窗并卸载组件树，避免残留流订阅挂起
    await tester.tap(find.byKey(const ValueKey('settings-close')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });

  testWidgets('回收站：恢复事件回到日历，彻底清理后清空', (tester) async {
    final now = DateTime.now();
    var id = 0;
    await tester.runAsync(() async {
      id = await seed('删除我', DateTime(now.year, now.month, 10, 10));
      await dao.deleteEvent(id);
    });

    await pumpApp(tester);
    await openSettings(tester);

    // 打开回收站
    await openTrash(tester);
    expect(find.text('删除我'), findsOneWidget);
    expect(find.text('共 1 个已删除事件'), findsOneWidget);

    // 恢复
    await tester.tap(find.byKey(ValueKey('trash-restore-$id')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('回收站是空的'), findsOneWidget);
    expect(await tester.runAsync(() => dao.getTrashCount()), 0);
    final monthEvents = await tester.runAsync(
      () => dao.getMonth(DateTime(now.year, now.month)),
    );
    expect(monthEvents, hasLength(1));

    // 关闭回收站 → 再删除 → 重开回收站（一次性查询需重新加载）
    await tester.tap(find.byKey(const ValueKey('trash-close')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => dao.deleteEvent(id));
    await tester.pump(const Duration(milliseconds: 100));
    await openTrash(tester);
    expect(find.text('删除我'), findsOneWidget);

    // 彻底清理
    await tester.tap(find.byKey(const ValueKey('trash-empty-btn')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('彻底清理'), findsWidgets);
    await tester.tap(find.text('彻底清理').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(await tester.runAsync(() => dao.getTrashCount()), 0);
    expect(await tester.runAsync(() => dao.getById(id)), isNull);
    expect(find.text('回收站是空的'), findsOneWidget);

    // 收尾：卸载组件树
    await tester.tap(find.byKey(const ValueKey('trash-close')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });

  testWidgets('批量删除空态：当月无事件时显示提示且删除禁用', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await openBatchDelete(tester);

    expect(find.text('这个月没有事件'), findsOneWidget);
    expect(find.text('已选 0 个'), findsOneWidget);
  });

  testWidgets('设置页主题三选一：切换即时生效并持久化', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);

    // 滚动到外观区的主题分段控件
    await scrollSettingsTo(
      tester,
      find.byKey(const ValueKey('settings-theme-segment')),
    );
    expect(find.text('毛玻璃'), findsOneWidget);

    // 默认浅色：DSTokensScope 提供 light
    DSTokens tokensOf() =>
        DSTokensScope.of(tester.element(find.byType(AppShell)));
    expect(tokensOf().glassBlurSigma, 0);
    expect(tokensOf().mainBackground, DSTokens.light.mainBackground);

    // 切深色：token 立即变为 dark（亮度分层 + 无投影）
    await tester.tap(find.text('深色'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tokensOf().mainBackground, DSTokens.dark.mainBackground);
    expect(tokensOf().dialogBackground, DSTokens.dark.dialogBackground);
    // 持久化到数据库
    expect(
      await tester.runAsync(() => SettingsDao(db).get(kSettingThemeMode)),
      kThemeModeDark,
    );

    // 切毛玻璃：token 变为 glass（启用模糊与 hairline）
    await tester.tap(find.text('毛玻璃'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tokensOf().glassBlurSigma, greaterThan(0));
    expect(tokensOf().textPrimary, DSTokens.glass.textPrimary);
    expect(tokensOf().accentBlue, const Color(0xFF3D7EC5));

    // 玻璃只用于顶层浮层：输入条为轻玻璃，设置窗口为强玻璃。
    expect(
      find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(BackdropFilter),
      ),
      findsWidgets,
    );
    final kinds = tester
        .widgetList<DSGlassSurface>(find.byType(DSGlassSurface))
        .map((surface) => surface.kind);
    expect(kinds, contains(DSGlassSurfaceKind.floating));
    expect(kinds, contains(DSGlassSurfaceKind.dialog));
    expect(
      find.descendant(
        of: find.byType(DSGlassSurface),
        matching: find.byType(AnimatedScale),
      ),
      findsWidgets,
    );
    // 设置分组是普通清晰表面，不再嵌套玻璃或 BackdropFilter。
    expect(
      find.descendant(
        of: find.byType(SettingsDialogBody),
        matching: find.byType(DSGlassSurface),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SettingsDialogBody),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );

    // 收尾
    await tester.tap(find.byKey(const ValueKey('settings-close')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });
}
