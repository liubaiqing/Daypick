/// 向子树提供当前主题的 DSTokens（AppShell 依据系统亮度选择浅/深）。
library;

import 'package:flutter/widgets.dart';

import 'ds_tokens.dart';

class DSTokensScope extends InheritedWidget {
  const DSTokensScope({super.key, required this.tokens, required super.child});

  final DSTokens tokens;

  static DSTokens of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DSTokensScope>();
    assert(scope != null, 'DSTokensScope not found in context');
    return scope!.tokens;
  }

  @override
  bool updateShouldNotify(DSTokensScope oldWidget) =>
      tokens != oldWidget.tokens;
}
