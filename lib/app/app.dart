/// 应用根组件：MaterialApp 仅作为宿主（导航 / 主题分发 / 系统亮度），
/// 业务 UI 一律使用自建设计系统（shared/design），禁止 Material/Cupertino 业务组件（文档 2.3 节）。
library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../features/shell/app_shell.dart';

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
