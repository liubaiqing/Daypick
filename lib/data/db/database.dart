/// drift 数据库实例：连接 %APPDATA%\calendar\calendar.sqlite（文档 4.4 节）。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Events, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试用：注入内存/文件 executor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // 后续版本在此追加迁移步骤（文档 4.4 节），并同步提升 schemaVersion
        onUpgrade: (m, from, to) async {},
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, kDatabaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
