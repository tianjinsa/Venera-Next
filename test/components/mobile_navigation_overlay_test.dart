import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/navigation_dock.dart' as prism;
import 'package:venera_next/components/mobile_dock_inset.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/navigation_bar.dart';
import 'package:venera_next/components/scroll.dart';

void main() {
  testWidgets(
    'root tab paints and scrolls under the dock; a lone settings button acts directly',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 750)
        ..viewPadding = const FakeViewPadding(bottom: 24)
        ..padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      var settings = 0, outsideTaps = 0;
      final listController = ScrollController();
      addTearDown(listController.dispose);
      const viewport = ValueKey('viewport');
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          home: Material(
            child: NaviPane(
              observer: NaviObserver(),
              navigatorKey: GlobalKey<NavigatorState>(),
              paneItems: [
                PaneItemEntry(
                  label: 'Home',
                  icon: Icons.home,
                  activeIcon: Icons.home,
                  mobileGlyph: MobileNavGlyphs.home,
                ),
              ],
              paneActions: [
                PaneActionEntry(
                  label: 'Settings target',
                  icon: Icons.settings,
                  inMobileMenu: true,
                  onTap: () => settings++,
                ),
              ],
              pageBuilder: (_) => GestureDetector(
                key: viewport,
                behavior: HitTestBehavior.opaque,
                onTap: () => outsideTaps++,
                child: SmoothCustomScrollView(
                  controller: listController,
                  slivers: [
                    SliverFixedExtentList(
                      itemExtent: 60,
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Text('row $i'),
                        childCount: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final body = tester.getRect(find.byKey(viewport));
      final dock = tester.getRect(find.byType(prism.NavigationDock));
      expect(body.bottom, 750);
      expect(dock.bottom, body.bottom);
      expect(dock.top, lessThan(body.bottom));
      expect(
        MobileDockInset.of(tester.element(find.byKey(viewport))),
        greaterThan(24),
      );
      await tester.tapAt(Offset(3, body.bottom - 5));
      await tester.pump();
      expect(outsideTaps, 1);
      listController.jumpTo(listController.position.maxScrollExtent);
      await tester.pump();
      final label = tester.getRect(find.text('Home').last);
      expect(tester.getRect(find.text('row 39')).bottom, lessThan(label.top));
      expect(find.byType(MobileMenuButton), findsNothing);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      expect(settings, 1);
    },
  );
}
