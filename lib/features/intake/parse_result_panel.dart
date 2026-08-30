/// 解析结果面板（文档 8 章调整）：独立弹层展示待确认卡片流。
/// 逐条可编辑、保存才入库；关闭时若有未保存草稿需确认。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/providers.dart';
import '../../domain/parsed_event.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_glass_surface.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import 'confirm_card.dart';

/// 弹出解析结果面板
Future<void> showParseResultPanel(
  BuildContext context,
  List<ParsedEvent> events,
) {
  final tokens = DSTokensScope.of(context);
  // 动画开关：关闭时过渡瞬间完成
  final animOn = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(animationsEnabledProvider).value ??
      true;
  final transition = animOn ? kDurationQuick : Duration.zero;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'parse-result-panel',
    barrierColor: tokens.modalBarrier,
    transitionDuration: transition,
    pageBuilder: (context, _, _) => _ParseResultPanel(events: events),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.97,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

class _ParseResultPanel extends ConsumerStatefulWidget {
  const _ParseResultPanel({required this.events});

  final List<ParsedEvent> events;

  @override
  ConsumerState<_ParseResultPanel> createState() => _ParseResultPanelState();
}

class _ParseResultPanelState extends ConsumerState<_ParseResultPanel> {
  late final List<DraftEntry> _entries = [
    for (final e in widget.events) DraftEntry(e),
  ];

  int get _unsavedCount => _entries.where((e) => !e.saved).length;

  Future<void> _saveAll() async {
    var savedCount = 0;
    for (final card in _entries) {
      if (card.saved) continue;
      final state = card.key.currentState;
      if (state != null && await state.saveNow()) savedCount++;
    }
    if (!mounted) return;
    setState(() {});
    if (savedCount > 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已保存 $savedCount 条事件到日历')));
    }
  }

  Future<void> _requestClose() async {
    if (_unsavedCount > 0) {
      final ok = await showDSDialog<bool>(
        context,
        title: '关闭面板',
        content: Text(
          '还有 $_unsavedCount 条草稿未保存，关闭将丢弃这些草稿。确定关闭吗？',
          style: TextStyle(
            fontSize: kFontSizeBody,
            color: DSTokensScope.of(context).textPrimary,
          ),
        ),
        actions: [
          DSButton(
            label: '继续编辑',
            kind: DSButtonKind.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DSButton(
            label: '关闭并丢弃',
            kind: DSButtonKind.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final unsaved = _unsavedCount;
    return Center(
      child: DSGlassSurface(
        kind: DSGlassSurfaceKind.dialog,
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Text(
                    '待确认事件（$unsaved 条未保存）',
                    style: TextStyle(
                      fontSize: kFontSizeTitle,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _PanelCloseButton(
                    key: const ValueKey('panel-close'),
                    onTap: _requestClose,
                  ),
                ],
              ),
            ),
            Container(height: 1, color: tokens.divider),
            // 卡片列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  for (final entry in _entries)
                    ConfirmCard(
                      key: entry.key,
                      entry: entry,
                      onChanged: () => setState(() {}),
                      onDelete: () => setState(() {
                        _entries.remove(entry);
                      }),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: tokens.divider),
            // 底部操作
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DSButton(
                    label: '关闭',
                    kind: DSButtonKind.secondary,
                    onPressed: _requestClose,
                  ),
                  const SizedBox(width: 8),
                  if (unsaved > 0) DSButton(label: '全部保存', onPressed: _saveAll),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 面板右上角关闭按钮（圆角 hover）
class _PanelCloseButton extends StatefulWidget {
  const _PanelCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PanelCloseButton> createState() => _PanelCloseButtonState();
}

class _PanelCloseButtonState extends State<_PanelCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered
                ? tokens.textPrimary.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Icon(Icons.close, size: 15, color: tokens.textSecondary),
        ),
      ),
    );
  }
}
