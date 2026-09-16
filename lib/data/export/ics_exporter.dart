/// ics 导出（文档 12.1 节，RFC 5545）：VTIMEZONE Asia/Shanghai、
/// 文本转义、CRLF 行尾、75 字节折行、全天 VALUE=DATE、时间点事件无 DTEND。
library;

import 'dart:convert';

import '../db/database.dart';

class IcsExporter {
  const IcsExporter();

  static const String _tzid = 'Asia/Shanghai';

  /// 生成全量 ics 内容
  String build(List<Event> events) {
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//calendar//CN',
      'BEGIN:VTIMEZONE',
      'TZID:$_tzid',
      'BEGIN:STANDARD',
      'DTSTART:19700101T000000',
      'TZOFFSETFROM:+0800',
      'TZOFFSETTO:+0800',
      'END:STANDARD',
      'END:VTIMEZONE',
      for (final e in events) ..._buildEvent(e),
      'END:VCALENDAR',
    ];
    return _foldAndJoin(lines);
  }

  List<String> _buildEvent(Event e) {
    // 仅截止时间是待办的 DUE，不伪造 DTSTART。部分日历客户端需导入至任务列表。
    final deadlineOnly = !e.allDay && !e.hasStartTime && e.end != null;
    final component = deadlineOnly ? 'VTODO' : 'VEVENT';
    final lines = <String>[
      'BEGIN:$component',
      'UID:${e.id}@calendar.local',
      'DTSTAMP:${_formatUtc(DateTime.now())}',
    ];
    if (deadlineOnly) {
      lines.add('DUE;TZID=$_tzid:${_formatLocal(e.end!)}');
    } else if (e.allDay || !e.hasStartTime) {
      lines.add('DTSTART;VALUE=DATE:${_formatDate(e.start)}');
    } else {
      lines.add('DTSTART;TZID=$_tzid:${_formatLocal(e.start)}');
      if (e.end != null) {
        lines.add('DTEND;TZID=$_tzid:${_formatLocal(e.end!)}');
      }
    }
    lines.add('SUMMARY:${_escape(e.title)}');
    if (e.location != null && e.location!.isNotEmpty) {
      lines.add('LOCATION:${_escape(e.location!)}');
    }
    if (e.note != null && e.note!.isNotEmpty) {
      lines.add('DESCRIPTION:${_escape(e.note!)}');
    }
    lines.add('END:$component');
    return lines;
  }

  /// RFC 5545 文本转义：反斜杠 / 分号 / 逗号 / 换行
  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  static String _formatLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}${d.second.toString().padLeft(2, '0')}';

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static String _formatUtc(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${u.month.toString().padLeft(2, '0')}'
        '${u.day.toString().padLeft(2, '0')}T${u.hour.toString().padLeft(2, '0')}'
        '${u.minute.toString().padLeft(2, '0')}${u.second.toString().padLeft(2, '0')}Z';
  }

  /// 行尾 CRLF；超过 75 字节的行按字符折行（续行以空格开头，RFC 5545 §3.1）
  static String _foldAndJoin(List<String> lines) {
    final sb = StringBuffer();
    for (final line in lines) {
      if (utf8.encode(line).length <= 75) {
        sb.writeln(line);
        continue;
      }
      final current = StringBuffer();
      var currentBytes = 0;
      for (final ch in line.split('')) {
        final chBytes = utf8.encode(ch).length;
        if (currentBytes + chBytes > 74 && current.isNotEmpty) {
          sb.writeln(current);
          current.clear();
          current.write(' '); // 续行前缀
          currentBytes = 1;
        }
        current.write(ch);
        currentBytes += chBytes;
      }
      sb.writeln(current);
    }
    return sb.toString().replaceAll('\n', '\r\n');
  }
}
