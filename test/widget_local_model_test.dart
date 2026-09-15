import 'package:calendar/core/constants.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:calendar/domain/parsed_event.dart';
import 'package:calendar/features/intake/confirm_card.dart';
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
