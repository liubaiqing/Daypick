/// 事件数据访问：月/日流式查询与增删改。对应文档 10.4 节。
library;

import 'package:drift/drift.dart';

import 'database.dart';

class EventDao {
  EventDao(this._db);

  final AppDatabase _db;

  /// 某月全部事件（流式，供月视图圆点渲染）
  Stream<List<Event>> watchMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 1);
    return (_db.select(_db.events)
          ..where((t) =>
              t.start.isBiggerOrEqualValue(first) &
              t.start.isSmallerThanValue(last))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .watch();
  }

  /// 某日全部事件（流式，供今日待办列表）
  Stream<List<Event>> watchDay(DateTime day) {
    final first = DateTime(day.year, day.month, day.day);
    final last = first.add(const Duration(days: 1));
    return (_db.select(_db.events)
          ..where((t) =>
              t.start.isBiggerOrEqualValue(first) &
              t.start.isSmallerThanValue(last))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .watch();
  }

  /// 插入新事件（确认流保存 / 手动新建均走此入口）
  Future<int> insertEvent(EventsCompanion entry) =>
      _db.into(_db.events).insert(entry);

  /// 整行替换（编辑保存）
  Future<bool> replaceEvent(Event event) =>
      _db.update(_db.events).replace(event);

  /// 删除事件
  Future<int> deleteEvent(int id) =>
      (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();

  /// 全量事件（ics/JSON 导出用，文档 12 章）
  Future<List<Event>> getAll() => _db.select(_db.events).get();

  /// 按 id 查询（JSON 恢复合并去重用）
  Future<Event?> getById(int id) =>
      (_db.select(_db.events)..where((t) => t.id.equals(id))).getSingleOrNull();
}
