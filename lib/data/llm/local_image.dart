import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import '../../core/errors.dart';

Future<String> prepareLocalImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  ui.Codec? codec;
  ui.Image? image;
  try {
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
    if (png == null) throw const LocalParseException('图片无法解码');
    return base64Encode(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}
