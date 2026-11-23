import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_ui.dart';

const _summary = ValueKey('summary surface');
const _rows = ValueKey('row list');
const _desktopRow = ValueKey('desktop row');

Finder _gradientIn(Finder root) => find.descendant(
  of: root,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is ShapeDecoration &&
        (widget.decoration as ShapeDecoration).gradient is LinearGradient,
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'home card and lazy rows share a paint-only glass layer ($brightness)',
      (tester) async {
        // View drives MediaQuery (the compact gate), not just constraints.
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 750);
        addTearDown(tester.view.reset);
        final glass = ValueNotifier(true);
        addTearDown(glass.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var summaryTaps = 0;
        var summaryLongPresses = 0;
        var accessoryTaps = 0;
        var rowTaps = 0;
        var rowsBuilt = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
            home: Material(
              child: ValueListenableBuilder(
                valueListenable: glass,
                builder: (context, enabled, _) => prism.LiquidGlassScope(
                  enabled: enabled,
                  child: Column(
                    children: [
                      MobileContentSurface.summary(
                        key: _summary,
                        child: ClickInkWell(
                          onTap: () => summaryTaps++,
                          onLongPress: () => summaryLongPresses++,
                          child: const SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: Text('Home summary'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          key: _rows,
                          controller: controller,
                          itemCount: 1000,
                          itemBuilder: (_, index) {
                            rowsBuilt++;
                            return MobileContentRow(
                              title: Text('Folder $index'),
                              leading: const Icon(Icons.folder_outlined),
                              trailing: IconButton(
                                tooltip: 'Details $index',
                                onPressed: () => accessoryTaps++,
                                icon: const Icon(Icons.chevron_right),
                              ),
                              onTap: () => rowTaps++,
                            );
                          },
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
        expect(_gradientIn(find.byKey(_summary)), findsOneWidget);
        expect(_gradientIn(find.byKey(_rows)), findsWidgets);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(rowsBuilt, lessThan(100));

        await tester.tap(find.text('Home summary'));
        await tester.longPress(find.text('Home summary'));
        await tester.tap(find.text('Folder 0'));
        await tester.tap(find.byTooltip('Details 0'));
        expect(summaryTaps, 1);
        expect(summaryLongPresses, 1);
        expect(rowTaps, 1);
        expect(accessoryTaps, 1);

        glass.value = false;
        await tester.pumpAndSettle();
        expect(_gradientIn(find.byKey(_summary)), findsNothing);
        expect(_gradientIn(find.byKey(_rows)), findsNothing);
        controller.jumpTo(750);
        await tester.pumpAndSettle();
        expect(find.text('Folder 0'), findsNothing);
        expect(find.byType(MobileContentRow).evaluate().length, lessThan(40));
        expect(find.text('Folder 999'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final selected in [false, true]) {
      testWidgets(
        'card stays darker than its actual scaffold, still readable: $brightness selected=$selected',
        (tester) async {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(390, 750);
          addTearDown(tester.view.reset);
          final scheme = ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: brightness,
          );
          // Explicit override catches the former independently seeded Prism card.
          final page = brightness == Brightness.dark
              ? const Color(0xff101115)
              : const Color(0xfffafafa);
          for (final quality in ['off', 'standard', 'ultra']) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  colorScheme: scheme,
                  scaffoldBackgroundColor: page,
                ),
                builder: (_, child) =>
                    MobileUiTheme(glass: quality, child: child!),
                home: Scaffold(
                  body: MobileContentSurface(
                    key: _summary,
                    selected: selected,
                    child: const Text('Readable card'),
                  ),
                ),
              ),
            );
            await tester.pump();
            final fill = tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(_summary),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .map((w) => w.decoration)
                .whereType<ShapeDecoration>()
                .firstWhere((d) => d.color != null || d.gradient != null);
            expect(fill.gradient == null, quality == 'off');
            final stops = fill.gradient?.colors ?? [fill.color!];
            for (final color in stops) {
              final ink = scheme.onSurface.computeLuminance();
              final body = color.computeLuminance();
              expect(body, lessThan(page.computeLuminance()));
              final contrast = ink > body
                  ? (ink + .05) / (body + .05)
                  : (body + .05) / (ink + .05);
              expect(contrast, greaterThanOrEqualTo(4.5));
            }
            expect(find.byType(BackdropFilter), findsNothing);
          }
        },
      );
    }
  }

  testWidgets('desktop keeps plain rows and the original summary decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Column(
            children: [
              MobileContentSurface.summary(
                key: _summary,
                child: SizedBox(width: 300, height: 55),
              ),
              MobileContentSurface(
                key: _desktopRow,
                margin: EdgeInsets.all(18),
                child: SizedBox(width: 300, height: 42),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_gradientIn(find.byKey(_summary)), findsNothing);
    final summaryBox = find.descendant(
      of: find.byKey(_summary),
      matching: find.byType(DecoratedBox),
    );
    expect(
      tester.widget<DecoratedBox>(summaryBox).decoration,
      isA<BoxDecoration>(),
    );
    expect(tester.getSize(find.byKey(_desktopRow)), const Size(300, 42));
    expect(
      find.descendant(
        of: find.byKey(_desktopRow),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });
}
