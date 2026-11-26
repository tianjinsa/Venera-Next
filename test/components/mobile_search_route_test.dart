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

SearchMorphFrame _frame(WidgetTester tester) =>
    tester.widget<SearchMorphSurface>(_surface).frame;

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
      final pressed = Offset(
        entry.rect.left + entry.rect.width * .22,
        entry.rect.top + entry.rect.height * .37,
      );
      await tester.tapAt(pressed);
      // A PageRoute with a HeroController is initially measured offstage.
      // Bring it onstage and inspect its first visible frame (not its midpoint).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      final start = _frame(tester);
      expect(start.center.dx, closeTo(pressed.dx, .01));
      expect(start.center.dy, closeTo(pressed.dy, .01));
      expect(start.center, isNot(entry.rect.center));
      expect(start.anchor, entry.rect);
      expect(start.radius, closeTo(entry.rect.shortestSide / 2, .1));
      final surface = tester.widget<SearchMorphSurface>(_surface);
      expect(surface.sourceColor.a, 1);
      expect(surface.destinationColor.a, 1);
      expect(_opacity(tester), 0);
      expect(_backing, findsNothing);

      await tester.pump(const Duration(milliseconds: 35));
      final early = _frame(tester);
      expect(early.center, start.center);
      expect(early.radius, greaterThan(start.radius));
      expect(_opacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 225));
      expect(_frame(tester).center, start.center);
      expect(_frame(tester).radius, greaterThan(early.radius));
      expect(_opacity(tester), 0);
      const viewport = Rect.fromLTWH(0, 0, 390, 750);
      expect(tester.getRect(find.byKey(destination)), viewport);
      expect(find.text('results').hitTestable(), findsNothing);

      await tester.pump(const Duration(milliseconds: 80));
      // 341 ms: the old 315 ms geometry already faded, but this slower
      // opening still keeps the destination hidden behind the growing surface.
      expect(_opacity(tester), 0);
      expect(_surface, findsOneWidget);
      expect(_backing, findsNothing);
      final route = ModalRoute.of(tester.element(find.byKey(destination)))!;
      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 340),
      );

      await tester.pump(const Duration(milliseconds: 25));
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
        _frame(tester).radius,
        inExclusiveRange(0.0, start.coveringRadius),
      );
      expect(_frame(tester).center, start.center);
      await tester.pump(const Duration(milliseconds: 160));
      final last = _frame(tester);
      expect(last.anchor, start.anchor);
      expect(last.radius, closeTo(start.radius, 5));
      await tester.pumpAndSettle();
      expect(find.text(entry.name).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reverse remeasures a relocated trigger without recentering its tap',
    (tester) async {
      _phone(tester);
      final position = ValueNotifier(const Offset(24, 80));
      addTearDown(position.dispose);
      late NavigatorState navigator;
      const buttonSize = Size(120, 44);
      const localTap = Offset(32, 23);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder(
            valueListenable: position,
            builder: (_, offset, _) => Stack(
              children: [
                Positioned.fromRect(
                  rect: offset & buttonSize,
                  child: MobileSearchAnchor(
                    builder: (origin) => TextButton(
                      child: const Text('Tap here'),
                      onPressed: () {
                        navigator = Navigator.of(origin);
                        pushSearchFrom<void>(origin, () => const Scaffold());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(position.value + localTap);
      await tester.pumpAndSettle();
      position.value = const Offset(177, 158);
      await tester.pump();
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_frame(tester).center, position.value + localTap);
      expect(_frame(tester).anchor, position.value & buttonSize);
      await tester.pumpAndSettle();
      expect(find.text('Tap here').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('reverse fades if the trigger leaves the tree', (tester) async {
    _phone(tester);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    late NavigatorState navigator;
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: visible,
          builder: (_, shown, _) => shown
              ? MobileSearchAnchor(
                  builder: (origin) => TextButton(
                    onPressed: () {
                      navigator = Navigator.of(origin);
                      pushSearchFrom<void>(origin, () => const Scaffold());
                    },
                    child: const Text('Search entry'),
                  ),
                )
              : const Text('No entry'),
        ),
      ),
    );
    await tester.tap(find.text('Search entry'));
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pump();
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    expect(_surface, findsNothing);
    expect(_backing, findsNothing);
    expect(_opacity(tester), closeTo(.5, .01));
    await tester.pumpAndSettle();
    expect(find.text('No entry'), findsOneWidget);
  });

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

  testWidgets(
    'keyboard submission opens from the actual visible caret, not the large field',
    (tester) async {
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
      final editor = find.byType(EditableText);
      await tester.enterText(editor, 'artist:Example');
      final state = tester.state<EditableTextState>(editor);
      final editing = state.widget.controller;
      editing.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      final render = state.renderEditable;
      final expected = render.localToGlobal(
        render.getLocalRectForCaret(editing.selection.extent).center,
      );
      expect((expected.dx - trigger.center.dx).abs(), greaterThan(20));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      final start = _frame(tester);
      expect(start.center.dx, closeTo(expected.dx, .01));
      expect(start.center.dy, closeTo(expected.dy, .01));
      expect(start.anchor, trigger);
      expect(start.radius, closeTo(trigger.shortestSide / 2, .1));
      expect(submitted, ['artist:Example']);
      await tester.pumpAndSettle();
      expect(find.text('matching book').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EditableText).hitTestable(), findsOneWidget);
    },
  );

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
