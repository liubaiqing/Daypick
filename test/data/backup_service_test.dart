// JSON 备份/恢复单元测试（文档 12.2 节）：导出→恢复往返、按 id 去重、版本校验。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/event_dao.dart';
import 'package:calendar/data/export/backup_service.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventDao dao;
  late BackupService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = EventDao(db);
    service = BackupService(dao);
  });

  tearDown(() => db.close());

  Future<int> seed(String title, DateTime start, {int? id}) async {
    return dao.insertEvent(
      EventsCompanion(
        id: id == null ? const Value.absent() : Value(id),
        title: Value(title),
        start: Value(start),
        allDay: const Value(true),
        sourceType: const Value(EventSourceType.manual),
      ),
    );
  }

  test('只有截止时间的备份恢复保持开始为空', () async {
    final id = await dao.insertEvent(
      EventsCompanion(
        title: const Value('奖学金申报'),
        start: Value(DateTime(2026, 9, 19)),
        end: Value(DateTime(2026, 9, 19, 20)),
        hasStartTime: const Value(false),
        sourceType: const Value(EventSourceType.text),
      ),
    );
    final backup = await service.exportJson();
    expect(backup, contains('"has_start_time": false'));
    await dao.deleteEvent(id);
    expect((await service.restoreJson(backup)).restored, 1);
    final restored = (await dao.getAll()).single;
    expect(restored.hasStartTime, false);
    expect(restored.end, DateTime(2026, 9, 19, 20));
  });
  test('v1旧备份缺少开始标记，保留旧时间语义', () async {
    await service.restoreJson(
      '{"app":"calendar","version":1,"events":[{"id":100,"title":"旧会议","start":"2026-09-19T09:00:00","source_type":"text"}]}',
    );
    expect((await dao.getAll()).single.hasStartTime, true);
  });
  test('导出→空库恢复往返', () async {
    final id1 = await seed('事件A', DateTime(2026, 9, 1));
    final id2 = await seed('事件B', DateTime(2026, 9, 2));

    final json = await service.exportJson();
    expect(json, isNot(contains('llmApiKey'))); // 不含设置/Key

    // 清空后恢复
    await dao.deleteEvent(id1);
    await dao.deleteEvent(id2);
    expect(await dao.getAll(), isEmpty);

    final summary = await service.restoreJson(json);
    expect(summary.restored, 2);
    expect(summary.skipped, 0);
    final events = await dao.getAll();
    expect(events.map((e) => e.title).toSet(), {'事件A', '事件B'});
  });

  test('按 id 合并：已存在跳过', () async {
    final id1 = await seed('事件A', DateTime(2026, 9, 1));
    final json = await service.exportJson();
    final summary = await service.restoreJson(json);
    expect(summary.restored, 0);
    expect(summary.skipped, 1);
    expect(await dao.getAll(), hasLength(1));
    expect(id1, 1); // 未重复插入
  });

  test('非本应用备份 → FormatException', () {
    expect(
      service.restoreJson('{"app":"other","version":1,"events":[]}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('不是本应用'),
        ),
      ),
    );
  });

  test('版本过高 → FormatException', () {
    expect(
      service.restoreJson('{"app":"calendar","version":99,"events":[]}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('非法 JSON → FormatException', () {
    expect(service.restoreJson('not json'), throwsA(isA<FormatException>()));
  });
}
