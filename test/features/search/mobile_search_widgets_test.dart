import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/chip.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/search/mobile_search_widgets.dart';

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(320, 720);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: const [MobileUiLocalizations.delegate],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(1.6)),
        child: MobileUiTheme(glass: 'off', child: child!),
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('search row tap and trailing menu never claim one another', (
    tester,
  ) async {
    const rowKey = ValueKey('saved source row');
    var actions = 0;
    await _mount(
      tester,
      Column(
        children: [
          const MobileSearchSectionHeader('Saved tag searches'),
          MobileSearchMenuRow(
            key: rowKey,
            title: 'A saved source and tag lookup',
            subtitle: 'Source · namespace',
            items: [
              prism.PopupMenuItem(
                label: 'Copy fixture',
                onPressed: () => actions++,
              ),
            ],
            onSearch: (origin) => pushSearchFrom<void>(
              origin,
              () => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(origin).pop(),
                    child: const Text('Destination'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final row = find.byType(MobileSearchRow);
    final title = find.text('A saved source and tag lookup');
    expect(row, findsOneWidget);
    final tap = tester.getCenter(title);
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    final frame = tester
        .widget<SearchMorphSurface>(find.byType(SearchMorphSurface))
        .frame;
    expect(frame.center.dx, closeTo(tap.dx, .01));
    expect(frame.center.dy, closeTo(tap.dy, .01));
    expect(frame.radius, lessThan(4));
    await tester.pumpAndSettle();
    expect(find.text('Destination').hitTestable(), findsOneWidget);
    expect(find.text('Copy fixture'), findsNothing);
    await tester.tap(find.text('Destination'));
    await tester.pumpAndSettle();

    final menu = find.descendant(
      of: find.byKey(rowKey),
      matching: find.byType(MobileToolbarButton),
    );
    final choose = find.text('Copy fixture');
    Future<void> select() async {
      await tester.pumpAndSettle();
      expect(choose.hitTestable(), findsOneWidget);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsNothing);
    }

    await tester.tap(menu);
    await select();
    await tester.longPress(title);
    await select();
    await tester.tap(title, buttons: kSecondaryMouseButton);
    await select();
    expect(actions, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow mobile choice and suggestion retain labels and actions', (
    tester,
  ) async {
    final changes = <String>[];
    await _mount(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MobileSearchSectionHeader('Search in'),
          StatefulBuilder(
            builder: (context, setState) => MobileSearchChoiceChip(
              label: 'Very long comic provider first choice',
              selected: changes.isNotEmpty,
              onPressed: () => setState(() => changes.add('source key')),
            ),
          ),
          MobileSearchTagSuggestion(
            tag: 'My tag suggestion',
            namespace: 'artist',
            translation: 'Translated tag',
            onSelected: () => changes.add('tag insertion'),
          ),
        ],
      ),
    );
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(MobileContentSurface), findsOneWidget);
    final source = find.byType(prism.Chip);
    expect(tester.widget<prism.Chip>(source).selected, isFalse);
    await tester.tap(source);
    await tester.pumpAndSettle();
    expect(tester.widget<prism.Chip>(source).selected, isTrue);
    expect(find.text('Translated tag · artist'), findsOneWidget);
    await tester.tap(find.text('My tag suggestion'));
    expect(changes, ['source key', 'tag insertion']);
    expect(find.byType(SearchMorphSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
