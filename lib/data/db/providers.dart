/// Riverpod 依赖注入：数据库与 DAO。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'event_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final eventDaoProvider = Provider<EventDao>(
  (ref) => EventDao(ref.watch(databaseProvider)),
);

/// 某月事件流（月视图圆点数据源）
final monthEventsProvider =
    StreamProvider.family<List<Event>, DateTime>((ref, month) {
  return ref.watch(eventDaoProvider).watchMonth(month);
});

/// 某日事件流（今日待办列表数据源）
final dayEventsProvider =
    StreamProvider.family<List<Event>, DateTime>((ref, day) {
  return ref.watch(eventDaoProvider).watchDay(day);
});
