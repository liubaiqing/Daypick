/// macOS 风格勾选框（文档 9.6 节 DSCheckbox）：未选中空心圆角方框、
/// 选中蓝底白勾；用于批量删除窗口的逐条勾选与全选（文档 10.5 节）。
library;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

class DSCheckbox extends StatefulWidget {
  const DSCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 18,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// 边长（默认 18）
  final double size;

  @override
  State<DSCheckbox> createState() => _DSCheckboxState();
}

class _DSCheckboxState extends State<DSCheckbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: kDurationQuick,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.value
                ? tokens.accentBlue
                : _hovered
                    ? tokens.textPrimary.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.value
                  ? tokens.accentBlue
                  : _hovered
                      ? tokens.textSecondary
                      : tokens.divider,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: widget.value
              ? Icon(Icons.check, size: widget.size * 0.68, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
