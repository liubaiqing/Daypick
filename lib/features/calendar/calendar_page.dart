/// 日历页（文档 10 章）：月视图 + 今日待办列表；窄窗口（<1000px）自动折叠为上下布局。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../shared/design/dstokens_scope.dart';
import 'month_view.dart';
import 'today_list.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());

  void _handleSelectDay(DateTime day) {
    final newDay = DateUtils.dateOnly(day);
    final newMonth = DateTime(day.year, day.month);
    // 无实际变化时跳过重建，避免快速点击时无谓的流订阅抖动
    if (newDay == _selectedDay && newMonth == _month) return;
    setState(() {
      _selectedDay = newDay;
      // 点击跨月日期时自动切换月份（文档 10.1 节）
      _month = newMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final events = ref.watch(monthEventsProvider(_month));

    final counts = <int, int>{};
    for (final e in events.value ?? const <Event>[]) {
      counts[e.start.day] = (counts[e.start.day] ?? 0) + 1;
    }

    final month = MonthView(
      month: _month,
      selectedDay: _selectedDay,
      eventsByDay: counts,
      onSelectDay: _handleSelectDay,
    );
    final list = TodayList(day: _selectedDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          // 窄窗口：月历在上、列表在下
          return Column(
            children: [
              Expanded(flex: 3, child: month),
              Container(height: 1, color: tokens.divider),
              Expanded(flex: 2, child: list),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: month),
            Container(width: 1, color: tokens.divider),
            SizedBox(width: 320, child: list),
          ],
        );
      },
    );
  }
}
