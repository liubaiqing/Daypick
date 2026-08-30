/// JSON 备份与恢复（文档 12.2 节）：仅事件数据（不含 settings/API Key），
/// 顶层 schema version 校验，按 id 合并（已存在跳过）。
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide Column, Table;

import '../../domain/event_source_type.dart';
import '../db/database.dart';
import '../db/event_dao.dart';

class BackupService {
  BackupService(this._dao);

  final EventDao _dao;

  static const int _schemaVersion = 1;
  static const String _appTag = 'calendar';

  /// 导出全量事件为 JSON 字符串
  Future<String> exportJson() async {
    final events = await _dao.getAll();
    final payload = <String, dynamic>{
      'app': _appTag,
      'version': _schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'events': [
        for (final e in events)
          {
            'id': e.id,
            'title': e.title,
            'location': e.location,
            'start': e.start.toIso8601String(),
            'end': e.end?.toIso8601String(),
            'all_day': e.allDay,
            'note': e.note,
            'source_type': e.sourceType.name,
            'source_text': e.sourceText,
            'created_at': e.createdAt.toIso8601String(),
            'updated_at': e.updatedAt.toIso8601String(),
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// 恢复：校验版本后按 id 合并；返回 (恢复数, 跳过数)。
  Future<({int restored, int skipped})> restoreJson(String content) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const FormatException('备份文件不是有效 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件格式不正确');
    }
    if (decoded['app'] != _appTag) {
      throw const FormatException('不是本应用导出的备份文件');
    }
    final version = decoded['version'];
    if (version is! int || version < 1) {
      throw const FormatException('备份缺少版本号');
    }
    if (version > _schemaVersion) {
      throw FormatException(
        '备份版本（$version）高于当前支持的版本（$_schemaVersion），请升级应用后再恢复',
      );
    }
    final rawEvents = decoded['events'];
    if (rawEvents is! List) {
      throw const FormatException('备份缺少事件数据');
    }

    var restored = 0;
    var skipped = 0;
    for (final raw in rawEvents) {
      if (raw is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      final id = raw['id'];
      final title = (raw['title'] as String?)?.trim() ?? '';
      final startStr = raw['start'] as String?;
      final start = startStr == null ? null : DateTime.tryParse(startStr);
      if (id is! int || title.isEmpty || start == null) {
        skipped++;
        continue;
      }
      if (await _dao.getById(id) != null) {
        // 已存在：若为软删除（回收站）则复活并覆盖字段，否则跳过
        final existing = await _dao.getById(id);
        if (existing!.deletedAt == null) {
          skipped++;
          continue;
        }
        await _dao.restoreAndOverwrite(id, _companionFromRaw(raw, id));
        restored++;
        continue;
      }
      await _dao.insertEvent(
        _companionFromRaw(raw, id),
      );
      restored++;
    }
    return (restored: restored, skipped: skipped);
  }

  static EventsCompanion _companionFromRaw(
    Map<String, dynamic> raw,
    int id,
  ) {
    final endStr = raw['end'] as String?;
    final location = (raw['location'] as String?)?.trim();
    final note = (raw['note'] as String?)?.trim();
    final sourceName = raw['source_type'] as String?;
    return EventsCompanion(
      id: Value(id),
      title: Value((raw['title'] as String?)?.trim() ?? ''),
      location: Value((location == null || location.isEmpty) ? null : location),
      start: Value(DateTime.tryParse(raw['start'] as String? ?? '') ?? DateTime.now()),
      end: Value(endStr == null ? null : DateTime.tryParse(endStr)),
      allDay: Value(raw['all_day'] == true),
      note: Value((note == null || note.isEmpty) ? null : note),
      sourceType: Value(
        EventSourceType.values.firstWhere(
          (s) => s.name == sourceName,
          orElse: () => EventSourceType.manual,
        ),
      ),
      sourceText: Value(raw['source_text'] as String?),
      createdAt: Value(
        raw['created_at'] is String
            ? DateTime.tryParse(raw['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      ),
      updatedAt: Value(
        raw['updated_at'] is String
            ? DateTime.tryParse(raw['updated_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      ),
      deletedAt: const Value(null),
    );
  }
}
