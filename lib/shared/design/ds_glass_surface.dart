/// 毛玻璃容器（文档 9.6 节 DSGlassSurface / 9.4.2 节 HIG Materials）：
/// `BackdropFilter`（blur 20 + 饱和度补偿 1.8）+ 半透明白着色 + hairline 描边；
/// 仅毛玻璃主题（`DSTokens.glass`）启用，浅色/深色主题下退化为普通 Container。
///
/// 使用范围（文档 9.5 节）：仅窗口主背景、卡片/输入条、弹层三处；
/// 禁止在月视图网格、列表行等高频重绘区域使用（性能）。
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 饱和度补偿颜色矩阵（saturation 1.8，HIG Materials 惯例）。
/// 仅增强有彩色；中性色（黑/白/灰文字）输出不变，不影响前景可读性。
final List<double> _kSaturationMatrix = [
  0.2126 + 1.8 * 0.7873, 0.7152 - 1.8 * 0.7152, 0.0722 - 1.8 * 0.0722, 0, 0,
  0.2126 - 1.8 * 0.2126, 0.7152 + 1.8 * 0.2848, 0.0722 - 1.8 * 0.0722, 0, 0,
  0.2126 - 1.8 * 0.2126, 0.7152 - 1.8 * 0.7152, 0.0722 + 1.8 * 0.9278, 0, 0,
  0, 0, 0, 1, 0,
];

class DSGlassSurface extends StatelessWidget {
  const DSGlassSurface({
    super.key,
    required this.child,
    this.width,
    this.constraints,
    this.borderRadius,
    this.border,
  });

  final Widget child;

  /// 显式宽度（如弹窗 560）
  final double? width;

  /// 尺寸约束（如弹窗最大高度）
  final BoxConstraints? constraints;

  final BorderRadius? borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final isGlass = tokens.glassBlurSigma > 0;
    final radius = borderRadius ?? BorderRadius.circular(kRadiusPanel);

    Widget surface;
    if (!isGlass) {
      // 浅色/深色主题：退化为普通弹层容器（无模糊、无 hairline）
      surface = Container(
        decoration: BoxDecoration(
          color: tokens.dialogBackground,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tokens.panelShadowColor,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
    } else {
      // 毛玻璃：模糊背景 + 饱和度补偿 + 半透明白着色 + hairline 描边
      // （ColorFilter.matrix 施加在模糊合成结果上；中性文字不受影响）
      surface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma,
            sigmaY: tokens.glassBlurSigma,
          ),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_kSaturationMatrix),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.glassSurface,
                borderRadius: radius,
                border: border ??
                    Border.all(color: tokens.glassBorder, width: 1),
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
