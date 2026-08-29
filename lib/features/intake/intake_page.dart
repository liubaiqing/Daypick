/// 输入页（文档 8 章）：文本/图片输入 → OCR（图片）→ 解析（本地/AI 模式）→ 待确认卡片流。
/// 状态机：idle → inputReady → ocrRunning(图片) → textReady → parsing → cardsReady。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../data/db/providers.dart';
import '../../data/llm/openai_compatible_client.dart';
import '../../data/ocr/ocr_service.dart';
import '../../data/parsers/ai_parser.dart';
import '../../data/parsers/local_parser.dart';
import '../../domain/parsed_event.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_segmented_control.dart';
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
  final OpenAiCompatibleClient _llmClient = OpenAiCompatibleClient();
  final OcrService _ocrService = const OcrService();

  _ParseMode _mode = _ParseMode.local;
  bool _parsing = false;
  bool _ocrBusy = false;
  String? _error;
  List<DraftEntry> _cards = const [];

  @override
  void initState() {
    super.initState();
    // 默认解析模式来自设置（文档 11 章）
    ref.read(settingsDaoProvider).get(kSettingParseMode).then((mode) {
      if (!mounted || mode == null) return;
      setState(() => _mode = mode == kParseModeAi ? _ParseMode.ai : _ParseMode.local);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ 图片输入（OCR）

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    await _runOcr(() => _ocrService.recognizeFile(path));
  }

  Future<void> _pasteImage() async {
    final bytes = await Pasteboard.image;
    if (bytes == null) {
      _showError('剪贴板中没有图片');
      return;
    }
    await _runOcr(() => _ocrService.recognizeBytes(bytes));
  }

  Future<void> _runOcr(Future<String> Function() recognize) async {
    if (_ocrBusy) return;
    setState(() {
      _ocrBusy = true;
      _error = null;
    });
    try {
      final text = await recognize();
      if (!mounted) return;
      setState(() {
        _ocrBusy = false;
        _inputCtrl.text = text.trim();
      });
    } on OcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrBusy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrBusy = false;
        _error = '识别失败：$e';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  // ------------------------------------------------------------ 解析

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
        _ParseMode.ai => await _parseWithAi(text),
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

  Future<List<ParsedEvent>> _parseWithAi(String text) async {
    final dao = ref.read(settingsDaoProvider);
    final config = AiConfig(
      baseUrl: await dao.get(kSettingLlmBaseUrl) ?? kDefaultLlmBaseUrl,
      apiKey: await dao.get(kSettingLlmApiKey) ?? '',
      model: await dao.get(kSettingLlmModel) ?? kDefaultLlmModel,
    );
    final parser = AiParser(client: _llmClient, config: config);
    return parser.parse(text);
  }

  Future<void> _saveAll() async {
    var savedCount = 0;
    for (final card in _cards) {
      if (card.saved) continue;
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

  // ------------------------------------------------------------ UI

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
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              DSSegmentedControl(
                options: const [
                  (label: '本地解析', enabled: true, tooltip: null),
                  (label: 'AI 解析', enabled: true, tooltip: null),
                ],
                selectedIndex: _mode.index,
                onChanged: (i) => setState(
                  () => _mode = i == 0 ? _ParseMode.local : _ParseMode.ai,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            '粘贴或输入包含时间、地点、事务的文本；也可上传/粘贴图片自动识别（OCR）',
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
              const SizedBox(width: 8),
              DSButton(
                label: _ocrBusy ? '识别中…' : '选择图片',
                kind: DSButtonKind.secondary,
                onPressed: _ocrBusy ? null : _pickImage,
              ),
              const SizedBox(width: 8),
              DSButton(
                label: _ocrBusy ? '识别中…' : '粘贴图片',
                kind: DSButtonKind.secondary,
                onPressed: _ocrBusy ? null : _pasteImage,
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
                    fontWeight: FontWeight.w700,
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
