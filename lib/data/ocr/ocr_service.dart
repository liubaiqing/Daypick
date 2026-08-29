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

/// OCR 结果后处理（纯函数，便于单测）：
/// 1) 按阅读顺序（上→下、左→右）排序，y 中心相近的相邻框合并为一行；
/// 2) 折行合并：排版折行的长行（宽高比 ≥ [kFoldRatio]）若不以句末标点结尾，
///    视为被 UI 换行截断，与下一行拼接，恢复完整语义句。
List<OcrResult> mergeOcrResults(List<OcrResult> results) {
  if (results.isEmpty) return results;

  double centerY(OcrResult r) =>
      r.box.map((p) => p.dy).reduce((a, b) => a + b) / r.box.length;
  double centerX(OcrResult r) =>
      r.box.map((p) => p.dx).reduce((a, b) => a + b) / r.box.length;
  double height(OcrResult r) {
    final ys = r.box.map((p) => p.dy).toList();
    return ys.reduce((a, b) => a > b ? a : b) -
        ys.reduce((a, b) => a < b ? a : b);
  }

  double width(OcrResult r) {
    final xs = r.box.map((p) => p.dx).toList();
    return xs.reduce((a, b) => a > b ? a : b) -
        xs.reduce((a, b) => a < b ? a : b);
  }

  // 同行容差：两框行高较小者的一半
  double rowTolerance(OcrResult a, OcrResult b) {
    final h = height(a) < height(b) ? height(a) : height(b);
    return h * 0.5;
  }

  String joinText(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final aAscii = RegExp(r'[A-Za-z0-9]').hasMatch(a[a.length - 1]);
    final bAscii = RegExp(r'[A-Za-z0-9]').hasMatch(b[0]);
    return a + (aAscii && bAscii ? ' ' : '') + b;
  }

  final sorted = [...results]..sort((a, b) {
      final ay = centerY(a);
      final by = centerY(b);
      if ((ay - by).abs() < rowTolerance(a, b)) {
        return centerX(a).compareTo(centerX(b)); // 同一行按 x 排序
      }
      return ay.compareTo(by); // 不同行按 y 排序
    });

  // ---- 第一步：同一物理行相邻框合并 ----
  final merged = <OcrResult>[];
  for (final r in sorted) {
    if (merged.isEmpty) {
      merged.add(r);
      continue;
    }
    final last = merged.last;
    if ((centerY(last) - centerY(r)).abs() < rowTolerance(last, r)) {
      merged[merged.length - 1] = OcrResult(
        text: joinText(last.text, r.text),
        confidence: (last.confidence + r.confidence) / 2,
        box: [...last.box, ...r.box],
      );
    } else {
      merged.add(r);
    }
  }

  // ---- 第二步：折行合并（长行被换行截断 → 与下一行拼接）----
  // 折行判断只基于"最后一段框"的宽高比（并集框高会随合并行数累积而失真）
  bool isFoldLine(OcrResult r) => width(r) / height(r) >= kFoldRatio;

  bool endsWithSentenceBoundary(String s) {
    if (s.isEmpty) return true;
    const boundaries = '。！？；：、）】」…"\'';
    return boundaries.contains(s[s.length - 1]);
  }

  final rows = <({OcrResult result, bool foldable})>[
    for (final r in merged) (result: r, foldable: isFoldLine(r)),
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < rows.length - 1; i++) {
      final cur = rows[i];
      if (cur.foldable && !endsWithSentenceBoundary(cur.result.text)) {
        final next = rows[i + 1];
        rows[i] = (
          result: OcrResult(
            text: cur.result.text + next.result.text,
            confidence: (cur.result.confidence + next.result.confidence) / 2,
            box: [...cur.result.box, ...next.result.box],
          ),
          // 是否继续折行：取决于被拼入段是否也是长行
          foldable: isFoldLine(next.result),
        );
        rows.removeAt(i + 1);
        changed = true;
        break; // 合并后重新扫描
      }
    }
  }
  return [for (final r in rows) r.result];
}

/// 折行合并阈值：行宽/行高 ≥ 8（约 8 个汉字以上视为满行折行）
const double kFoldRatio = 8;

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

  /// 识别图片字节；先等比缩放（文档 7.2 节），再交 RapidOCR 推理，
  /// 最后按阅读顺序排序并合并同行片段，避免长行被检测框拆碎。
  Future<String> recognizeBytes(Uint8List bytes) async {
    await _ensureInitialized();
    final scaled = await _scaleImage(bytes);
    try {
      final results = await FlutterOnnxOcr.recognizeFromBytes(scaled);
      final merged = mergeOcrResults(results);
      return merged
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
