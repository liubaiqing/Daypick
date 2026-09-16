/// drift 表定义：events / settings。对应技术开发文档第 4.1 节。
library;

import 'package:drift/drift.dart';

import '../../domain/event_source_type.dart';

/// 事件表：库中只存用户已确认的事件（文档 4.3 节）；
/// deletedAt 为软删除标记（文档 4.1 节回收站）：null=正常，非 null=已删除时刻。
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get start => dateTime()();
  // start 同时作为日历归属日期；false 表示无开始时刻，start 仅存所选日00:00。
  BoolColumn get hasStartTime => boolean().withDefault(const Constant(true))();
  DateTimeColumn get end => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get sourceType => intEnum<EventSourceType>()();
  TextColumn get sourceText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// 设置表：parseMode / llmBaseUrl / llmApiKey / llmModel 等
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
