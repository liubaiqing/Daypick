/// 月视图（文档 10.1 节）：自绘 7 列网格，周一起始，今日蓝圈、事件圆点。
/// 选中聚焦动画（文档 10.1 节补充）：
/// - 首次点击：本月含今天 → 浅蓝圆从今天位置弹动到点击处；
///   本月不含今天 → 浅蓝圆在点击处原地浮现弹动；
/// - 后续点击：浅蓝圆从上一位置丝滑移动到新位置；
/// - 跨月切换（翻页/补白日期）不播放移动动画，直接切换。
library;

import 'package:flutter/material.dart';

import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

class MonthView extends StatefulWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onSelectDay,
  });

  /// 当前展示的月份（取 year/month 即可）
  final DateTime month;

  /// 选中的日期
  final DateTime selectedDay;

  /// 日期号 -> 事件数（月视图圆点）
  final Map<int, int> eventsByDay;

  final ValueChanged<DateTime> onSelectDay;

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView>
    with SingleTickerProviderStateMixin {
  static const List<String> _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  Animation<Offset>? _moveAnim;
  Animation<double>? _scaleAnim;
  Animation<double>? _fadeAnim;
  DateTime? _lastAnimated; // 网格内上一次动画目标（"从上一位置移动"用）
  Size? _gridSize;
  bool _showCircle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 网格几何

  int get _leading {
    final first = DateTime(widget.month.year, widget.month.month, 1);
    return first.weekday - 1;
  }

  int get _daysInMonth =>
      DateTime(widget.month.year, widget.month.month + 1, 0).day;

  int get _rows => ((_leading + _daysInMonth) / 7).ceil();

  bool _isSameMonth(DateTime date) =>
      date.year == widget.month.year && date.month == widget.month.month;

  /// 日期在本网格中的格子中心坐标（含补白格）；不在网格返回 null
  Offset? _gridCenter(DateTime date, Size grid) {
    final first = DateTime(widget.month.year, widget.month.month, 1);
    final diff = DateUtils.dateOnly(date)
        .difference(DateUtils.dateOnly(first))
        .inDays;
    final idx = _leading + diff;
    if (idx < 0 || idx >= _rows * 7) return null;
    final col = idx % 7;
    final row = idx ~/ 7;
    return Offset(
      (col + 0.5) * grid.width / 7,
      (row + 0.5) * grid.height / _rows,
    );
  }

  // ------------------------------------------------------------ 选中动画

  void _handleDayTap(DateTime date) {
    final target = DateUtils.dateOnly(date);
    // 跨月：直接切换，不播放移动动画（本月聚焦逻辑随网格重建）
    if (!_isSameMonth(target)) {
      _lastAnimated = null;
      widget.onSelectDay(date);
      return;
    }
    final grid = _gridSize;
    if (grid == null) {
      widget.onSelectDay(date);
      return;
    }
    final to = _gridCenter(target, grid);
    if (to == null) {
      widget.onSelectDay(date);
      return;
    }

    final last = _lastAnimated;
    final isFirst = last == null;
    Offset? from;
    if (isFirst) {
      // 首次：本月含今天 → 从今天位置弹出；否则原地浮现
      final today = DateUtils.dateOnly(DateTime.now());
      final todayCenter =
          _isSameMonth(today) ? _gridCenter(today, grid) : null;
      from = todayCenter ?? to;
    } else {
      from = _gridCenter(last, grid) ?? to;
    }
    final sameSpot = (from.dx - to.dx).abs() < 0.5 &&
        (from.dy - to.dy).abs() < 0.5;
    // 非首次且位置相同（重复点击同一天）：无动画
    if (sameSpot && !isFirst) {
      widget.onSelectDay(date);
      return;
    }

    setState(() => _showCircle = true);
    _controller.reset();
    _moveAnim = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _controller,
        // 首次从今天弹出用回弹曲线；后续移动用平滑曲线
        curve: isFirst ? Curves.easeOutBack : Curves.easeInOutCubic,
      ),
    );
    if (sameSpot && isFirst) {
      // 原地浮现弹动（本月不含今天 或 点击目标即今天）
      _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      );
      _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    } else {
      _scaleAnim = null;
      _fadeAnim = null;
    }
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted) setState(() => _showCircle = false);
    });
    widget.onSelectDay(date);
    _lastAnimated = target;
  }

  // ------------------------------------------------------------ UI

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
                '${widget.month.year}年${widget.month.month}月',
                style: TextStyle(
                  fontSize: kFontSizeLargeTitle,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _SmallIconButton(
                icon: Icons.chevron_left,
                onTap: () => widget.onSelectDay(
                  DateTime(widget.month.year, widget.month.month - 1, 1),
                ),
              ),
              const SizedBox(width: 4),
              _SmallIconButton(
                icon: Icons.chevron_right,
                onTap: () => widget.onSelectDay(
                  DateTime(widget.month.year, widget.month.month + 1, 1),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  widget.onSelectDay(
                    DateTime(now.year, now.month, now.day),
                  );
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
        // 网格 + 选中聚焦动画层
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gridSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  _buildGrid(tokens),
                  // 移动中的浅蓝选中圆（到达后由目标格自身选中态接管）
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      if (!_showCircle || _moveAnim == null) {
                        return const SizedBox.shrink();
                      }
                      final pos = _moveAnim!.value;
                      final scale = _scaleAnim?.value ?? 1.0;
                      final opacity = _fadeAnim?.value ?? 1.0;
                      return Positioned(
                        key: const ValueKey('selection-anim'),
                        left: pos.dx - 13,
                        top: pos.dy - 13,
                        width: 26,
                        height: 26,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            alignment: Alignment.center,
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.accentBlue
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(DSTokens tokens) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
    );
    final leading = _leading;
    final daysInMonth = _daysInMonth;
    final rows = _rows;
    final cells = leading + daysInMonth;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final date = _dateAt(r, c, leading, daysInMonth);
                      return _DayCell(
                        key: ValueKey(
                          'day-${date.year}-${date.month}-${date.day}',
                        ),
                        date: date,
                        inMonth: _inMonth(r, c, leading, daysInMonth, cells),
                        isToday: date == today,
                        isSelected: date == selected,
                        eventCount: widget.eventsByDay[date.day] ?? 0,
                        onTap: () => _handleDayTap(date),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _inMonth(int r, int c, int leading, int daysInMonth, int cells) {
    final idx = r * 7 + c;
    return idx >= leading && idx < leading + daysInMonth;
  }

  DateTime _dateAt(int r, int c, int leading, int daysInMonth) {
    final idx = r * 7 + c;
    if (idx < leading) {
      final prev = DateTime(widget.month.year, widget.month.month, 0).day;
      return DateTime(
        widget.month.year,
        widget.month.month - 1,
        prev - leading + idx + 1,
      );
    }
    if (idx >= leading + daysInMonth) {
      return DateTime(
        widget.month.year,
        widget.month.month + 1,
        idx - leading - daysInMonth + 1,
      );
    }
    return DateTime(widget.month.year, widget.month.month, idx - leading + 1);
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.eventCount,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int eventCount;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final textColor = widget.isToday
        ? Colors.white
        : widget.isSelected
            ? tokens.accentBlue
            : widget.inMonth
                ? tokens.textPrimary
                : tokens.textSecondary.withValues(alpha: 0.35);

    final dotColor = widget.isToday ? Colors.white : tokens.accentBlue;
    final dotCount = widget.eventCount.clamp(1, 3);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 只注册 onTap：onTap 与 onDoubleTap 并存会让单击延迟 300ms（双击判定）
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationQuick,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // hover 高亮（mac 日历惯例），选中/今日优先于 hover
            color: widget.isToday || widget.isSelected
                ? Colors.transparent
                : _hovered
                    ? tokens.textPrimary.withValues(alpha: 0.05)
                    : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isToday
                      ? tokens.accentBlue
                      : widget.isSelected
                          ? tokens.accentBlue.withValues(alpha: 0.12)
                          : Colors.transparent,
                ),
                child: Text(
                  '${widget.date.day}',
                  style: TextStyle(
                    fontSize: kFontSizeBody,
                    fontWeight:
                        widget.isToday ? FontWeight.w700 : FontWeight.w400,
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
                          color:
                              widget.eventCount > 0 ? dotColor : Colors.transparent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
