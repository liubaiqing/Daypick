/// 输入页（文档 8 章）：文本输入 → 解析（本地/AI 模式）→ 待确认卡片流。
/// 状态机：idle → inputReady → parsing → cardsReady（逐条保存/删除/全部保存）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../data/parsers/local_parser.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import 'confirm_card.dart';

enum _ParseMode { local, ai }

class IntakePage extends ConsumerStatefulWidget {
  const IntakePage({super.key});

  @override
  ConsumerState<IntakePage> createState() => _IntakePageState();
}

class _IntakePageState extends ConsumerState<IntakePage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final LocalParser _localParser = LocalParser();
  _ParseMode _mode = _ParseMode.local;
  bool _parsing = false;
  String? _error;
  List<DraftEntry> _cards = const [];

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _parsing) return;
    setState(() {
      _parsing = true;
      _error = null;
    });
    try {
      final events = switch (_mode) {
        _ParseMode.local => await _localParser.parse(text),
        _ParseMode.ai => throw const AiParseException(
            'AI 解析模式将在后续版本接入，请先使用本地模式',
          ),
      };
      if (!mounted) return;
      setState(() {
        _cards = [for (final e in events) DraftEntry(e)];
        _parsing = false;
      });
    } on ParserException catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _error = '解析失败：$e';
      });
    }
  }

  Future<void> _saveAll() async {
    var savedCount = 0;
    for (final card in _cards) {
      if (card.saved) continue;
      // 通过 GlobalKey 触发卡片保存
      final state = card.key.currentState;
      if (state != null && await state.saveNow()) savedCount++;
    }
    if (!mounted) return;
    setState(() {}); // 刷新全部保存按钮状态
    if (savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 $savedCount 条事件到日历')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final hasCards = _cards.isNotEmpty;
    final unsavedCount = _cards.where((c) => !c.saved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Text(
                '新建事务',
                style: TextStyle(
                  fontSize: kFontSizeLargeTitle,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              _SegmentedControl(
                options: const [
                  (label: '本地解析', enabled: true),
                  (label: 'AI 解析', enabled: false),
                ],
                selectedIndex: _mode.index,
                onChanged: (i) {
                  if (_mode.index != i && i == 0) {
                    setState(() => _mode = _ParseMode.local);
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            '粘贴包含时间、地点、事务的文本（图片识别将在后续版本提供）',
            style: TextStyle(
              fontSize: kFontSizeSmall,
              color: tokens.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(kRadiusTextField),
              border: Border.all(color: tokens.divider),
            ),
            child: TextField(
              controller: _inputCtrl,
              minLines: 3,
              maxLines: 6,
              style:
                  TextStyle(fontSize: kFontSizeBody, color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: '例如：3月15日下午2点去上海虹桥机场出差',
                hintStyle: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textSecondary.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              DSButton(
                label: _parsing ? '解析中…' : '解析',
                onPressed: _parsing ? null : _parse,
              ),
              if (_error != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: kFontSizeSmall,
                      color: tokens.dangerRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasCards) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Text(
                  '待确认（$unsavedCount 条未保存）',
                  style: TextStyle(
                    fontSize: kFontSizeCaption,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const Spacer(),
                if (unsavedCount > 0)
                  DSButton(label: '全部保存', small: true, onPressed: _saveAll),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                for (final entry in _cards)
                  ConfirmCard(
                    key: entry.key,
                    entry: entry,
                    onChanged: () => setState(() {}),
                    onDelete: () => setState(
                      () => _cards = [
                        for (final c in _cards)
                          if (c != entry) c,
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// macOS 风格分段控件（文档 9.6 节 DSSegmentedControl）
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<({String label, bool enabled})> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _Segment(
              label: options[i].label,
              enabled: options[i].enabled,
              selected: i == selectedIndex,
              onTap: options[i].enabled ? () => onChanged(i) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final fg = !enabled
        ? tokens.textSecondary.withValues(alpha: 0.5)
        : selected
            ? tokens.textPrimary
            : tokens.textSecondary;
    return Tooltip(
      message: enabled ? '' : 'AI 解析将在后续版本接入',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: kDurationQuick,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? tokens.cardBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: kFontSizeCaption,
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
