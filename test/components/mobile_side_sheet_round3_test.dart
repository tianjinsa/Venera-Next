import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_side_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';

void main() {
  const size = Size(390, 750);
  final panel = find.byKey(const ValueKey('mobile-side-sheet-surface'));
  final grabber = find.byKey(const ValueKey('mobile-side-sheet-handle'));

  for (final direction in TextDirection.values) {
    testWidgets('floating modal always uses physical left ($direction)', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      addTearDown(tester.view.reset);
      final owner = GlobalKey<NavigatorState>();
      final originFocus = FocusNode();
      final sheetFocus = FocusNode();
      addTearDown(originFocus.dispose);
      addTearDown(sheetFocus.dispose);
      var backgroundTaps = 0;
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: owner,
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(13, 24, 11, 25),
              viewInsets: const EdgeInsets.only(bottom: 90),
            ),
            child: MobileUiTheme(
              glass: 'off',
              child: Directionality(textDirection: direction, child: child!),
            ),
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => backgroundTaps++,
                  ),
                ),
                Positioned(
                  left: 32,
                  top: 48,
                  child: Builder(
                    builder: (context) => TextButton(
                      focusNode: originFocus,
                      onPressed: () async {
                        chosen = await owner.currentState!.push<String>(
                          MobileSideSheetRoute<String>(
                            context: context,
                            builder: (context) => Align(
                              alignment: Alignment.topCenter,
                              child: TextButton(
                                autofocus: true,
                                focusNode: sheetFocus,
                                onPressed: () =>
                                    Navigator.pop(context, 'child'),
                                child: Text(
                                  Directionality.of(context) == direction
                                      ? 'Choose child'
                                      : 'Wrong text direction',
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Current folder'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> open() async {
        originFocus.requestFocus();
        await tester.pump();
        await tester.tap(find.text('Current folder'));
        await tester.pump();
      }

      await open();
      await tester.pump(const Duration(milliseconds: 50));
      final incoming = tester.getRect(panel);
      expect(incoming.left, lessThan(0));
      await tester.pumpAndSettle();
      final landed = tester.getRect(panel);
      expect(landed.left, 13);
      const safeHeight = 750.0 - 90 - 24 - 25;
      const safeWidth = 390.0 - 13 - 11;
      expect(landed.width, closeTo(safeWidth * .4, .01));
      expect(landed.height, closeTo(safeHeight * .86, .01));
      expect(landed.top, greaterThan(24));
      expect(landed.bottom, lessThan(size.height - 90 - 25));
      expect(
        tester.widget<Material>(panel).shape,
        isA<RoundedSuperellipseBorder>(),
      );
      expect(tester.getCenter(grabber).dx, greaterThan(landed.center.dx));
      expect(sheetFocus.hasPrimaryFocus, isTrue);

      final grow = await tester.startGesture(tester.getCenter(grabber));
      await grow.moveBy(const Offset(30, 0)); // Recognizer's touch slop.
      await tester.pump(const Duration(milliseconds: 30));
      await grow.moveBy(const Offset(72, 0));
      await tester.pump(const Duration(milliseconds: 70));
      final held = tester.getRect(panel);
      expect(held.left, landed.left);
      expect(held.width, greaterThan(landed.width + 40));
      expect(held.width, lessThan(safeWidth));
      expect(held.height, greaterThan(landed.height));
      expect(held.height, lessThan(safeHeight));
      expect(held.top, lessThan(landed.top));
      expect(held.bottom, greaterThan(landed.bottom));
      await grow.moveBy(const Offset(160, 0));
      await tester.pump();
      await grow.up();
      await tester.pumpAndSettle();
      final wide = tester.getRect(panel);
      expect(wide.left, landed.left);
      expect(wide.right, size.width - 11);
      expect(wide.top, 24);
      expect(wide.bottom, size.height - 90 - 25);
      expect(sheetFocus.hasPrimaryFocus, isTrue);

      final shrink = await tester.startGesture(tester.getCenter(grabber));
      await shrink.moveBy(const Offset(-30, 0));
      await shrink.moveBy(const Offset(-125, 0));
      await tester.pump();
      expect(tester.getRect(panel).width, lessThan(wide.width));
      expect(tester.getRect(panel).left, landed.left);
      await shrink.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(panel), wide);

      await tester.tap(grabber);
      await tester.pumpAndSettle();
      expect(tester.getRect(panel), landed);

      await tester.tapAt(Offset(size.width - 12, 125));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(backgroundTaps, 0);
      expect(originFocus.hasFocus, isTrue);

      await open();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await open();
      await tester.pumpAndSettle();
      final finger = await tester.startGesture(tester.getCenter(grabber));
      await finger.moveBy(const Offset(-36, 0));
      await finger.moveBy(const Offset(-38, 0));
      await tester.pump();
      expect(tester.getRect(panel).left, lessThan(0));
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(panel), landed);

      final release = await tester.startGesture(tester.getCenter(grabber));
      await release.moveBy(const Offset(-30, 0));
      await release.moveBy(const Offset(-150, 0));
      await release.up();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await open();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 'child');
      expect(panel, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduce motion opens and closes without a travelling frame', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: MobileUiTheme(glass: 'off', child: child!),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MobileSideSheetRoute<void>(
                  context: context,
                  builder: (_) => const Center(child: CloseButton()),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(panel).dx, 8);
    expect(tester.getTopLeft(panel).dy, greaterThan(8));
    expect(tester.getSize(panel).width, closeTo((size.width - 16) * .4, .01));
    await tester.tap(grabber);
    await tester.pump();
    expect(tester.getTopLeft(panel), const Offset(8, 8));
    expect(tester.getSize(panel).width, size.width - 16);
    await tester.tap(find.byType(CloseButton));
    await tester.pump();
    await tester.pump();
    expect(panel, findsNothing);
  });
}
