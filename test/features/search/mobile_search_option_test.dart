import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/search/search_page.dart';

void main() {
  testWidgets('source filter returns the option key, not its display label', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final writes = <String>[];
    final options = SearchOptions(
      LinkedHashMap.of({
        for (var i = 0; i < 8; i++) 'source-id-$i': i > 5 ? 'Alias' : 'Row $i',
      }),
      'Sort comics',
      'dropdown',
      null,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [MobileUiLocalizations.delegate],
        builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
        home: Scaffold(
          body: Center(
            child: SearchOptionWidget(
              option: options,
              sourceKey: 'fixture',
              value: 'source-id-0',
              onChanged: writes.add,
            ),
          ),
        ),
      ),
    );
    final trigger = find.byType(MobileChoiceButton);
    expect(
      tester.getCenter(trigger).dx,
      greaterThan(tester.getCenter(find.text('Sort comics')).dx),
    );
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final key = find.byKey(const ValueKey('source-id-7'));
    await tester.scrollUntilVisible(
      key,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(key);
    await tester.pumpAndSettle();
    expect(writes, ['source-id-7']);
  });
}
