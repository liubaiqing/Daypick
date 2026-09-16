// 数据库迁移测试：v1/v2 → v3，保留旧事件及默认开始时间语义。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/event_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  for (final version in [1, 2]) {
    test('v$version 数据库升级到 v3：旧事件保留开始时间与软删除状态', () async {
      // 1. 用 sqlite3 手工创建 v1 结构的 events 表并插入数据
      final sql = sqlite3.sqlite3.openInMemory();
      sql.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        location TEXT,
        start INTEGER NOT NULL,
        end INTEGER,
        all_day INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        source_type INTEGER NOT NULL DEFAULT 2,
        source_text TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
      sql.execute('''
      INSERT INTO events (title, start, all_day, source_type, created_at, updated_at)
      VALUES ('迁移前事件', 1785643200, 0, 2, 1785643200, 1785643200)
    ''');
      // drift 以 user_version 判断当前 schema 版本
      if (version == 2) {
        sql.execute('ALTER TABLE events ADD COLUMN deleted_at INTEGER');
      }
      sql.execute('PRAGMA user_version = $version');

      // 2. 用当前 schema（v3）打开同一数据库，触发 onUpgrade 迁移
      final db = AppDatabase.forTesting(NativeDatabase.opened(sql));
      final dao = EventDao(db);

      // 3. 老数据保留、deletedAt 为 null，正常查询可见
      final events = await dao.getAll();
      expect(events, hasLength(1));
      expect(events.first.title, '迁移前事件');
      expect(events.first.deletedAt, null);
      expect(events.first.hasStartTime, true);
      expect(sql.select('PRAGMA user_version').single['user_version'], 3);
      expect(await dao.getTrashCount(), 0);

      await db.close();
    });
  }
}
