/// drift 表定义：events / settings。对应技术开发文档第 4.1 节。
library;

import 'package:drift/drift.dart';

import '../../domain/event_source_type.dart';

/// 事件表：库中只存用户已确认的事件（文档 4.3 节）
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get sourceType => intEnum<EventSourceType>()();
  TextColumn get sourceText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 设置表：parseMode / llmBaseUrl / llmApiKey / llmModel 等
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
