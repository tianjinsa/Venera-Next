import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/mobile_global_search_bar.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 750);
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {String glass = 'off', bool reduce = false}) =>
    MaterialApp(
      localizationsDelegates: const [MobileUiLocalizations.delegate],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: MobileUiTheme(glass: glass, child: child!),
      ),
      home: Scaffold(body: home),
    );

final _surface = find.byType(SearchMorphSurface);
final _backing = find.byKey(const ValueKey('search-route-backing'));
final _content = find.byKey(const ValueKey('search-route-content'));

Rect _bounds(WidgetTester tester) =>
    tester.widget<SearchMorphSurface>(_surface).frame.outline().getBounds();

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(_content).opacity;

void main() {
  for (final entry in [
    (name: 'home bar', rect: const Rect.fromLTWH(16, 68, 358, 50)),
    (name: 'toolbar button', rect: const Rect.fromLTWH(288, 8, 44, 44)),
    (name: 'detail tag', rect: const Rect.fromLTWH(82, 515, 140, 32)),
  ]) {
    testWidgets('search grows from the ${entry.name} and contracts back', (
      tester,
    ) async {
      _phone(tester);
      int builds = 0;
      late NavigatorState owner;
      const destination = ValueKey('destination');
      await tester.pumpWidget(
        _app(
          Stack(
            children: [
              Positioned.fromRect(
                rect: entry.rect,
                child: MobileSearchAnchor(
                  builder: (origin) => TextButton(
                    onPressed: () {
                      owner = Navigator.of(origin);
                      pushSearchFrom(origin, () {
                        builds++;
                        return const Scaffold(
                          key: destination,
                          body: Text('results'),
                        );
                      });
                    },
                    child: Text(entry.name),
                  ),
                ),
              ),
            ],
          ),
          glass: 'standard',
        ),
      );
      await tester.tap(find.text(entry.name));
      // A PageRoute with a HeroController is initially measured offstage.
      // Bring it onstage and inspect its first visible frame (not its midpoint).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      final start = _bounds(tester);
      expect(start.left, closeTo(entry.rect.left, 2));
      expect(start.top, closeTo(entry.rect.top, 2));
      expect(start.right, closeTo(entry.rect.right, 2));
      expect(start.bottom, closeTo(entry.rect.bottom, 2));
      final surface = tester.widget<SearchMorphSurface>(_surface);
      expect(surface.sourceColor.a, 1);
      expect(surface.destinationColor.a, 1);
      expect(_opacity(tester), 0);
      expect(_backing, findsNothing);

      await tester.pump(const Duration(milliseconds: 35));
      final early = _bounds(tester);
      expect(early, isNot(start));
      expect(early.contains(entry.rect.center), isTrue);
      expect(early.width, greaterThanOrEqualTo(start.width));
      expect(early.height, greaterThan(start.height));
      expect(_opacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 225));
      expect(_bounds(tester).height, greaterThan(early.height));
      expect(_opacity(tester), 0);
      const viewport = Rect.fromLTWH(0, 0, 390, 750);
      expect(tester.getRect(find.byKey(destination)), viewport);
      expect(find.text('results').hitTestable(), findsNothing);

      await tester.pump(const Duration(milliseconds: 80));
      final inFade = _opacity(tester);
      expect(inFade, inExclusiveRange(0, 1));
      expect(_surface, findsNothing);
      expect(tester.getRect(_backing), viewport);
      expect(
        tester.widget<ColoredBox>(_backing).color,
        surface.destinationColor,
      );
      expect(tester.getRect(find.byKey(destination)), viewport);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_opacity(tester), greaterThan(inFade));
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(tester.getRect(_backing), viewport);
      expect(builds, 1);
      owner.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester), inExclusiveRange(0, 1));
      expect(tester.getRect(_backing), viewport);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacity(tester), 0);
      expect(
        _bounds(tester).height,
        inExclusiveRange(entry.rect.height, 750.0),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.name).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduce motion skips the pane and still owns a normal route', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => pushSearchFrom(
              context,
              () => const Scaffold(body: BackButton()),
            ),
            child: const Text('entry'),
          ),
        ),
        glass: 'standard',
        reduce: true,
      ),
    );
    await tester.tap(find.text('entry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-route-reveal')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('entry').hitTestable(), findsOneWidget);
  });

  testWidgets('keyboard submission opens from the actual 46dp sliver field', (
    tester,
  ) async {
    _phone(tester);
    final submitted = <String>[];
    await tester.pumpWidget(
      _app(
        CustomScrollView(
          slivers: [
            SliverSearchBar(
              controller: SearchBarController(
                onSearch: (_) => fail('unanchored mobile fallback'),
              ),
              action: const SizedBox(width: 52),
              onSubmitFrom: (text, field) {
                submitted.add(text);
                pushSearchFrom<void>(
                  field,
                  () => const Scaffold(body: Text('matching book')),
                );
              },
            ),
          ],
        ),
      ),
    );
    final field = find.byKey(const ValueKey('mobile-global-search-field'));
    final trigger = tester.getRect(field);
    expect(trigger.height, 46);
    expect(trigger.width, lessThan(350));
    await tester.enterText(find.byType(EditableText), 'artist:Example');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    final start = _bounds(tester);
    expect(start.center.dx, closeTo(trigger.center.dx, 2));
    expect(start.center.dy, closeTo(trigger.center.dy, 2));
    expect(start.width, closeTo(trigger.width, 2));
    expect(start.height, closeTo(trigger.height, 2));
    expect(submitted, ['artist:Example']);
    await tester.pumpAndSettle();
    expect(find.text('matching book').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(EditableText).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'global field submits full source URLs; clear notifies suggestions',
    (tester) async {
      _phone(tester);
      final editing = TextEditingController();
      addTearDown(editing.dispose);
      final changes = <String>[], submitted = <String>[];
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.topCenter,
            child: MobileGlobalSearchBar(
              editing: editing,
              topPadding: 24,
              onSubmit: submitted.add,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      final uri = 'https://example.test/${'a' * 300}';
      await tester.enterText(find.byType(EditableText), uri);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, [uri]);
      expect(changes, [uri]);
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();
      expect(editing.text, '');
      expect(changes, [uri, '']);
    },
  );
}
