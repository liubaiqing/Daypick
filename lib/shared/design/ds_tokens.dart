/// 仿 macOS 设计系统 token：色彩 / 圆角 / 阴影 / 字号 / 动效。
/// 对应技术开发文档第 9.4 / 9.5 节；所有组件一律经此处取色，禁止散落硬编码颜色。
library;

import 'dart:ui';

/// 设计 token 集合（按主题区分：浅色 / 深色）
class DSTokens {
  const DSTokens({
    required this.sidebarBackground,
    required this.mainBackground,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.accentBlue,
    required this.dangerRed,
    required this.successGreen,
    required this.warningOrange,
    required this.yellow,
    required this.windowButtonClose,
    required this.windowButtonMinimize,
    required this.windowButtonMaximize,
  });

  // ---- 背景 ----
  /// 侧边栏（毛玻璃下 80% 不透明度）
  final Color sidebarBackground;
  final Color mainBackground;
  final Color cardBackground;

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

  // ---- 交通灯窗口按钮（见文档 9.1 节）----
  final Color windowButtonClose;
  final Color windowButtonMinimize;
  final Color windowButtonMaximize;

  /// 浅色主题（macOS 系统色板）
  static const DSTokens light = DSTokens(
    sidebarBackground: Color(0xCCF5F5F7),
    mainBackground: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xD9000000),
    textSecondary: Color(0x80000000),
    divider: Color(0x1A000000),
    accentBlue: Color(0xFF007AFF),
    dangerRed: Color(0xFFFF3B30),
    successGreen: Color(0xFF34C759),
    warningOrange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    windowButtonClose: Color(0xFFFF5F57),
    windowButtonMinimize: Color(0xFFFEBC2E),
    windowButtonMaximize: Color(0xFF28C840),
  );

  /// 深色主题
  static const DSTokens dark = DSTokens(
    sidebarBackground: Color(0xCC1C1C1E),
    mainBackground: Color(0xFF1E1E1E),
    cardBackground: Color(0xFF2C2C2E),
    textPrimary: Color(0xEBFFFFFF),
    textSecondary: Color(0x8CFFFFFF),
    divider: Color(0x1AFFFFFF),
    accentBlue: Color(0xFF0A84FF),
    dangerRed: Color(0xFFFF453A),
    successGreen: Color(0xFF32D74B),
    warningOrange: Color(0xFFFF9F0A),
    yellow: Color(0xFFFFD60A),
    windowButtonClose: Color(0xFFFF5F57),
    windowButtonMinimize: Color(0xFFFEBC2E),
    windowButtonMaximize: Color(0xFF28C840),
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
