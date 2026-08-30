/// Apple Liquid Glass 风格动态材质容器：背景折射与散射、环境色反射、
/// 多层透镜边缘和指针高光共同构成“液态玻璃”，而非高白度磨砂卡片。
/// 轻玻璃用于输入条/下拉浮层，强玻璃用于居中弹窗；浅色/深色主题
/// 退化为原有普通 Container。
library;

import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

enum DSGlassSurfaceKind { floating, dialog }

class DSGlassSurface extends StatefulWidget {
  const DSGlassSurface({
    super.key,
    required this.child,
    this.width,
    this.constraints,
    this.borderRadius,
    this.border,
    this.fallbackColor,
    this.fallbackShadowColor,
    this.fallbackShadow = true,
    this.kind = DSGlassSurfaceKind.dialog,
    this.tint,
  });

  final Widget child;
  final double? width;
  final BoxConstraints? constraints;
  final BorderRadius? borderRadius;
  final Border? border;
  final DSGlassSurfaceKind kind;
  final Color? fallbackColor;
  final Color? fallbackShadowColor;
  final bool fallbackShadow;

  /// 可选强调色着色（对应 Liquid Glass tint）；透明度由调用方控制。
  final Color? tint;

  @override
  State<DSGlassSurface> createState() => _DSGlassSurfaceState();
}

class _DSGlassSurfaceState extends State<DSGlassSurface> {
  Offset? _pointer;
  bool _hovered = false;
  bool _pressed = false;

