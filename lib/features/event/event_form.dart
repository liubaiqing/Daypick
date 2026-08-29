/// 事件表单（文档 10.3 节）：新建/编辑，校验后保存入库（手动创建 sourceType=manual）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// drift 的 Column/Table 与 Flutter 组件重名，隐藏之
import 'package:drift/drift.dart' hide Column, Table;

import '../../data/db/database.dart';
import '../../data/db/providers.dart';
import '../../data/db/tables.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_date_picker.dart';
import '../../shared/design/ds_dialog.dart';
import '../../shared/design/ds_text_field.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

/// 弹出事件表单；保存成功返回 true，取消/关闭返回 null/false。
Future<bool?> showEventFormDialog(
  BuildContext context, {
  Event? existing,
  DateTime? initialDate,
}) {
  return showDSDialog<bool>(
    context,
    title: existing == null ? '新建事件' : '编辑事件',
    content: _EventFormBody(existing: existing, initialDate: initialDate),
    actions: const [],
  );
}

class _EventFormBody extends ConsumerStatefulWidget {
  const _EventFormBody({this.existing, this.initialDate});

  final Event? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<_EventFormBody> createState() => _EventFormBodyState();
}

class _EventFormBodyState extends ConsumerState<_EventFormBody> {
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final base = e != null ? DateUtils.dateOnly(e.start) : DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    _date = base;
    _allDay = e?.allDay ?? false;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _startCtrl = TextEditingController(
      text: e != null && !e.allDay ? _fmt(e.start) : '09:00',
    );
    _endCtrl = TextEditingController(
      text: e != null && !e.allDay && e.end != null ? _fmt(e.end!) : '10:00',
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

  Future<void> _pickDate() async {
    final picked = await showDSDatePicker(context, initial: _date);
    if (picked != null) setState(() => _date = picked);
  }

  DateTime _parseTime(String text) {
    final m = _timeRe.firstMatch(text)!;
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
        } else if (_timeRe.hasMatch(_startCtrl.text.trim())) {
          final s = _parseTime(_startCtrl.text.trim());
          final t = _parseTime(_endCtrl.text.trim());
          if (t.isBefore(s)) _endError = '结束需不早于开始';
        }
      }
    });
    return _titleError == null && _startError == null && _endError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final dao = ref.read(eventDaoProvider);
    final title = _titleCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final start = _allDay
        ? DateTime(_date.year, _date.month, _date.day)
        : _parseTime(_startCtrl.text.trim());
    final end = _allDay ? null : _parseTime(_endCtrl.text.trim());
    final existing = widget.existing;
    try {
      if (existing == null) {
        await dao.insertEvent(EventsCompanion(
          title: Value(title),
          location: Value(location.isEmpty ? null : location),
          start: Value(start),
          end: Value(end),
          allDay: Value(_allDay),
          note: Value(note.isEmpty ? null : note),
          sourceType: Value(EventSourceType.manual),
          sourceText: const Value(null),
        ));
      } else {
        await dao.replaceEvent(existing.copyWith(
          title: title,
          location: Value(location.isEmpty ? null : location),
          start: start,
          end: Value(end),
          allDay: _allDay,
          note: Value(note.isEmpty ? null : note),
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        // 保存失败：表单内容保留，提示后重试（文档 14 章）
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSTextField(
            controller: _titleCtrl,
            hintText: '标题',
            errorText: _titleError,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _ReadonlyField(
                    label: '日期',
                    value:
                        '${_date.year}年${_date.month}月${_date.day}日',
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
                    _DSSwitch(
                      value: _allDay,
                      onChanged: (v) => setState(() => _allDay = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_allDay) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          DSTextField(controller: _locationCtrl, hintText: '地点（可选）'),
          const SizedBox(height: 12),
          DSTextField(controller: _noteCtrl, hintText: '备注（可选）'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: '取消',
                kind: DSButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 8),
              DSButton(label: '保存', onPressed: _save),
            ],
          ),
        ],
      ),
    );
  }
}

/// 只读展示字段（日期等），点击触发选择
class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusTextField),
        border: Border.all(color: tokens.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: tokens.accentBlue),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontSize: kFontSizeBody, color: tokens.textPrimary),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: kFontSizeSmall,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// macOS 风格开关（全天等布尔项）
class _DSSwitch extends StatelessWidget {
  const _DSSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: kDurationQuick,
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? tokens.successGreen : tokens.textSecondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: kDurationQuick,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
