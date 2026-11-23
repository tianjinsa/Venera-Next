import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_collection_ui.dart';
import 'package:venera_next/components/mobile_ui.dart';

Widget _phone(Widget home) => MaterialApp(
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
  home: Scaffold(body: home),
);

void main() {
  test('collection options mark the saved choice without resubmitting it', () {
    final changes = <String>[];
    final current = collectionOption(
      label: 'Gallery',
      value: 'gallery',
      current: 'gallery',
      onSelected: changes.add,
    );
    final other = collectionOption(
      label: 'List',
      value: 'list',
      current: 'gallery',
      onSelected: changes.add,
    );
    expect(current.checked, isTrue);
    expect(other.checked, isFalse);
    current.onPressed!();
    expect(changes, isEmpty);
    other.onPressed!();
    expect(changes, ['list']);
  });

  testWidgets(
    'entering selection keeps tile state and adds selected semantics',
    (tester) async {
      final selected = ValueNotifier<bool?>(null);
      addTearDown(selected.dispose);
      const tile = ValueKey('tile');
      const child = ValueKey('tile-surface');
      await tester.pumpWidget(
        _phone(
          ValueListenableBuilder(
            valueListenable: selected,
            builder: (_, value, _) => SizedBox(
              width: 124,
              height: 180,
              child: MobileCollectionTileFrame(
                key: tile,
                selectionMode: value != null,
                selected: value ?? false,
                child: const ColoredBox(key: child, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
      final childElement = tester.element(find.byKey(child));
      final childBounds = tester.getRect(find.byKey(child));
      final tileSemantics = find.descendant(
        of: find.byKey(tile),
        matching: find.byType(Semantics),
      );
      expect(
        tester.widget<Semantics>(tileSemantics.first).properties.selected,
        isNull,
      );

      selected.value = true;
      await tester.pump();
      expect(tester.element(find.byKey(child)), same(childElement));
      expect(tester.getRect(find.byKey(child)), childBounds);
      expect(
        tester.widget<Semantics>(tileSemantics.first).properties.selected,
        isTrue,
      );
      selected.value = null;
      await tester.pump();
      expect(tester.element(find.byKey(child)), same(childElement));
      expect(tester.getRect(find.byKey(child)), childBounds);
    },
  );

  testWidgets('folder open and delete are separate touch targets', (
    tester,
  ) async {
    var opens = 0;
    var deletes = 0;
    await tester.pumpWidget(
      _phone(
        MobileCollectionFolder(
          label: 'A folder',
          onOpen: () => opens++,
          onDelete: () => deletes++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect((opens, deletes), (0, 1));
    await tester.tap(find.text('A folder'));
    expect((opens, deletes), (1, 1));
  });
}
