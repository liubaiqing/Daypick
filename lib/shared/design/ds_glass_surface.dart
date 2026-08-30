/// Apple Liquid Glass 风格动态材质容器：背景折射与散射、环境色反射、
/// 多层透镜边缘和指针高光共同构成“液态玻璃”，而非高白度磨砂卡片。
/// 轻玻璃用于输入条/下拉浮层，强玻璃用于居中弹窗；浅色/深色主题
/// 退化为原有普通 Container。
library;

import 'dart:ui';

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
    final materialColor =
        isDialog ? tokens.dialogBackground : tokens.glassSurface;
    final baseColor = widget.tint == null
        ? materialColor
        : Color.alphaBlend(widget.tint!, materialColor);
    final blurSigma =
        isDialog ? tokens.glassDialogBlurSigma : tokens.glassBlurSigma;
    final shadowColor =
        isDialog ? tokens.panelShadowColor : tokens.cardShadowColor;

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
              final refractScale = isDialog ? 1.008 : 1.018;
              final lensMatrix = Matrix4.identity()
                ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
                ..scaleByDouble(refractScale, refractScale, 1, 1)
                ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
              final filter = ImageFilter.compose(
                outer: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                inner: ImageFilter.matrix(
                  lensMatrix.storage,
                  filterQuality: FilterQuality.medium,
                ),
              );
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.accentBlue.withValues(
                        alpha: isDialog ? 0.06 : 0.1,
                      ),
                      offset: const Offset(-4, -2),
                      blurRadius: isDialog ? 30 : 22,
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: shadowColor,
                      offset: Offset(0, isDialog ? 16 : 9),
                      blurRadius: isDialog ? 44 : 26,
                      spreadRadius: isDialog ? -9 : -5,
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
                              Color.alphaBlend(
                                tokens.glassTintEnd,
                                baseColor,
                              ),
                            ],
                            begin: const Alignment(-1, -1),
                            end: const Alignment(0.75, 0.8),
                          ),
                          border: widget.border ??
                              Border.all(
                                color: tokens.glassBorder,
                                width: 0.8,
                              ),
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

/// 多层透镜边缘：亮边、暗部折射、轻微色散与跟随指针的镜面高光。
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
    final rrect = radius.toRRect(rect).deflate(0.75);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDialog ? 1.2 : 1.5
      ..shader = const SweepGradient(
        center: Alignment.center,
        startAngle: -0.8,
        endAngle: 5.5,
        colors: [
          Color(0xE6FFFFFF),
          Color(0x553EC8FF),
          Color(0x24FFFFFF),
          Color(0x443F2C76),
          Color(0x30182736),
          Color(0xCCFFFFFF),
          Color(0xE6FFFFFF),
        ],
        stops: [0, 0.16, 0.34, 0.52, 0.7, 0.88, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);

    final innerRect = rect.deflate(isDialog ? 2.2 : 2.5);
    final innerRRect = radius.toRRect(innerRect);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDialog ? 1.6 : 2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x8FFFFFFF),
          Color(0x10FFFFFF),
          Color(0x26182736),
        ],
        stops: [0, 0.48, 1],
      ).createShader(innerRect);
    canvas.drawRRect(innerRRect, innerPaint);

    final point = pointer;
    if (hovered && point != null) {
      canvas.save();
      canvas.clipRRect(radius.toRRect(rect));
      final highlightRadius = isDialog ? 150.0 : 95.0;
      final highlightRect = Rect.fromCircle(
        center: point,
        radius: highlightRadius,
      );
      final highlightPaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isDialog ? 0.13 : 0.24),
            const Color(0x163EC8FF),
            Colors.transparent,
          ],
          stops: const [0, 0.34, 1],
        ).createShader(highlightRect);
      canvas.drawCircle(point, highlightRadius, highlightPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.pointer != pointer ||
      oldDelegate.hovered != hovered ||
      oldDelegate.isDialog != isDialog;
}
