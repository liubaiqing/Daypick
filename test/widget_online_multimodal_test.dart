import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calendar/core/constants.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:calendar/data/db/settings_dao.dart';
import 'package:calendar/data/llm/openai_compatible_client.dart';
import 'package:calendar/features/intake/chat_composer_bar.dart';
import 'package:calendar/shared/design/ds_tokens.dart';
import 'package:calendar/shared/design/dstokens_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingGateway implements LlmGateway {
  var response = Completer<Map<String, dynamic>>();
  List<LlmChatMessage> messages = [];
  @override
  Future<Map<String, dynamic>> chatJson({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmChatMessage> messages,
  }) {
    this.messages = messages;
    return response.future;
  }
}

void main() {
  testWidgets('在线图文忙碌锁定、失败保留整批、成功只生成草稿', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = PendingGateway();
    late Directory dir;
    late File file;
    await tester.runAsync(() async {
      final dao = SettingsDao(db);
      await dao.set(kSettingParseMode, kParseModeAi);
      await dao.set(kSettingLlmApiKey, 'test-key');
      dir = await Directory.systemTemp.createTemp('daypick-widget-image-');
      file = File('${dir.path}/notice.png');
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.white, ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(20, 20);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineLlmGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          builder: (context, child) => DSTokensScope(
            tokens: DSTokens.light,
            child: Material(child: child!),
          ),
          home: const Scaffold(body: ChatComposerBar()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ChatComposerBar));
    ProviderScope.containerOf(context)
        .read(droppedImagesProvider.notifier)
        .set([file.path]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '补充通知');
    Future<void> sendAndWait() async {
      gateway.messages = [];
      await tester.tap(find.byKey(const ValueKey('composer-send')));
      for (var i = 0; i < 100 && gateway.messages.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(gateway.messages, isNotEmpty);
    }

    await sendAndWait();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(gateway.messages.last.images, hasLength(1));
    gateway.response.completeError(const LlmException('图文请求被拒绝'));
    await tester.pumpAndSettle();
    expect(find.text('图文请求被拒绝'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '补充通知',
    );
    expect(find.byType(Image), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as FileImage).file.path,
      file.path,
    );
    gateway.response = Completer<Map<String, dynamic>>();
    await sendAndWait();
    gateway.response.complete({
      'events': [
        {'title': '通知会议', 'start': '2027-01-01T09:00:00'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('通知会议'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.select(db.events).get(), isEmpty);
      expect(await file.exists(), true); // 用户原图不能删除。
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
  });
}
