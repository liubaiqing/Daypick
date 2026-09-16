// 显式启用：flutter test test/local_model_live_test.dart --dart-define=RUN_LOCAL_MODEL_TESTS=true
// 使用本机模型和临时合成图片，不访问或写入日历数据库。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calendar/data/llm/ollama_client.dart';
import 'package:calendar/data/llm/local_image.dart';
import 'package:calendar/data/parsers/local_model_parser.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '本机 Qwen：文本、独立图片、多图顺序、图文分配、无思考输出',
    () async {
      await ui.loadFontFromList(
        await File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
        fontFamily: 'LiveChinese',
      );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (r, h) {
            if (r.requestOptions.path.endsWith('/api/chat')) {
              expect((r.data['message'] as Map)['thinking'] ?? '', '');
              // ignore: avoid_print
              print('模型输出：${r.data['message']['content']}');
            }
            h.next(r);
          },
        ),
      );
      final client = OllamaClient(const LocalModelConfig(), dio: dio);
      await client.check();
      final parser = LocalModelParser(
        client,
        now: () => DateTime(2026, 9, 16, 12),
      );
      final timer = Stopwatch()..start();
      final text = await parser.parse(
        const LocalInput(text: '明天下午3点在行政楼301开会，后天上午10点在科技园面试。'),
      );
      expect(
        text.map((e) => e.start),
        containsAll([DateTime(2026, 9, 17, 15), DateTime(2026, 9, 18, 10)]),
      );
      // ignore: avoid_print
      print('首次文本 ${timer.elapsedMilliseconds}ms');
      timer.reset();
      final changed = await parser.parse(
        const LocalInput(text: '原定9月18日14:00在会议室B的会议取消，改为9月21日15:30，地点不变。'),
      );
      expect(changed.length, 1);
      expect(changed.single.start, DateTime(2026, 9, 21, 15, 30));
      expect(changed.single.location, contains('B'));
      // ignore: avoid_print
      print('预热改期 ${timer.elapsedMilliseconds}ms');
      final temp = await Directory.systemTemp.createTemp('calendar-qwen-test-');
      try {
        final paths = <String>[];
        for (var i = 1; i <= 2; i++) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)
            ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
          final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 38))
            ..pushStyle(
              ui.TextStyle(
                color: const ui.Color(0xff000000),
                fontFamily: 'LiveChinese',
              ),
            )
            ..addText(
              '人工智能讲座通知 $i\n报名截止：2026年9月18日 17:00\n讲座时间：2026年9月20日 09:00—11:00\n讲座地点：理科楼 A20$i',
            );
          final paragraph = builder.build()
            ..layout(const ui.ParagraphConstraints(width: 1050));
          canvas.drawParagraph(paragraph, const ui.Offset(20, 40));
          final picture = recorder.endRecording();
          final image = await picture.toImage(1100, 500);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${temp.path}/notice$i.png');
          await file.writeAsBytes(png!.buffer.asUint8List());
          paths.add(file.path);
          image.dispose();
          picture.dispose();
          paragraph.dispose();
        }
        timer.reset();
        final inputs = await parser.prepare(
          '第二张图片的讲座地点改为行政楼301。另外明天下午四点跑步。',
          paths,
        );
        expect(inputs.length, 3);
        expect(inputs.first.text, isEmpty);
        expect(inputs[1].text, contains('301'));
        final result = await runLocalBatch(
          inputs,
          (input) async => parser.parse(
            input,
            image: input.path == null
                ? null
                : await prepareLocalImage(input.path!),
          ),
        );
        expect(result.errors, isEmpty);
        expect(result.events.first.sourceText, startsWith('图片 1'));
        expect(result.events.last.sourceText, contains('跑步'));
        expect(
          result.events
              .where((e) => e.sourceText.startsWith('图片 1'))
              .map((e) => e.start ?? e.end),
          containsAll([DateTime(2026, 9, 18, 17), DateTime(2026, 9, 20, 9)]),
        );
        expect(
          result.events
              .where((e) => e.sourceText.startsWith('图片 2'))
              .any((e) => e.location?.contains('301') == true),
          true,
        );
        // ignore: avoid_print
        print('多图混合（含文字分配）${timer.elapsedMilliseconds}ms');
      } finally {
        // 仅删除本测试新建的临时目录。
        await temp.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LOCAL_MODEL_TESTS'),
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
