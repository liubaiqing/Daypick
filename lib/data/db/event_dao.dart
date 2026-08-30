/// 事件数据访问：月/日流式查询与增删改（文档 10.4 节）。
/// 回收站：删除为软删除（deletedAt），恢复/彻底清理见 10.6 节；
/// 所有"正常事件"查询与导出统一过滤 deletedAt IS NULL（文档 4.1 节）。
library;

import 'package:drift/drift.dart';

import 'database.dart';

class EventDao {
  EventDao(this._db);

  final AppDatabase _db;

  /// 某月全部**正常**事件（流式，供月视图圆点渲染）
  Stream<List<Event>> watchMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 1);
    return (_db.select(_db.events)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.start.isBiggerOrEqualValue(first) &
              t.start.isSmallerThanValue(last))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .watch();
  }

  /// 某日全部**正常**事件（流式，供今日待办列表）
  Stream<List<Event>> watchDay(DateTime day) {
    final first = DateTime(day.year, day.month, day.day);
    final last = first.add(const Duration(days: 1));
    return (_db.select(_db.events)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.start.isBiggerOrEqualValue(first) &
              t.start.isSmallerThanValue(last))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .watch();
  }

  /// 某月全部**正常**事件（一次性查询，批量删除窗口用）
  Future<List<Event>> getMonth(DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 1);
    return (_db.select(_db.events)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.start.isBiggerOrEqualValue(first) &
              t.start.isSmallerThanValue(last))
          ..orderBy([(t) => OrderingTerm(expression: t.start)]))
        .get();
  }

  /// 回收站全部事件（流式，按删除时间倒序，供回收站窗口）
  Stream<List<Event>> watchTrash() {
    return (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 回收站全部事件（一次性查询；UI 操作后手动刷新，避免常驻流订阅）
  Future<List<Event>> getTrash() async {
    return (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// 回收站事件数量（设置入口徽标）
  Future<int> getTrashCount() async {
    final query = _db.selectOnly(_db.events)
      ..addColumns([_db.events.id.count()])
      ..where(_db.events.deletedAt.isNotNull());
    return query.map((row) => row.read(_db.events.id.count())!).getSingle();
  }

  /// 插入新事件（确认流保存 / 手动新建均走此入口）
  Future<int> insertEvent(EventsCompanion entry) =>
      _db.into(_db.events).insert(entry);

  /// 整行替换（编辑保存）
  Future<bool> replaceEvent(Event event) =>
      _db.update(_db.events).replace(event);

  /// 删除事件（**软删除**：写入 deletedAt，进入回收站，可恢复）
  Future<int> deleteEvent(int id) =>
      _softDelete([id]);

  /// 批量软删除（批量删除窗口，文档 10.5 节）
  Future<int> softDeleteMany(List<int> ids) => _softDelete(ids);

  Future<int> _softDelete(List<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    final stmt = _db.update(_db.events)
      ..where((t) => t.id.isIn(ids) & t.deletedAt.isNull());
    return stmt.write(EventsCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 恢复事件（回收站 → 日历，deletedAt 置 null）
  Future<int> restoreEvent(int id) {
    final stmt = _db.update(_db.events)..where((t) => t.id.equals(id));
    return stmt.write(EventsCompanion(
      deletedAt: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 备份恢复用：复活软删除行并整体覆盖字段（文档 12.2 节）
  Future<int> restoreAndOverwrite(int id, EventsCompanion entry) {
    final stmt = _db.update(_db.events)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNotNull());
    return stmt.write(entry.copyWith(deletedAt: const Value(null)));
  }

  /// 彻底清理回收站（物理删除全部已删除事件，不可恢复）
  Future<int> emptyTrash() =>
      (_db.delete(_db.events)..where((t) => t.deletedAt.isNotNull())).go();

  /// 全量**正常**事件（ics/JSON 导出用，文档 12 章：回收站不导出）
  Future<List<Event>> getAll() =>
      (_db.select(_db.events)..where((t) => t.deletedAt.isNull())).get();

  /// 按 id 查询（JSON 恢复合并去重用）
  Future<Event?> getById(int id) =>
      (_db.select(_db.events)..where((t) => t.id.equals(id))).getSingleOrNull();
}
