/// 应用根组件：MaterialApp 仅作为宿主（导航 / 主题分发 / 系统亮度），
/// 业务 UI 一律使用自建设计系统（shared/design），禁止 Material/Cupertino 业务组件（文档 2.3 节）。
///
/// 重要：DSTokensScope 必须包裹在 MaterialApp.builder（Navigator 之上），
/// 否则 showGeneralDialog 打开的弹层/Overlay 无法访问主题 token（Release 下会空指针 → 灰屏）。
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../features/shell/app_shell.dart';
import '../shared/design/ds_tokens.dart';
import '../shared/design/dstokens_scope.dart';

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'HarmonyOS Sans SC',
        fontFamilyFallback: const [
          'Microsoft YaHei UI',
          'Microsoft YaHei',
        ],
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // 依据系统亮度选择浅/深主题，并让所有路由与弹层可见；
        // 透明 Material 提供 TextField 等组件所需的 Material 祖先（Debug/Release 一致）
        final brightness = MediaQuery.platformBrightnessOf(context);
        final tokens =
            brightness == Brightness.dark ? DSTokens.dark : DSTokens.light;
        return Material(
          type: MaterialType.transparency,
          child: DSTokensScope(tokens: tokens, child: child!),
        );
      },
      home: const AppShell(),
    );
  }
}
