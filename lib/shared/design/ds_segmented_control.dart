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

class _Segment extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final fg = !enabled
        ? tokens.textSecondary.withValues(alpha: 0.5)
        : selected
            ? tokens.textPrimary
            : tokens.textSecondary;
    final segment = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kDurationQuick,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
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
          label,
          style: TextStyle(
            fontSize: kFontSizeCaption,
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
    if (tooltip == null) return segment;
    return Tooltip(message: tooltip!, child: segment);
  }
}
