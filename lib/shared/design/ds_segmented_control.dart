/// macOS 风格分段控件（文档 9.6 节 DSSegmentedControl）：圆角容器 + 选中块白底阴影。
library;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 选项：label 显示文本；enabled 是否可点；tooltip 禁用时的提示
typedef DSSegmentOption = ({String label, bool enabled, String? tooltip});

class DSSegmentedControl extends StatelessWidget {
  const DSSegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<DSSegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _Segment(
              label: options[i].label,
              enabled: options[i].enabled,
              selected: i == selectedIndex,
              tooltip: options[i].tooltip,
              onTap: options[i].enabled ? () => onChanged(i) : null,
            ),
          ],
        ],
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
        child: AnimatedContainer(
          duration: kDurationQuick,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? tokens.cardBackground
                : _hovered && widget.enabled
                    ? tokens.textPrimary.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: widget.selected
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: kFontSizeCaption,
              color: fg,
              fontWeight:
                  widget.selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return segment;
    return Tooltip(message: widget.tooltip!, child: segment);
  }
}
