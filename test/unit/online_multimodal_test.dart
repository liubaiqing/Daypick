import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calendar/core/errors.dart';
import 'package:calendar/data/llm/model_image.dart';
import 'package:calendar/data/llm/openai_compatible_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同一模型支持文字、单图、多图混合消息，无模型分类', () async {
    final dio = Dio();
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'choices': [
                  {
                    'message': {'content': '{"events":[]}'},
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final client = OpenAiCompatibleClient(dio: dio);
    for (final images in <List<LlmImage>>[
      [],
      [const LlmImage(name: '1.png', base64Png: 'AAAA')],
      [
        const LlmImage(name: '1.png', base64Png: 'AAAA'),
        const LlmImage(name: '2.png', base64Png: 'BBBB'),
      ],
    ]) {
      await client.chatJson(
        baseUrl: 'https://example.invalid/v1',
        apiKey: 'test',
        model: 'my-qwen-vl',
        messages: [
          LlmChatMessage(role: 'user', content: '整理日程', images: images),
        ],
      );
    }
    expect(requests.map((r) => r.data['model']), everyElement('my-qwen-vl'));
    expect(requests.first.data['messages'][0]['content'], '整理日程');
    final parts = requests.last.data['messages'][0]['content'] as List;
    expect(
      parts
          .where((p) => p['type'] == 'image_url')
          .map((p) => p['image_url']['url']),
      ['data:image/png;base64,AAAA', 'data:image/png;base64,BBBB'],
    );
    expect(parts.first, {'type': 'text', 'text': '整理日程'});
    expect(parts[1]['text'], '图片1');
    expect(parts[3]['text'], '图片2');
    dio.close();
  });

  for (final code in [400, 413, 422]) {
    test('图文HTTP $code明确报错且不重试或降级', () async {
      final dio = Dio();
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: code),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      await expectLater(
        OpenAiCompatibleClient(dio: dio).chatJson(
          baseUrl: 'https://example.invalid/v1',
          apiKey: 'test',
          model: 'my-model',
          messages: [
            const LlmChatMessage(
              role: 'user',
              content: '解析',
              images: [LlmImage(name: 'x', base64Png: 'private-data')],
            ),
          ],
        ),
        throwsA(
          isA<LlmException>().having(
            (e) => e.message,
            'message',
            allOf(contains('图文请求'), isNot(contains('private-data'))),
          ),
        ),
      );
      expect(calls, 1);
      dio.close();
    });
  }

  test('共享图片预处理等比缩小到2000并编码PNG', () async {
    final dir = await Directory.systemTemp.createTemp('daypick-image-test-');
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFFABCDEF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final original = await picture.toImage(2400, 1200);
    final bytes = await original.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${dir.path}/test.png');
    try {
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      final encoded = await prepareModelImage(file.path);
      final png = base64Decode(encoded);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 2000);
      expect(image.height, 1000);
      image.dispose();
      codec.dispose();
      await file.writeAsString('not an image');
      await expectLater(
        prepareModelImage(file.path),
        throwsA(isA<ImageParseException>()),
      );
    } finally {
      original.dispose();
      picture.dispose();
      await dir.delete(recursive: true);
    }
  });
}
