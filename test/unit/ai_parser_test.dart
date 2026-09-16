// AiParser 单元测试（文档 15.3 节）：注入 fake LLM 网关，不发真实请求。
import 'package:calendar/core/errors.dart';
import 'package:calendar/data/llm/openai_compatible_client.dart';
import 'package:calendar/data/parsers/ai_parser.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可编程 fake 网关
class FakeLlmGateway implements LlmGateway {
  FakeLlmGateway(this.response);

  Map<String, dynamic> response;
  LlmException? error;
  int calls = 0;
  List<LlmChatMessage> lastMessages = [];

  @override
  Future<Map<String, dynamic>> chatJson({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmChatMessage> messages,
  }) async {
    calls++;
    lastMessages = messages;
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  // 固定时钟：2026-08-29 10:00（年份规则与宽松解析用例依赖）
  final now = DateTime(2026, 8, 29, 10, 0);
  final config = const AiConfig(
    baseUrl: 'https://api.deepseek.com',
    apiKey: 'sk-test',
    model: 'deepseek-chat',
  );

  AiParser parserWith(FakeLlmGateway gateway) =>
      AiParser(client: gateway, config: config, now: () => now);

  for (final text in ['', '第二张改到下午三点']) {
    test('图片及混合输入直传、来源不含二进制、图片年份不被覆盖：$text', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {'title': '通知', 'start': '2027-01-02T15:00:00'},
          {'title': '提交', 'end': '2027-01-03T20:00:00'},
        ],
      });
      final images = [
        const LlmImage(name: '通知.png', base64Png: 'first-image-data'),
        const LlmImage(name: '附件.png', base64Png: 'second-image-data'),
      ];
      final events = await parserWith(gateway).parse(text, images: images);
      expect(gateway.lastMessages.last.images, images);
      expect(events, hasLength(2));
      expect(events.first.start!.year, 2027);
      expect(events.last.start, isNull);
      expect(events.last.end!.year, 2027);
      expect(events.first.sourceType, EventSourceType.image);
      expect(events.first.sourceText, contains('图片1：通知.png'));
      expect(events.first.sourceText, contains('图片2：附件.png'));
      expect(events.first.sourceText, isNot(contains('image-data')));
      if (text.isNotEmpty) expect(events.first.sourceText, contains(text));
    });
  }

  test('图文归属不明确时返回澄清而非猜测草稿', () async {
    final gateway = FakeLlmGateway({'clarification': '修改哪一张？', 'events': []});
    await expectLater(
      parserWith(gateway).parse(
        '改到九点',
        images: [const LlmImage(name: '图片.png', base64Png: 'data')],
      ),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.message,
          'message',
          contains('请澄清'),
        ),
      ),
    );
  });

  test('空输入不发请求', () async {
    final gateway = FakeLlmGateway({});
    await expectLater(
      parserWith(gateway).parse(''),
      throwsA(isA<AiParseException>()),
    );
    expect(gateway.calls, 0);
  });

  test('合法返回 → 结构化草稿', () async {
    final gateway = FakeLlmGateway({
      'events': [
        {
          'title': '去上海出差',
          'location': '上海',
          'start': '2026-09-15T09:00:00',
          'end': '2026-09-15T17:00:00',
          'all_day': false,
          'note': null,
        },
      ],
    });
    final events = await parserWith(gateway).parse('9月15日去上海出差');
    expect(events, hasLength(1));
    expect(events.first.title, '去上海出差');
    expect(events.first.location, '上海');
    expect(events.first.start, DateTime(2026, 9, 15, 9));
    expect(events.first.end, DateTime(2026, 9, 15, 17));
    expect(events.first.hasMissingTime, isFalse);
    expect(events.first.lowConfidence, isFalse);
    expect(gateway.calls, 1);
  });

  test('全天事件：start 归零、end 置空', () async {
    final gateway = FakeLlmGateway({
      'events': [
        {
          'title': '生日',
          'location': null,
          'start': '2026-12-25T14:30:00',
          'end': '2026-12-25T20:00:00',
          'all_day': true,
          'note': null,
        },
      ],
    });
    final e = (await parserWith(gateway).parse('圣诞节')).single;
    expect(e.allDay, isTrue);
    expect(e.start, DateTime(2026, 12, 25));
    expect(e.end, isNull);
  });

  test('跨天区间：结束加一天', () async {
    final gateway = FakeLlmGateway({
      'events': [
        {
          'title': '值班',
          'location': null,
          'start': '2026-08-29T23:00:00',
          'end': '2026-08-30T01:00:00',
          'all_day': false,
          'note': null,
        },
      ],
    });
    final e = (await parserWith(gateway).parse('值班')).single;
    expect(e.start, DateTime(2026, 8, 29, 23));
    expect(e.end, DateTime(2026, 8, 30, 1));
  });

  test('start 缺失 → missing 标记 time', () async {
    final gateway = FakeLlmGateway({
      'events': [
        {
          'title': '交房租',
          'location': null,
          'start': null,
          'end': null,
          'all_day': false,
          'note': null,
        },
      ],
    });
    final e = (await parserWith(gateway).parse('交房租')).single;
    expect(e.hasMissingTime, isTrue);
    expect(e.start, isNull);
  });

  test('空标题条目被丢弃', () async {
    final gateway = FakeLlmGateway({
      'events': [
        {
          'title': '  ',
          'location': null,
          'start': null,
          'end': null,
          'all_day': false,
          'note': null,
        },
        {
          'title': '有效事件',
          'location': '公司',
          'start': '2026-09-01T10:00:00',
          'end': null,
          'all_day': false,
          'note': null,
        },
      ],
    });
    final events = await parserWith(gateway).parse('测试');
    expect(events, hasLength(1));
    expect(events.single.title, '有效事件');
  });

  test('events 为空 → AiParseException', () {
    final gateway = FakeLlmGateway({'events': []});
    expect(parserWith(gateway).parse('测试'), throwsA(isA<AiParseException>()));
  });

  test('客户端抛 LlmException（如 401）→ AiParseException 传递消息', () {
    final gateway = FakeLlmGateway({})
      ..error = const LlmException('API Key 无效，请到设置页检查');
    expect(
      parserWith(gateway).parse('测试'),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.message,
          'message',
          contains('API Key'),
        ),
      ),
    );
  });

  test('未配置 API Key → AiParseException 提示配置', () {
    final gateway = FakeLlmGateway({});
    final parser = AiParser(
      client: gateway,
      now: () => now,
      config: const AiConfig(
        baseUrl: 'https://api.deepseek.com',
        apiKey: '',
        model: 'deepseek-chat',
      ),
    );
    expect(
      parser.parse('测试'),
      throwsA(
        isA<AiParseException>().having(
          (e) => e.message,
          'message',
          contains('API Key'),
        ),
      ),
    );
  });

  group('年份缺省规则（无年份默认当前系统年，与本地模式一致）', () {
    test('用户文本无年份 + AI 返回错误年份 → 强制当前年', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '出差',
            'location': null,
            'start': '2027-03-15T14:00:00', // 模型猜测了明年
            'end': null,
            'all_day': false,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('3月15日下午2点出差')).single;
      expect(e.start, DateTime(2026, 3, 15, 14)); // 系统年 2026
    });

    test('用户文本无年份 + AI 返回缺年份格式 → 宽松解析补当前年', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '开会',
            'location': null,
            'start': '09-15T09:00:00', // 缺年份的 ISO 片段
            'end': null,
            'all_day': false,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('9月15日上午9点开会')).single;
      expect(e.start, DateTime(2026, 9, 15, 9));
    });

    test('用户文本含显式年份 → 保持 AI 返回的年份', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '出差',
            'location': null,
            'start': '2027-03-15T09:00:00',
            'end': null,
            'all_day': false,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('2027年3月15日出差')).single;
      expect(e.start, DateTime(2027, 3, 15, 9));
    });

    test('end 同样应用年份规则（跨天保留月日）', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '值班',
            'location': null,
            'start': '2027-08-29T23:00:00',
            'end': '2027-08-30T01:00:00',
            'all_day': false,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('8月29日晚上11点值班')).single;
      expect(e.start, DateTime(2026, 8, 29, 23));
      expect(e.end, DateTime(2026, 8, 30, 1));
    });

    test('仅提供日：AI 返回缺年月格式 → 补当前年月', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '开会',
            'location': null,
            'start': '15T14:00:00', // 仅日+时间
            'end': null,
            'all_day': false,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('15号下午2点开会')).single;
      expect(e.start, DateTime(2026, 8, 15, 14));
    });

    test('仅提供日：纯数字（无时间）→ 补当前年月', () async {
      final gateway = FakeLlmGateway({
        'events': [
          {
            'title': '体检',
            'location': null,
            'start': '31',
            'end': null,
            'all_day': true,
            'note': null,
          },
        ],
      });
      final e = (await parserWith(gateway).parse('31号体检')).single;
      expect(e.start, DateTime(2026, 8, 31));
      expect(e.allDay, isTrue);
    });
  });
}
