/// 应用外壳：自绘标题栏（右上角窗口按钮）+ 全屏日历 + 左下角设置圆钮；
/// 全窗口图片拖拽上传。对应技术开发文档第 9.1 / 9.2 节。
///
/// 毛玻璃主题使用淡蓝灰环境背景；输入条和弹窗等顶层浮层经
/// DSGlassSurface 模糊背后真实内容。月视图、列表和设置分组不做模糊。
library;

import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants.dart';
import '../../shared/design/ds_glass_surface.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../calendar/calendar_page.dart';
import '../intake/chat_composer_bar.dart';
import '../settings/settings_page.dart';
import 'window_resize_geometry.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    // 主题 token 由 CalendarApp 的 MaterialApp.builder 提供（覆盖 Navigator 与全部弹层）
    final tokens = DSTokensScope.of(context);
    final isGlass = tokens.glassBlurSigma > 0;
    return DropTarget(
      // 全窗口拖拽图片：路径写入 provider，由日历页输入条消费（文档 8 章调整）
      onDragDone: (details) {
        final paths = [
          for (final f in details.files)
            if (f.path.isNotEmpty) f.path,
        ];
        if (paths.isNotEmpty) {
          ref.read(droppedImagesProvider.notifier).set(paths);
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: isGlass
                ? _GlassAmbientBackground(child: _buildBody(context, true))
                : _buildBody(context, false),
          ),
          // 窗口边缘缩放热区：MouseRegion 显示缩放光标（Flutter 框架光标），
          // 按下经 window_manager.startResizing 触发系统缩放循环
          const Positioned.fill(child: _WindowResizeEdges()),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isGlass) {
    final tokens = DSTokensScope.of(context);
    return ColoredBox(
      // Liquid Glass 需要可折射的环境色；仅覆盖轻白蒙层保证日历可读。
      color: isGlass ? const Color(0x18FFFFFF) : tokens.mainBackground,
      child: Column(
        children: [
          const _TitleBar(),
          Expanded(
            child: Stack(
              children: [
                // 日历占满整个内容区（无侧边栏）
                const Positioned.fill(child: CalendarPage()),
                // 左下角设置圆钮
                Positioned(
                  left: 20,
                  bottom: 16,
                  child: _SettingsButton(
                    onTap: () => showSettingsDialog(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liquid Glass 背后的应用内环境层。蓝、紫、青环境光为透明浮层提供
/// 可折射、可反射的真实色彩，同时保持窗口本身不透明。
class _GlassAmbientBackground extends StatelessWidget {
  const _GlassAmbientBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return ColoredBox(
      color: tokens.mainBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, -0.95),
                radius: 0.95,
                colors: [Color(0xB8A9D5F7), Color(0x00A9D5F7)],
                stops: [0, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.95, -0.55),
                radius: 0.85,
                colors: [Color(0x8FCABFEE), Color(0x00CABFEE)],
                stops: [0, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.45, 1.05),
                radius: 0.9,
                colors: [Color(0x99B4E9DF), Color(0x00B4E9DF)],
                stops: [0, 1],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 窗口边缘缩放热区（无边框窗口恢复自由缩放，文档 9.1 节）：
/// 四边/四角各 6px 区域——MouseRegion 悬停显示缩放光标；
/// GestureDetector 捕获拖动生命周期；尺寸计算使用 screen_retriever 返回的
/// 系统级绝对光标位置，并串行合并 windowManager.setBounds 更新。
/// 不依赖系统 SC_SIZE 循环——Flutter 引擎会拦截该循环期间的鼠标消息。
class _WindowResizeEdges extends StatefulWidget {
  const _WindowResizeEdges();

  static const double _edge = 6;

  @override
  State<_WindowResizeEdges> createState() => _WindowResizeEdgesState();
}

class _WindowResizeEdgesState extends State<_WindowResizeEdges> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 上边 / 下边
        Positioned(
          left: _WindowResizeEdges._edge,
          right: _WindowResizeEdges._edge,
          top: 0,
          height: _WindowResizeEdges._edge,
          child: _edgeZone(ResizeEdge.top, SystemMouseCursors.resizeUpDown),
        ),
        Positioned(
          left: _WindowResizeEdges._edge,
          right: _WindowResizeEdges._edge,
          bottom: 0,
          height: _WindowResizeEdges._edge,
          child: _edgeZone(ResizeEdge.bottom, SystemMouseCursors.resizeUpDown),
        ),
        // 左边 / 右边
        Positioned(
          top: _WindowResizeEdges._edge,
          bottom: _WindowResizeEdges._edge,
          left: 0,
          width: _WindowResizeEdges._edge,
          child: _edgeZone(ResizeEdge.left, SystemMouseCursors.resizeLeftRight),
        ),
        Positioned(
          top: _WindowResizeEdges._edge,
          bottom: _WindowResizeEdges._edge,
          right: 0,
          width: _WindowResizeEdges._edge,
          child: _edgeZone(
            ResizeEdge.right,
            SystemMouseCursors.resizeLeftRight,
          ),
        ),
        // 四角（覆盖边）
        Positioned(
          top: 0,
          left: 0,
          width: _WindowResizeEdges._edge * 2,
          height: _WindowResizeEdges._edge * 2,
          child: _edgeZone(
            ResizeEdge.topLeft,
            SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          width: _WindowResizeEdges._edge * 2,
          height: _WindowResizeEdges._edge * 2,
          child: _edgeZone(
            ResizeEdge.topRight,
            SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          width: _WindowResizeEdges._edge * 2,
          height: _WindowResizeEdges._edge * 2,
          child: _edgeZone(
            ResizeEdge.bottomLeft,
            SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: _WindowResizeEdges._edge * 2,
          height: _WindowResizeEdges._edge * 2,
          child: _edgeZone(
            ResizeEdge.bottomRight,
            SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
      ],
    );
  }

  Widget _edgeZone(ResizeEdge edge, MouseCursor cursor) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) => _beginResize(edge, details.globalPosition),
        onPanUpdate: (_) => _requestResize(),
        onPanEnd: (_) => _finishResize(),
        onPanCancel: _finishResize,
        child: const SizedBox.expand(),
      ),
    );
  }

  Rect? _startBounds;
  Offset? _startCursor;
  ResizeEdge? _edge;
  int _resizeSession = 0;
  bool _resizeRequested = false;
  bool _resizeWorkerRunning = false;
  bool _resizeEnding = false;

  Future<void> _beginResize(ResizeEdge edge, Offset pointerDownPosition) async {
    final session = ++_resizeSession;
    // 边缘与会话同步建立；平台初始读取完成前到来的 update/end 会被缓存，
    // 避免快速短拖动因异步初始化尚未完成而完全失效。
    _edge = edge;
    _startBounds = null;
    _startCursor = null;
    _resizeEnding = false;
    _resizeRequested = false;

    final startBounds = await windowManager.getBounds();
    if (!mounted || session != _resizeSession) return;
    _edge = edge;
    _startBounds = startBounds;
    // globalPosition 是按下当帧的窗口内坐标；与窗口屏幕位置组合即可得到
    // 不受异步平台调用延迟影响的绝对起点。
    _startCursor = startBounds.topLeft + pointerDownPosition;
    _requestResize();
  }

  void _requestResize() {
    if (_edge == null) return;
    _resizeRequested = true;
    if (_startBounds == null || _startCursor == null) return;
    if (!_resizeWorkerRunning) {
      unawaited(_drainResizeRequests(_resizeSession));
    }
  }

  /// 串行处理窗口更新，并把处理期间到来的多次鼠标事件合并为最新一帧。
  /// 这样不会出现多个 setBounds 平台请求乱序完成、旧尺寸覆盖新尺寸的闪烁。
  Future<void> _drainResizeRequests(int session) async {
    if (_resizeWorkerRunning) return;
    _resizeWorkerRunning = true;
    try {
      while (mounted && session == _resizeSession && _resizeRequested) {
        _resizeRequested = false;
        final start = _startBounds;
        final startCursor = _startCursor;
        final edge = _edge;
        if (start == null || startCursor == null || edge == null) break;

        final cursor = await screenRetriever.getCursorScreenPoint();
        if (!mounted || session != _resizeSession) break;
        final target = calculateWindowResizeBounds(
          startBounds: start,
          cursorDelta: cursor - startCursor,
          edge: edge,
          minimumSize: const Size(kWindowMinWidth, kWindowMinHeight),
        );
        await windowManager.setBounds(
          null,
          position: target.topLeft,
          size: target.size,
        );
      }
    } finally {
      _resizeWorkerRunning = false;
      if (session == _resizeSession && _resizeRequested) {
        unawaited(_drainResizeRequests(session));
      } else if (session == _resizeSession && _resizeEnding) {
        _clearResize(session);
      } else if (_resizeRequested && _edge != null) {
        // 上一轮异步请求结束前用户已开始新一轮拖动。
        unawaited(_drainResizeRequests(_resizeSession));
      }
    }
  }

  void _finishResize() {
    if (_edge == null) return;
    _resizeEnding = true;
    // 强制读取一次释放时的绝对光标位置，确保最后一小段位移也被应用。
    _requestResize();
  }

  void _clearResize(int session) {
    if (session != _resizeSession) return;
    _edge = null;
    _startBounds = null;
    _startCursor = null;
    _resizeRequested = false;
    _resizeEnding = false;
    _resizeSession++;
  }
}

/// 左下角圆形设置按钮
class _SettingsButton extends StatefulWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Tooltip(
      message: '设置',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: DSGlassSurface(
            kind: DSGlassSurfaceKind.floating,
            borderRadius: BorderRadius.circular(20),
            fallbackColor: tokens.textPrimary.withValues(alpha: 0.05),
            fallbackShadow: false,
            child: AnimatedContainer(
              duration: kDurationQuick,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hovered
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 20,
                color: _hovered ? tokens.textPrimary : tokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 自绘标题栏：拖拽区（双击最大化，仅空白区）+ 右上角独立按钮区（即时响应，文档 9.1 节）。
/// 注意：按钮区必须与 onDoubleTap 手势区分离——同一手势区内 onClick/onDoubleTap
/// 并存会让单击等待 300ms 双击判定，导致按钮响应延迟。
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return ColoredBox(
      key: const ValueKey('window-titlebar-surface'),
      // 环境背景已覆盖整个窗口；玻璃模式不再叠加独立白底或模糊层。
      color: tokens.glassBlurSigma > 0
          ? Colors.transparent
          : tokens.sidebarBackground,
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            // 拖拽 + 双击最大化区（不含按钮）
            Expanded(
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
                  ],
                ),
              ),
            ),
            // 独立按钮区：不参与双击判定，点击即时响应
            const _WindowControls(),
          ],
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
    windowManager.addListener(
      _WindowListener(
        onMaximize: () => setState(() => _maximized = true),
        onUnmaximize: () => setState(() => _maximized = false),
      ),
    );
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
