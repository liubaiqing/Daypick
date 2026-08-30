// 设置存取单元测试（文档 4.1 节 settings 表）。
import 'package:calendar/core/constants.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/settings_dao.dart';
import 'package:calendar/shared/design/ds_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SettingsDao(db);
  });

  tearDown(() => db.close());

  test('未设置时返回 null', () async {
    expect(await dao.get('parseMode'), isNull);
  });

  test('set/get 往返', () async {
    await dao.set('parseMode', 'ai');
    expect(await dao.get('parseMode'), 'ai');
  });

  test('覆盖更新', () async {
    await dao.set('llmModel', 'deepseek-chat');
    await dao.set('llmModel', 'deepseek-reasoner');
    expect(await dao.get('llmModel'), 'deepseek-reasoner');
  });

  test('themeMode 持久化读写（默认浅色，可切深色/毛玻璃）', () async {
    expect(await dao.get(kSettingThemeMode), isNull);
    await dao.set(kSettingThemeMode, kThemeModeDark);
    expect(await dao.get(kSettingThemeMode), kThemeModeDark);
    await dao.set(kSettingThemeMode, kThemeModeGlass);
    expect(await dao.get(kSettingThemeMode), kThemeModeGlass);
    await dao.set(kSettingThemeMode, kThemeModeLight);
    expect(await dao.get(kSettingThemeMode), kThemeModeLight);
  });

  test('DSTokens 主题三态：毛玻璃冷静通透色板、深色亮度分层', () {
    // 毛玻璃使用独立的冷蓝灰色板与统一强调色。
    expect(DSTokens.glass.mainBackground, const Color(0xFFF3F6FA));
    expect(DSTokens.glass.textPrimary, const Color(0xFF1B2430));
    expect(DSTokens.glass.textSecondary, const Color(0xFF667487));
    expect(DSTokens.glass.accentBlue, const Color(0xFF3F7FC4));
    expect(DSTokens.glass.successGreen, const Color(0xFF3C9B70));
    expect(DSTokens.glass.glassBlurSigma, greaterThan(0));
    expect(
      DSTokens.glass.glassDialogBlurSigma,
      greaterThan(DSTokens.glass.glassBlurSigma),
    );
    expect(DSTokens.glass.glassSurface, isNot(DSTokens.light.glassSurface));
    expect(DSTokens.glass.glassSurface, DSTokens.glass.cardBackground);
    expect(
      DSTokens.glass.dialogBackground.a,
      greaterThan(DSTokens.glass.glassSurface.a),
    );
    expect(
      DSTokens.glass.modalBarrier.a,
      lessThan(DSTokens.light.modalBarrier.a),
    );
    // 浅色/深色不启用玻璃
    expect(DSTokens.light.glassBlurSigma, 0);
    expect(DSTokens.dark.glassBlurSigma, 0);
    expect(DSTokens.light.glassDialogBlurSigma, 0);
    expect(DSTokens.dark.glassDialogBlurSigma, 0);
    // 深色亮度分层：主背景 < 卡片 < 弹层（亮度递增）
    expect(
      DSTokens.dark.mainBackground.computeLuminance(),
      lessThan(DSTokens.dark.cardBackground.computeLuminance()),
    );
    expect(
      DSTokens.dark.cardBackground.computeLuminance(),
      lessThan(DSTokens.dark.dialogBackground.computeLuminance()),
    );
    // 深色移除投影
    expect(DSTokens.dark.panelShadowColor, const Color(0x00000000));
    expect(DSTokens.dark.cardShadowColor, const Color(0x00000000));
    // 毛玻璃材质只保留轻微反光渐变（左上高光 > 右下）。
    expect(
      DSTokens.glass.glassTintStart.a,
      greaterThan(DSTokens.glass.glassTintEnd.a),
    );
    expect(DSTokens.light.glassTintStart.a, 0);
  });
}
