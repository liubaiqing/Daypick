/// 仿 macOS 设计系统 token：色彩 / 圆角 / 阴影 / 字号 / 动效。
/// 对应技术开发文档第 9.4 / 9.5 节；所有组件一律经此处取色，禁止散落硬编码颜色。
/// 主题三选一（文档 4.1 节）：浅色 light / 深色 dark（HIG Dark Mode）/
/// 毛玻璃 glass（HIG Materials，基于浅色色板派生）。
library;

import 'dart:ui';

/// 设计 token 集合（按主题区分：浅色 / 深色 / 毛玻璃）
class DSTokens {
  const DSTokens({
    required this.sidebarBackground,
    required this.mainBackground,
    required this.cardBackground,
    required this.dialogBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.accentBlue,
    required this.dangerRed,
    required this.successGreen,
    required this.warningOrange,
    required this.yellow,
    required this.softAccentBlue,
    required this.softSuccessGreen,
    required this.windowButtonClose,
    required this.windowButtonMinimize,
    required this.windowButtonMaximize,
    required this.glassSurface,
    required this.glassBorder,
    required this.glassBlurSigma,
    required this.glassTintStart,
    required this.glassTintEnd,
    required this.glassEdgeStart,
    required this.glassEdgeEnd,
    required this.panelShadowColor,
    required this.cardShadowColor,
  });

  // ---- 背景 ----
  /// 侧边栏（毛玻璃下 80% 不透明度）
  final Color sidebarBackground;
  final Color mainBackground;
  final Color cardBackground;

  /// 弹层层级背景（深色主题亮度分层：主背景 < 卡片 < 弹层，文档 9.4.1）
  final Color dialogBackground;

  // ---- 文字 ----
  final Color textPrimary;
  final Color textSecondary;

  // ---- 分隔线 ----
  final Color divider;

  // ---- 强调色 ----
  final Color accentBlue;
  final Color dangerRed;
  final Color successGreen;
  final Color warningOrange;
  final Color yellow;

  /// 柔和强调蓝：毛玻璃主题下为低饱和柔和版（设置窗口按钮用，
  /// 避免在玻璃材质上刺眼）；浅色/深色主题下与 accentBlue 一致。
  final Color softAccentBlue;

  /// 柔和强调绿：同上（设置窗口开关用）。
  final Color softSuccessGreen;

  // ---- 交通灯窗口按钮（见文档 9.1 节）----
  final Color windowButtonClose;
  final Color windowButtonMinimize;
  final Color windowButtonMaximize;

  // ---- 毛玻璃材质（文档 9.4.2，仅 glass 主题生效）----
  /// 半透明白着色（弹层最实、主背景最透，由组件按层级取用）
  final Color glassSurface;
  /// hairline 描边
  final Color glassBorder;
  /// 背景模糊半径
  final double glassBlurSigma;
  /// 玻璃反光渐变着色起点（高光，左上）
  final Color glassTintStart;
  /// 玻璃反光渐变着色终点（透明，右下）
  final Color glassTintEnd;
  /// 玻璃边缘渐变描边起点（高光反射）
  final Color glassEdgeStart;
  /// 玻璃边缘渐变描边终点
  final Color glassEdgeEnd;

  // ---- 投影（文档 9.5 深色主题移除投影，改 hairline + 亮度分层）----
  /// 弹层/浮层投影色（浅色正常、深色透明、毛玻璃调轻）
  final Color panelShadowColor;
  /// 卡片/输入条投影色（同上）
  final Color cardShadowColor;

