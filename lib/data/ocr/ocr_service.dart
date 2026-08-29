/// OCR 服务（文档 7 章）：图片预处理（等比缩放 ≤ 2000px）+
/// RapidOCR（ONNX Runtime + PaddleOCR PP-OCRv5 模型，经 flutter_onnx_ocr 封装）。
/// 跨平台本地离线：Windows/macOS 已验证，Android/iOS 随 onnxruntime_v2 全平台支持扩展。
/// 注意：非 WinRT API，无需 MSIX 包身份，普通 exe 即可使用。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnx_ocr/flutter_onnx_ocr.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';

class OcrService {
  OcrService();

  /// 模型资源路径（插件自动从 assets 复制到临时目录加载）
  static const String _detModel = 'assets/models/ch_PP-OCRv5_det_mobile.onnx';
  static const String _recModel = 'assets/models/ch_PP-OCRv5_rec_mobile.onnx';
  static const String _dictPath = 'assets/models/ch_ppocrv5_dict.txt';

  Future<void>? _initFuture;

  /// 懒初始化（首次识别时加载模型，约 1–2 秒）
  Future<void> _ensureInitialized() {
    return _initFuture ??= FlutterOnnxOcr.initialize(
      detectionModelPath: _detModel,
      recognitionModelPath: _recModel,
      characterDictPath: _dictPath,
    ).catchError((Object e) {
      _initFuture = null; // 初始化失败允许重试
      throw OcrException('OCR 模型加载失败：$e');
    });
  }

  /// 识别本地图片文件（png/jpg/bmp），返回纯文本；失败抛 [OcrException]。
  Future<String> recognizeFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw OcrException('图片文件不存在：$path');
    }
    return recognizeBytes(await file.readAsBytes());
  }

  /// 识别图片字节；先等比缩放（文档 7.2 节），再交 RapidOCR 推理。
  Future<String> recognizeBytes(Uint8List bytes) async {
    await _ensureInitialized();
    final scaled = await _scaleImage(bytes);
    try {
      final results = await FlutterOnnxOcr.recognizeFromBytes(scaled);
      return results
          .map((r) => r.text)
          .where((t) => t.trim().isNotEmpty)
          .join('\n');
    } catch (e) {
      throw OcrException('图片识别失败：$e');
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
