// 离线解析引擎单元测试（文档 15.1 节用例表）。
// 固定时钟：2026-08-29（周六）10:00，保证日期归一化用例确定性。
import 'package:calendar/core/errors.dart';
import 'package:calendar/data/parsers/local_parser.dart';
import 'package:calendar/domain/parsed_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 29, 10, 0);
  LocalParser parser() => LocalParser(now: () => now);

  Future<List<ParsedEvent>> parseOne(String text) =>
      parser().parse(text);

  group('日期归一化（文档 5.2 节）', () {
    test('绝对日期-带年份', () async {
      final e = (await parseOne('2026年9月15日 开会')).single;
      expect(e.start, DateTime(2026, 9, 15));
      expect(e.allDay, isTrue);
    });

    test('绝对日期-无年份 未来取今年', () async {
      final e = (await parseOne('9月15日 开会')).single;
      expect(e.start, DateTime(2026, 9, 15));
    });

    test('绝对日期-无年份 默认当前系统年（已过不自动顺延）', () async {
      final e = (await parseOne('3月15日 出差')).single;
      expect(e.start, DateTime(2026, 3, 15));
      expect(e.isPastDate(now), isTrue); // 已过由 UI 提示，不偏移到明年
    });

    test('跨年边界：无年份固定当前年', () async {
      final p = LocalParser(now: () => DateTime(2026, 12, 20, 10, 0));
      final e = (await p.parse('1月5日 体检')).single;
      expect(e.start, DateTime(2026, 1, 5));
    });

    test('闰年 2 月 29 日有效', () async {
      final e = (await parseOne('2028年2月29日 开会')).single;
      expect(e.start, DateTime(2028, 2, 29));
    });

    test('非法日期（2026 非闰年 2 月 29 日）视为无效，缺时间', () async {
      final e = (await parseOne('2026年2月29日 开会')).single;
      expect(e.start, isNull);
      expect(e.hasMissingTime, isTrue);
    });

    test('相对日期-明天', () async {
      final e = (await parseOne('明天下午3点开会')).single;
      expect(e.start, DateTime(2026, 8, 30, 15, 0));
    });

    test('相对日期-下周三（跨周）', () async {
      final e = (await parseOne('下周三开会')).single;
      expect(e.start, DateTime(2026, 9, 2));
      expect(e.allDay, isTrue);
    });

    test('周X 就近未来：本周已过取下周', () async {
      final wed = (await parseOne('周三开会')).single; // 本周三 8/26 已过
      expect(wed.start, DateTime(2026, 9, 2));
      final mon = (await parseOne('周一开会')).single; // 本周一 8/24 已过
      expect(mon.start, DateTime(2026, 8, 31));
    });

    test('时段映射-晚上 8 点 → 20:00（时刻未过取今天）', () async {
      final e = (await parseOne('晚上8点开会')).single;
      expect(e.start, DateTime(2026, 8, 29, 20, 0));
    });

    test('矛盾表述：下午 12 点归中午 12:00（数值为准）', () async {
      final e = (await parseOne('下午12点开会')).single;
      expect(e.start, DateTime(2026, 8, 29, 12, 0));
    });

    test('半点：下午 3 点半 → 15:30', () async {
      final e = (await parseOne('下午3点半开会')).single;
      expect(e.start, DateTime(2026, 8, 29, 15, 30));
    });

    test('时刻已过无日期 → 顺延明天', () async {
      final e = (await parseOne('9点到11点开会')).single;
      expect(e.start, DateTime(2026, 8, 30, 9, 0));
      expect(e.end, DateTime(2026, 8, 30, 11, 0));
    });

    test('区间-今日未来时段', () async {
      final e = (await parseOne('下午3点到5点开会')).single;
      expect(e.start, DateTime(2026, 8, 29, 15, 0));
      expect(e.end, DateTime(2026, 8, 29, 17, 0));
    });

    test('跨天区间：结束加一天', () async {
      final e = (await parseOne('晚上11点到凌晨1点值班')).single;
      expect(e.start, DateTime(2026, 8, 29, 23, 0));
      expect(e.end, DateTime(2026, 8, 30, 1, 0));
    });

    test('全天提示词', () async {
      final e = (await parseOne('8月30日全天 搬家')).single;
      expect(e.allDay, isTrue);
      expect(e.start, DateTime(2026, 8, 30));
    });

    test('仅提供日 → 年月取系统当前（15号=本月15日）', () async {
      final e = (await parseOne('15号下午2点开会')).single;
      expect(e.start, DateTime(2026, 8, 15, 14, 0));
    });

    test('仅提供日-全天', () async {
      final e = (await parseOne('3号全天搬家')).single;
      expect(e.start, DateTime(2026, 8, 3));
      expect(e.allDay, isTrue);
    });

    test('仅提供日-当月月末有效', () async {
      final e = (await parseOne('31号体检')).single;
      expect(e.start, DateTime(2026, 8, 31));
    });

    test('仅提供日-当月无此日则无效（4月31日）', () async {
      final p = LocalParser(now: () => DateTime(2026, 4, 20, 10, 0));
      final e = (await p.parse('31号开会')).single;
      expect(e.start, isNull);
      expect(e.hasMissingTime, isTrue);
    });

    test('绝对日期优先于仅日（3月15日不被误拆）', () async {
      final e = (await parseOne('3月15日下午2点出差')).single;
      expect(e.start, DateTime(2026, 3, 15, 14, 0));
    });

    test('过去日期（昨天）可解析且提示', () async {
      final e = (await parseOne('昨天开会')).single;
      expect(e.start, DateTime(2026, 8, 28));
      expect(e.isPastDate(now), isTrue);
    });
  });

  group('地点抽取（文档 5.3 节）', () {
    test('介词锚点+关键词截断', () async {
      final e = (await parseOne('3月15日下午2点去上海虹桥机场出差')).single;
      expect(e.location, '上海虹桥机场');
      expect(e.start, DateTime(2026, 3, 15, 14, 0));
    });

    test('在+地点短语', () async {
      final e =
          (await parseOne('明天上午10点在公司3楼会议室开会，讨论季度计划')).single;
      expect(e.location, '公司3楼会议室');
    });

    test('后缀词表兜底（不跨日期片段）', () async {
      final e = (await parseOne('12月25日 广州大厦开会')).single;
      expect(e.location, '广州大厦');
    });

    test('无地点 → missing 标记', () async {
      final e = (await parseOne('12月25日 圣诞节')).single;
      expect(e.hasMissingLocation, isTrue);
      expect(e.location, isNull);
    });
  });

  group('标题与备注（文档 5.4 节）', () {
    test('动宾短语扩展：交房租', () async {
      final e = (await parseOne('记得交房租')).single;
      expect(e.title, '交房租');
      expect(e.hasMissingTime, isTrue);
      expect(e.lowConfidence, isTrue);
    });

    test('连接词后内容转入备注', () async {
      final e =
          (await parseOne('明天上午10点在公司3楼会议室开会，讨论季度计划')).single;
      expect(e.title, '开会');
      expect(e.note, '讨论季度计划');
    });

    test('关键词拼接：出差开会', () async {
      final e = (await parseOne('去上海出差开会')).single;
      expect(e.title, '出差开会');
      expect(e.location, '上海');
    });

    test('无关键词取主干', () async {
      final e = (await parseOne('12月25日 圣诞节')).single;
      expect(e.title, '圣诞节');
    });
  });

  group('多事件与异常（文档 5.5 节）', () {
    test('一句多事件：按关键词分段', () async {
      final events = await parseOne('周一开会，周二出差');
      expect(events, hasLength(2));
      expect(events[0].title, '开会');
      expect(events[0].start, DateTime(2026, 8, 31));
      expect(events[1].title, '出差');
      expect(events[1].start, DateTime(2026, 9, 1));
    });

    test('多句切分', () async {
      final events = await parseOne('明天开会。后天出差');
      expect(events, hasLength(2));
      expect(events[0].start, DateTime(2026, 8, 30));
      expect(events[1].start, DateTime(2026, 8, 31));
    });

    test('零命中抛 LocalParseException', () {
      expect(
        parseOne('随便写点什么'),
        throwsA(isA<LocalParseException>()),
      );
    });
  });

  group('置信度（文档 5.6 节）', () {
    test('全命中 = 1.0', () async {
      final e = (await parseOne('3月15日下午2点去上海虹桥机场出差')).single;
      expect(e.confidence, 1.0);
    });

    test('仅关键词 = 0.3（低置信）', () async {
      final e = (await parseOne('记得交房租')).single;
      expect(e.confidence, 0.3);
      expect(e.lowConfidence, isTrue);
    });
  });
}
