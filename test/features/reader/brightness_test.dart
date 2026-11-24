import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/slider.dart' as prism show Slider;
import 'package:prism_ui/switch.dart' as prism show Switch;
import 'package:venera_next/components/mobile_large_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/brightness_policy.dart';

void main() {
  group('reader brightness', () {
    test('normalizes missing and out-of-range values', () {
      expect(normalizeReaderBrightness(null), defaultReaderBrightness);
      expect(normalizeReaderBrightness(5), readerBrightnessMin);
      expect(normalizeReaderBrightness(120), readerBrightnessMax);
      expect(normalizeReaderBrightness(42.6), 43);
    });

    test('maps brightness to a black overlay opacity', () {
      expect(readerBrightnessOverlayOpacity(enabled: false, brightness: 20), 0);
      expect(readerBrightnessOverlayOpacity(enabled: true, brightness: 100), 0);
      expect(
        readerBrightnessOverlayOpacity(enabled: true, brightness: 50),
        0.5,
      );
      expect(
        readerBrightnessOverlayOpacity(enabled: true, brightness: 20),
        0.8,
      );
    });
  });

  testWidgets('brightness overlay does not intercept reader gestures', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 200,
          child: ReaderBrightnessOverlay(enabled: true, brightness: 50),
        ),
      ),
    );

    expect(find.byType(IgnorePointer), findsOneWidget);
    expect(
      tester.widget<IgnorePointer>(find.byType(IgnorePointer)).ignoring,
      isTrue,
    );
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
      Colors.black.withValues(alpha: 0.5),
    );
  });

  testWidgets('brightness control exposes the configured range', (
    tester,
  ) async {
    bool? enabledValue;
    int? brightnessValue;
    int? brightnessEndValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: ReaderBrightnessControl(
              enabled: true,
              brightness: 50,
              onEnabledChanged: (value) => enabledValue = value,
              onBrightnessChanged: (value) => brightnessValue = value,
              onBrightnessChangeEnd: (value) => brightnessEndValue = value,
              compact: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(enabledValue, isFalse);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, readerBrightnessMin);
    expect(slider.max, readerBrightnessMax);
    expect(slider.value, 50);
    slider.onChanged!(75);
    slider.onChangeEnd!(70);
    expect(brightnessValue, 75);
    expect(brightnessEndValue, 70);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picture sheet previews on one fixed track and saves on release',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      final saved = ValueNotifier(50);
      final preview = ReaderBrightnessPreview();
      final release = Completer<void>();
      final writes = <int>[];
      var siblingBuilds = 0;
      addTearDown(saved.dispose);
      addTearDown(preview.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMobileLargeSheet<void>(
                  context: context,
                  builder: (_) => ValueListenableBuilder(
                    valueListenable: saved,
                    builder: (_, brightness, _) => ReaderBrightnessPanel(
                      enabled: true,
                      brightness: brightness,
                      onEnabledChanged: (_) {},
                      onBrightnessChanged: (_) => fail('legacy write on drag'),
                      previewBrightness: preview.previewBrightness,
                      commitBrightness: (value) async {
                        writes.add(value);
                        await release.future;
                        saved.value = value;
                      },
                      additionalSettings: Builder(
                        builder: (_) {
                          siblingBuilds++;
                          return const Text('Other picture controls');
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(prism.Switch), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      final slider = find.byType(prism.Slider);
      final track = tester.getRect(slider);
      final siblingCount = siblingBuilds;
      final gesture = await tester.startGesture(track.center);
      await tester.pump(const Duration(milliseconds: 180));
      for (final x in [track.right - 40, track.right - 15, track.right + 4]) {
        await gesture.moveTo(Offset(x, track.center.dy));
        await tester.pump();
        expect(tester.getRect(slider), track);
      }
      expect(preview.brightness, 100);
      expect(tester.widget<prism.Slider>(slider).value, 100);
      expect(siblingBuilds, siblingCount);
      expect(writes, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(writes, [100]);
      expect(preview.brightness, 100);
      release.complete();
      await tester.pumpAndSettle();
      expect(preview.brightness, isNull);
      expect(saved.value, 100);

      // A held tap can produce a provisional Prism sample before the sheet
      // takes the vertical gesture. It must never persist that sample.
      final vertical = await tester.startGesture(tester.getCenter(slider));
      await tester.pump(const Duration(milliseconds: 180));
      await vertical.moveBy(const Offset(0, -110));
      await tester.pump();
      await vertical.up();
      await tester.pumpAndSettle();
      expect(writes, [100]);
      expect(preview.brightness, isNull);
      expect(tester.widget<prism.Slider>(slider).value, 100);

      final abandoned = await tester.startGesture(tester.getCenter(slider));
      await tester.pump(const Duration(milliseconds: 180));
      await abandoned.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(preview.brightness, lessThan(100));
      await abandoned.cancel();
      await tester.pumpAndSettle();
      expect(writes, [100]);
      expect(preview.brightness, isNull);
      expect(tester.widget<prism.Slider>(slider).value, 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
