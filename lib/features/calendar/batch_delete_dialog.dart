/// 批量删除窗口（文档 10.5 节）：按月列出事件 + 逐条勾选 + 全选 +
/// 已选计数；确认删除后事件进入回收站（软删除，可恢复）。
/// 入口：设置 → 数据管理 → "批量删除事件"。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_checkbox.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_glass_surface.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

/// 弹出批量删除窗口；返回 true 表示发生过删除。
Future<bool?> showBatchDeleteDialog(BuildContext context) {
  final animOn = ProviderScope.containerOf(context, listen: false)
          .read(animationsEnabledProvider)
          .value ??
      true;
  final transition = animOn ? kDurationQuick : Duration.zero;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'batch-delete',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: transition,
    pageBuilder: (context, _, _) {
      return Center(
        child: DSGlassSurface(
          width: 560,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: const BatchDeleteDialogBody(),
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

class BatchDeleteDialogBody extends ConsumerStatefulWidget {
  const BatchDeleteDialogBody({super.key});

  @override
  ConsumerState<BatchDeleteDialogBody> createState() =>
      _BatchDeleteDialogBodyState();
}

class _BatchDeleteDialogBodyState extends ConsumerState<BatchDeleteDialogBody> {
  late DateTime _month;
  List<Event> _events = const [];
  final Set<int> _selected = {};
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final events = await ref.read(eventDaoProvider).getMonth(_month);
    if (!mounted) return;
    setState(() {
      _events = events;
      _selected.clear();
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  bool get _allSelected =>
      _events.isNotEmpty && _selected.length == _events.length;

  Future<void> _confirmDelete() async {
    final ok = await showDSDialog<bool>(
      context,
      title: '批量删除',
      content: Text(
        '将删除 ${_selected.length} 个事件，删除后可在回收站恢复。',
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
          key: const ValueKey('batch-delete-confirm-dialog'),
          label: '删除',
          kind: DSButtonKind.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (ok != true || _selected.isEmpty) return;
    setState(() => _deleting = true);
    await ref
        .read(eventDaoProvider)
        .softDeleteMany(_selected.toList(growable: false));
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
                '批量删除事件',
                style: TextStyle(
                  fontSize: kFontSizeTitle,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              // 月份切换
              _MonthSwitcher(
                month: _month,
                onPrev: () => _changeMonth(-1),
                onNext: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        Container(height: 1, color: tokens.divider),
        // 全选行
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              DSCheckbox(
                key: const ValueKey('batch-select-all'),
                value: _allSelected,
                onChanged: (v) => setState(() {
                  _selected.clear();
                  if (v) {
                    _selected.addAll(_events.map((e) => e.id));
                  }
                }),
              ),
              const SizedBox(width: 10),
              Text(
                '全选（本月 ${_events.length} 个事件）',
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _events.isEmpty
                  ? Center(
                      child: Text(
                        '这个月没有事件',
                        style: TextStyle(
                          fontSize: kFontSizeBody,
                          color: tokens.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      itemCount: _events.length,
                      separatorBuilder: (_, _) =>
                          Container(height: 1, color: tokens.divider),
                      itemBuilder: (context, i) {
                        final e = _events[i];
                        return _EventRow(
                          event: e,
                          checked: _selected.contains(e.id),
                          onChanged: (v) => setState(() {
                            if (v) {
                              _selected.add(e.id);
                            } else {
                              _selected.remove(e.id);
                            }
                          }),
                        );
                      },
                    ),
        ),
        Container(height: 1, color: tokens.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Text(
                '已选 ${_selected.length} 个',
                key: const ValueKey('batch-selected-count'),
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              DSButton(
                label: '取消',
                kind: DSButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              DSButton(
                key: const ValueKey('batch-delete-confirm'),
                label: _deleting ? '删除中…' : '删除',
                kind: DSButtonKind.destructive,
                onPressed: _selected.isEmpty || _deleting
                    ? null
                    : _confirmDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 月份切换器：`2026年8月` + 左右箭头
class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(icon: Icons.chevron_left, onTap: onPrev),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${month.year}年${month.month}月',
            key: const ValueKey('batch-month-label'),
            style: TextStyle(
              fontSize: kFontSizeBody,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
        _ArrowButton(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
          child: Icon(widget.icon, size: 16, color: tokens.textSecondary),
        ),
      ),
    );
  }
}

/// 事件行：勾选框 + 日期/时间 + 标题 + 地点
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.checked,
    required this.onChanged,
  });

  final Event event;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final time = event.allDay
        ? '全天'
        : '${_two(event.start.hour)}:${_two(event.start.minute)}'
            '${event.end == null ? '' : ' – ${_two(event.end!.hour)}:${_two(event.end!.minute)}'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          DSCheckbox(
            key: ValueKey('batch-check-${event.id}'),
            value: checked,
            onChanged: onChanged,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 74,
            child: Text(
              '${event.start.month}月${event.start.day}日',
              style: TextStyle(
                fontSize: kFontSizeBody,
                color: tokens.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 96,
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
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: kFontSizeBody,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
          ),
          if (event.location != null && event.location!.isNotEmpty)
            Flexible(
              child: Text(
                event.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
