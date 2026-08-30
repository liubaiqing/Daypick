/// 日历主界面底部输入条（AI 对话式胶囊圆角条，文档 9.6 节）。
/// 左侧上传按钮（文件夹选择）+ 中间文本输入 + 右侧解析模式小分段控件与发送按钮；
/// 支持图片附件（可删除、图文并存）、回车发送（Shift+Enter 换行）、全窗口拖拽图片（经 droppedImagesProvider）。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../data/db/providers.dart';
import '../../data/llm/openai_compatible_client.dart';
import '../../data/ocr/ocr_service.dart';
import '../../data/parsers/ai_parser.dart';
import '../../data/parsers/local_parser.dart';
import '../../domain/parsed_event.dart';
import '../../shared/design/ds_glass_surface.dart';
import '../../shared/design/ds_segmented_control.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import 'parse_result_panel.dart';

/// 全窗口拖拽图片的交接点：AppShell 的 DropTarget 写入路径列表，输入条消费后清空
class DroppedImages extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void set(List<String> paths) => state = paths;
}

final droppedImagesProvider = NotifierProvider<DroppedImages, List<String>>(
  DroppedImages.new,
);

/// 支持的图片扩展名（拖拽过滤用）
const List<String> kImageExtensions = [
  'png',
  'jpg',
  'jpeg',
  'bmp',
  'webp',
  'gif',
];

class ChatComposerBar extends ConsumerStatefulWidget {
  const ChatComposerBar({super.key});

  @override
  ConsumerState<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends ConsumerState<ChatComposerBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LocalParser _localParser = LocalParser();
  final OpenAiCompatibleClient _llmClient = OpenAiCompatibleClient();
  final OcrService _ocrService = OcrService();

  final List<String> _attachmentPaths = [];

