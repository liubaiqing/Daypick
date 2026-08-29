/// OCR 服务（文档 7 章）：图片预处理（等比缩放 ≤ 2000px）+
/// Windows.Media.Ocr（经 winrt_ocr_flutter 的 C++/WinRT 封装）。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:winrt_ocr_flutter/winrt_ocr_flutter.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';

class OcrService {
  const OcrService();

  /// 识别本地图片文件（png/jpg/bmp），返回纯文本；失败抛 [OcrException]。
  Future<String> recognizeFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw OcrException('图片文件不存在：$path');
    }
    return recognizeBytes(await file.readAsBytes());
  }

  /// 识别图片字节；先解码并按最长边缩放（文档 7.2 节），再写入临时文件交原生引擎。
  Future<String> recognizeBytes(Uint8List bytes) async {
    final scaled = await _scaleImage(bytes);

    // 插件只接受本地文件路径，写临时 PNG
    final dir = await getTemporaryDirectory();
    final tmp = File(
      '${dir.path}${Platform.pathSeparator}ocr_input_'
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tmp.writeAsBytes(scaled, flush: true);
    try {
      return await WinrtOcr.recognizeText(tmp.path);
    } on WinrtOcrException catch (e) {
      // 引擎级失败（如未安装中文语言包）
      throw OcrException(e.message);
    } finally {
      try {
        await tmp.delete();
      } catch (_) {
        // 临时文件清理失败不影响结果
      }
    }
  }

  /// 解码图片；最长边超过 [kOcrMaxImageDimension] 时等比缩放（文档 7.2 节）
  Future<Uint8List> _scaleImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final longest = image.width > image.height ? image.width : image.height;
        if (longest <= kOcrMaxImageDimension) return bytes;
        final scale = kOcrMaxImageDimension / longest;
        final w = (image.width * scale).round();
        final h = (image.height * scale).round();
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final scaledImage = await picture.toImage(w, h);
        try {
          final byteData = await scaledImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          return byteData!.buffer.asUint8List();
        } finally {
          scaledImage.dispose();
          picture.dispose();
        }
      } finally {
        image.dispose();
      }
    } catch (e) {
      throw OcrException('图片解码失败：$e');
    }
  }
}
