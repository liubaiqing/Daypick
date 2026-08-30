/// drift 数据库实例：连接 %APPDATA%\calendar\calendar.sqlite（文档 4.4 节）。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../domain/event_source_type.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Events, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试用：注入内存/文件 executor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2：回收站软删除字段（文档 4.4 节，老数据全部为 null）
          if (from < 2) {
            await m.addColumn(events, events.deletedAt);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, kDatabaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