  /// 浅色主题（macOS 系统色板）
  static const DSTokens light = DSTokens(
    sidebarBackground: Color(0xCCF5F5F7),
    mainBackground: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    dialogBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xD9000000),
    textSecondary: Color(0x80000000),
    divider: Color(0x1A000000),
    accentBlue: Color(0xFF007AFF),
    dangerRed: Color(0xFFFF3B30),
    successGreen: Color(0xFF34C759),
    warningOrange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    softAccentBlue: Color(0xFF007AFF),
    softSuccessGreen: Color(0xFF34C759),
    windowButtonClose: Color(0xFFFF5F57),
    windowButtonMinimize: Color(0xFFFEBC2E),
    windowButtonMaximize: Color(0xFF28C840),
    glassSurface: Color(0x00000000),
    glassBorder: Color(0x00000000),
    glassBlurSigma: 0,
    glassTintStart: Color(0x00000000),
    glassTintEnd: Color(0x00000000),
    glassEdgeStart: Color(0x00000000),
    glassEdgeEnd: Color(0x00000000),
    panelShadowColor: Color(0x40000000),
    cardShadowColor: Color(0x14000000),
  );

  /// 深色主题（Apple HIG Dark Mode，文档 9.4.1）
  static const DSTokens dark = DSTokens(
    sidebarBackground: Color(0xCC1C1C1E),
    mainBackground: Color(0xFF1E1E1E),
    cardBackground: Color(0xFF2C2C2E),
    dialogBackground: Color(0xFF3A3A3C),
    textPrimary: Color(0xEBFFFFFF),
    textSecondary: Color(0x8CFFFFFF),
    divider: Color(0x1AFFFFFF),
    accentBlue: Color(0xFF0A84FF),
    dangerRed: Color(0xFFFF453A),
    successGreen: Color(0xFF32D74B),
    warningOrange: Color(0xFFFF9F0A),
    yellow: Color(0xFFFFD60A),
    softAccentBlue: Color(0xFF0A84FF),
    softSuccessGreen: Color(0xFF32D74B),
    windowButtonClose: Color(0xFFFF5F57),
    windowButtonMinimize: Color(0xFFFEBC2E),
    windowButtonMaximize: Color(0xFF28C840),
    glassSurface: Color(0x00000000),
    glassBorder: Color(0x00000000),
    glassBlurSigma: 0,
    glassTintStart: Color(0x00000000),
    glassTintEnd: Color(0x00000000),
    glassEdgeStart: Color(0x00000000),
    glassEdgeEnd: Color(0x00000000),
    // 深色主题移除投影（亮度分层代替阴影）
    panelShadowColor: Color(0x00000000),
    cardShadowColor: Color(0x00000000),
  );

  /// 毛玻璃主题（Apple HIG Materials，文档 9.4.2）：
  /// 基于浅色色板派生，文字/强调色与浅色一致，仅背景/描边/模糊不同。
  static const DSTokens glass = DSTokens(
    sidebarBackground: Color(0xCCF5F5F7),
    // 窗口主背景：半透明白 0.65 + blur 20
    mainBackground: Color(0xA6FFFFFF),
    // 卡片/输入条：半透明白 0.75 + blur 20
    cardBackground: Color(0xBFFFFFFF),
    // 弹层：高不透明度半透明白（叠在 0.32 遮罩上仍保持明亮，
    // 避免透出遮罩暗色让弹窗整体变暗；保留玻璃透感）
    dialogBackground: Color(0xF0FFFFFF),
    textPrimary: Color(0xD9000000),
    textSecondary: Color(0x80000000),
    divider: Color(0x1A000000),
    accentBlue: Color(0xFF007AFF),
    dangerRed: Color(0xFFFF3B30),
    successGreen: Color(0xFF34C759),
    warningOrange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    // 毛玻璃主题下的柔和强调色（设置窗口按钮/开关用：
    // 比主色低一档饱和度，避免刺眼，但保持鲜活不发灰）
    softAccentBlue: Color(0xFF4D8FE0),
    softSuccessGreen: Color(0xFF45B97C),
    windowButtonClose: Color(0xFFFF5F57),
    windowButtonMinimize: Color(0xFFFEBC2E),
    windowButtonMaximize: Color(0xFF28C840),
    glassSurface: Color(0xBFFFFFFF),
    glassBorder: Color(0x0F000000),
    glassBlurSigma: 20,
    // 玻璃反光渐变：左上高光白 0.32 → 右下淡白 0.2（两端均保持白底，
    // 避免透明端露出背后暗色造成"左白右黑"）
    glassTintStart: Color(0x52FFFFFF),
    glassTintEnd: Color(0x33FFFFFF),
    // 边缘渐变描边：白 0.5 → 白 0.12（玻璃边缘反射）
    glassEdgeStart: Color(0x80FFFFFF),
    glassEdgeEnd: Color(0x1FFFFFFF),
    // 玻璃弹层 shadow 调轻（玻璃自身已有层次）
    panelShadowColor: Color(0x26000000),
    cardShadowColor: Color(0x0F000000),
  );
}

// ---- 圆角（见文档 9.5 节）----
const double kRadiusButton = 6;
const double kRadiusTextField = 8;
const double kRadiusCard = 12;
const double kRadiusDialog = 14;
const double kRadiusComposer = 22; // 主界面输入条（胶囊形）
const double kRadiusPanel = 14; // 解析结果面板

// ---- 阴影（见文档 9.5 节）----
const double kShadowCardOpacity = 0.08;
const double kShadowCardHoverOpacity = 0.12;
const Offset kShadowCardOffset = Offset(0, 1);
const double kShadowCardBlur = 3;
const Offset kShadowCardHoverOffset = Offset(0, 2);
const double kShadowCardHoverBlur = 8;

// ---- 字号梯度（见文档 9.3 节）----
const double kFontSizeSmall = 11;
const double kFontSizeCaption = 12;
const double kFontSizeBody = 13;
const double kFontSizeTitle = 17;
const double kFontSizeLargeTitle = 20;

// ---- 动效时长（见文档 9.5 节）----
const Duration kDurationQuick = Duration(milliseconds: 150);
const Duration kDurationNormal = Duration(milliseconds: 200);
