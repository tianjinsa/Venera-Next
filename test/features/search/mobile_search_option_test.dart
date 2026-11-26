import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
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
    final menu = find.byType(prism.PopupMenu);
    final scrollable = find.descendant(
      of: menu,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pumpAndSettle();
    final aliases = find.descendant(of: menu, matching: find.text('Alias'));
    expect(aliases, findsNWidgets(2));
    await tester.tap(aliases.last);
    await tester.pumpAndSettle();
    expect(writes, ['source-id-7']);
  });
}
