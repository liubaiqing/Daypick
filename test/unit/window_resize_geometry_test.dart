import 'dart:ui';

import 'package:calendar/features/shell/window_resize_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  const minimum = Size(900, 600);
  const start = Rect.fromLTWH(100, 80, 1200, 800);

  test('右下角使用累计光标位移同时改变宽高', () {
    final result = calculateWindowResizeBounds(
      startBounds: start,
      cursorDelta: const Offset(160, 90),
      edge: ResizeEdge.bottomRight,
      minimumSize: minimum,
    );

    expect(result, const Rect.fromLTWH(100, 80, 1360, 890));
  });

  test('左上角移动窗口原点并保持右下锚点固定', () {
    final result = calculateWindowResizeBounds(
      startBounds: start,
      cursorDelta: const Offset(-120, -60),
      edge: ResizeEdge.topLeft,
      minimumSize: minimum,
    );

    expect(result, const Rect.fromLTWH(-20, 20, 1320, 860));
    expect(result.bottomRight, start.bottomRight);
  });

  test('拖动左上边缘超过最小尺寸时固定右下锚点', () {
    final result = calculateWindowResizeBounds(
      startBounds: start,
      cursorDelta: const Offset(600, 500),
      edge: ResizeEdge.topLeft,
      minimumSize: minimum,
    );

    expect(result.size, minimum);
    expect(result.bottomRight, start.bottomRight);
  });

  test('拖动右下边缘超过最小尺寸时固定左上锚点', () {
    final result = calculateWindowResizeBounds(
      startBounds: start,
      cursorDelta: const Offset(-600, -500),
      edge: ResizeEdge.bottomRight,
      minimumSize: minimum,
    );

    expect(result, const Rect.fromLTWH(100, 80, 900, 600));
  });

  test('单边拖动不改变正交方向尺寸', () {
    final result = calculateWindowResizeBounds(
      startBounds: start,
      cursorDelta: const Offset(140, 300),
      edge: ResizeEdge.right,
      minimumSize: minimum,
    );

    expect(result, const Rect.fromLTWH(100, 80, 1340, 800));
  });
}
