/// 应用外壳：自绘标题栏（右上角窗口按钮）+ 全屏日历 + 左下角设置圆钮；
/// 全窗口图片拖拽上传。对应技术开发文档第 9.1 / 9.2 节。
library;

import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../calendar/calendar_page.dart';
import '../intake/chat_composer_bar.dart';
import '../settings/settings_page.dart';

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
      child: isGlass
          // 毛玻璃主界面（文档 9.4.2）：装饰背景 → 全屏模糊玻璃层 → 清晰内容层
          ? Stack(
              fit: StackFit.expand,
              children: [
                // 1) 装饰背景：模拟桌面壁纸的柔和光斑（供模糊层采样）
                const _GlassBackdrop(),
                // 2) 全屏毛玻璃：高斯模糊 + 白渐变着色（左上高光 → 右下通透）
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: tokens.glassBlurSigma,
                    sigmaY: tokens.glassBlurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tokens.mainBackground,
                          tokens.mainBackground.withValues(alpha: 0.8),
                        ],
                        begin: const Alignment(-0.8, -0.8),
                        end: const Alignment(0.6, 0.7),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                // 3) 内容层：标题栏 + 日历（清晰叠在玻璃上）
                _buildBody(context),
              ],
            )
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return ColoredBox(
      color: tokens.mainBackground,
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

/// 毛玻璃主题的装饰背景：浅色基座 + 柔和彩色光斑（模拟桌面壁纸），
/// 被上层全屏 BackdropFilter 模糊后呈现玻璃透光层次（文档 9.4.2）。
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFE9E9F0)),
        // 左上蓝
        Positioned(
          left: -120,
          top: -80,
          child: _Glow(
            colors: const [Color(0x664DA3FF), Color(0x004DA3FF)],
            size: 420,
          ),
        ),
        // 右上紫
        Positioned(
          right: -100,
          top: 60,
          child: _Glow(
            colors: const [Color(0x55A78BFA), Color(0x00A78BFA)],
            size: 380,
          ),
        ),
        // 左下粉橙
        Positioned(
          left: 40,
          bottom: -120,
          child: _Glow(
            colors: const [Color(0x55FB7185), Color(0x00FB7185)],
            size: 400,
          ),
        ),
        // 右下青
        Positioned(
          right: 20,
          bottom: 40,
          child: _Glow(
            colors: const [Color(0x4434D399), Color(0x0034D399)],
            size: 320,
          ),
        ),
      ],
    );
  }
}

/// 单个柔和光斑（径向渐变圆）
class _Glow extends StatelessWidget {
  const _Glow({required this.colors, required this.size});

  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
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
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? tokens.accentBlue.withValues(alpha: 0.14)
                  : tokens.textPrimary.withValues(alpha: 0.05),
              border: Border.all(color: tokens.divider),
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 20,
              color: _hovered ? tokens.accentBlue : tokens.textSecondary,
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
      color: tokens.sidebarBackground,
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
