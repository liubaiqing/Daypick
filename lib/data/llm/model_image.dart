import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import '../../core/errors.dart';

/// 本地和在线共用：最长边2000px，首帧转PNG，不运行OCR。
Future<String> prepareModelImage(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    final bytes = await File(path).readAsBytes();
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final ratio = longest > 2000 ? 2000 / longest : 1.0;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * ratio).round().clamp(1, 2000),
      targetHeight: (descriptor.height * ratio).round().clamp(1, 2000),
    );
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const ImageParseException('图片无法解码');
    return base64Encode(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
  } catch (_) {
    throw const ImageParseException('图片无法读取或解码，请检查文件后重试');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
