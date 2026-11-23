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
      expect(landed.top, 24);
      expect(landed.bottom, size.height - 90 - 25);
      expect(landed.right, lessThan(size.width - 45));
      expect(
        tester.widget<Material>(panel).shape,
        isA<RoundedSuperellipseBorder>(),
      );
      expect(tester.getCenter(grabber).dx, greaterThan(landed.center.dx));
      expect(sheetFocus.hasPrimaryFocus, isTrue);

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
    expect(tester.getTopLeft(panel), const Offset(8, 8));
    expect(grabber, findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pump();
    await tester.pump();
    expect(panel, findsNothing);
  });
}
