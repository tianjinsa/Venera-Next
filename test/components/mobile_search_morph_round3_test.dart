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
    'a connected shape grows in place immediately and settles before the fade',
    () {
      final beginning = SearchMorphFrame.at(anchor, page, 0);
      expect(beginning.outline().getBounds(), anchor);
      var previous = beginning.platter;
      var actuallyDeformed = false;
      for (final tick in Iterable<int>.generate(70, (index) => index + 1)) {
        final t = tick / 100;
        final frame = SearchMorphFrame.at(
          anchor,
          page,
          t,
          relative: const Offset(.08, .95),
        );
        final path = frame.outline();
        final bounds = path.getBounds();
        // Path.getBounds includes Bézier control points. The painter also
        // clips to this envelope, so none of the motion can lead the platter.
        expect(bounds.left, closeTo(frame.platter.left, 5));
        expect(bounds.top, closeTo(frame.platter.top, 5));
        expect(bounds.right, closeTo(frame.platter.right, 5));
        expect(bounds.bottom, closeTo(frame.platter.bottom, 5));
        expect(path.contains(anchor.center), isTrue);
        expect(
          path.computeMetrics().length,
          1,
          reason: 'the shape must never detach at t=$t',
        );
        expect(frame.platter.width, greaterThan(previous.width));
        expect(frame.platter.height, greaterThan(previous.height));
        expect(SearchMorphFrame.contentOpacity(t), 0);
        final plain = Path()..addRSuperellipse(frame.clip);
        final added = Path.combine(PathOperation.difference, path, plain);
        actuallyDeformed |= added.computeMetrics().any(
          (contour) => contour.length > 3,
        );
        previous = frame.platter;
      }
      expect(
        actuallyDeformed,
        isTrue,
        reason: 'the contact corner deforms rather than just growing a rounded rectangle',
      );
      expect(previous, page);
      expect(SearchMorphFrame.at(anchor, page, 1).radius, 0);
      expect(SearchMorphFrame.contentOpacity(.85), inExclusiveRange(0.0, 1.0));
      expect(SearchMorphFrame.contentOpacity(1), 1);
    },
  );

  testWidgets(
    'all painted interior pixels remain opaque even in the sheen mode',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = page.size;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final frame = SearchMorphFrame.at(
        anchor,
        page,
        .41,
        relative: const Offset(.08, .95),
      );
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox.fromSize(
              size: page.size,
              child: SearchMorphSurface(
                frame: frame,
                sourceColor: const Color(0x22663F15),
                destinationColor: const Color(0x225B50A5),
                sheen: Colors.cyan,
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
          int channel(Offset p, int channel) => data.getUint8(
            (p.dy.floor() * image.width + p.dx.floor()) * 4 + channel,
          );
          expect(channel(anchor.center, 3), 255);
          expect(channel(frame.platter.center, 3), 255);
          expect(
            channel(frame.platter.bottomCenter + const Offset(0, 2), 3),
            0,
          );
          expect(channel(const Offset(2, 2), 3), 0);
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
          tester.widget<SearchMorphSurface>(surface).frame.platter,
          frame.platter,
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
