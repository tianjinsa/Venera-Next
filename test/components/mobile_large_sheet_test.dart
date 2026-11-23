import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:prism_ui/sheet_header.dart' show SheetDragHandle;
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_large_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 800)
    ..viewPadding = const FakeViewPadding(top: 24, bottom: 24)
    ..padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  theme: ThemeData.dark(),
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: (context, child) => MobileUiTheme(
    glass: 'off',
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('phone sheet widens during drag, then scrolls its list', (
    tester,
  ) async {
    _phone(tester);
    final result = <int?>[];
    final list = find.byType(ListView);
    late ScrollController controller;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.add(
                await showMobileLargeSheet<int>(
                  context: context,
                  builder: (sheet) {
                    controller = PrimaryScrollController.of(sheet);
                    return ListView.builder(
                      primary: true,
                      itemExtent: 54,
                      itemCount: 80,
                      itemBuilder: (_, i) => TextButton(
                        onPressed: () => Navigator.pop(sheet, i),
                        child: Text('Row $i'),
                      ),
                    );
                  },
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('mobile-large-sheet-surface'));
    final half = tester.getRect(surface);
    expect(half.left, closeTo(8, 1));
    expect(half.top, closeTo(24 + (800 - 24) * .5, 1));
    expect(half.width, closeTo(374, 1));
    expect(tester.getBottomLeft(list).dy, lessThanOrEqualTo(800 - 24));

    final drag = await tester.startGesture(tester.getCenter(list));
    await drag.moveBy(const Offset(0, -34));
    await tester.pump();
    await drag.moveBy(const Offset(0, -80));
    await tester.pump();
    final mid = tester.getRect(surface);
    expect(mid.top, lessThan(half.top));
    expect(mid.width, inExclusiveRange(half.width, 390));
    expect(controller.offset, closeTo(0, 1));
    await drag.moveBy(const Offset(0, -75));
    await tester.pump();
    final wider = tester.getRect(surface);
    expect(wider.width, inExclusiveRange(mid.width, 390));
    await drag.moveBy(const Offset(0, -260));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).width, closeTo(390, 1));

    await tester.drag(list, const Offset(0, -170));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tester.getRect(surface).width, closeTo(390, 1));
    expect(result, isEmpty);
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    // At the top an intentional down-drag can leave the large detent. Do
    // not translate a dismissed route into a list selection.
    await tester.flingFrom(
      tester.getCenter(find.byType(SheetDragHandle)),
      const Offset(0, 725),
      1500,
    );
    await tester.pumpAndSettle();
    expect(result, [null]);
  });

  testWidgets('search survives keyboard lift and commits the filtered row', (
    tester,
  ) async {
    _phone(tester);
    final picks = <int>[];
    await tester.pumpWidget(
      _app(
        MobileChoice<int>(
          label: 'Choose a model',
          value: 0,
          searchable: true,
          onChanged: picks.add,
          options: [
            for (var i = 0; i < 15; i++) MobileChoiceOption(i, 'Model $i'),
          ],
        ),
        textScale: 1.65,
      ),
    );
    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Model 14');
    tester.view
      ..padding = const FakeViewPadding(top: 24)
      ..viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pumpAndSettle();
    final row = find
        .descendant(
          of: find.byType(prism.ListRow),
          matching: find.text('Model 14'),
        )
        .hitTestable();
    expect(row, findsOneWidget);
    expect(tester.getBottomLeft(row).dy, lessThan(800 - 310));
    expect(find.text('Model 13'), findsNothing);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(picks, [14]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned sheet removal releases exactly its own route', (
    tester,
  ) async {
    _phone(tester);
    late NavigatorState nav;
    late PopupRoute<int> owned;
    var disposed = 0;
    final results = <int?>[];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              nav = Navigator.of(context);
              owned = mobileLargeSheetRoute<int>(
                context: context,
                onDispose: () => disposed++,
                builder: (sheet) => Center(
                  child: TextButton(
                    child: const Text('Cover'),
                    onPressed: () => nav.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('Other')),
                      ),
                    ),
                  ),
                ),
              );
              results.add(await nav.push(owned));
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cover'));
    await tester.pumpAndSettle();
    nav.removeRoute(owned);
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    expect(disposed, 1);
    expect(results, [null]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
