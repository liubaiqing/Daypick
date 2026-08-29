// AiParser 单元测试（文档 15.3 节）：注入 fake LLM 网关，不发真实请求。
import 'package:calendar/core/errors.dart';
import 'package:calendar/data/llm/openai_compatible_client.dart';
import 'package:calendar/data/parsers/ai_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可编程 fake 网关
class FakeLlmGateway implements LlmGateway {
  FakeLlmGateway(this.response);

  Map<String, dynamic> response;
  LlmException? error;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> chatJson({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmChatMessage> messages,
  }) async {
    calls++;
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  final config = const AiConfig(
    baseUrl: 'https://api.deepseek.com',
    apiKey: 'sk-test',
    model: 'deepseek-chat',
  );

  AiParser parserWith(FakeLlmGateway gateway) =>
      AiParser(client: gateway, config: config);

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
    expect(
      parserWith(gateway).parse('测试'),
      throwsA(isA<AiParseException>()),
    );
  });

  test('客户端抛 LlmException（如 401）→ AiParseException 传递消息', () {
    final gateway = FakeLlmGateway({})..error = const LlmException('API Key 无效，请到设置页检查');
    expect(
      parserWith(gateway).parse('测试'),
      throwsA(
        isA<AiParseException>().having((e) => e.message, 'message', contains('API Key')),
      ),
    );
  });

  test('未配置 API Key → AiParseException 提示配置', () {
    final gateway = FakeLlmGateway({});
    final parser = AiParser(
      client: gateway,
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
}