  void _updatePointer(PointerEvent event) {
    setState(() {
      _pointer = event.localPosition;
      _hovered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final isGlass = tokens.glassBlurSigma > 0;
    final defaultRadius = isGlass && widget.kind == DSGlassSurfaceKind.dialog
        ? kRadiusLiquidDialog
        : kRadiusPanel;
    final radius = widget.borderRadius ?? BorderRadius.circular(defaultRadius);

    Widget surface = isGlass
        ? _buildLiquidGlass(tokens, radius)
        : _buildFallback(tokens, radius);

    if (widget.constraints != null && widget.width != null) {
      surface = ConstrainedBox(
        constraints: widget.constraints!,
        child: SizedBox(width: widget.width, child: surface),
      );
    } else if (widget.constraints != null) {
      surface = ConstrainedBox(
        constraints: widget.constraints!,
        child: surface,
      );
    } else if (widget.width != null) {
      surface = SizedBox(width: widget.width, child: surface);
    }
    return surface;
  }

  Widget _buildFallback(DSTokens tokens, BorderRadius radius) {
    return Container(
      decoration: BoxDecoration(
        color: widget.fallbackColor ?? tokens.dialogBackground,
        borderRadius: radius,
        border: widget.border,
        boxShadow: widget.fallbackShadow
            ? [
                BoxShadow(
                  color: widget.fallbackShadowColor ?? tokens.panelShadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );
  }

  Widget _buildLiquidGlass(DSTokens tokens, BorderRadius radius) {
    final isDialog = widget.kind == DSGlassSurfaceKind.dialog;
    final materialColor = isDialog
        ? tokens.dialogBackground
        : tokens.glassSurface;
    final baseColor = widget.tint == null
        ? materialColor
        : Color.alphaBlend(widget.tint!, materialColor);
    final blurSigma = isDialog
        ? tokens.glassDialogBlurSigma
        : tokens.glassBlurSigma;
    final shadowColor = isDialog
        ? tokens.panelShadowColor
        : tokens.cardShadowColor;

    return MouseRegion(
      onEnter: (event) => _updatePointer(event),
      onHover: _updatePointer,
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _updatePointer(event);
          if (!isDialog) setState(() => _pressed = true);
        },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.988 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.hasBoundedWidth ? constraints.maxWidth : 0,
                constraints.hasBoundedHeight ? constraints.maxHeight : 0,
              );
              final isCompactControl =
                  !isDialog &&
                  size.shortestSide <= 48 &&
                  size.width <= size.height * 1.5;
              final refractScale = isDialog ? 1.008 : 1.018;
              final lensMatrix = Matrix4.identity()
                ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
                ..scaleByDouble(refractScale, refractScale, 1, 1)
                ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
              final filter = ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                inner: ImageFilter.matrix(
                  lensMatrix.storage,
                  filterQuality: FilterQuality.medium,
                ),
              );
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    if (isDialog)
                      BoxShadow(
                        color: tokens.accentBlue.withValues(alpha: 0.025),
                        offset: const Offset(-4, -2),
                        blurRadius: 30,
                        spreadRadius: -5,
                      ),
                    BoxShadow(
                      color: isCompactControl
                          ? shadowColor.withValues(alpha: 0.1)
                          : shadowColor,
                      offset: Offset(
                        0,
                        isDialog ? 16 : (isCompactControl ? 4 : 9),
                      ),
                      blurRadius: isDialog ? 44 : (isCompactControl ? 10 : 26),
                      spreadRadius: isDialog
                          ? -9
                          : (isCompactControl ? -2 : -5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: filter,
                    child: CustomPaint(
                      foregroundPainter: _LiquidGlassPainter(
                        radius: radius,
                        pointer: _pointer,
                        hovered: _hovered,
                        isDialog: isDialog,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            colors: [
                              Color.alphaBlend(
                                tokens.glassTintStart,
                                baseColor,
                              ),
                              Color.alphaBlend(tokens.glassTintEnd, baseColor),
                            ],
                            begin: const Alignment(-1, -1),
                            end: const Alignment(0.75, 0.8),
                          ),
                          border: widget.border,
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 连续弧面透镜边缘：宽边缘带负责圆润曲率，柔化内缘和极细外高光
/// 负责玻璃边界，避免用彩色硬描边模拟反射。
class _LiquidGlassPainter extends CustomPainter {
  const _LiquidGlassPainter({
    required this.radius,
    required this.pointer,
    required this.hovered,
    required this.isDialog,
  });

  final BorderRadius radius;
  final Offset? pointer;
  final bool hovered;
  final bool isDialog;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outerRRect = radius.toRRect(rect).deflate(0.55);
    final desiredDepth = size.shortestSide * (isDialog ? 0.035 : 0.11);
    final maximumDepth = math.max(0.75, size.shortestSide / 2 - 0.75);
    final edgeDepth = math.min(
      desiredDepth.clamp(isDialog ? 7.0 : 4.0, isDialog ? 13.0 : 9.0),
      maximumDepth,
    );
    final innerRRect = outerRRect.deflate(edgeDepth);
    final edgeBand = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outerRRect)
      ..addRRect(innerRRect);

    canvas.save();
    canvas.clipRRect(outerRRect);

    // 先铺一层低强度、覆盖整面的环境反射，让宽边缘不是独立色环。
    final ambientGlaze = Paint()
      ..blendMode = BlendMode.screen
      ..shader = const RadialGradient(
        center: Alignment(-0.55, -0.7),
        radius: 1.25,
        colors: [Color(0x28FFFFFF), Color(0x08FFFFFF), Colors.transparent],
        stops: [0, 0.48, 1],
      ).createShader(rect);
    canvas.drawRect(rect, ambientGlaze);

    if (isDialog) {
      // 强玻璃只允许一个清晰轮廓。宽反射使用模糊描边向内自然衰减，
      // 不再绘制独立 innerRRect，避免视觉上形成“玻璃套玻璃”。
      final featheredRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2)
        ..shader = const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.8, 1),
          colors: [
            Color(0x58FFFFFF),
            Color(0x20EAF7FF),
            Color(0x08FFFFFF),
            Color(0x2CFFF8E8),
          ],
          stops: [0, 0.34, 0.7, 1],
        ).createShader(rect);
      canvas.drawRRect(outerRRect.deflate(4), featheredRimPaint);
    } else {
      // 轻玻璃控件保留较集中的弧面与内缘焦散，以强化小尺寸反馈。
      final softBandPaint = Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.1)
        ..shader = const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.8, 1),
          colors: [
            Color(0x70FFFFFF),
            Color(0x2EFFFFFF),
            Color(0x0FFFFFFF),
            Color(0x3AFFF8E8),
          ],
          stops: [0, 0.32, 0.68, 1],
        ).createShader(rect);
      canvas.drawPath(edgeBand, softBandPaint);

      final lensBandPaint = Paint()
        ..shader = const SweepGradient(
          center: Alignment.center,
          startAngle: -0.7,
          endAngle: 5.58,
          colors: [
            Color(0x55FFFFFF),
            Color(0x24EAF7FF),
            Color(0x0AFFFFFF),
            Color(0x1217202B),
            Color(0x22FFF7E5),
            Color(0x4DFFFFFF),
            Color(0x55FFFFFF),
          ],
          stops: [0, 0.18, 0.38, 0.58, 0.76, 0.9, 1],
        ).createShader(rect);
      canvas.drawPath(edgeBand, lensBandPaint);

      final innerCausticPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1)
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x52FFFFFF),
            Color(0x0AFFFFFF),
            Color(0x1817202B),
            Color(0x3DFFFFFF),
          ],
          stops: [0, 0.42, 0.72, 1],
        ).createShader(rect);
      canvas.drawRRect(innerRRect, innerCausticPaint);
    }

    final point = pointer;
    if (hovered && point != null) {
      final highlightRadius = isDialog ? 150.0 : 95.0;
      final highlightRect = Rect.fromCircle(
        center: point,
        radius: highlightRadius,
      );
      final highlightPaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isDialog ? 0.1 : 0.18),
            const Color(0x0CEAF7FF),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ).createShader(highlightRect);
      canvas.drawCircle(point, highlightRadius, highlightPaint);
    }

    canvas.restore();

    // 最外侧仅保留中性色、亚像素级高光，明确轮廓但不形成硬色环。
    final outerHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xE0FFFFFF),
          Color(0x66FFFFFF),
          Color(0x2417202B),
          Color(0xB8FFFFFF),
        ],
        stops: [0, 0.42, 0.72, 1],
      ).createShader(rect);
    canvas.drawRRect(outerRRect, outerHighlightPaint);
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.pointer != pointer ||
      oldDelegate.hovered != hovered ||
      oldDelegate.isDialog != isDialog;
}
