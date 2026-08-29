// 存储层单元测试（文档 15.1/15.2 节）：插入 / 月查询 / 日查询 / 删除。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/event_dao.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = EventDao(db);
  });

  tearDown(() => db.close());

  test('insert 后当日流式查询可读到事件', () async {
    final start = DateTime(2026, 8, 29, 9, 0);
    await dao.insertEvent(EventsCompanion(
      title: const Value('测试事件'),
      start: Value(start),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));

    final events = await dao.watchDay(DateTime(2026, 8, 29)).first;
    expect(events, hasLength(1));
    expect(events.first.title, '测试事件');
    expect(events.first.start, start);
    expect(events.first.sourceType, EventSourceType.manual);
  });

  test('月查询只含当月事件，删除后为空', () async {
    await dao.insertEvent(EventsCompanion(
      title: const Value('八月事件'),
      start: Value(DateTime(2026, 8, 1, 8)),
      allDay: const Value(true),
      sourceType: const Value(EventSourceType.manual),
    ));
    await dao.insertEvent(EventsCompanion(
      title: const Value('九月事件'),
      start: Value(DateTime(2026, 9, 1, 8)),
      allDay: const Value(true),
      sourceType: const Value(EventSourceType.manual),
    ));

    final august = await dao.watchMonth(DateTime(2026, 8)).first;
    expect(august, hasLength(1));
    expect(august.first.title, '八月事件');

    await dao.deleteEvent(august.first.id);
    expect(await dao.watchMonth(DateTime(2026, 8)).first, isEmpty);
    expect(await dao.watchMonth(DateTime(2026, 9)).first, hasLength(1));
  });
}
