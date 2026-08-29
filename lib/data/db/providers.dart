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
