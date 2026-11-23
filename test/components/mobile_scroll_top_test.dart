import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/navigation_dock.dart' as prism;
import 'package:venera_next/components/mobile_dock_inset.dart';
import 'package:venera_next/components/mobile_scroll_top.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/navigation_bar.dart';
import 'package:venera_next/components/scroll.dart';

const _viewport = ValueKey('scroll viewport');
const _top = ValueKey('scroll-top');
const _refresh = ValueKey('scroll-refresh');

Widget _list(ScrollController controller) => SmoothCustomScrollView(
  key: _viewport,
  controller: controller,
  slivers: [
    SliverFixedExtentList.builder(
      itemExtent: 60,
      itemCount: 80,
      itemBuilder: (_, i) => Text('row $i'),
    ),
  ],
);

void main() {
  for (final bottomInset in [0.0, 34.0]) {
    testWidgets(
      'scroll-to-top is independently tappable above dock (safe bottom $bottomInset)',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 750)
          ..viewPadding = FakeViewPadding(bottom: bottomInset)
          ..padding = FakeViewPadding(bottom: bottomInset);
        addTearDown(tester.view.reset);
        await tester.binding.setSurfaceSize(const Size(390, 750));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final navigatorKey = GlobalKey<NavigatorState>();
        var refreshes = 0;
        var selected = 0;

        Widget page(int index) => index == 0
            ? MobileScrollTopOverlay(
                controller: controller,
                onRefresh: () => refreshes++,
                child: _list(controller),
              )
            : const Text('second destination');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: MobileUiTheme(glass: 'off', child: child!),
            ),
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            home: Material(
              child: NaviPane(
                observer: NaviObserver(),
                navigatorKey: navigatorKey,
                paneItems: [
                  for (final entry in [
                    ('Explore', MobileNavGlyphs.explore),
                    ('Favorites', MobileNavGlyphs.favorites),
                    ('Agent', MobileNavGlyphs.agent),
                    ('Home', MobileNavGlyphs.home),
                    ('Categories', MobileNavGlyphs.categories),
                  ])
                    PaneItemEntry(
                      label: entry.$1,
                      icon: Icons.circle_outlined,
                      activeIcon: Icons.circle,
                      mobileGlyph: entry.$2,
                    ),
                ],
                paneActions: const [],
                pageBuilder: page,
                onPageChanged: (index) => selected = index,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_top), findsNothing);
        await tester.tap(find.byKey(_refresh).hitTestable());
        expect(refreshes, 1);
        controller.jumpTo(600);
        await tester.pumpAndSettle();
        final button = find.byKey(_top);
        final dock = find.byType(prism.FloatingNavigationBar);
        final dockRect = tester.getRect(dock);
        final viewport = tester.getRect(find.byKey(_viewport));
        final clearance = MobileDockInset.of(
          tester.element(find.byKey(_viewport)),
        );

        expect(viewport.bottom, 750);
        expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
        expect(tester.getRect(button).bottom, closeTo(dockRect.top - 8, .1));
        expect(tester.getRect(button).bottom, closeTo(750 - clearance, .1));
        expect(button.hitTestable(), findsOneWidget);

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.minScrollExtent);
        expect(find.byKey(_top), findsNothing);
        expect(find.byKey(_refresh), findsOneWidget);
        expect(refreshes, 1);
        expect(selected, 0);

        await tester.tap(find.text('Favorites').hitTestable());
        await tester.pumpAndSettle();
        expect(selected, 1);
      },
    );
  }

  testWidgets(
    'standalone overlay uses safe area once and honors reduce motion',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 750);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(right: 10, bottom: 34),
              disableAnimations: true,
            ),
            child: MobileUiTheme(glass: 'off', child: child!),
          ),
          home: Material(
            child: MobileScrollTopOverlay(
              controller: controller,
              child: _list(controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_top), findsNothing);
      expect(find.byKey(_refresh), findsNothing);
      controller.jumpTo(600);
      await tester.pump();
      final button = find.byKey(_top);
      expect(tester.getRect(button).bottom, 750 - 34 - 16);
      expect(tester.getRect(button).right, 390 - 10 - 16);
      await tester.tap(button.hitTestable());
      expect(controller.offset, controller.position.minScrollExtent);
    },
  );

  testWidgets('desktop scope never adds the fixed mobile overlay', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MobileScrollTopOverlay(
            controller: controller,
            onRefresh: () {},
            child: _list(controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(600);
    await tester.pumpAndSettle();
    expect(find.byKey(_top), findsNothing);
    expect(find.byKey(_refresh), findsNothing);
    expect(controller.offset, 600);
  });
}
