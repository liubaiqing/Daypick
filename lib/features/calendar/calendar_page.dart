/// 日历页（月视图 + 今日待办列表）——M1 建设中，占位。
library;

import 'package:flutter/material.dart';

import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Center(
      child: Text(
        '日历（月视图建设中）',
        style: TextStyle(fontSize: kFontSizeBody, color: tokens.textSecondary),
      ),
    );
  }
}
