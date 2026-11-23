import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/button.dart' as prism show TonalButtonGroup;
import 'package:prism_ui/liquid_glass.dart' as prism show LiquidGlassScope;
import 'package:prism_ui/navigation_dock.dart' as prism;
import 'package:prism_ui/page_transition.dart' as prism show CardRouteMixin;
import 'package:prism_ui/popup.dart' as prism show PopupMenu, PopupMenuItem;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/navigation_bar.dart';
import 'package:venera_next/foundation/context.dart';

Widget _app(Widget home, {String glass = 'standard'}) => MaterialApp(
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: (_, child) => MobileUiTheme(glass: glass, child: child!),
  home: Material(child: home),
);

void _phone(WidgetTester tester, {double width = 390}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('the dock only changes page when the drag commits', (
    tester,
  ) async {
    _phone(tester);
    final selected = <int>[];
    final committed = ValueNotifier(0);
    addTearDown(committed.dispose);
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: ValueListenableBuilder(
            valueListenable: committed,
            builder: (_, index, _) => prism.NavigationDock(
              destinations: const [
                prism.NavigationDockDestination(
                  label: 'Home',
                  glyph: MobileNavGlyphs.home,
                ),
                prism.NavigationDockDestination(
                  label: 'Favorites',
                  glyph: MobileNavGlyphs.favorites,
                ),
                prism.NavigationDockDestination(
                  label: 'Agent',
                  glyph: MobileNavGlyphs.agent,
                ),
              ],
              selectedIndex: index,
              onSelected: (index) {
                selected.add(index);
                committed.value = index;
              },
            ),
          ),
        ),
        glass: 'off',
      ),
    );
    await tester.pumpAndSettle();

    final home = tester.getCenter(find.text('Home'));
    final agent = tester.getCenter(find.text('Agent'));
    final cancelled = await tester.startGesture(home);
    await tester.pump(const Duration(milliseconds: 150));
    await cancelled.moveTo(agent);
    await tester.pump(const Duration(milliseconds: 80));
    expect(selected, isEmpty);
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(committed.value, 0);

    final drag = await tester.startGesture(home);
    await tester.pump(const Duration(milliseconds: 150));
    await drag.moveTo(agent);
    await tester.pump(const Duration(milliseconds: 80));
    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, [2]);
    expect(committed.value, 2);
    expect(tester.takeException(), isNull);
  });

  for (final glass in ['off', 'standard', 'ultra']) {
    testWidgets('toolbar actions and menu hierarchy work in $glass mode', (
      tester,
    ) async {
      _phone(tester, width: 320);
      var searches = 0;
      var refreshes = 0;
      var copies = 0;
      const searchKey = ValueKey('search');
      const refreshKey = ValueKey('refresh');
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              MobileToolbar(
                title: const Text('Library'),
                shortcuts: [
                  MobileToolbarButton(
                    key: searchKey,
                    label: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () => searches++,
                  ),
                  MobileToolbarButton(
                    key: refreshKey,
                    label: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => refreshes++,
                  ),
                ],
                more: MobileMenuButton(
                  items: [
                    prism.PopupMenuItem(
                      label: 'Copy',
                      subItems: [
                        prism.PopupMenuItem(
                          label: 'Title',
                          onPressed: () => copies++,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          glass: glass,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(prism.TonalButtonGroup), findsOneWidget);
      final context = tester.element(find.byType(MobileToolbar));
      expect(prism.LiquidGlassScope.of(context), glass != 'off');
      await tester.tap(find.byKey(searchKey));
      await tester.tap(find.byKey(refreshKey));
      await tester.pumpAndSettle();
      expect((searches, refreshes), (1, 1));

      await tester.tap(find.byType(MobileMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsWidgets);
      await tester.tap(find.text('Copy').hitTestable().last);
      await tester.pumpAndSettle();
      expect(find.text('Title').hitTestable(), findsOneWidget);
      expect(copies, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsNothing);
      expect(find.byType(prism.PopupMenu), findsOneWidget);
      await tester.tap(find.text('Copy').hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Title').hitTestable());
      await tester.pumpAndSettle();
      expect(copies, 1);
      expect(find.byType(prism.PopupMenu), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact navigation pushes and returns on the same navigator', (
    tester,
  ) async {
    _phone(tester);
    final navigator = GlobalKey<NavigatorState>();
    final observer = NaviObserver();
    const openKey = ValueKey('open-page');
    await tester.pumpWidget(
      _app(
        NaviPane(
          navigatorKey: navigator,
          observer: observer,
          paneItems: [
            PaneItemEntry(
              label: 'Home',
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              mobileGlyph: MobileNavGlyphs.home,
            ),
          ],
          paneActions: const [],
          pageBuilder: (_) => Builder(
            builder: (context) => Center(
              child: TextButton(
                key: openKey,
                onPressed: () => context.to(
                  () => const Material(
                    child: Column(
                      children: [
                        MobileToolbar(title: Text('Details'), showBack: true),
                      ],
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(prism.NavigationDock), findsOneWidget);
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    expect(observer.pageCount, 2);
    expect(observer.routes.last, isA<prism.CardRouteMixin<dynamic>>());
    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.byType(MobileToolbarButton));
    await tester.pumpAndSettle();
    expect(observer.pageCount, 1);
    expect(find.byKey(openKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
