import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:venera_next/components/mobile_collection_ui.dart';
import 'package:venera_next/components/mobile_ui.dart';

Finder _action(String label) =>
    find.byWidgetPredicate((w) => w is MobileToolbarButton && w.label == label);
final _pane = find.byKey(const ValueKey('collection-search-pane'));

int _imeShows(WidgetTester tester) => tester.testTextInput.log
    .where((call) => call.method == 'TextInput.show')
    .length;

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'collection search grows from the tapped slot ($direction), edits, clears and reverses',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final controller = TextEditingController();
        final open = ValueNotifier(false);
        final edits = <String>[];
        addTearDown(controller.dispose);
        addTearDown(open.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: SizedBox(
                  height: 52,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: open,
                    builder: (context, value, _) =>
                        MobileCollectionSearchToolbar(
                          search: CollectionBarSearch(
                            open: value,
                            controller: controller,
                            onOpen: () => open.value = true,
                            onClose: () => open.value = false,
                            onChanged: edits.add,
                            more: MobileMenuButton(
                              items: [collectionSelectionEntry(() {})],
                            ),
                          ),
                          toolbar: (button) => MobileToolbar(
                            height: 52,
                            title: const Text('Collection'),
                            shortcuts: [
                              button,
                              MobileToolbarButton(
                                label: 'Refresh',
                                icon: const Icon(Icons.refresh),
                                onPressed: () {},
                              ),
                            ],
                            more: MobileMenuButton(
                              items: [collectionSelectionEntry(() {})],
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.testTextInput.log.clear();
        final source = tester.getRect(_action('Search'));
        await tester.tap(_action('Search'));
        await tester.pump();
        expect(tester.getRect(_pane).center.dx, closeTo(source.center.dx, 1));
        expect(tester.getRect(_pane).width, closeTo(source.width, 1));
        await tester.pump(const Duration(milliseconds: 55));
        final mid = tester.getRect(_pane);
        expect(mid.width, greaterThan(source.width + 5));
        expect(_imeShows(tester), 0);
        await tester.tapAt(mid.center);
        await tester.pump();
        expect(_imeShows(tester), 0);

        // Back (also driven by PopScope at each real call site) during the
        // opening motion must not jump to the finished field.
        open.value = false;
        await tester.pump();
        expect(tester.getRect(_pane).width, closeTo(mid.width, 1));
        await tester.pump(const Duration(milliseconds: 14));
        expect(tester.getRect(_pane).width, lessThan(mid.width));
        // A fresh tap while closing plays from this exact frame, not zero.
        final reversing = tester.getRect(_pane);
        await tester.tap(_action('Search'));
        await tester.pump();
        expect(tester.getRect(_pane).width, closeTo(reversing.width, 1));
        expect(_imeShows(tester), 0);
        await tester.pumpAndSettle();
        expect(tester.getRect(_pane).width, greaterThan(mid.width));
        expect(find.byType(prism.SearchField), findsOneWidget);
        final editor = find.byType(EditableText);
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
        expect(_imeShows(tester), greaterThan(0));
        expect(
          tester.testTextInput.log.where(
            (m) => m.method == 'TextInput.setClient',
          ),
          hasLength(1),
        );
        await tester.enterText(editor, 'abc');
        await tester.pump();
        expect(controller.text, 'abc');
        expect(edits, ['abc']);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is prism.GlyphIcon && w.glyph == prism.Glyphs.clearField,
          ),
        );
        await tester.pump();
        expect(edits, ['abc', '']);
        expect(controller.text, isEmpty);
        await tester.tap(_action('Cancel'));
        await tester.pumpAndSettle();
        expect(_pane, findsNothing);
        expect(find.byType(prism.SearchField), findsNothing);
        expect(tester.getRect(_action('Search')), source);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a hidden collection cannot reopen the keyboard on a tab restore',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      final open = ValueNotifier(false);
      final visible = ValueNotifier(true);
      final input = TextEditingController(text: 'Retained query');
      addTearDown(visible.dispose);
      addTearDown(open.dispose);
      addTearDown(input.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: visible,
              builder: (_, shown, _) => !shown
                  ? const Text('Other tab')
                  : SizedBox(
                      height: 52,
                      child: ValueListenableBuilder(
                        valueListenable: open,
                        builder: (_, open, _) => MobileCollectionSearchToolbar(
                          search: CollectionBarSearch(
                            open: open,
                            controller: input,
                            onOpen: () {},
                            onClose: () {},
                            onChanged: (_) {},
                          ),
                          toolbar: (button) => MobileToolbar(
                            title: const Text('Collection'),
                            shortcuts: [button],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      );
      tester.testTextInput.log.clear();
      open.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      visible.value = false;
      await tester.pumpAndSettle();
      expect(_imeShows(tester), 0);
      visible.value = true;
      await tester.pumpAndSettle();
      final editor = find.byType(EditableText);
      expect(
        tester.widget<EditableText>(editor).controller.text,
        'Retained query',
      );
      expect(_imeShows(tester), 0);
      await tester.tap(editor);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(editor).focusNode.hasPrimaryFocus,
        isTrue,
      );
      expect(_imeShows(tester), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
