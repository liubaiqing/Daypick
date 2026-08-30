/// 毛玻璃容器（文档 9.6 节 DSGlassSurface / 9.4.2 节 HIG Materials）：
/// `BackdropFilter`（blur 20 + 饱和度补偿 1.8）+ **半透明白渐变着色**（左上高光
/// 白 0.4 → 右下透明，模拟玻璃反光）+ **渐变边缘描边**（白 0.5 → 白 0.12，
/// 模拟玻璃边缘反射）+ hairline 底描边；圆角裁剪保证模糊只作用于卡片区域。
/// 仅毛玻璃主题（`DSTokens.glass`）启用，浅色/深色主题下退化为普通 Container。
///
/// 实现参考：devgex.com/zh-CN/article/00042834（ClipRect 裁剪与模糊分层）、
/// juejin.cn/post/7425527459683860491（渐变着色/渐变边框/阴影 spreadRadius=-1）。
///
/// 使用范围（文档 9.5 节）：仅窗口主背景、卡片/输入条、弹层三处；
/// 禁止在月视图网格、列表行等高频重绘区域使用（性能）。
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

class DSGlassSurface extends StatelessWidget {
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
  });

  final Widget child;

  /// 显式宽度（如弹窗 560）
  final double? width;

  /// 尺寸约束（如弹窗最大高度）
  final BoxConstraints? constraints;

  final BorderRadius? borderRadius;
  final Border? border;

  /// 非毛玻璃主题下的背景色（默认弹层级；输入条等卡片场景传 cardBackground）
  final Color? fallbackColor;

  /// 非毛玻璃主题下的投影色（默认弹层投影；输入条传卡片投影）
  final Color? fallbackShadowColor;

  /// 非毛玻璃主题是否渲染投影（分区卡片等无投影场景传 false）
  final bool fallbackShadow;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final isGlass = tokens.glassBlurSigma > 0;
    final radius = borderRadius ?? BorderRadius.circular(kRadiusPanel);

    Widget surface;
    if (!isGlass) {
      // 浅色/深色主题：退化为普通容器（无模糊、无 hairline）
      surface = Container(
        decoration: BoxDecoration(
          color: fallbackColor ?? tokens.dialogBackground,
          borderRadius: radius,
          border: border,
          boxShadow: fallbackShadow
              ? [
                  BoxShadow(
                    color: fallbackShadowColor ?? tokens.panelShadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: child,
      );
    } else {
      // 毛玻璃（教程参数）：
      // 1) ClipRRect 裁剪模糊只作用于圆角卡片区域（devgex 要点）
      // 2) BackdropFilter 高斯模糊背景
      // 3) 渐变着色模拟玻璃反光 + 阴影 spreadRadius=-1（juejin 要点）
      // 4) 渐变边缘描边模拟玻璃边缘反射（juejin 点睛之笔）
      // 注意：不做 ColorFiltered 饱和度补偿——它会作用于容器内所有
      // 前景内容（按钮/开关/文字），把强调色重新拉饱和（刺眼根因）。
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma,
            sigmaY: tokens.glassBlurSigma,
          ),
          child: CustomPaint(
            painter: _GlassEdgePainter(
              radius: radius,
              start: tokens.glassEdgeStart,
              end: tokens.glassEdgeEnd,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                // 玻璃反光渐变：左上高光 → 右下透明
                gradient: LinearGradient(
                  colors: [tokens.glassTintStart, tokens.glassTintEnd],
                  begin: const Alignment(-1, -1),
                  end: const Alignment(0.4, 0.6),
                ),
                border: border ??
                    Border.all(color: tokens.glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: tokens.panelShadowColor,
                    offset: const Offset(0, 1),
                    blurRadius: 24,
                    // 玻璃阴影：外扩为负，贴合边缘（juejin 要点）
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    if (constraints != null && width != null) {
      return ConstrainedBox(
        constraints: constraints!,
        child: SizedBox(width: width, child: surface),
      );
    }
    if (constraints != null) {
      return ConstrainedBox(constraints: constraints!, child: surface);
    }
    if (width != null) {
      return SizedBox(width: width, child: surface);
    }
    return surface;
  }
}

/// 玻璃边缘渐变描边：沿圆角矩形描边，左上高光 → 右下渐隐（模拟定向光反射）
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.radius,
    required this.start,
    required this.end,
  });

  final BorderRadius radius;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    if (start == end) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius.topLeft,
      topRight: radius.topRight,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [start, end],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}
