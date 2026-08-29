/// 应用外壳：自绘标题栏（交通灯窗口按钮）+ 侧边栏导航 + 内容区。
/// 对应技术开发文档第 9.1 / 9.2 节。
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../calendar/calendar_page.dart';
import '../settings/settings_page.dart';

enum _NavItem { calendar, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _NavItem _current = _NavItem.calendar;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final tokens =
        brightness == Brightness.dark ? DSTokens.dark : DSTokens.light;
    return DSTokensScope(
      tokens: tokens,
      child: ColoredBox(
        color: tokens.mainBackground,
        child: Column(
          children: [
            const _TitleBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Sidebar(
                    current: _current,
                    onSelect: (item) => setState(() => _current = item),
                  ),
                  Container(width: 1, color: tokens.divider),
                  Expanded(
                    child: switch (_current) {
                      _NavItem.calendar => const CalendarPage(),
                      _NavItem.settings => const SettingsPage(),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自绘标题栏：拖拽区 + 红黄绿交通灯（文档 9.1 节）
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return SizedBox(
      height: 38,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: ColoredBox(
          color: tokens.sidebarBackground,
          child: Row(
            children: [
              const SizedBox(width: 12),
              const _TrafficLightBar(),
              const Spacer(),
              Text(
                kAppName,
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // 右侧留白使标题居中于窗口
              const SizedBox(width: 12 + 3 * 12 + 2 * 8 + 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 交通灯按钮组（关闭 / 最小化 / 最大化）
class _TrafficLightBar extends StatelessWidget {
  const _TrafficLightBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficLightButton(
          color: Color(0xFFFF5F57),
          hoverColor: Color(0xFFE0443E),
          glyph: '×',
          action: _WindowAction.close,
        ),
        SizedBox(width: 8),
        _TrafficLightButton(
          color: Color(0xFFFEBC2E),
          hoverColor: Color(0xFFD89E24),
          glyph: '−',
          action: _WindowAction.minimize,
        ),
        SizedBox(width: 8),
        _TrafficLightButton(
          color: Color(0xFF28C840),
          hoverColor: Color(0xFF1EAA32),
          glyph: '+',
          action: _WindowAction.maximize,
        ),
      ],
    );
  }
}

enum _WindowAction { close, minimize, maximize }

class _TrafficLightButton extends StatefulWidget {
  const _TrafficLightButton({
    required this.color,
    required this.hoverColor,
    required this.glyph,
    required this.action,
  });

  final Color color;
  final Color hoverColor;
  final String glyph;
  final _WindowAction action;

  @override
  State<_TrafficLightButton> createState() => _TrafficLightButtonState();
}

class _TrafficLightButtonState extends State<_TrafficLightButton> {
  bool _hovered = false;

  Future<void> _handleTap() async {
    switch (widget.action) {
      case _WindowAction.close:
        await windowManager.close();
      case _WindowAction.minimize:
        await windowManager.minimize();
      case _WindowAction.maximize:
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered ? widget.hoverColor : widget.color,
          ),
          alignment: Alignment.center,
          child: _hovered
              ? Text(
                  widget.glyph,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// 侧边栏（文档 9.2 节）
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onSelect});

  final _NavItem current;
  final ValueChanged<_NavItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: tokens.sidebarBackground,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavTile(
                icon: Icons.calendar_month_outlined,
                label: '日历',
                selected: current == _NavItem.calendar,
                onTap: () => onSelect(_NavItem.calendar),
              ),
              const SizedBox(height: 2),
              _NavTile(
                icon: Icons.settings_outlined,
                label: '设置',
                selected: current == _NavItem.settings,
                onTap: () => onSelect(_NavItem.settings),
              ),
              const Spacer(),
              Text(
                'v1.0.0+1',
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final bg = widget.selected
        ? tokens.accentBlue.withValues(alpha: 0.12)
        : _hovered
            ? tokens.textPrimary.withValues(alpha: 0.05)
            : Colors.transparent;
    final fg = widget.selected ? tokens.accentBlue : tokens.textPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationQuick,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(fontSize: kFontSizeBody, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
