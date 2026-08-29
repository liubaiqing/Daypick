/// 应用外壳：自绘标题栏（交通灯窗口按钮）+ 侧边栏导航 + 内容区。
/// 对应技术开发文档第 9.1 / 9.2 节。
library;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../calendar/calendar_page.dart';
import '../intake/intake_page.dart';
import '../settings/settings_page.dart';

enum _NavItem { calendar, intake, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _NavItem _current = _NavItem.calendar;

  @override
  Widget build(BuildContext context) {
    // 主题 token 由 CalendarApp 的 MaterialApp.builder 提供（覆盖 Navigator 与全部弹层）
    return ColoredBox(
      color: DSTokensScope.of(context).mainBackground,
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
                Container(width: 1, color: DSTokensScope.of(context).divider),
                Expanded(
                  child: switch (_current) {
                    _NavItem.calendar => const CalendarPage(),
                    _NavItem.intake => const IntakePage(),
                    _NavItem.settings => const SettingsPage(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 自绘标题栏：拖拽区（双击最大化）+ 右上角 Windows 风格窗口按钮（文档 9.1 节）
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
        onDoubleTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: ColoredBox(
          color: tokens.sidebarBackground,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text(
                kAppName,
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const _WindowControls(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Windows 风格窗口按钮组（右上角：最小化 / 最大化还原 / 关闭）
class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(_WindowListener(
      onMaximize: () => setState(() => _maximized = true),
      onUnmaximize: () => setState(() => _maximized = false),
    ));
  }

  Future<void> _handleTap(_WindowAction action) async {
    switch (action) {
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          action: _WindowAction.minimize,
          onTap: () => _handleTap(_WindowAction.minimize),
        ),
        _WindowButton(
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          tooltip: _maximized ? '还原' : '最大化',
          action: _WindowAction.maximize,
          onTap: () => _handleTap(_WindowAction.maximize),
        ),
        _WindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          action: _WindowAction.close,
          onTap: () => _handleTap(_WindowAction.close),
          danger: true,
        ),
      ],
    );
  }
}

class _WindowListener extends WindowListener {
  _WindowListener({required this.onMaximize, required this.onUnmaximize});

  final VoidCallback onMaximize;
  final VoidCallback onUnmaximize;

  @override
  void onWindowMaximize() => onMaximize();

  @override
  void onWindowUnmaximize() => onUnmaximize();
}

enum _WindowAction { close, minimize, maximize }

/// 单个窗口按钮：标准 46×32 命中区；hover 提亮；关闭按钮 hover 红底白字
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.action,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final _WindowAction action;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final bg = widget.danger && _hovered
        ? const Color(0xFFE81123) // Windows 关闭按钮 hover 红
        : _hovered
            ? tokens.textPrimary.withValues(alpha: 0.06)
            : Colors.transparent;
    final fg = widget.danger && _hovered
        ? Colors.white
        : tokens.textPrimary.withValues(alpha: 0.75);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: 38,
            color: bg,
            child: Icon(widget.icon, size: 12, color: fg),
          ),
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
                icon: Icons.note_add_outlined,
                label: '新建',
                selected: current == _NavItem.intake,
                onTap: () => onSelect(_NavItem.intake),
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
