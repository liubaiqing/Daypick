/// 冷静通透的毛玻璃容器（文档 9.6 节 DSGlassSurface）：
/// 轻玻璃用于输入条/下拉浮层，强玻璃用于居中弹窗；两者均由明确的半透明
/// 基础填充、轻微定向高光、单一亮边和冷灰投影组成。
/// 仅毛玻璃主题（`DSTokens.glass`）启用，浅色/深色主题下退化为普通 Container。
/// 使用范围：只用于输入条、下拉菜单和顶层弹窗；
/// 禁止在月视图网格、列表行等高频重绘区域使用（性能）。
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

enum DSGlassSurfaceKind { floating, dialog }

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
    this.kind = DSGlassSurfaceKind.dialog,
  });

  final Widget child;

  /// 显式宽度（如弹窗 560）
  final double? width;

  /// 尺寸约束（如弹窗最大高度）
  final BoxConstraints? constraints;

  final BorderRadius? borderRadius;
  final Border? border;

  /// 轻玻璃用于输入条/下拉菜单，强玻璃用于模态弹窗。
  final DSGlassSurfaceKind kind;

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
      final isDialog = kind == DSGlassSurfaceKind.dialog;
      final baseColor =
          isDialog ? tokens.dialogBackground : tokens.glassSurface;
      final blurSigma =
          isDialog ? tokens.glassDialogBlurSigma : tokens.glassBlurSigma;
      final shadowColor =
          isDialog ? tokens.panelShadowColor : tokens.cardShadowColor;
      final tinted = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(tokens.glassTintStart, baseColor),
              Color.alphaBlend(tokens.glassTintEnd, baseColor),
            ],
            begin: const Alignment(-1, -1),
            end: const Alignment(0.6, 0.7),
          ),
          border: border ?? Border.all(color: tokens.glassBorder, width: 1),
        ),
        child: child,
      );
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, isDialog ? 18 : 8),
              blurRadius: isDialog ? 50 : 28,
              spreadRadius: isDialog ? -8 : -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: tinted,
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
