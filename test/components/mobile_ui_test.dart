import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/button.dart' as prism show TonalButtonGroup;
import 'package:prism_ui/liquid_glass.dart' as prism show LiquidGlassScope;
import 'package:prism_ui/navigation_dock.dart' as prism;
import 'package:prism_ui/page_transition.dart' as prism show CardRouteMixin;
import 'package:prism_ui/popup.dart' as prism show PopupMenu, PopupMenuItem;
import 'package:venera_next/components/mobile_search_route.dart';
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

  for (final count in [3, 4, 5]) {
    testWidgets('$count shortcuts form independent pairs and keep More', (
      tester,
    ) async {
      _phone(tester);
      final picked = <int>[];
      await tester.pumpWidget(
        _app(
          MobileToolbar(
            title: const Text('Library'),
            shortcuts: [
              for (var i = 0; i < count; i++)
                MobileToolbarButton(
                  key: ValueKey(i),
                  label: 'Action $i',
                  icon: const Icon(Icons.circle),
                  onPressed: () => picked.add(i),
                ),
            ],
            more: MobileMenuButton(
              key: const ValueKey('separate-more'),
              items: [
                prism.PopupMenuItem(
                  label: 'More action',
                  onPressed: () => picked.add(count),
                ),
              ],
            ),
          ),
          glass: 'off',
        ),
      );
      final capsules = find.byType(prism.TonalButtonGroup);
      expect(capsules, findsNWidgets(count ~/ 2));
      for (var i = 0; i < count ~/ 2; i++) {
        final capsule = capsules.at(i);
        expect(
          tester.widget<prism.TonalButtonGroup>(capsule).children,
          hasLength(2),
        );
        for (final index in [2 * i, 2 * i + 1]) {
          expect(
            find.descendant(of: capsule, matching: find.byKey(ValueKey(index))),
            findsOneWidget,
          );
        }
        if (i > 0) {
          expect(
            tester.getRect(capsule).left,
            tester.getRect(capsules.at(i - 1)).right + MobileToolbarActions.gap,
          );
        }
      }
      if (count.isOdd) {
        expect(
          find.descendant(
            of: capsules,
            matching: find.byKey(ValueKey(count - 1)),
          ),
          findsNothing,
        );
      }
      for (var i = 0; i < count; i++) {
        await tester.tap(find.byKey(ValueKey(i)).hitTestable());
        await tester.pumpAndSettle();
      }
      final more = find.byKey(const ValueKey('separate-more'));
      expect(find.descendant(of: capsules, matching: more), findsNothing);
      expect(
        tester.getRect(more).left,
        tester.getRect(find.byKey(ValueKey(count - 1))).right +
            MobileToolbarActions.gap,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text('More action').hitTestable());
      await tester.pumpAndSettle();
      expect(picked, List<int>.generate(count + 1, (index) => index));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'very narrow toolbar scrolls shortcuts without hiding Back or More',
    (tester) async {
      _phone(tester, width: 280);
      final picks = <String>[];
      await tester.pumpWidget(
        _app(
          MobileToolbar(
            title: const Text('Library'),
            leading: MobileToolbarButton(
              label: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => picks.add('back'),
            ),
            shortcuts: [
              for (var i = 0; i < 5; i++)
                MobileToolbarButton(
                  label: 'Shortcut $i',
                  icon: const Icon(Icons.circle),
                  onPressed: () => picks.add('$i'),
                ),
            ],
            more: MobileToolbarButton(
              label: 'More',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => picks.add('more'),
            ),
          ),
          glass: 'off',
        ),
      );
      final scrollable = find.descendant(
        of: find.byType(MobileToolbar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(find.byTooltip('Shortcut 4').hitTestable(), findsNothing);
      final back = find.byTooltip('Back');
      final more = find.byTooltip('More');
      final backLocation = tester.getCenter(back);
      final moreLocation = tester.getCenter(more);
      await tester.drag(scrollable, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(tester.getCenter(back), backLocation);
      expect(tester.getCenter(more), moreLocation);
      await tester.tap(find.byTooltip('Shortcut 4').hitTestable());
      await tester.tap(back);
      await tester.tap(more);
      expect(picks, ['4', 'back', 'more']);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'grouped pane search starts from the actual tap, not its shared lens',
    (tester) async {
      _phone(tester);
      final navigator = GlobalKey<NavigatorState>();
      final observer = NaviObserver();
      var settingsTaps = 0;
      await tester.pumpWidget(
        _app(
          NaviPane(
            navigatorKey: navigator,
            observer: observer,
            paneItems: [
              PaneItemEntry(
                label: 'Favorites',
                icon: Icons.favorite_outline,
                activeIcon: Icons.favorite,
                mobileGlyph: MobileNavGlyphs.favorites,
              ),
            ],
            paneActions: [
              PaneActionEntry(
                label: 'Search',
                icon: Icons.search,
                onTap: () => fail('compact search must use its actual anchor'),
                onMobileTapFrom: (origin) => pushSearchFrom(
                  origin,
                  () => const Scaffold(body: Text('Search destination')),
                ),
              ),
              PaneActionEntry(
                label: 'Settings',
                icon: Icons.settings,
                onTap: () => settingsTaps++,
              ),
            ],
            pageBuilder: (_) => const SizedBox.expand(),
          ),
          glass: 'off',
        ),
      );
      await tester.pumpAndSettle();
      Finder action(String label) => find.byWidgetPredicate(
        (w) => w is MobileToolbarButton && w.label == label,
      );
      final search = action('Search');
      final settings = action('Settings');
      final capsule = find.byType(prism.TonalButtonGroup);
      expect(capsule, findsOneWidget);
      expect(find.descendant(of: capsule, matching: search), findsOneWidget);
      expect(find.descendant(of: capsule, matching: settings), findsOneWidget);
      final source = tester.getRect(search);
      final pressed = source.center + const Offset(-6, 4);
      await tester.tapAt(pressed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      final morph = tester.widget<SearchMorphSurface>(
        find.byType(SearchMorphSurface),
      );
      final start = morph.frame;
      expect(start.center.dx, closeTo(pressed.dx, .01));
      expect(start.center.dy, closeTo(pressed.dy, .01));
      expect(start.radius, closeTo(start.anchor.shortestSide / 2, .1));
      await tester.pumpAndSettle();
      expect(observer.pageCount, 2);
      expect(find.text('Search destination'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(observer.pageCount, 1);
      await tester.tap(settings.hitTestable());
      expect(settingsTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
