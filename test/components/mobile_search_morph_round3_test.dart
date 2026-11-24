import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';

void main() {
  const page = Rect.fromLTWH(0, 0, 390, 750);
  const anchor = Rect.fromLTWH(150, 52, 48, 48);

  test(
    'one concentric radius grows from the pointer through the farthest corner before the fade',
    () {
      // A point near two edges distinguishes the true diagonal from one side
      // or half of a centered diagonal.
      const contact = Offset(16, 51);
      const corners = [
        Offset.zero,
        Offset(0, 750),
        Offset(390, 0),
        Offset(390, 750),
      ];
      final furthest = (corners.last - contact).distance;
      var previous = SearchMorphFrame.at(contact, page, 0);
      expect(previous.center, contact);
      expect(previous.radius, 0);
      expect(previous.coveringRadius, furthest);
      for (var tick = 1; tick <= 70; ++tick) {
        final t = tick / 100;
        final frame = SearchMorphFrame.at(contact, page, t);
        expect(frame.center, previous.center);
        expect(frame.radius, greaterThan(previous.radius));
        expect(frame.radius, lessThanOrEqualTo(furthest));
        expect(SearchMorphFrame.contentOpacity(t), 0);
        previous = frame;
      }
      expect(previous.radius, furthest);
      expect(
        corners.every((p) => (p - contact).distance <= previous.radius),
        isTrue,
      );
      expect(SearchMorphFrame.contentOpacity(.85), inExclusiveRange(0.0, 1.0));
      expect(SearchMorphFrame.contentOpacity(1), 1);
    },
  );

  testWidgets(
    'painter is round, opaque in its interior, and clipped to the viewport',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = page.size + const Offset(20, 20);
      addTearDown(tester.view.reset);
      const contact = Offset(16, 102);
      const pad = Offset(10, 10);
      final boundary = GlobalKey();
      final frame = SearchMorphFrame.at(contact, page, .25);
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox.fromSize(
                size: page.size,
                child: SearchMorphSurface(
                  frame: frame,
                  sourceColor: const Color(0x22663F15),
                  destinationColor: const Color(0x225B50A5),
                ),
              ),
            ),
          ),
        ),
      );
      final box =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await box.toImage();
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(Offset p) => data.getUint8(
            (p.dy.floor() * image.width + p.dx.floor()) * 4 + 3,
          );
          final axis = frame.radius * .75;
          expect(alpha(contact + pad), 255);
          expect(alpha(contact + pad + Offset(axis, 0)), 255);
          expect(alpha(contact + pad + Offset(0, axis)), 255);
          // Inside a rectangular envelope but outside the actual circle.
          expect(alpha(contact + pad + Offset(axis, axis)), 0);
          // The opaque circle crosses the viewport edge, not its clip.
          expect(alpha(Offset(pad.dx - 3, contact.dy + pad.dy)), 0);
        } finally {
          image.dispose();
        }
      });
    },
  );

  testWidgets(
    'interrupting expansion returns the result and restores the exact trigger twice',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = page.size;
      addTearDown(tester.view.reset);
      final values = <int?>[];
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fromRect(
                  rect: anchor,
                  child: MobileSearchAnchor(
                    builder: (origin) => TextButton(
                      onPressed: () async {
                        values.add(
                          await pushSearchFrom<int>(
                            origin,
                            () => const Scaffold(),
                          ),
                        );
                      },
                      child: const Text('go'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final ms in [65, 148]) {
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(Duration(milliseconds: ms));
        final surface = find.byType(SearchMorphSurface);
        expect(surface, findsOneWidget);
        final frame = tester.widget<SearchMorphSurface>(surface).frame;
        navigator.currentState!.pop(ms);
        await tester.pump();
        expect(
          tester.widget<SearchMorphSurface>(surface).frame.radius,
          frame.radius,
        );
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
        expect(find.text('go').hitTestable(), findsOneWidget);
        expect(tester.getRect(find.byType(TextButton)), anchor);
      }
      expect(values, [65, 148]);
      expect(tester.takeException(), isNull);
    },
  );
}
