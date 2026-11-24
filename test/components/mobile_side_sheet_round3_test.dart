import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_side_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';

void main() {
  const size = Size(390, 750);
  final panel = find.byKey(const ValueKey('mobile-side-sheet-viewport'));
  final card = find.byKey(const ValueKey('mobile-side-sheet-surface'));
  final hidden = find.byKey(const ValueKey('wide-only-action'));
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
      final layouts = <Size>{};
      var hiddenTaps = 0;
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
                            builder: (context) {
                              final layout = MobileSideSheetLayout.maybeOf(
                                context,
                              )!;
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  layouts.add(constraints.biggest);
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: SizedBox(
                                          width: 132,
                                          child: TextButton(
                                            autofocus: true,
                                            focusNode: sheetFocus,
                                            onPressed: () =>
                                                Navigator.pop(context, 'child'),
                                            child: Text(
                                              Directionality.of(context) ==
                                                      direction
                                                  ? 'Choose child'
                                                  : 'Wrong text direction',
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: layout.minContentWidth + 4,
                                        top: 100,
                                        width: 20,
                                        height: 44,
                                        child: TextButton(
                                          key: const ValueKey(
                                            'wide-only-action',
                                          ),
                                          onPressed: () => hiddenTaps++,
                                          child: const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
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
      final incoming = tester.getRect(card);
      expect(incoming.left, lessThan(0));
      await tester.pumpAndSettle();
      final landed = tester.getRect(panel);
      expect(landed.left, 13);
      const safeHeight = 750.0 - 90 - 24 - 25;
      const safeWidth = 390.0 - 13 - 11;
      expect(landed.width, closeTo(safeWidth * .50, .01));
      expect(landed.height, closeTo(safeHeight * .86, .01));
      expect(landed.top, greaterThan(24));
      expect(landed.bottom, lessThan(size.height - 90 - 25));
      final compactCard = tester.getRect(card);
      expect(compactCard, landed);
      expect(hidden.hitTestable(), findsNothing);
      expect(
        tester.widget<Material>(card).shape,
        isA<RoundedSuperellipseBorder>(),
      );
      expect(tester.getCenter(grabber).dx, greaterThan(landed.center.dx));
      expect(sheetFocus.hasPrimaryFocus, isTrue);

      final grow = await tester.startGesture(tester.getCenter(grabber));
      await grow.moveBy(const Offset(30, 0)); // Recognizer's touch slop.
      await tester.pump(const Duration(milliseconds: 30));
      await grow.moveBy(const Offset(52, 0));
      await tester.pump(const Duration(milliseconds: 70));
      final held = tester.getRect(panel);
      expect(held.left, landed.left);
      expect(held.width, greaterThan(landed.width + 40));
      expect(held.width, lessThan(safeWidth * .75));
      expect(held.height, greaterThan(landed.height));
      expect(held.height, lessThan(safeHeight));
      expect(held.top, lessThan(landed.top));
      expect(held.bottom, greaterThan(landed.bottom));
      final heldCard = tester.getRect(card);
      expect(heldCard, held);
      await grow.moveBy(const Offset(160, 0));
      await tester.pump();
      await grow.up();
      await tester.pumpAndSettle();
      final wide = tester.getRect(panel);
      expect(wide.left, landed.left);
      expect(wide.width, closeTo(safeWidth * .75, .01));
      expect(wide.top, 24);
      expect(wide.bottom, size.height - 90 - 25);
      expect(tester.getRect(card), wide);
      for (final frame in [landed, held, wide]) {
        expect(
          layouts.any(
            (size) =>
                (size.width - (frame.width - 22)).abs() < .01 &&
                (size.height - frame.height).abs() < .01,
          ),
          isTrue,
          reason: 'visible body was laid out for $frame',
        );
      }
      expect(sheetFocus.hasPrimaryFocus, isTrue);
      expect(hidden.hitTestable(), findsOneWidget);
      await tester.tap(hidden);
      expect(hiddenTaps, 1);

      final shrink = await tester.startGesture(tester.getCenter(grabber));
      await shrink.moveBy(const Offset(-30, 0));
      await shrink.moveBy(const Offset(-45, 0));
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
      expect(tester.getRect(panel).width, landed.width);
      expect(tester.getRect(card).left, lessThan(compactCard.left));
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
                  builder: (context) => const Align(
                    alignment: Alignment.topRight,
                    child: CloseButton(),
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
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(panel).dx, 8);
    expect(tester.getTopLeft(panel).dy, greaterThan(8));
    expect(tester.getSize(panel).width, closeTo((size.width - 16) * .50, .01));
    final narrowCard = tester.getSize(card);
    expect(narrowCard.width, tester.getSize(panel).width);
    expect(find.byType(CloseButton).hitTestable(), findsOneWidget);
    await tester.tap(grabber);
    await tester.pump();
    expect(tester.getTopLeft(panel), const Offset(8, 8));
    expect(tester.getSize(panel).width, (size.width - 16) * .75);
    expect(tester.getSize(card), tester.getSize(panel));
    await tester.tap(find.byType(CloseButton));
    await tester.pump();
    await tester.pump();
    expect(panel, findsNothing);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'swipe opens the closed panel only from the interior physical left ($direction)',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var opens = 0, taps = 0;
        var allowed = true;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(systemGestureInsets: const EdgeInsets.only(left: 36)),
              child: MobileUiTheme(
                glass: 'off',
                child: Directionality(textDirection: direction, child: child!),
              ),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  void open() {
                    opens++;
                    Navigator.of(context).push(
                      MobileSideSheetRoute<void>(
                        context: context,
                        builder: (_) => const Text('Folder sheet'),
                      ),
                    );
                  }

                  return MobileSideSheetSwipe(
                    enabled: () => allowed,
                    onOpen: open,
                    child: ListView.builder(
                      controller: scroll,
                      itemExtent: 64,
                      itemCount: 25,
                      itemBuilder: (_, index) => index == 0
                          ? TextButton(
                              onPressed: open,
                              child: const Text('Current folder'),
                            )
                          : InkWell(
                              onTap: () => taps++,
                              child: Text('Content $index'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tapAt(const Offset(54, 93));
        expect(taps, 1);
        await tester.dragFrom(const Offset(54, 290), const Offset(6, -110));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        for (final (start, delta) in const [
          (Offset(30, 220), Offset(150, 0)), // OS gesture strip.
          (Offset(180, 220), Offset(150, 0)), // Main content, not the edge.
          (Offset(54, 220), Offset(-46, 0)), // Wrong direction.
          (Offset(54, 220), Offset(32, 0)), // Too short.
        ]) {
          await tester.dragFrom(start, delta);
          await tester.pumpAndSettle();
          expect(opens, 0);
        }
        final interrupted = await tester.startGesture(const Offset(54, 220));
        await interrupted.moveBy(const Offset(95, 0));
        await tester.pump();
        await interrupted.cancel();
        expect(opens, 0);
        allowed = false;
        await tester.dragFrom(const Offset(54, 220), const Offset(140, 0));
        await tester.pumpAndSettle();
        expect(opens, 0);
        allowed = true;
        await tester.dragFrom(const Offset(54, 220), const Offset(170, 0));
        await tester.pumpAndSettle();
        expect(opens, 1);
        expect(tester.getTopLeft(panel).dx, 8);
        expect(tester.getSize(panel).width, (size.width - 16) * .50);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Current folder'));
        await tester.pumpAndSettle();
        expect(opens, 2);
        expect(find.text('Folder sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
