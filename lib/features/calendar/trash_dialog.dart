/// 回收站窗口（文档 10.6 节）：软删除事件列表（按删除时间倒序）、
/// 逐条恢复、彻底清理（确认警告后物理删除，不可恢复）。
/// 入口：设置 → 数据管理 → "回收站"。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

/// 弹出回收站窗口；返回 true 表示发生任何变更（恢复/清理）。
Future<bool?> showTrashDialog(BuildContext context) {
  final animOn = ProviderScope.containerOf(context, listen: false)
          .read(animationsEnabledProvider)
          .value ??
      true;
  final transition = animOn ? kDurationQuick : Duration.zero;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'trash',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: transition,
    pageBuilder: (context, _, _) {
      final tokens = DSTokensScope.of(context);
      return Center(
        child: Container(
          width: 560,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            borderRadius: BorderRadius.circular(kRadiusPanel),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const TrashDialogBody(),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}

class TrashDialogBody extends ConsumerStatefulWidget {
  const TrashDialogBody({super.key});

  @override
  ConsumerState<TrashDialogBody> createState() => _TrashDialogBodyState();
}

class _TrashDialogBodyState extends ConsumerState<TrashDialogBody> {
  List<Event> _trash = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final trash = await ref.read(eventDaoProvider).getTrash();
    if (!mounted) return;
    setState(() {
      _trash = trash;
      _loading = false;
    });
  }

  Future<void> _restore(Event e) async {
    setState(() => _busy = true);
    await ref.read(eventDaoProvider).restoreEvent(e.id);
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _emptyTrash() async {
    final ok = await showDSDialog<bool>(
      context,
      title: '彻底清理',
      content: Text(
        '将彻底删除回收站中全部 ${_trash.length} 个事件，此操作不可恢复。',
        style: TextStyle(
          fontSize: kFontSizeBody,
          color: DSTokensScope.of(context).textPrimary,
        ),
      ),
      actions: [
        DSButton(
          label: '取消',
          kind: DSButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DSButton(
          label: '彻底清理',
          kind: DSButtonKind.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await ref.read(eventDaoProvider).emptyTrash();
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Text(
                '回收站',
                style: TextStyle(
                  fontSize: kFontSizeTitle,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.delete_outline, size: 18, color: tokens.textSecondary),
            ],
          ),
        ),
        Container(height: 1, color: tokens.divider),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : trashList(),
        ),
        Container(height: 1, color: tokens.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Text(
                '共 ${_trash.length} 个已删除事件',
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              DSButton(
                key: const ValueKey('trash-close'),
                label: '关闭',
                kind: DSButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              DSButton(
                key: const ValueKey('trash-empty-btn'),
                label: _busy ? '处理中…' : '彻底清理',
                kind: DSButtonKind.destructive,
                onPressed: _trash.isEmpty || _busy ? null : _emptyTrash,
              ),
            ],
          ),
        ),
      ],
    );
  }
  /// 回收站列表主体（空态 / 行列表）
  Widget trashList() {
    final tokens = DSTokensScope.of(context);
    if (_trash.isEmpty) {
      return Center(
        child: Text(
          '回收站是空的',
          key: const ValueKey('trash-empty'),
          style: TextStyle(
            fontSize: kFontSizeBody,
            color: tokens.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: _trash.length,
      separatorBuilder: (_, _) => Container(height: 1, color: tokens.divider),
      itemBuilder: (context, i) => _TrashRow(
        event: _trash[i],
        busy: _busy,
        onRestore: () => _restore(_trash[i]),
      ),
    );
  }
}

/// 回收站行：原日期/时间/标题 + 删除时间 + hover 恢复按钮
class _TrashRow extends StatefulWidget {
  const _TrashRow({
    required this.event,
    required this.busy,
    required this.onRestore,
  });

  final Event event;
  final bool busy;
  final VoidCallback onRestore;

  @override
  State<_TrashRow> createState() => _TrashRowState();
}

class _TrashRowState extends State<_TrashRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final e = widget.event;
    final time = e.allDay
        ? '全天'
        : '${_two(e.start.hour)}:${_two(e.start.minute)}';
    final deletedAt = e.deletedAt;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(
                '${e.start.month}月${e.start.day}日',
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            if (deletedAt != null)
              Text(
                '${deletedAt.month}月${deletedAt.day}日 '
                '${_two(deletedAt.hour)}:${_two(deletedAt.minute)} 删除',
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            const SizedBox(width: 10),
            // hover 浮现恢复按钮
            AnimatedOpacity(
              duration: kDurationQuick,
              opacity: _hovered ? 1 : 0,
              child: DSButton(
                key: ValueKey('trash-restore-${e.id}'),
                label: '恢复',
                kind: DSButtonKind.secondary,
                small: true,
                onPressed: widget.busy ? null : widget.onRestore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
