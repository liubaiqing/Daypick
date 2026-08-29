// 本地 OCR 集成测试（真实引擎 + RapidOCR PP-OCRv5 模型）：
// 用 TextPainter 合成含中文的图片 → 本地离线识别 → 断言识别结果包含关键文字。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calendar/app/app.dart';
import 'package:calendar/data/ocr/ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<Uint8List> _renderTextImage(String text) async {
  final width = 800;
  final height = 160;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // 先铺白色背景（toImage 默认透明背景，检测模型对透明图处理差）
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFFFFFFFF),
  );
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 36,
        color: Color(0xFF000000),
        fontWeight: FontWeight.w400,
        // 必须指定应用打包的中文字体：测试环境默认字体无中文字形（豆腐块）
        fontFamily: 'HarmonyOS Sans SC',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, const Offset(32, 60));
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RapidOCR 本地离线识别中文合成图片', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalendarApp()));
    await tester.pump(const Duration(milliseconds: 300));

    final bytes = await _renderTextImage('明天下午3点开会');

    // 真实 ONNX 推理（首次加载模型较慢）
    final text = await OcrService().recognizeBytes(bytes);

    // PP-OCRv5 对清晰合成文字准确率高；断言宽松防抖动
    expect(text.trim(), isNotEmpty, reason: '应识别出文字，实际：$text');
    expect(
      text.contains('开会') || text.contains('明天'),
      isTrue,
      reason: '识别结果应包含关键文字，实际：$text',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
