import 'dart:async';

import 'package:calendar/core/errors.dart';
import 'package:calendar/data/llm/ollama_client.dart';
import 'package:calendar/data/parsers/local_model_parser.dart';
import 'package:calendar/domain/event_source_type.dart';
import 'package:calendar/domain/parsed_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeModel implements LocalModelGateway {
  Map<String, dynamic> output = {};
  final List<({String text, String? image, String system})> calls = [];
  @override
  Future<Map<String, dynamic>> generate({
    required String system,
    required String text,
    required Map<String, dynamic> schema,
    String? image,
  }) async {
    calls.add((text: text, image: image, system: system));
    return output;
  }
}

Map<String, dynamic> event({
  String? start = '2027-01-01T15:00:00',
  String? end,
  bool allDay = false,
}) => {
  'events': [
    {
      'title': '会议',
      'location': null,
      'start': start,
      'end': end,
      'all_day': allDay,
      'note': null,
    },
  ],
};

void main() {
  test('云端模型、缺失模型、错误JSON与重定向不会被本地模式接受', () async {
    for (final variant in ['cloud', 'missing', 'redirect', 'json']) {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              if (r.path.endsWith('/api/version')) {
                h.resolve(
                  Response(requestOptions: r, data: {'version': '0.34.0'}),
                );
              } else if (variant == 'cloud') {
                h.resolve(
                  Response(
                    requestOptions: r,
                    data: {
                      'remote_model': 'remote',
                      'capabilities': ['vision', 'completion'],
                    },
                  ),
                );
              } else if (variant == 'missing' || variant == 'redirect') {
                h.reject(
                  DioException(
                    requestOptions: r,
                    response: Response(
                      requestOptions: r,
                      statusCode: variant == 'missing' ? 404 : 302,
                    ),
                  ),
                );
              } else {
                h.resolve(
                  Response(
                    requestOptions: r,
                    data: {
                      'done': true,
                      'message': {'content': 'not JSON'},
                    },
                  ),
                );
              }
            },
          ),
        );
      final client = OllamaClient(const LocalModelConfig(), dio: dio);
      await expectLater(
        variant == 'cloud' || variant == 'missing'
            ? client.check()
            : client.generate(system: '', text: '', schema: eventSchema),
        throwsA(isA<LocalParseException>()),
      );
    }
  });
  test('重复文字分配必须阻断，避免重复创建独立事件', () async {
    final fake = FakeModel()
      ..output = {
        'standalone': '明天跑步',
        'assignments': [
          {'image': 1, 'text': '明天跑步'},
        ],
        'clarification': '',
      };
    await expectLater(
      LocalModelParser(fake).prepare('明天跑步', ['a.png']),
      throwsA(isA<LocalParseException>()),
    );
  });
  test('本地地址严格限制，拒绝外部、凭据、路径和重定向入口', () {
    for (final url in [
      'http://localhost:11434',
      'http://127.0.0.1:2233',
      'http://[::1]:11434/',
    ]) {
      expect(LocalModelConfig(url: url).endpoint, isA<Uri>());
    }
    for (final url in [
      'https://example.com',
      'http://127.0.0.1.evil.com',
      'http://user@localhost',
      'http://localhost/v1',
      'http://localhost?url=x',
      'file:///localhost',
      'http://192.168.1.1',
    ]) {
      expect(
        () => LocalModelConfig(url: url).endpoint,
        throwsA(isA<LocalParseException>()),
      );
    }
  });
  test('请求显式关闭思考、限制8K且图片只有一张', () async {
    late RequestOptions sent;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            sent = r;
            h.resolve(
              Response(
                requestOptions: r,
                data: {
                  'done': true,
                  'message': {'content': '{"events":[]}'},
                },
              ),
            );
          },
        ),
      );
    await OllamaClient(
      const LocalModelConfig(),
      dio: dio,
    ).generate(system: 's', text: 't', schema: eventSchema, image: 'one');
    expect(sent.data['think'], false);
    expect(sent.data['stream'], false);
    expect(sent.data['options']['num_ctx'], 8192);
    expect(sent.data['options']['presence_penalty'], 0);
    expect(sent.data['messages'][1]['images'], ['one']);
    expect(sent.followRedirects, false);
    expect(sent.data['format'], eventSchema);
  });
  test('输出截断不可误用为成功草稿', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) => h.resolve(
            Response(
              requestOptions: r,
              data: {'done': true, 'done_reason': 'length'},
            ),
          ),
        ),
      );
    expect(
      OllamaClient(
        const LocalModelConfig(),
        dio: dio,
      ).generate(system: '', text: '', schema: eventSchema),
      throwsA(isA<LocalParseException>()),
    );
  });
  test('服务启动去重，模型检查有视觉能力', () async {
    var ready = false;
    var starts = 0;
    final gate = Completer<void>();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (!ready) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            h.resolve(
              Response(
                requestOptions: r,
                data: {
                  'capabilities': ['vision', 'completion'],
                },
              ),
            );
          },
        ),
      );
    final client = OllamaClient(
      const LocalModelConfig(),
      dio: dio,
      launcher: () async {
        starts++;
        await gate.future;
        ready = true;
        return true;
      },
    );
    final a = client.check(autoStart: true);
    final b = client.check(autoStart: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    await Future.wait([a, b]);
    expect(starts, 1);
  });
  test('无视觉能力不得作为图文模型', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) => h.resolve(
            Response(
              requestOptions: r,
              data: {
                'capabilities': ['completion'],
              },
            ),
          ),
        ),
      );
    expect(
      OllamaClient(const LocalModelConfig(), dio: dio).check(),
      throwsA(isA<LocalParseException>()),
    );
  });
  test('跨年不强改，跨天不截断，单点无结束时间，统一人工核对', () async {
    final fake = FakeModel()..output = event(end: '2027-01-02T03:00:00');
    final parser = LocalModelParser(fake, now: () => DateTime(2026, 12, 31));
    final e = (await parser.parse(const LocalInput(text: '明天下午3点开会'))).single;
    expect(e.start, DateTime(2027, 1, 1, 15));
    expect(e.end, DateTime(2027, 1, 2, 3));
    expect(e.lowConfidence, true);
    expect(fake.calls.single.system, contains('2026-12-31'));
    fake.output = event();
    expect(
      (await parser.parse(const LocalInput(text: '开会'))).single.end,
      isNull,
    );
  });
  test('非法日期和倒置结束留空，不补造全天', () {
    final parser = LocalModelParser(FakeModel());
    final e = parser
        .mapEvents(
          event(start: '2026-02-30T25:00:00', allDay: true),
          const LocalInput(text: '不确定'),
        )
        .single;
    expect(e.start, isNull);
    expect(e.allDay, false);
    expect(e.hasMissingTime, true);
    final reversed = parser
        .mapEvents(
          event(end: '2026-12-31T09:00:00'),
          const LocalInput(text: ''),
        )
        .single;
    expect(reversed.end, isNull);
    expect(reversed.note, contains('核对'));
  });
  test('图片正确来源、原文不伪装OCR，空事件与格式错误保留输入', () {
    final parser = LocalModelParser(FakeModel());
    final e = parser
        .mapEvents(
          event(),
          const LocalInput(text: '改周五', path: 'C:\\a.png', imageNumber: 2),
        )
        .single;
    expect(e.sourceType, EventSourceType.image);
    expect(e.sourceText, '图片 2：a.png\n补充：改周五');
    expect(
      () => parser.mapEvents({'events': []}, const LocalInput(text: '取消')),
      throwsA(isA<LocalParseException>()),
    );
    expect(
      () => parser.mapEvents({
        'events': [1],
      }, const LocalInput(text: '')),
      throwsA(isA<LocalParseException>()),
    );
  });
  test('混合文字先分配，图片互不共享补充上下文', () async {
    final fake = FakeModel()
      ..output = {
        'standalone': '明天跑步',
        'assignments': [
          {'image': 2, 'text': '改到周五'},
        ],
        'clarification': '',
      };
    final tasks = await LocalModelParser(fake)
        .prepare('第二张改到周五，明天跑步', ['a.png', 'b.png']);
    expect(tasks.map((i) => i.text), ['', '改到周五', '明天跑步']);
    expect(tasks.map((i) => i.path), ['a.png', 'b.png', null]);
    expect(fake.calls.single.image, isNull);
    fake.output = {
      'standalone': '',
      'assignments': [],
      'clarification': '请问是哪张图片？',
    };
    expect(
      LocalModelParser(fake).prepare('改周五', ['a', 'b']),
      throwsA(isA<LocalParseException>()),
    );
  });
  test('最多两个并发，乱序完成仍按上传次序，失败任务可单独重试', () async {
    var active = 0;
    var peak = 0;
    final inputs = [
      for (var i = 1; i <= 5; i++)
        LocalInput(text: '补充$i', path: '$i.png', imageNumber: i),
    ];
    Future<List<ParsedEvent>> parse(LocalInput i) async {
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(
        Duration(milliseconds: i.imageNumber == 1 ? 30 : 2),
      );
      active--;
      if (i.imageNumber == 2) throw const LocalParseException('失败');
      return [
        ParsedEvent(
          title: '${i.imageNumber}',
          sourceType: EventSourceType.image,
          sourceText: i.text,
        ),
      ];
    }

    final result = await runLocalBatch(inputs, parse);
    expect(peak, 2);
    expect(result.events.map((e) => e.title), ['1', '3', '4', '5']);
    expect(result.failed.single.text, '补充2');
    var retryCount = 0;
    await runLocalBatch(result.failed, (i) async {
      retryCount++;
      return [];
    });
    expect(retryCount, 1);
  });
}
