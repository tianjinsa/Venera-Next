import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Rect _clip(WidgetTester tester) {
  final findClip = find.byKey(const ValueKey('search-route-reveal'));
  return tester
      .widget<ClipRSuperellipse>(findClip)
      .clipper!
      .getClip(tester.getSize(findClip))
      .outerRect;
}

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
      final surface = find.byType(SearchMorphSurface);
      final first = tester.widget<SearchMorphSurface>(surface);
      final start = first.frame.outline().getBounds();
      expect(start.left, closeTo(entry.rect.left, 1));
      expect(start.top, closeTo(entry.rect.top, 1));
      expect(start.right, closeTo(entry.rect.right, 1));
      expect(start.bottom, closeTo(entry.rect.bottom, 1));
      expect(first.glass, isNotNull);
      // During release the destination platter travels away from the
      // residual. It must not enclose the whole trigger like a rect tween.
      await tester.pump(const Duration(milliseconds: 135));
      final release = tester.widget<SearchMorphSurface>(surface).frame;
      expect(release.platter.contains(release.droplet!.center), isFalse);
      expect(release.droplet!.size.width, lessThan(start.width));
      await tester.pump(const Duration(milliseconds: 140));
      final middle = _clip(tester);
      expect(middle.width, greaterThan(release.platter.width));
      expect(middle.height, greaterThan(release.platter.height));
      expect(tester.getSize(find.byKey(destination)), const Size(390, 750));
      await tester.pumpAndSettle();
      expect(_clip(tester), const Rect.fromLTWH(0, 0, 390, 750));
      expect(surface, findsNothing);
      expect(builds, 1);
      owner.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 170));
      expect(_clip(tester).width, inExclusiveRange(0.0, 390.0));
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
