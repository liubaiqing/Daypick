import 'package:calendar/app/app.dart';
import 'package:calendar/data/db/database.dart';
import 'package:calendar/data/db/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in ['light', 'dark', 'glass']) {
    testWidgets('$theme 标题栏上下留白可长按拖动，双击与按钮独立', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async {
          calls.add(call.method);
          if (call.method == 'isMaximized' || call.method == 'isFullScreen')
            return false;
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          null,
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            themeModeProvider.overrideWith((ref) async => theme),
            monthEventsProvider.overrideWith(
              (ref, arg) => Stream.value(const <Event>[]),
            ),
            dayEventsProvider.overrideWith(
              (ref, arg) => Stream.value(const <Event>[]),
            ),
          ],
          child: const CalendarApp(),
        ),
      );
      await tester.pumpAndSettle();
      final region = find.byKey(const ValueKey('window-titlebar-drag-region'));
      expect(tester.getSize(region).height, 38);
      for (final y in [8.0, 19.0, 34.0]) {
        calls.clear();
        final pointer = await tester.startGesture(
          Offset(300, y),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await pointer.moveBy(const Offset(50, 0));
        await tester.pump();
        await pointer.up();
        await tester.pumpAndSettle();
        expect(
          calls.where((c) => c == 'startDragging'),
          hasLength(1),
          reason: 'y=$y',
        );
      }
      calls.clear();
      await tester.tapAt(const Offset(300, 19));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(300, 19));
      await tester.pumpAndSettle();
      expect(calls, contains('maximize'));
      expect(calls, isNot(contains('startDragging')));
      calls.clear();
      await tester.tap(find.byTooltip('最小化'));
      await tester.pumpAndSettle();
      expect(calls, contains('minimize'));
      expect(calls, isNot(contains('startDragging')));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
}
