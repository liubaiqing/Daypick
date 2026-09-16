import 'package:calendar/core/constants.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:calendar/domain/parsed_event.dart';
import 'package:calendar/features/intake/confirm_card.dart';
import 'package:calendar/features/event/event_form.dart';
import 'package:calendar/domain/event_time.dart';
import 'package:calendar/features/settings/settings_page.dart';
import 'package:calendar/shared/design/ds_tokens.dart';
import 'package:calendar/shared/design/dstokens_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      builder: (context, child) => DSTokensScope(
        tokens: DSTokens.light,
        child: Material(child: child!),
      ),
      home: DSTokensScope(
        tokens: DSTokens.light,
        child: Scaffold(
          body: child is SettingsDialogBody
              ? child
              : SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  Finder clockField(String prefix) => find.byWidgetPredicate(
    (w) =>
        w is TextField && (w.decoration?.hintText?.startsWith(prefix) ?? false),
  );

  testWidgets('截止时间保存与重新编辑：开始保持空，结束20:00', (tester) async {
    final entry = DraftEntry(
      ParsedEvent(
        title: '奖学金申报',
        end: DateTime(2026, 9, 19, 20),
        sourceType: EventSourceType.text,
        sourceText: '9月19日晚8点前完成',
      ),
    );
    await tester.pumpWidget(
      host(
        ConfirmCard(
          key: entry.key,
          entry: entry,
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    expect(tester.widget<TextField>(clockField('开始')).controller!.text, '');
    expect(
      tester.widget<TextField>(clockField('结束／截止')).controller!.text,
      '20:00',
    );
    late Event saved;
    await tester.runAsync(() async {
      expect(await entry.key.currentState!.saveNow(), true);
      saved = (await db.select(db.events).get()).single;
      expect(saved.actualStart, isNull);
      expect(saved.hasStartTime, false);
      expect(saved.timeLabel, '截止 20:00');
      expect(saved.end, DateTime(2026, 9, 19, 20));
      expect(saved.start, DateTime(2026, 9, 19));
    });
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventFormDialog(context, existing: saved),
            child: const Text('打开编辑'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(clockField('开始')).controller!.text, '');
    expect(
      tester.widget<TextField>(clockField('结束／截止')).controller!.text,
      '20:00',
    );
    await tester.tap(find.text('保存'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect((await db.select(db.events).get()).single.hasStartTime, false);
    });
  });

  for (final sample in {
    '': '全天',
    '9': '09:00',
    '9.00': '09:00',
    '9.5': '09:05',
    '0': '00:00',
  }.entries) {
    testWidgets('草稿时刻输入 ${sample.key}，空结束，保存为${sample.value}', (tester) async {
      final entry = DraftEntry(
        ParsedEvent(
          title: '输入测试',
          start: DateTime(2026, 9, 19, 10),
          sourceType: EventSourceType.text,
          sourceText: '测试',
        ),
      );
      await tester.pumpWidget(
        host(
          ConfirmCard(
            key: entry.key,
            entry: entry,
            onChanged: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.enterText(clockField('开始'), sample.key);
      await tester.runAsync(() async {
        expect(await entry.key.currentState!.saveNow(), true);
        final row = (await db.select(db.events).get()).single;
        expect(row.timeLabel, sample.value);
        expect(row.allDay, sample.key.isEmpty);
        expect(row.end, isNull);
      });
      await tester.pump();
    });
  }

  testWidgets('手动新建两个时刻都空保存为全天', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventFormDialog(
              context,
              initialDate: DateTime(2026, 9, 19),
            ),
            child: const Text('打开新建'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开新建'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '标题',
      ),
      '全天测试',
    );
    expect(tester.widget<TextField>(clockField('开始')).controller!.text, '');
    await tester.tap(find.text('保存'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final row = (await db.select(db.events).get()).single;
      expect(row.allDay, true);
      expect(row.actualStart, isNull);
      expect(row.end, isNull);
    });
  });

  testWidgets('未知日期不默认今天且阻止保存', (tester) async {
    final entry = DraftEntry(
      const ParsedEvent(
        title: '待定会议',
        sourceType: EventSourceType.text,
        sourceText: '之后开会',
        missing: {MissingField.time},
      ),
    );
    await tester.pumpWidget(
      host(
        ConfirmCard(
          key: entry.key,
          entry: entry,
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    expect(find.text('请选择日期'), findsWidgets);
    expect(await entry.key.currentState!.saveNow(), false);
    expect(entry.saved, false);
    await tester.pump();
    expect(find.text('09:00'), findsNothing);
  });
  testWidgets('跨天日期保存不丢失，草稿确认前不入库', (tester) async {
    final entry = DraftEntry(
      ParsedEvent(
        title: '夜间值班',
        start: DateTime(2026, 9, 20, 23),
        end: DateTime(2026, 9, 21, 2),
        sourceType: EventSourceType.image,
        sourceText: '通知',
      ),
    );
    await tester.pumpWidget(
      host(
        ConfirmCard(
          key: entry.key,
          entry: entry,
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.runAsync(() async {
      expect(await db.select(db.events).get(), isEmpty);
      expect(await entry.key.currentState!.saveNow(), true);
      final row = (await db.select(db.events).get()).single;
      expect(row.start, DateTime(2026, 9, 20, 23));
      expect(row.end, DateTime(2026, 9, 21, 2));
    });
    await tester.pump();
  });
  testWidgets('单点事件不补结束时间', (tester) async {
    final entry = DraftEntry(
      ParsedEvent(
        title: '报名截止',
        start: DateTime(2026, 9, 18, 17),
        sourceType: EventSourceType.text,
        sourceText: '截止',
      ),
    );
    await tester.pumpWidget(
      host(
        ConfirmCard(
          key: entry.key,
          entry: entry,
          onChanged: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.runAsync(() async {
      expect(await entry.key.currentState!.saveNow(), true);
      expect((await db.select(db.events).get()).single.end, isNull);
    });
    await tester.pump();
  });
  testWidgets('本地设置独立回显，不覆盖在线配置', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final dao = container.read(settingsDaoProvider);
    await tester.runAsync(() async {
      await dao.set(kSettingLocalUrl, 'http://127.0.0.1:2233');
      await dao.set(kSettingLocalModel, 'qwen3.5:4b');
      await dao.set(kSettingLlmModel, 'online-test');
    });
    await tester.pumpWidget(host(const SettingsDialogBody()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const ValueKey('local-url')),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(field).controller!.text,
      'http://127.0.0.1:2233',
    );
    await tester.runAsync(() async {
      expect(await dao.get(kSettingLlmModel), 'online-test');
    });
    container.dispose();
  });
}
