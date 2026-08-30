/// 今日待办列表（文档 10.2 节）：全天分区 + 定时分区，流式数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../domain/event_source_type.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../event/event_form.dart';

class TodayList extends ConsumerWidget {
  const TodayList({super.key, required this.day});

  final DateTime day;

  static const List<String> _weekNames = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DSTokensScope.of(context);
    final events = ref.watch(dayEventsProvider(day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${day.month}月${day.day}日 ${_weekNames[day.weekday - 1]}',
                  style: TextStyle(
                    fontSize: kFontSizeTitle,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              // 新建事件（替代原"双击日期新建"，保证单击选中即时响应）
              GestureDetector(
                onTap: () => showEventFormDialog(context, initialDate: day),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: tokens.textPrimary.withValues(alpha: 0.05),
                  ),
                  child: Icon(Icons.add, size: 16, color: tokens.accentBlue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: events.when(
            loading: () => const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                '加载失败：$e',
                style: TextStyle(fontSize: kFontSizeBody, color: tokens.dangerRed),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 36,
                        color: tokens.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '这一天还没有安排',
                        style: TextStyle(
                          fontSize: kFontSizeBody,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final allDay = list.where((e) => e.allDay).toList();
              final timed = list.where((e) => !e.allDay).toList()
                ..sort((a, b) => a.start.compareTo(b.start));

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  if (allDay.isNotEmpty) ...[
                    _SectionLabel(tokens: tokens, text: '全天'),
                    for (final e in allDay) _EventRow(event: e, day: day),
                  ],
                  if (timed.isNotEmpty) ...[
                    if (allDay.isNotEmpty) const SizedBox(height: 10),
                    _SectionLabel(tokens: tokens, text: '定时'),
                    for (final e in timed)
                      _EventRow(
                        event: e,
                        day: day,
                        timeText: _formatTime(e.start),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.tokens, required this.text});

  final DSTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: kFontSizeSmall,
          color: tokens.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventRow extends ConsumerStatefulWidget {
  const _EventRow({required this.event, required this.day, this.timeText});

  final Event event;
  final DateTime day;
  final String? timeText;

  @override
  ConsumerState<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends ConsumerState<_EventRow> {
  bool _hovered = false;

  Future<void> _confirmDelete() async {
    final ok = await showDSDialog<bool>(
      context,
      title: '删除事件',
      content: Text(
        '确定删除「${widget.event.title}」吗？删除后可到回收站恢复。',
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
          label: '删除',
          kind: DSButtonKind.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (ok == true) {
      await ref.read(eventDaoProvider).deleteEvent(widget.event.id);
    }
  }

  Future<void> _edit() async {
    await showEventFormDialog(context, existing: widget.event);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final sourceIcon = switch (widget.event.sourceType) {
      EventSourceType.text => Icons.text_fields,
      EventSourceType.image => Icons.image_outlined,
      EventSourceType.manual => Icons.edit_outlined,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: _edit,
        child: AnimatedContainer(
          duration: kDurationQuick,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? tokens.textPrimary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusCard - 2),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  widget.timeText ?? '全天',
                  style: TextStyle(
                    fontSize: kFontSizeCaption,
                    color: widget.timeText == null
                        ? tokens.accentBlue
                        : tokens.textPrimary,
                    fontWeight: widget.timeText == null
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: kFontSizeBody,
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (widget.event.location != null &&
                        widget.event.location!.isNotEmpty)
                      Text(
                        widget.event.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: kFontSizeSmall,
                          color: tokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (_hovered) ...[
                Icon(sourceIcon, size: 13, color: tokens.textSecondary),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _edit,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _confirmDelete,
                  child: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: tokens.dangerRed,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
