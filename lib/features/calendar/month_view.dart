/// 月视图（文档 10.1 节）：自绘 7 列网格，周一起始，今日蓝圈、事件圆点。
library;

import 'package:flutter/material.dart';

import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onSelectDay,
    required this.onNewEvent,
  });

  /// 当前展示的月份（取 year/month 即可）
  final DateTime month;

  /// 选中的日期
  final DateTime selectedDay;

  /// 日期号 -> 事件数（月视图圆点）
  final Map<int, int> eventsByDay;

  final ValueChanged<DateTime> onSelectDay;

  /// 双击某日期新建事件
  final ValueChanged<DateTime> onNewEvent;

  static const List<String> _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶栏：年月标题 + 翻页 + 今天（文档 10.1）
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                '${month.year}年${month.month}月',
                style: TextStyle(
                  fontSize: kFontSizeLargeTitle,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _SmallIconButton(
                icon: Icons.chevron_left,
                onTap: () => onSelectDay(
                  DateTime(month.year, month.month - 1, 1),
                ),
              ),
              const SizedBox(width: 4),
              _SmallIconButton(
                icon: Icons.chevron_right,
                onTap: () => onSelectDay(
                  DateTime(month.year, month.month + 1, 1),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  onSelectDay(DateTime(now.year, now.month, now.day));
                },
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: tokens.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(kRadiusButton),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '今天',
                    style: TextStyle(
                      fontSize: kFontSizeBody,
                      color: tokens.accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 星期表头
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final label in _weekLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: kFontSizeSmall,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 网格
        Expanded(child: _buildGrid(tokens)),
      ],
    );
  }

  Widget _buildGrid(DSTokens tokens) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _DayCell(
                      date: _dateAt(r, c, leading, daysInMonth),
                      inMonth: _inMonth(r, c, leading, daysInMonth),
                      isToday: _dateAt(r, c, leading, daysInMonth) == today,
                      isSelected: _dateAt(r, c, leading, daysInMonth) == selected,
                      eventCount: eventsByDay[
                              _dateAt(r, c, leading, daysInMonth).day] ??
                          0,
                      onTap: () =>
                          onSelectDay(_dateAt(r, c, leading, daysInMonth)),
                      onDoubleTap: () =>
                          onNewEvent(_dateAt(r, c, leading, daysInMonth)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _inMonth(int r, int c, int leading, int daysInMonth) {
    final idx = r * 7 + c;
    return idx >= leading && idx < leading + daysInMonth;
  }

  DateTime _dateAt(int r, int c, int leading, int daysInMonth) {
    final idx = r * 7 + c;
    if (idx < leading) {
      final prev = DateTime(month.year, month.month, 0).day;
      return DateTime(month.year, month.month - 1, prev - leading + idx + 1);
    }
    if (idx >= leading + daysInMonth) {
      return DateTime(
        month.year,
        month.month + 1,
        idx - leading - daysInMonth + 1,
      );
    }
    return DateTime(month.year, month.month, idx - leading + 1);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.eventCount,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int eventCount;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final textColor = isToday
        ? Colors.white
        : isSelected
            ? tokens.accentBlue
            : inMonth
                ? tokens.textPrimary
                : tokens.textSecondary.withValues(alpha: 0.35);

    final dotColor = isToday ? Colors.white : tokens.accentBlue;
    final dotCount = eventCount.clamp(1, 3);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? tokens.accentBlue
                  : isSelected
                      ? tokens.accentBlue.withValues(alpha: 0.12)
                      : Colors.transparent,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: kFontSizeBody,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < dotCount; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: eventCount > 0 ? dotColor : Colors.transparent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: tokens.textPrimary.withValues(alpha: 0.05),
        ),
        child: Icon(icon, size: 18, color: tokens.textPrimary),
      ),
    );
  }
}
