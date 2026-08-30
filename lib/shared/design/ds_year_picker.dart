/// macOS 风格年份选择弹层（文档 9.6 节）：12 年一页网格，
/// 上下翻页，hover 高亮，当前年 accentBlue 强调；点击返回选中年份。
/// 供月视图年月标题点击后跨年跳转使用。
library;

import 'package:flutter/material.dart';

import 'ds_button.dart';
import 'ds_dialog.dart';
import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 弹出年份选择器，返回选中的年份；取消返回 null。
Future<int?> showDSYearPicker(
  BuildContext context, {
  required int initialYear,
}) {
  return showDSDialog<int>(
    context,
    title: '选择年份',
    content: _YearGrid(initialYear: initialYear),
    actions: [
      DSButton(
        label: '取消',
        kind: DSButtonKind.secondary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

/// 每页年份数：4 列 × 3 行
const int _kYearsPerPage = 12;

class _YearGrid extends StatefulWidget {
  const _YearGrid({required this.initialYear});

  final int initialYear;

  @override
  State<_YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<_YearGrid> {
  /// 当前页起始年（12 年一组）
  late int _pageStart = _pageStartOf(widget.initialYear);

  /// 当前页起始年（12 年一组；Dart 的 % 恒非负，直接减去余数即向下取整到组首）
  static int _pageStartOf(int year) => year - year % _kYearsPerPage;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 页码切换
        Row(
          children: [
            _IconButton(
              icon: Icons.chevron_left,
              onTap: () => setState(
                () => _pageStart -= _kYearsPerPage,
              ),
            ),
            Expanded(
              child: Text(
                '$_pageStart – ${_pageStart + _kYearsPerPage - 1} 年',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            _IconButton(
              icon: Icons.chevron_right,
              onTap: () => setState(
                () => _pageStart += _kYearsPerPage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 年份网格：4 列 × 3 行
        for (var row = 0; row < 3; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 4; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                Expanded(
                  child: _YearCell(
                    year: _pageStart + row * 4 + col,
                    isCurrentYear: _pageStart + row * 4 + col == now.year,
                    onTap: () => Navigator.of(context)
                        .pop(_pageStart + row * 4 + col),
                  ),
                ),
              ],
            ],
          ),
          if (row < 2) const SizedBox(height: 6),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// 单个年份格子：hover 圆角底色提示，当前年 accentBlue 强调
class _YearCell extends StatefulWidget {
  const _YearCell({
    required this.year,
    required this.isCurrentYear,
    required this.onTap,
  });

  final int year;
  final bool isCurrentYear;
  final VoidCallback onTap;

  @override
  State<_YearCell> createState() => _YearCellState();
}

class _YearCellState extends State<_YearCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationQuick,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? tokens.textPrimary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrentYear
                ? Border.all(color: tokens.accentBlue, width: 1.2)
                : null,
          ),
          child: Text(
            '${widget.year}',
            style: TextStyle(
              fontSize: kFontSizeBody,
              fontWeight: widget.isCurrentYear
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: widget.isCurrentYear
                  ? tokens.accentBlue
                  : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _hovered
                ? tokens.textPrimary.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Icon(widget.icon, size: 18, color: tokens.textPrimary),
        ),
      ),
    );
  }
}
