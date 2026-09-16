import 'package:calendar/domain/clock_input.dart';
import 'package:calendar/data/parsers/local_model_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_model_test.dart' show FakeModel;

void main() {
  for (final entry in {
    '9': '09:00',
    '09': '09:00',
    '9.00': '09:00',
    '9.5': '09:05',
    '9:5': '09:05',
    '9:05': '09:05',
    '0': '00:00',
    '0.5': '00:05',
    '23.59': '23:59',
    '9点': '09:00',
    '9点整': '09:00',
    '9时5分': '09:05',
    '０９：０５': '09:05',
    ' 20 ': '20:00',
  }.entries) {
    test(
      '${entry.key} → ${entry.value}',
      () => expect(ClockInput.parse(entry.key)?.formatted, entry.value),
    );
  }
  for (final text in [
    '',
    '24',
    '24:00',
    '9.60',
    '9:99',
    '-1',
    '9.',
    '9:',
    '123',
    '9.005',
    '09:00:00',
    'abc',
  ]) {
    test('拒绝无效时刻 "$text"', () => expect(ClockInput.parse(text), isNull));
  }
  test('只有截止时间不被解析器丢弃，也不标记缺失日期', () {
    final parser = LocalModelParser(FakeModel());
    final draft = parser.mapEvents({
      'events': [
        {
          'title': '奖学金申报',
          'location': null,
          'start': null,
          'end': '2026-09-19T20:00:00',
          'all_day': false,
          'note': null,
        },
      ],
    }, const LocalInput(text: '9月19日晚8点前完成')).single;
    expect(draft.start, isNull);
    expect(draft.end, DateTime(2026, 9, 19, 20));
    expect(draft.hasMissingTime, false);
    expect(draft.allDay, false);
  });
}
