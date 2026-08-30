/// macOS 风格下拉选择（文档 9.6 节 DSDropdown）：点击弹出锚定菜单，hover 高亮、选中打勾。
library;

import 'package:flutter/material.dart';

import 'ds_glass_surface.dart';
import 'ds_tokens.dart';
import 'dstokens_scope.dart';

class DSDropdownItem<T> {
  const DSDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;

  /// 右侧灰色小字（如 baseURL）
  final String? subtitle;
}

class DSDropdown<T> extends StatefulWidget {
  const DSDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.width = 340,
    this.hintText = '请选择',
  });

  final List<DSDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final double width;
  final String hintText;

  @override
  State<DSDropdown<T>> createState() => _DSDropdownState<T>();
}

class _DSDropdownState<T> extends State<DSDropdown<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _menu;

  DSDropdownItem<T>? get _selectedItem {
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _toggle() {
    if (_menu != null) {
      _close();
      return;
    }
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero, ancestor: overlay);
    // OverlayEntry 的 context 位于 DSTokensScope 之上，提前捕获 token
    final tokens = DSTokensScope.of(context);
    final width = widget.width;
    final items = widget.items;
    final value = widget.value;
    _menu = OverlayEntry(
      builder: (ctx) => _buildMenu(tokens, position, width, items, value),
    );
    Overlay.of(context).insert(_menu!);
  }

  void _close() {
    _menu?.remove();
    _menu = null;
  }

  Widget _buildMenu(
    DSTokens tokens,
    Offset position,
    double width,
    List<DSDropdownItem<T>> items,
    T? value,
  ) {
    return Stack(
      children: [
        // 点击外部关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: position.dx,
          top: position.dy + 40,
          width: width,
          child: _buildMenuSurface(tokens, items, value),
        ),
      ],
    );
  }

  Widget _buildMenuSurface(
    DSTokens tokens,
    List<DSDropdownItem<T>> items,
    T? value,
  ) {
    final content = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _MenuItem<T>(
              tokens: tokens,
              item: item,
              selected: item.value == value,
              onTap: () {
                widget.onChanged(item.value);
                _close();
              },
            ),
        ],
      ),
    );
    final radius = BorderRadius.circular(10);
    if (tokens.glassBlurSigma > 0) {
      // OverlayEntry 位于应用 DSTokensScope 之上，显式补回当前主题 token。
      return DSTokensScope(
        tokens: tokens,
        child: DSGlassSurface(
          kind: DSGlassSurfaceKind.floating,
          borderRadius: radius,
          child: content,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: tokens.dialogBackground,
        borderRadius: radius,
        border: Border.all(color: tokens.divider),
        boxShadow: [
          BoxShadow(
            color: tokens.panelShadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final selected = _selectedItem;
    return GestureDetector(
      key: _anchorKey,
      onTap: _toggle,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(kRadiusTextField),
          border: Border.all(color: tokens.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.label ?? widget.hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: selected == null
                      ? tokens.textSecondary.withValues(alpha: 0.6)
                      : tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem<T> extends StatefulWidget {
  const _MenuItem({
    required this.tokens,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DSTokens tokens;
  final DSDropdownItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MenuItem<T>> createState() => _MenuItemState<T>();
}

class _MenuItemState<T> extends State<_MenuItem<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? tokens.accentBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kFontSizeBody,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (widget.item.subtitle != null)
                Flexible(
                  child: Text(
                    widget.item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: kFontSizeSmall,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              if (widget.selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 14, color: tokens.accentBlue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
