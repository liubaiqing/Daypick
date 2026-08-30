/// 无边框窗口缩放的纯几何计算。
///
/// 使用拖动开始时的窗口边界与系统级绝对光标累计位移计算目标边界，
/// 避免把 Flutter 每帧增量误当成总位移而造成窗口尺寸来回跳动。
library;

import 'dart:ui';

import 'package:window_manager/window_manager.dart';

/// 根据初始窗口边界、光标累计位移和拖动边缘计算目标窗口边界。
///
/// [minimumSize] 在几何层直接约束最小尺寸；拖动左/上边缘触及最小尺寸时，
/// 固定右/下边界，避免由系统二次纠正尺寸引发位置闪烁。
Rect calculateWindowResizeBounds({
  required Rect startBounds,
  required Offset cursorDelta,
  required ResizeEdge edge,
  required Size minimumSize,
}) {
  var left = startBounds.left;
  var top = startBounds.top;
  var right = startBounds.right;
  var bottom = startBounds.bottom;

  final movesLeft = switch (edge) {
    ResizeEdge.left || ResizeEdge.topLeft || ResizeEdge.bottomLeft => true,
    _ => false,
  };
  final movesRight = switch (edge) {
    ResizeEdge.right || ResizeEdge.topRight || ResizeEdge.bottomRight => true,
    _ => false,
  };
  final movesTop = switch (edge) {
    ResizeEdge.top || ResizeEdge.topLeft || ResizeEdge.topRight => true,
    _ => false,
  };
  final movesBottom = switch (edge) {
    ResizeEdge.bottom ||
    ResizeEdge.bottomLeft ||
    ResizeEdge.bottomRight => true,
    _ => false,
  };

  if (movesLeft) left += cursorDelta.dx;
  if (movesRight) right += cursorDelta.dx;
  if (movesTop) top += cursorDelta.dy;
  if (movesBottom) bottom += cursorDelta.dy;

  if (right - left < minimumSize.width) {
    if (movesLeft) {
      left = right - minimumSize.width;
    } else {
      right = left + minimumSize.width;
    }
  }
  if (bottom - top < minimumSize.height) {
    if (movesTop) {
      top = bottom - minimumSize.height;
    } else {
      bottom = top + minimumSize.height;
    }
  }

  return Rect.fromLTRB(left, top, right, bottom);
}
