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

  test('DSTokens 主题三态：毛玻璃基于浅色派生、深色亮度分层', () {
    // 毛玻璃：文字/强调色与浅色一致，仅背景/描边/模糊不同
    expect(DSTokens.glass.textPrimary, DSTokens.light.textPrimary);
    expect(DSTokens.glass.accentBlue, DSTokens.light.accentBlue);
    expect(DSTokens.glass.glassBlurSigma, greaterThan(0));
    expect(DSTokens.glass.glassSurface, isNot(DSTokens.light.glassSurface));
    // 浅色/深色不启用玻璃
    expect(DSTokens.light.glassBlurSigma, 0);
    expect(DSTokens.dark.glassBlurSigma, 0);
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
  });
}
