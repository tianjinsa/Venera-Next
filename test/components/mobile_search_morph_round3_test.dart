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
    'the control grows into a circle covering the farthest corner before the fade',
    () {
      // A point near two edges distinguishes the true diagonal from one side
      // or half of a centered diagonal.
      const contact = Offset(16, 51);
      const control = Rect.fromLTWH(8, 38, 130, 40);
      const corners = [
        Offset.zero,
        Offset(0, 750),
        Offset(390, 0),
        Offset(390, 750),
      ];
      final furthest = (corners.last - contact).distance;
      SearchMorphFrame frameAt(double t) => SearchMorphFrame.at(
        anchor: control,
        origin: contact,
        viewport: page,
        t: t,
      );
      var previous = frameAt(0);
      expect(previous.center, contact);
      expect(previous.anchor, control);
      expect(previous.radius, control.shortestSide / 2);
      expect(previous.coveringRadius, furthest);
      for (var tick = 1; tick <= 70; ++tick) {
        final t = tick / 100;
        final frame = frameAt(t);
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

  test('equal time steps accelerate out of the touch then gently settle', () {
    const touch = Offset(170, 42);
    double growth(double fraction) => SearchMorphFrame.at(
      anchor: anchor,
      origin: touch,
      viewport: page,
      t: fraction * SearchMorphFrame.growthEnd,
    ).growth;
    final initial = growth(.10) - growth(0);
    final middle = growth(.50) - growth(.40);
    final last = growth(1) - growth(.90);
    expect(initial, inExclusiveRange(0.0, .04));
    expect(middle, greaterThan(initial * 4));
    expect(last, lessThan(middle / 4));
    expect(growth(1), 1);
  });

  testWidgets(
    'early spread follows the chip radius and leaves its label visible',
    (tester) async {
      const chip = Rect.fromLTWH(30, 60, 170, 44);
      await tester.pumpWidget(
        SizedBox.fromSize(
          size: page.size,
          child: SearchMorphSurface(
            frame: SearchMorphFrame.at(
              anchor: chip,
              origin: const Offset(68, 70),
              viewport: page,
              t: .012,
            ),
            sourceColor: Colors.orange,
            destinationColor: Colors.white,
            cornerRadius: 12,
          ),
        ),
      );
      final canvas = TestRecordingCanvas();
      tester
          .widget<CustomPaint>(find.byType(CustomPaint))
          .painter!
          .paint(canvas, page.size);
      final calls = [for (final entry in canvas.invocations) entry.invocation];
      expect(calls.map((call) => call.memberName), [
        #save,
        #clipRect,
        #clipPath,
        #drawPath,
        #restore,
      ]);
      final contour = calls[2].positionalArguments.first as Path;
      expect(contour.contains(chip.topLeft.translate(6, 3)), isTrue);
      expect(contour.contains(chip.topLeft.translate(1, 1)), isFalse);
      expect(contour.contains(chip.topCenter.translate(0, -2)), isFalse);
      final aperture = calls[3].positionalArguments.first as Path;
      expect(aperture.contains(chip.center), isFalse);
      expect(aperture.contains(chip.topLeft.translate(6, 3)), isFalse);
    },
  );

  testWidgets(
    'late spread is round around the touch point, opaque, and clipped to the viewport',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = page.size + const Offset(20, 20);
      addTearDown(tester.view.reset);
      const contact = Offset(16, 102);
      const pad = Offset(10, 10);
      final boundary = GlobalKey();
      final frame = SearchMorphFrame.at(
        anchor: const Rect.fromLTWH(8, 85, 120, 44),
        origin: contact,
        viewport: page,
        t: .51,
      );
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
          expect(alpha(Offset(page.right - 3, contact.dy) + pad), 255);
          expect(alpha(contact + pad + Offset(0, axis)), 255);
          // Inside a rectangular envelope but outside the actual circle.
          expect(alpha(Offset(page.right - 3, page.bottom - 3) + pad), 0);
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
