/// 设置内容（文档 11 章）：外观、AI 服务（LLM 配置）、数据管理、关于。
/// 以弹窗形式呈现（左下角圆形设置按钮触发，见 showSettingsDialog）。
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
import '../../shared/design/ds_glass_surface.dart';
import '../../shared/design/ds_segmented_control.dart';
import '../../shared/design/ds_switch.dart';
import '../../shared/design/ds_text_field.dart';
import '../../shared/design/ds_tokens.dart';
import '../../shared/design/dstokens_scope.dart';
import '../calendar/batch_delete_dialog.dart';
import '../calendar/trash_dialog.dart';

/// 弹出设置小窗（左下角圆形按钮触发）
Future<void> showSettingsDialog(BuildContext context) {
  final tokens = DSTokensScope.of(context);
  final animOn = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(animationsEnabledProvider).value ??
      true;
  final transition = animOn ? kDurationQuick : Duration.zero;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'settings',
    barrierColor: tokens.modalBarrier,
    transitionDuration: transition,
    pageBuilder: (context, _, _) {
      return Center(
        child: DSGlassSurface(
          kind: DSGlassSurfaceKind.dialog,
          width: 560,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: kFontSizeTitle,
                        fontWeight: FontWeight.w700,
                        color: DSTokensScope.of(context).textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _DialogCloseButton(
                      key: const ValueKey('settings-close'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: DSTokensScope.of(context).divider),
              Expanded(child: SettingsDialogBody()),
            ],
          ),
        ),
      );
    },
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

/// 弹窗右上角关闭按钮
class _DialogCloseButton extends StatefulWidget {
  const _DialogCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DialogCloseButton> createState() => _DialogCloseButtonState();
}

class _DialogCloseButtonState extends State<_DialogCloseButton> {
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

class SettingsDialogBody extends ConsumerStatefulWidget {
  const SettingsDialogBody({super.key});

  @override
  ConsumerState<SettingsDialogBody> createState() => _SettingsDialogBodyState();
}

class _SettingsDialogBodyState extends ConsumerState<SettingsDialogBody> {
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  final OpenAiCompatibleClient _client = OpenAiCompatibleClient();

  bool _loaded = false;
  bool _obscureKey = true;
  bool _testing = false;
  bool _dataBusy = false;
  bool _animationsEnabled = true;
  String _themeMode = kDefaultThemeMode;
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
    final base = await dao.get(kSettingLlmBaseUrl) ?? kDefaultLlmBaseUrl;
    final key = await dao.get(kSettingLlmApiKey) ?? '';
    final model = await dao.get(kSettingLlmModel) ?? kDefaultLlmModel;
    final anims = await dao.get(kSettingAnimationsEnabled);
    final theme = await dao.get(kSettingThemeMode);
    if (!mounted) return;
    setState(() {
      _baseUrlCtrl.text = base;
      _apiKeyCtrl.text = key;
      _modelCtrl.text = model;
      _animationsEnabled = anims != '0';
      _themeMode = theme ?? kDefaultThemeMode;
      // 按 baseURL 反查预设回显；未匹配视为自定义
      _selectedPreset = presetForBaseUrl(base);
      _loaded = true;
    });
  }

  Future<void> _toggleAnimations(bool enabled) async {
    setState(() => _animationsEnabled = enabled);
    await ref
        .read(settingsDaoProvider)
        .set(kSettingAnimationsEnabled, enabled ? '1' : '0');
    ref.invalidate(animationsEnabledProvider);
  }

  Future<void> _setThemeMode(String mode) async {
    setState(() => _themeMode = mode);
    await ref.read(settingsDaoProvider).set(kSettingThemeMode, mode);
    ref.invalidate(themeModeProvider);
  }

