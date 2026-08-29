/// Riverpod 依赖注入：数据库与 DAO。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import 'database.dart';
import 'event_dao.dart';
import 'settings_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final eventDaoProvider = Provider<EventDao>(
  (ref) => EventDao(ref.watch(databaseProvider)),
);

/// 某月事件流（月视图圆点数据源）
final monthEventsProvider =
    StreamProvider.family<List<Event>, DateTime>((ref, month) {
  return ref.watch(eventDaoProvider).watchMonth(month);
});

/// 某日事件流（今日待办列表数据源）
final dayEventsProvider =
    StreamProvider.family<List<Event>, DateTime>((ref, day) {
  return ref.watch(eventDaoProvider).watchDay(day);
});

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => SettingsDao(ref.watch(databaseProvider)),
);

/// 解析模式（local/ai；设置页修改后 invalidate 刷新）
final parseModeProvider = FutureProvider<String>((ref) async {
  return await ref.watch(settingsDaoProvider).get(kSettingParseMode) ??
      kDefaultParseMode;
});

final llmBaseUrlProvider = FutureProvider<String>((ref) async {
  return await ref.watch(settingsDaoProvider).get(kSettingLlmBaseUrl) ??
      kDefaultLlmBaseUrl;
});

final llmApiKeyProvider = FutureProvider<String>((ref) async {
  return await ref.watch(settingsDaoProvider).get(kSettingLlmApiKey) ?? '';
});

final llmModelProvider = FutureProvider<String>((ref) async {
  return await ref.watch(settingsDaoProvider).get(kSettingLlmModel) ??
      kDefaultLlmModel;
});

/// 界面动画总开关（设置页"外观"；默认开启，关闭以适配低性能设备）
final animationsEnabledProvider = FutureProvider<bool>((ref) async {
  final v = await ref.watch(settingsDaoProvider).get(kSettingAnimationsEnabled);
  return v != '0';
});
