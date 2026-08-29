/// macOS 风格日期选择弹层（文档 9.6 节 DSDatePicker）：自绘迷你月历。
library;

import 'package:flutter/material.dart';

import 'ds_button.dart';
import 'ds_dialog.dart';
import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 弹出日期选择器，返回选中的日期（本地时间零点）；取消返回 null。
Future<DateTime?> showDSDatePicker(
  BuildContext context, {
  required DateTime initial,
}) {
  return showDSDialog<DateTime>(
    context,
    title: '选择日期',
    content: _DatePickerGrid(initial: initial),
    actions: [
      DSButton(
        label: '取消',
        kind: DSButtonKind.secondary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

class _DatePickerGrid extends StatefulWidget {
  const _DatePickerGrid({required this.initial});

  final DateTime initial;

  @override
  State<_DatePickerGrid> createState() => _DatePickerGridState();
}

class _DatePickerGridState extends State<_DatePickerGrid> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _selected = widget.initial;

  static const List<String> _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 年月切换
        Row(
          children: [
            _IconButton(
              icon: Icons.chevron_left,
              onTap: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
            ),
            Expanded(
              child: Text(
                '${_month.year}年${_month.month}月',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            _IconButton(
              icon: Icons.chevron_right,
              onTap: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 星期表头
        Row(
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
        const SizedBox(height: 4),
        ..._buildWeeks(tokens),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: DSButton(
            label: '今天',
            kind: DSButtonKind.secondary,
            small: true,
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _month = DateTime(now.year, now.month);
                _selected = DateTime(now.year, now.month, now.day);
              });
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWeeks(DSTokens tokens) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday - 1; // 周一为起始
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    final children = <Widget>[];
    for (var r = 0; r < rows; r++) {
      children.add(Row(
        children: [
          for (var c = 0; c < 7; c++) ...[
            Expanded(
              child: _DayCell(
                day: _dayAt(r, c, leading, daysInMonth),
                inMonth: _inMonth(r, c, leading, daysInMonth),
                isToday: _dayAt(r, c, leading, daysInMonth) == today,
                isSelected: _dayAt(r, c, leading, daysInMonth) == _selected,
                onTap: () =>
                    Navigator.of(context).pop(_dayAt(r, c, leading, daysInMonth)),
              ),
            ),
          ],
        ],
      ));
    }
    return children;
  }

  bool _inMonth(int r, int c, int leading, int daysInMonth) {
    final idx = r * 7 + c;
    return idx >= leading && idx < leading + daysInMonth;
  }

  DateTime _dayAt(int r, int c, int leading, int daysInMonth) {
    final idx = r * 7 + c;
    if (idx < leading) {
      final prev = DateTime(_month.year, _month.month, 0).day;
      return DateTime(_month.year, _month.month - 1, prev - leading + idx + 1);
    }
    if (idx >= leading + daysInMonth) {
      return DateTime(_month.year, _month.month + 1, idx - leading - daysInMonth + 1);
    }
    return DateTime(_month.year, _month.month, idx - leading + 1);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final textColor = isToday
        ? Colors.white
        : isSelected
            ? tokens.accentBlue
            : inMonth
                ? tokens.textPrimary
                : tokens.textSecondary.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
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
          '${day.day}',
          style: TextStyle(fontSize: kFontSizeBody, color: textColor),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: tokens.textPrimary.withValues(alpha: 0.05),
        ),
        child: Icon(icon, size: 16, color: tokens.textPrimary),
      ),
    );
  }
}
