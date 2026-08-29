import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 无边框自绘标题栏（文档 9.1 节）
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(kWindowDefaultWidth, kWindowDefaultHeight),
    minimumSize: Size(kWindowMinWidth, kWindowMinHeight),
    center: true,
    title: kAppName,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: CalendarApp()));
}
