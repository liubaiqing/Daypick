// 设置存取单元测试（文档 4.1 节 settings 表）。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/settings_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SettingsDao(db);
  });

  tearDown(() => db.close());

  test('未设置时返回 null', () async {
    expect(await dao.get('parseMode'), isNull);
  });

  test('set/get 往返', () async {
    await dao.set('parseMode', 'ai');
    expect(await dao.get('parseMode'), 'ai');
  });

  test('覆盖更新', () async {
    await dao.set('llmModel', 'deepseek-chat');
    await dao.set('llmModel', 'deepseek-reasoner');
    expect(await dao.get('llmModel'), 'deepseek-reasoner');
  });
}
