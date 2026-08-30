/// 应用根组件：MaterialApp 仅作为宿主（导航 / 主题分发），
/// 业务 UI 一律使用自建设计系统（shared/design），禁止 Material/Cupertino 业务组件（文档 2.3 节）。
///
/// 重要：DSTokensScope 必须包裹在 MaterialApp.builder（Navigator 之上），
/// 否则 showGeneralDialog 打开的弹层/Overlay 无法访问主题 token（Release 下会空指针 → 灰屏）。
///
/// 主题三选一（文档 4.1/9.4 节）：浅色 light / 深色 dark / 毛玻璃 glass；
/// 由设置页持久化（themeMode），默认浅色，不再跟随系统亮度。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/db/providers.dart';
import '../features/shell/app_shell.dart';
import '../shared/design/ds_tokens.dart';
import '../shared/design/dstokens_scope.dart';

class CalendarApp extends ConsumerWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题模式：首次加载前默认浅色（FutureProvider 未完成时 value 为 null）
    final themeMode = ref.watch(themeModeProvider).value ?? kDefaultThemeMode;
    final isDark = themeMode == kThemeModeDark;
    final tokens = switch (themeMode) {
      kThemeModeDark => DSTokens.dark,
      kThemeModeGlass => DSTokens.glass,
      _ => DSTokens.light,
    };
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        // 字体策略（文档 9.3 节）：HarmonyOS Sans SC 一款字体覆盖中英文，
        // 避免混排割裂；只使用 400/700 真实字重，避免合成加粗
        fontFamily: 'HarmonyOS Sans SC',
        fontFamilyFallback: const [
          'Microsoft YaHei UI',
          'Microsoft YaHei',
        ],
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        // 依据主题模式分发 token，并让所有路由与弹层可见；
        // 透明 Material 提供 TextField 等组件所需的 Material 祖先（Debug/Release 一致）
        return Material(
          type: MaterialType.transparency,
          child: DSTokensScope(tokens: tokens, child: child!),
        );
      },
      home: const AppShell(),
    );
  }
}