  Future<void> _save() async {
    final dao = ref.read(settingsDaoProvider);
    await dao.set(kSettingLlmBaseUrl, _baseUrlCtrl.text.trim());
    await dao.set(kSettingLlmApiKey, _apiKeyCtrl.text.trim());
    await dao.set(kSettingLlmModel, _modelCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('设置已保存')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导出 ${events.length} 条事件：$path')));
  }

  Future<void> _exportBackup() async {
    final path = await FilePicker.saveFile(
      dialogTitle: '导出 JSON 备份',
      fileName: 'calendar_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;
    final content =
        await BackupService(ref.read(eventDaoProvider)).exportJson();
    await File(path).writeAsString(content);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('JSON 备份已导出（不含 API Key）')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
  }

  Future<void> _openBatchDelete() async {
    // 批量删除窗口：按月勾选删除（文档 10.5 节）
    await showBatchDeleteDialog(context);
  }

  Future<void> _openTrash() async {
    // 回收站窗口：恢复 / 彻底清理（文档 10.6 节）
    await showTrashDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final isGlass = tokens.glassBlurSigma > 0;
    final sectionGap = isGlass ? 6.0 : 14.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, isGlass ? 8 : 12, 16, 20),
      children: [
        // ---- 外观 ----
        _SettingsSection(
          surfaceKey: const ValueKey('settings-section-appearance'),
          title: '外观',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '启用界面动画',
                      style: TextStyle(
                        fontSize: kFontSizeBody,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '日期聚焦动画、侧边栏收起与弹层过渡（关闭以适配低性能设备）',
                      style: TextStyle(
                        fontSize: kFontSizeSmall,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DSSwitch(
                value: _animationsEnabled,
                onChanged: _toggleAnimations,
                activeColor: tokens.successGreen,
              ),
            ],
          ),
        ),
        SizedBox(height: sectionGap),

        // ---- 主题（文档 11 章：浅色/深色/毛玻璃三选一）----
        _SettingsSection(
          surfaceKey: const ValueKey('settings-section-theme'),
          title: '主题',
          child: DSSegmentedControl(
            key: const ValueKey('settings-theme-segment'),
            options: const [
              (label: '浅色', enabled: true, tooltip: null),
              (label: '深色', enabled: true, tooltip: null),
              (label: '毛玻璃', enabled: true, tooltip: null),
            ],
            selectedIndex: switch (_themeMode) {
              kThemeModeDark => 1,
              kThemeModeGlass => 2,
              _ => 0,
            },
            onChanged: (i) => _setThemeMode(switch (i) {
              1 => kThemeModeDark,
              2 => kThemeModeGlass,
              _ => kThemeModeLight,
            }),
          ),
        ),
        SizedBox(height: sectionGap),

        // ---- AI 服务 ----
        _SettingsSection(
          surfaceKey: const ValueKey('settings-section-ai'),
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
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
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
                        _testResult == 'ok' ? '连接成功' : _testResult!,
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
                child: DSButton(
                  label: '保存设置',
                  onPressed: _save,
                  color: tokens.accentBlue,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sectionGap),

        // ---- 数据管理 ----
        _SettingsSection(
          surfaceKey: const ValueKey('settings-section-data'),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  DSButton(
                    key: const ValueKey('settings-batch-delete'),
                    label: '批量删除事件',
                    kind: DSButtonKind.secondary,
                    onPressed: _dataBusy ? null : _openBatchDelete,
                  ),
                  const SizedBox(width: 8),
                  // 回收站入口（文档 10.6 节）
                  DSButton(
                    key: const ValueKey('settings-trash'),
                    label: '回收站',
                    kind: DSButtonKind.secondary,
                    onPressed: _dataBusy ? null : _openTrash,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: sectionGap),

        // ---- 关于 ----
        _SettingsSection(
          surfaceKey: const ValueKey('settings-section-about'),
          title: '关于',
          child: Text(
            'calendar v1.0.4+1 · Windows 桌面关键事务日历',
            style: TextStyle(
              fontSize: kFontSizeBody,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 设置内容分组：毛玻璃主题直接排版在单块玻璃上，其他主题保持卡片回退。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.surfaceKey,
    required this.title,
    required this.child,
  });

  final Key surfaceKey;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: kFontSizeCaption,
            fontWeight: FontWeight.w700,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );

    if (tokens.glassBlurSigma > 0) {
      return Padding(
        key: surfaceKey,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: content,
      );
    }

    return Container(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}
