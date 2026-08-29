/// 设置页——占位（M3 实现：解析模式 / LLM 配置 / 数据管理）。
library;

import 'package:flutter/material.dart';

import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Center(
      child: Text(
        '设置（建设中）',
        style: TextStyle(fontSize: kFontSizeBody, color: tokens.textSecondary),
      ),
    );
  }
}