  /// 粘贴生成的临时图片文件（删除附件时一并清理；用户选择/拖拽的文件不清理）
  final Set<String> _pasteTempFiles = {};
  String _mode = kParseModeLocal;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 上次使用的解析模式作为默认（设置页不再管理，文档 11 章调整）
    ref.read(settingsDaoProvider).get(kSettingParseMode).then((mode) {
      if (!mounted || mode == null) return;
      setState(() {
        _mode = mode == kParseModeAi ? kParseModeAi : kParseModeLocal;
      });
    });
  }

  @override
  void dispose() {
    // 清理粘贴生成的临时图片
    for (final p in _pasteTempFiles) {
      File(p).delete().ignore();
    }
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 粘贴（Ctrl+V）

  /// Ctrl+V：剪贴板为图片 → 作为附件加入；为文本 → 手动粘贴（覆盖选区）
  Future<void> _handlePaste() async {
    if (_busy) return;
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}${Platform.pathSeparator}pasted_'
          '${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(imageBytes, flush: true);
        if (!mounted) return;
        setState(() {
          _attachmentPaths.add(file.path);
          _pasteTempFiles.add(file.path);
          _error = null;
        });
        return;
      }
      final text = await Pasteboard.text;
      if (text == null || text.isEmpty || !mounted) return;
      _insertText(text);
    } catch (e) {
      _showError('粘贴失败：$e');
    }
  }

  void _insertText(String text) {
    final value = _textCtrl.value;
    final selection = value.selection;
    if (!selection.isValid) {
      _textCtrl.text = text;
      return;
    }
    final newText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  // ------------------------------------------------------------ 附件

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    final paths = [
      for (final f in result?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    setState(() {
      _attachmentPaths.addAll(paths);
      _error = null;
    });
  }

  void _addDroppedFiles(List<String> paths) {
    final images = <String>[
      for (final p in paths)
        if (_isImage(p)) p,
    ];
    if (images.isEmpty) {
      _showError('仅支持图片文件（png/jpg/bmp/webp/gif）');
      return;
    }
    setState(() {
      _attachmentPaths.addAll(images);
      _error = null;
    });
  }

  bool _isImage(String path) {
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return kImageExtensions.contains(name.substring(dot + 1));
  }

  void _removeAttachment(int index) {
    final path = _attachmentPaths[index];
    setState(() => _attachmentPaths.removeAt(index));
    // 粘贴生成的临时文件随附件删除而清理
    if (_pasteTempFiles.remove(path)) {
      File(path).delete().ignore();
    }
  }

  // ------------------------------------------------------------ 解析

  Future<void> _setMode(String mode) async {
    setState(() => _mode = mode);
    // 持久化，下次启动沿用（文档 11 章）
    await ref.read(settingsDaoProvider).set(kSettingParseMode, mode);
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachmentPaths.isEmpty) {
      _showError('请输入内容或上传图片');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 1. 附件 OCR + 文本合并（图文并存，OCR 文本与手输文本换行连接）
      final parts = <String>[];
      for (final path in _attachmentPaths) {
        parts.add((await _ocrService.recognizeFile(path)).trim());
      }
      if (text.isNotEmpty) parts.add(text);
      final combined = parts.where((p) => p.isNotEmpty).join('\n');
      if (combined.isEmpty) {
        setState(() => _busy = false);
        _showError('未能从图片中识别出内容');
        return;
      }

      // 2. 按当前模式解析
      final events = _mode == kParseModeLocal
          ? await _localParser.parse(combined)
          : await _parseWithAi(combined);

      // 3. 清空输入并弹出结果面板
      if (!mounted) return;
      setState(() {
        _busy = false;
        _textCtrl.clear();
        _attachmentPaths.clear();
      });
      await showParseResultPanel(context, events);
    } on ParserException catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.message);
    } on OcrException catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError(e.message);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError('解析失败：$e');
    }
  }

  Future<List<ParsedEvent>> _parseWithAi(String text) async {
    final dao = ref.read(settingsDaoProvider);
    final config = AiConfig(
      baseUrl: await dao.get(kSettingLlmBaseUrl) ?? kDefaultLlmBaseUrl,
      apiKey: await dao.get(kSettingLlmApiKey) ?? '',
      model: await dao.get(kSettingLlmModel) ?? kDefaultLlmModel,
    );
    return AiParser(client: _llmClient, config: config).parse(text);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored; // Shift+Enter 换行
      }
      _send(); // 回车发送
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    // 动画开关：关闭时分段滑块瞬间就位
    final animOn = ref.watch(animationsEnabledProvider).value ?? true;
    // 消费全窗口拖入的图片（build 内监听，Riverpod 自动管理生命周期）
    ref.listen(droppedImagesProvider, (prev, next) {
      if (next.isEmpty) return;
      _addDroppedFiles(next);
      ref.read(droppedImagesProvider.notifier).set([]);
    });
    // 布局：外层 _ComposerSlot 已给出 tight 宽度（ConstrainedBox 640），
    // 内部 Column stretch 传导；分段控件内容自适应，不依赖宽度约束。
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.dangerRed,
                ),
              ),
            ),
          DSGlassSurface(
            kind: DSGlassSurfaceKind.floating,
            borderRadius: BorderRadius.circular(kRadiusComposer),
            // 非毛玻璃主题下保持输入条原有卡片视觉
            fallbackColor: tokens.cardBackground,
            fallbackShadowColor: tokens.cardShadowColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 图片附件缩略图（输入框内，可删除）
                  if (_attachmentPaths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _attachmentPaths.length; i++)
                            _AttachmentThumb(
                              key: ValueKey('attachment-$i'),
                              path: _attachmentPaths[i],
                              onRemove:
                                  _busy ? null : () => _removeAttachment(i),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 上传按钮
                      _ComposerIconButton(
                        icon: Icons.image_outlined,
                        tooltip: '从文件夹上传图片',
                        onTap: _busy ? null : _pickImages,
                      ),
                      const SizedBox(width: 8),
                      // 文本输入（Ctrl+V 经 PasteTextIntent 拦截：图片→附件，文本→手动粘贴；
                      // 回车发送、Shift+Enter 换行）
                      Expanded(
                        child: Actions(
                          actions: {
                            PasteTextIntent: CallbackAction<PasteTextIntent>(
                              onInvoke: (intent) {
                                _handlePaste();
                                return null;
                              },
                            ),
                          },
                          child: Focus(
                            onKeyEvent: _handleKey,
                            child: TextField(
                              controller: _textCtrl,
                              focusNode: _focusNode,
                              enabled: !_busy,
                              minLines: 1,
                              maxLines: 4,
                              keyboardType: TextInputType.multiline,
                              style: TextStyle(
                                fontSize: kFontSizeBody,
                                color: tokens.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '输入包含时间、地点、事务的内容，或上传图片…',
                                hintStyle: TextStyle(
                                  fontSize: kFontSizeBody,
                                  color: tokens.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 解析模式小分段控件（滑块平滑滑动，受动画开关控制）
                      DSSegmentedControl(
                        options: const [
                          (label: '本地', enabled: true, tooltip: null),
                          (label: 'AI', enabled: true, tooltip: null),
                        ],
                        selectedIndex: _mode == kParseModeAi ? 1 : 0,
                        duration: animOn ? kDurationNormal : Duration.zero,
                        onChanged: (i) =>
                            _setMode(i == 0 ? kParseModeLocal : kParseModeAi),
                      ),
                      const SizedBox(width: 8),
                      // 发送按钮
                      _SendActionButton(
                        key: const ValueKey('composer-send'),
                        busy: _busy,
                        onTap: _send,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单层主操作圆盘：高光完全裁剪在蓝色圆面内部，不叠加玻璃外环。
class _SendActionButton extends StatefulWidget {
  const _SendActionButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  State<_SendActionButton> createState() => _SendActionButtonState();
}

class _SendActionButtonState extends State<_SendActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final accent = tokens.accentBlue;
    final isGlass = tokens.glassBlurSigma > 0;
    final opacity = widget.busy
        ? (isGlass ? 0.2 : 0.5)
        : (isGlass ? (_hovered ? 0.42 : 0.34) : 1.0);
    final highlight = Color.lerp(
      accent,
      Colors.white,
      _hovered ? 0.26 : 0.18,
    )!.withValues(alpha: opacity * 0.68);
    final depth = Color.lerp(
      accent,
      Colors.black,
      _pressed ? 0.12 : 0.04,
    )!.withValues(alpha: (opacity * 0.96).clamp(0, 1));
    final iconColor = isGlass
        ? tokens.textPrimary.withValues(alpha: widget.busy ? 0.45 : 0.88)
        : Colors.white;

    return MouseRegion(
      cursor: widget.busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: widget.busy ? null : (_) => _setPressed(true),
        onPointerUp: widget.busy ? null : (_) => _setPressed(false),
        onPointerCancel: widget.busy ? null : (_) => _setPressed(false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: kDurationQuick,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.42),
                  radius: 1.15,
                  colors: [
                    highlight,
                    accent.withValues(alpha: opacity),
                    depth,
                  ],
                  stops: const [0, 0.58, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF182736)
                        .withValues(alpha: widget.busy ? 0.06 : 0.14),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: widget.busy
                  ? Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(iconColor),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward,
                      size: 16,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 输入条内图标按钮（上传等）：圆角 hover
class _ComposerIconButton extends StatefulWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_ComposerIconButton> createState() => _ComposerIconButtonState();
}

class _ComposerIconButtonState extends State<_ComposerIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final enabled = widget.onTap != null;
    final color = enabled ? tokens.accentBlue : tokens.textSecondary;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _hovered && enabled
                  ? tokens.textPrimary.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: color.withValues(alpha: enabled ? 1 : 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片附件缩略图 + 右上角删除
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({
    super.key,
    required this.path,
    required this.onRemove,
  });

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(path),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              color: tokens.textPrimary.withValues(alpha: 0.05),
              child: Icon(
                Icons.image_outlined,
                size: 20,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.cardBackground,
                  border: Border.all(color: tokens.divider),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 4),
                  ],
                ),
                child: Icon(Icons.close, size: 11, color: tokens.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}
