// ics 导出单元测试（文档 12.1 / 15.1 节）：转义、折行、全天、时间点事件、CRLF。
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/export/ics_exporter.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exporter = const IcsExporter();

  Event makeEvent({
    required int id,
    required String title,
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    bool hasStartTime = true,
    String? location,
    String? note,
  }) {
    final s = start ?? DateTime(2026, 9, 15, 9, 0);
    return Event(
      id: id,
      title: title,
      location: location,
      start: s,
      hasStartTime: hasStartTime,
      end: end,
      allDay: allDay,
      note: note,
      sourceType: EventSourceType.manual,
      sourceText: null,
      createdAt: s,
      updatedAt: s,
    );
  }

  test('仅截止时间使用VTODO DUE，不伪造开始时间', () {
    final content = exporter.build([
      makeEvent(
        id: 8,
        title: '奖学金申报',
        start: DateTime(2026, 9, 19),
        end: DateTime(2026, 9, 19, 20),
        hasStartTime: false,
      ),
    ]);
    final task = content.split('BEGIN:VTODO').last;
    expect(task, contains('DUE;TZID=Asia/Shanghai:20260919T200000'));
    expect(task, isNot(contains('DTSTART')));
    expect(task, isNot(contains('DTEND')));
  });
  test('基础结构：VCALENDAR/VTIMEZONE/VEVENT，CRLF 行尾', () {
    final content = exporter.build([makeEvent(id: 1, title: '开会')]);
    expect(content.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(content, contains('PRODID:-//calendar//CN'));
    expect(content, contains('BEGIN:VTIMEZONE'));
    expect(content, contains('TZID:Asia/Shanghai'));
    expect(content, contains('UID:1@calendar.local'));
    expect(content, contains('END:VEVENT\r\nEND:VCALENDAR'));
    // 全部行尾均为 CRLF（\n 的数量等于 \r\n 的数量）
    final lfCount = '\n'.allMatches(content).length;
    final crlfCount = '\r\n'.allMatches(content).length;
    expect(lfCount, crlfCount);
  });

  test('定时事件：DTSTART/DTEND 带 TZID', () {
    final content = exporter.build([
      makeEvent(
        id: 2,
        title: '出差',
        start: DateTime(2026, 9, 15, 9, 0),
        end: DateTime(2026, 9, 15, 17, 0),
      ),
    ]);
    expect(content, contains('DTSTART;TZID=Asia/Shanghai:20260915T090000'));
    expect(content, contains('DTEND;TZID=Asia/Shanghai:20260915T170000'));
  });

  test('全天事件：VALUE=DATE 且无 DTEND', () {
    final content = exporter.build([
      makeEvent(
        id: 3,
        title: '生日',
        start: DateTime(2026, 12, 25),
        allDay: true,
      ),
    ]);
    expect(content, contains('DTSTART;VALUE=DATE:20261225'));
    expect(content.contains('DTEND'), isFalse);
  });

  test('时间点事件：仅 DTSTART 无 DTEND', () {
    final content = exporter.build([
      makeEvent(id: 4, title: '面试', start: DateTime(2026, 9, 16, 14, 30)),
    ]);
    expect(content, contains('DTSTART;TZID=Asia/Shanghai:20260916T143000'));
    expect(content.contains('DTEND'), isFalse);
  });

  test('文本转义：逗号/分号/反斜杠/换行', () {
    final content = exporter.build([
      makeEvent(id: 5, title: '开会,讨论;方案\\A\nB', location: '公司;3楼,会议室'),
    ]);
    expect(content, contains('SUMMARY:开会\\,讨论\\;方案\\\\A\\nB'));
    expect(content, contains('LOCATION:公司\\;3楼\\,会议室'));
  });

  test('超长行按 75 字节折行（续行以空格开头）', () {
    final longTitle = '很长的会议标题' * 20;
    final content = exporter.build([makeEvent(id: 6, title: longTitle)]);
    for (final line in content.split('\r\n')) {
      // 折行后每行不超过 75 字节
      expect(line.length <= 75, isTrue, reason: '超长行：$line');
    }
  });
}
