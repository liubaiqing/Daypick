/// macOS 风格分段控件（文档 9.6 节 DSSegmentedControl）：
/// 选中项以"滑块"形式呈现——切换时滑块在段之间**平滑滑动**
/// （AnimatedPositioned + emphasized 缓动）；滑块动画时长可由动画总开关控制
/// （关闭动画时传 Duration.zero，滑块瞬间就位）。
///
/// 布局：**内容自适应**——用 TextPainter 同步测量各段文字宽度，
/// 段宽 = 最宽文字 + 两侧留白，控件总宽由内容决定。
/// 因此可在 Row 的非 flex 槽位中安全使用（Flutter 的 Flex 布局
/// 对非 flex 子元素在主轴方向不限制宽度，控件不得依赖父约束）。
library;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 选项：label 显示文本；enabled 是否可点；tooltip 禁用时的提示
typedef DSSegmentOption = ({String label, bool enabled, String? tooltip});

/// 段水平留白（每侧）
const double _kSegHPadding = 12;

/// 段间距
const double _kSegGap = 2;

class DSSegmentedControl extends StatefulWidget {
  const DSSegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.duration = kDurationNormal,
  });

  final List<DSSegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 滑块滑动时长（动画开关关闭时传 Duration.zero）
  final Duration duration;

  @override
  State<DSSegmentedControl> createState() => _DSSegmentedControlState();
}

class _DSSegmentedControlState extends State<DSSegmentedControl> {
  /// 同步测量文字宽度（与 _Segment 渲染样式一致），用于确定段宽
  double _measureLabel(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: kFontSizeCaption,
          fontWeight: FontWeight.w400,
          fontFamily: 'HarmonyOS Sans SC',
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final count = widget.options.length;
    // 段宽 = 最宽文字 + 两侧留白（等宽分段，滑块无需测量即可对齐）
    var maxLabel = 0.0;
    for (final option in widget.options) {
      final w = _measureLabel(context, option.label);
      if (w > maxLabel) maxLabel = w;
    }
    final segWidth = maxLabel + _kSegHPadding * 2;
    final totalWidth = count * segWidth + (count - 1) * _kSegGap;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      // 显式尺寸：内容自适应（不依赖父约束，可在 Row 非 flex 槽位中使用）
      child: SizedBox(
        width: totalWidth,
        height: 26,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // 选中滑块：位置随选中索引平滑滑动（等宽分段，无需测量）
            AnimatedPositioned(
              duration: widget.duration,
              curve: Curves.easeInOutCubicEmphasized,
              left: widget.selectedIndex * (segWidth + _kSegGap),
              top: 0,
              bottom: 0,
              width: segWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.cardBackground,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.cardShadowColor,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            // 段（文本层，位于滑块之上）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: _kSegGap),
                  SizedBox(
                    width: segWidth,
                    child: _Segment(
                      label: widget.options[i].label,
                      enabled: widget.options[i].enabled,
                      selected: i == widget.selectedIndex,
                      tooltip: widget.options[i].tooltip,
                      onTap: widget.options[i].enabled
                          ? () => widget.onChanged(i)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final fg = !widget.enabled
        ? tokens.textSecondary.withValues(alpha: 0.5)
        : widget.selected
        ? tokens.textPrimary
        : tokens.textSecondary;
    final segment = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            // 未选中 hover 淡色高亮；选中态由底层滑块呈现
            color: !widget.selected && _hovered && widget.enabled
                ? tokens.textPrimary.withValues(alpha: 0.04)
                : Colors.transparent,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: kFontSizeCaption,
              color: fg,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return segment;
    return Tooltip(message: widget.tooltip!, child: segment);
  }
}
