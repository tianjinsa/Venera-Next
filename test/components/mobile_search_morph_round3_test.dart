import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';

void main() {
  const page = Rect.fromLTWH(0, 0, 390, 750);
  const anchor = Rect.fromLTWH(150, 52, 48, 48);

  testWidgets(
    'the painted material forms a neck, pinches apart, then fills the page',
    (tester) async {
      final boundary = GlobalKey();
      bool foundNeck = false;
      bool foundGap = false;
      for (final i in Iterable<int>.generate(39)) {
        final frame = SearchMorphFrame.at(anchor, page, i / 100);
        final drop = frame.droplet!;
        // A probe in the gap between the two raw shapes can be filled *only*
        // by a real liquid bridge, not a Stack of two rounded rectangles.
        if (frame.platter.top <= drop.bottom + 3) continue;
        final y = (frame.platter.top + drop.bottom) / 2;
        final x = (frame.platter.center.dx + drop.center.dx) / 2;
        final probe = Offset(x.floor() + .5, y.floor() + .5);
        final joined = frame.outline().contains(probe);
        if ((!foundNeck && !joined) || (foundNeck && joined)) continue;
        await tester.pumpWidget(
          Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox.fromSize(
                size: page.size,
                child: SearchMorphSurface(
                  frame: frame,
                  color: Colors.red,
                  glass: null,
                ),
              ),
            ),
          ),
        );
        final box =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        // Widget test's default logical height is 600: the probe is above that.
        final image = await tester.runAsync(() => box.toImage());
        final data = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final pixel = (probe.dy.floor() * image!.width + probe.dx.floor()) * 4;
        final alpha = data!.getUint8(pixel + 3);
        image.dispose();
        if (!foundNeck && alpha > 200) {
          foundNeck = true;
        } else if (foundNeck && !joined && alpha < 10) {
          foundGap = true;
          break;
        }
      }
      expect(foundNeck, isTrue, reason: 'A visible bridge outside both lobes');
      expect(
        foundGap,
        isTrue,
        reason: 'The bridge breaks before the page grows',
      );
      expect(
        SearchMorphFrame.at(anchor, page, 0).outline().getBounds(),
        anchor,
      );
      final settled = SearchMorphFrame.at(anchor, page, 1);
      expect(settled.droplet, isNull);
      expect(settled.clip.outerRect, page);
      expect(settled.radius, 0);
    },
  );

  testWidgets(
    'interrupting the release returns the result and restores the exact trigger twice',
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
