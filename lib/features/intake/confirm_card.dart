/// 确认卡片（文档 8.2/8.3 节）：草稿逐条可编辑，保存才写入数据库。
/// 缺失字段红色高亮、低置信"建议人工核对"徽标、过去日期提示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// drift 的 Column/Table 与 Flutter 组件重名，隐藏之
import 'package:drift/drift.dart' hide Column, Table;

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../domain/parsed_event.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_date_picker.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_switch.dart';
import '../../shared/design/ds_text_field.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

/// 草稿卡片条目状态（由输入页持有）
class DraftEntry {
  DraftEntry(this.event);

  ParsedEvent event;

  /// 已确认写入数据库
  bool saved = false;

  /// 写入后的事件 id（用于撤销删除）
  int? savedId;

  /// 供"全部保存"批量触发卡片保存
  final GlobalKey<ConfirmCardState> key = GlobalKey<ConfirmCardState>();
}

class ConfirmCard extends ConsumerStatefulWidget {
  const ConfirmCard({
    super.key,
    required this.entry,
    required this.onChanged,
    required this.onDelete,
  });

  final DraftEntry entry;
  final VoidCallback onChanged;

  /// 删除草稿（不写库，从列表移除）
  final VoidCallback onDelete;

  @override
  ConsumerState<ConfirmCard> createState() => ConfirmCardState();
}

class ConfirmCardState extends ConsumerState<ConfirmCard> {
  static final RegExp _timeRe = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$');

  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late DateTime _date;
  late bool _allDay;
  String? _titleError;
  String? _startError;
  String? _endError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry.event;
    _date = e.start == null
        ? DateUtils.dateOnly(DateTime.now())
        : DateUtils.dateOnly(e.start!);
    _allDay = e.allDay;
    _titleCtrl = TextEditingController(text: e.title);
    _locationCtrl = TextEditingController(text: e.location ?? '');
    _noteCtrl = TextEditingController(text: e.note ?? '');
    _startCtrl = TextEditingController(
      text: e.start == null || e.allDay ? '09:00' : _fmt(e.start!),
    );
    _endCtrl = TextEditingController(
      text: e.end == null ? '10:00' : _fmt(e.end!),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  DateTime? _parseTime(String text) {
    final m = _timeRe.firstMatch(text.trim());
    if (m == null) return null;
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    );
  }

