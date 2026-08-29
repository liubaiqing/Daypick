/// macOS 风格按钮（文档 9.6 节 DSButton）：primary / secondary / destructive。
library;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

enum DSButtonKind { primary, secondary, destructive }

class DSButton extends StatefulWidget {
  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = DSButtonKind.primary,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DSButtonKind kind;
  final bool small;

  @override
  State<DSButton> createState() => _DSButtonState();
}

class _DSButtonState extends State<DSButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final enabled = widget.onPressed != null;

    Color bg;
    Color fg;
    switch (widget.kind) {
      case DSButtonKind.primary:
        bg = tokens.accentBlue;
        fg = Colors.white;
      case DSButtonKind.secondary:
        bg = tokens.textPrimary.withValues(alpha: 0.08);
        fg = tokens.textPrimary;
      case DSButtonKind.destructive:
        bg = tokens.dangerRed;
        fg = Colors.white;
    }

    if (!enabled) {
      bg = bg.withValues(alpha: 0.4);
      fg = fg.withValues(alpha: 0.8);
    } else if (_pressed) {
      bg = Color.lerp(bg, Colors.black, 0.08)!;
    } else if (_hovered) {
      bg = Color.lerp(bg, Colors.white, 0.05)!;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: kDurationQuick,
          height: widget.small ? 28 : 32,
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 12 : 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(kRadiusButton),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: kFontSizeBody,
              color: fg,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
