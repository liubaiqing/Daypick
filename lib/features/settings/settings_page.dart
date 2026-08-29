/// 设置页（文档 11 章）：解析模式、LLM 配置（含测试连接）、数据管理（M4 接入）、关于。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/db/providers.dart';
import '../../data/export/backup_service.dart';
import '../../data/export/ics_exporter.dart';
import '../../data/llm/openai_compatible_client.dart';
import '../../domain/llm_providers.dart';
import '../../shared/design/ds_button.dart';
import '../../shared/design/ds_dropdown.dart';
import '../../shared/design/ds_segmented_control.dart';
import '../../shared/design/ds_text_field.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final OpenAiCompatibleClient _client = OpenAiCompatibleClient();

  String _parseMode = kDefaultParseMode;
  bool _loaded = false;
  bool _obscureKey = true;
  bool _testing = false;
  bool _dataBusy = false;
  String? _testResult; // null=未测试, 'ok'=成功, 其他=失败信息
  LlmProviderPreset? _selectedPreset; // null = 自定义

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dao = ref.read(settingsDaoProvider);
    final mode = await dao.get(kSettingParseMode) ?? kDefaultParseMode;
    final base = await dao.get(kSettingLlmBaseUrl) ?? kDefaultLlmBaseUrl;
    final key = await dao.get(kSettingLlmApiKey) ?? '';
    final model = await dao.get(kSettingLlmModel) ?? kDefaultLlmModel;
    if (!mounted) return;
    setState(() {
      _parseMode = mode;
      _baseUrlCtrl.text = base;
      _apiKeyCtrl.text = key;
      _modelCtrl.text = model;
      // 按 baseURL 反查预设回显；未匹配视为自定义
      _selectedPreset = presetForBaseUrl(base);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final dao = ref.read(settingsDaoProvider);
    await dao.set(kSettingParseMode, _parseMode);
    await dao.set(kSettingLlmBaseUrl, _baseUrlCtrl.text.trim());
    await dao.set(kSettingLlmApiKey, _apiKeyCtrl.text.trim());
    await dao.set(kSettingLlmModel, _modelCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _client.testConnection(
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'ok';
      });
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = '连接失败：$e';
      });
    }
  }

  Future<void> _exportIcs() async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出 ics',
      fileName: 'calendar_events.ics',
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (path == null) return;
    final events = await ref.read(eventDaoProvider).getAll();
    final content = const IcsExporter().build(events);
    await File(path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出 ${events.length} 条事件：$path')),
    );
  }

  Future<void> _exportBackup() async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出 JSON 备份',
      fileName: 'calendar_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;
    final content = await BackupService(ref.read(eventDaoProvider)).exportJson();
    await File(path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON 备份已导出（不含 API Key）')),
    );
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _dataBusy = true);
    try {
      final content = await File(path).readAsString();
      final summary =
          await BackupService(ref.read(eventDaoProvider)).restoreJson(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '恢复完成：新增 ${summary.restored} 条，跳过 ${summary.skipped} 条',
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '设置',
          style: TextStyle(
            fontSize: kFontSizeLargeTitle,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // ---- 解析 ----
        _SectionCard(
          title: '解析',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '默认解析模式（输入页可临时切换）',
                style: TextStyle(
                  fontSize: kFontSizeBody,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DSSegmentedControl(
                options: const [
                  (label: '本地解析', enabled: true, tooltip: null),
                  (label: 'AI 解析', enabled: true, tooltip: null),
                ],
                selectedIndex: _parseMode == kParseModeAi ? 1 : 0,
                onChanged: (i) => setState(
                  () => _parseMode = i == 0 ? kParseModeLocal : kParseModeAi,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '本地解析：离线规则引擎，无需网络；AI 解析：调用大模型，需要 API Key。',
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- AI 服务 ----
        _SectionCard(
          title: 'AI 服务（OpenAI 兼容）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '供应商',
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              DSDropdown<LlmProviderPreset?>(
                value: _selectedPreset,
                hintText: '请选择供应商',
                onChanged: (preset) => setState(() {
                  _selectedPreset = preset;
                  _testResult = null;
                  if (preset != null) {
                    // 选中预设自动回填 baseURL 与默认模型（文档 11 章）
                    _baseUrlCtrl.text = preset.baseUrl;
                    _modelCtrl.text = preset.defaultModel;
                  }
                }),
                items: [
                  for (final p in kLlmProviderPresets)
                    DSDropdownItem<LlmProviderPreset?>(
                      value: p,
                      label: p.name,
                      subtitle: p.baseUrl,
                    ),
                  const DSDropdownItem<LlmProviderPreset?>(
                    value: null,
                    label: '自定义',
                    subtitle: '手动填写 baseURL',
                  ),
                ],
              ),
              if (_selectedPreset == null) ...[
                const SizedBox(height: 10),
                DSTextField(controller: _baseUrlCtrl, hintText: 'baseURL'),
              ],
              const SizedBox(height: 10),
              DSTextField(
                controller: _apiKeyCtrl,
                hintText: 'API Key',
                obscureText: _obscureKey,
                onChanged: (_) => setState(() => _testResult = null),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  DSButton(
                    label: _obscureKey ? '显示' : '隐藏',
                    kind: DSButtonKind.secondary,
                    small: true,
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                  const Spacer(),
                  Text(
                    'Key 仅保存在本机数据库（明文，二期将加密）',
                    style: TextStyle(
                      fontSize: kFontSizeSmall,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DSTextField(controller: _modelCtrl, hintText: '模型名'),
              const SizedBox(height: 12),
              Row(
                children: [
                  DSButton(
                    label: _testing ? '测试中…' : '测试连接',
                    kind: DSButtonKind.secondary,
                    onPressed: _testing ? null : _testConnection,
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testResult == 'ok'
                            ? '连接成功'
                            : _testResult!,
                        style: TextStyle(
                          fontSize: kFontSizeSmall,
                          color: _testResult == 'ok'
                              ? tokens.successGreen
                              : tokens.dangerRed,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: DSButton(label: '保存设置', onPressed: _save),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- 数据管理 ----
        _SectionCard(
          title: '数据管理',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DSButton(
                    label: '导出 ics',
                    kind: DSButtonKind.secondary,
                    onPressed: _dataBusy ? null : _exportIcs,
                  ),
                  const SizedBox(width: 8),
                  DSButton(
                    label: '导出 JSON 备份',
                    kind: DSButtonKind.secondary,
                    onPressed: _dataBusy ? null : _exportBackup,
                  ),
                  const SizedBox(width: 8),
                  DSButton(
                    label: '恢复备份',
                    kind: DSButtonKind.secondary,
                    onPressed: _dataBusy ? null : _restoreBackup,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '导出文件保存在你选择的位置；恢复按 id 合并，已存在的事件跳过。备份不含 API Key。',
                style: TextStyle(
                  fontSize: kFontSizeSmall,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- 关于 ----
        _SectionCard(
          title: '关于',
          child: Text(
            'calendar v1.0.0+1 · Windows 桌面关键事务日历',
            style: TextStyle(fontSize: kFontSizeBody, color: tokens.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// 设置分组卡片
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: kFontSizeCaption,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
