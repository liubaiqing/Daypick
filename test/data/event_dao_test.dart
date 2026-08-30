// 存储层单元测试（文档 15.1/15.2 节）：插入 / 月查询 / 日查询 / 删除。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/event_dao.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  test('软删除后进回收站，正常查询/月查询/日查询均过滤', () async {
    final id = await dao.insertEvent(EventsCompanion(
      title: const Value('待删除事件'),
      start: Value(DateTime(2026, 8, 29, 10)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));

    await dao.deleteEvent(id);

    // 回收站可见
    final trash = await dao.watchTrash().first;
    expect(trash, hasLength(1));
    expect(trash.first.title, '待删除事件');
    expect(trash.first.deletedAt, isNot(null));

    // 正常查询均不可见
    expect(await dao.watchMonth(DateTime(2026, 8)).first, isEmpty);
    expect(await dao.watchDay(DateTime(2026, 8, 29)).first, isEmpty);
    expect(await dao.getAll(), isEmpty);
    expect(await dao.getMonth(DateTime(2026, 8)), isEmpty);
    expect(await dao.getTrashCount(), 1);
  });

  test('批量软删除多事件并幂等（重复删除跳过）', () async {
    final a = await dao.insertEvent(EventsCompanion(
      title: const Value('A'),
      start: Value(DateTime(2026, 8, 1, 9)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));
    final b = await dao.insertEvent(EventsCompanion(
      title: const Value('B'),
      start: Value(DateTime(2026, 8, 2, 9)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));

    await dao.softDeleteMany([a, b]);
    expect(await dao.getTrashCount(), 2);

    // 再次删除同一批：已删除的跳过，不重复计数
    await dao.softDeleteMany([a, b]);
    expect(await dao.getTrashCount(), 2);
  });

  test('恢复事件回到日历，回收站移除', () async {
    final id = await dao.insertEvent(EventsCompanion(
      title: const Value('恢复我'),
      start: Value(DateTime(2026, 8, 15, 9)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));
    await dao.deleteEvent(id);
    expect(await dao.getTrashCount(), 1);

    await dao.restoreEvent(id);
    expect(await dao.getTrashCount(), 0);
    final events = await dao.watchMonth(DateTime(2026, 8)).first;
    expect(events, hasLength(1));
    expect(events.first.title, '恢复我');
    expect(events.first.deletedAt, null);
  });

  test('彻底清理物理删除回收站全部事件', () async {
    final id = await dao.insertEvent(EventsCompanion(
      title: const Value('将被清空'),
      start: Value(DateTime(2026, 8, 20, 9)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));
    await dao.deleteEvent(id);
    expect(await dao.getTrashCount(), 1);

    await dao.emptyTrash();
    expect(await dao.getTrashCount(), 0);
    // 物理删除：按 id 也查不到
    expect(await dao.getById(id), isNull);
  });

  test('回收站按删除时间倒序排列', () async {
    // drift 的 dateTime 存 unix 秒，直接指定 deletedAt 验证排序
    final a = await dao.insertEvent(EventsCompanion(
      title: const Value('先删'),
      start: Value(DateTime(2026, 8, 1, 9)),
      deletedAt: Value(DateTime(2026, 8, 10, 9, 0)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));
    final b = await dao.insertEvent(EventsCompanion(
      title: const Value('后删'),
      start: Value(DateTime(2026, 8, 2, 9)),
      deletedAt: Value(DateTime(2026, 8, 11, 9, 0)),
      allDay: const Value(false),
      sourceType: const Value(EventSourceType.manual),
    ));

    final trash = await dao.watchTrash().first;
    expect(trash, hasLength(2));
    expect(trash.first.title, '后删');
    expect(trash.last.title, '先删');
    expect(a, isNot(b));
  });
}