  bool _validate() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty ? '请填写标题' : null;
      _startError = null;
      _endError = null;
      if (!_allDay) {
        if (!_timeRe.hasMatch(_startCtrl.text.trim())) {
          _startError = '格式如 09:00';
        }
        if (!_timeRe.hasMatch(_endCtrl.text.trim())) {
          _endError = '格式如 10:00';
        } else {
          final s = _parseTime(_startCtrl.text.trim());
          final t = _parseTime(_endCtrl.text.trim());
          if (s != null && t != null && t.isBefore(s)) {
            _endError = '结束需不早于开始';
          }
        }
      }
    });
    return _titleError == null && _startError == null && _endError == null;
  }

  /// 保存草稿入库（确认流的唯一写库路径）；成功返回 true
  Future<bool> saveNow() async {
    if (_saving) return false;
    if (!_validate()) return false;
    final dao = ref.read(eventDaoProvider);
    final title = _titleCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final start = _allDay
        ? DateTime(_date.year, _date.month, _date.day)
        : _parseTime(_startCtrl.text.trim());
    if (start == null) return false;
    final end = _allDay ? null : _parseTime(_endCtrl.text.trim());
    final source = widget.entry.event;
    setState(() => _saving = true);
    try {
      final id = await dao.insertEvent(EventsCompanion(
        title: Value(title),
        location: Value(location.isEmpty ? null : location),
        start: Value(start),
        end: Value(end),
        allDay: Value(_allDay),
        note: Value(note.isEmpty ? null : note),
        sourceType: Value(source.sourceType),
        sourceText: Value(source.sourceText),
      ));
      if (!mounted) return true;
      setState(() {
        _saving = false;
        widget.entry.saved = true;
        widget.entry.savedId = id;
      });
      widget.onChanged();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
      return false;
    }
  }

  Future<void> _undo() async {
    final ok = await showDSDialog<bool>(
      context,
      title: '撤销保存',
      content: Text(
        '将从日历中删除该事件，确定撤销吗？',
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
          label: '撤销',
          kind: DSButtonKind.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (ok != true || widget.entry.savedId == null) return;
    await ref.read(eventDaoProvider).deleteEvent(widget.entry.savedId!);
    if (!mounted) return;
    setState(() {
      widget.entry.saved = false;
      widget.entry.savedId = null;
    });
    widget.onChanged();
  }

  Future<void> _pickDate() async {
    final picked = await showDSDatePicker(context, initial: _date);
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final e = widget.entry.event;
    final saved = widget.entry.saved;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saved
            ? tokens.textPrimary.withValues(alpha: 0.03)
            : tokens.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(
          color: saved ? tokens.successGreen.withValues(alpha: 0.4) : tokens.divider,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 来源原文（可追溯）
          Text(
            e.sourceText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: kFontSizeSmall,
              color: tokens.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          // 警告徽标
          if (e.lowConfidence || e.isPastDate(DateTime.now())) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (e.lowConfidence)
                  _Badge(
                    label: '建议人工核对',
                    color: tokens.warningOrange,
                  ),
                if (e.isPastDate(DateTime.now()))
                  _Badge(label: '日期已过', color: tokens.textSecondary),
              ],
            ),
          ],
          const SizedBox(height: 10),
          DSTextField(
            controller: _titleCtrl,
            hintText: '标题',
            errorText: _titleError,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: saved ? null : _pickDate,
                  child: _DateField(
                    date: _date,
                    highlight: e.hasMissingTime && !saved,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '全天',
                      style: TextStyle(
                        fontSize: kFontSizeBody,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DSSwitch(
                      value: _allDay,
                      enabled: !saved,
                      onChanged: (v) => setState(() => _allDay = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_allDay) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DSTextField(
                    controller: _startCtrl,
                    hintText: '开始 09:00',
                    errorText: _startError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DSTextField(
                    controller: _endCtrl,
                    hintText: '结束 10:00',
                    errorText: _endError,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          DSTextField(controller: _locationCtrl, hintText: '地点（可选）'),
          const SizedBox(height: 10),
          DSTextField(controller: _noteCtrl, hintText: '备注（可选）'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: saved
                ? [
                    Icon(
                      Icons.check_circle,
                      size: 15,
                      color: tokens.successGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已保存',
                      style: TextStyle(
                        fontSize: kFontSizeBody,
                        color: tokens.successGreen,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    DSButton(
                      label: '撤销',
                      kind: DSButtonKind.secondary,
                      small: true,
                      onPressed: _undo,
                    ),
                  ]
                : [
                    DSButton(
                      label: '删除',
                      kind: DSButtonKind.destructive,
                      small: true,
                      onPressed: widget.onDelete,
                    ),
                    const SizedBox(width: 8),
                    DSButton(
                      label: _saving ? '保存中…' : '保存',
                      small: true,
                      onPressed: _saving ? null : saveNow,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// 橙色/灰色徽标
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: kFontSizeSmall, color: color),
      ),
    );
  }
}

/// 日期只读字段；缺时间草稿红色高亮提示补全
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.highlight});

  final DateTime date;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final borderColor = highlight ? tokens.dangerRed : tokens.divider;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusTextField),
        border: Border.all(color: borderColor, width: highlight ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 13,
            color: highlight ? tokens.dangerRed : tokens.accentBlue,
          ),
          const SizedBox(width: 6),
          Text(
            '${date.year}年${date.month}月${date.day}日',
            style: TextStyle(fontSize: kFontSizeBody, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
