import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/favorites/mobile_folder_sheet_widgets.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      '40%-width folder cells prioritize name and separate toggle: $direction',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 680);
        addTearDown(tester.view.reset);
        const name = 'A long bilingual folder name 正常 / 收藏';
        var toggles = 0;
        var selections = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.6)),
              child: MobileUiTheme(
                glass: 'off',
                child: Directionality(textDirection: direction, child: child!),
              ),
            ),
            home: Scaffold(
              body: SizedBox(
                // 40% of a 304dp safe viewport, minus the 22dp physical rail.
                width: 99.6,
                child: ListView(
                  children: [
                    MobileFolderSheetRow(
                      label: name,
                      icon: Icons.folder_outlined,
                      count: 123456,
                      nested: true,
                      selected: true,
                      expanded: false,
                      subtitle: 'Nested in another long label',
                      onToggle: () => toggles++,
                      onPressed: () => selections++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text(name);
        final count = find.byKey(const ValueKey('mobile-folder-sheet-count'));
        final toggle = find.byKey(const ValueKey('mobile-folder-sheet-expand'));
        final select = find.byKey(const ValueKey('mobile-folder-sheet-select'));
        expect(tester.getRect(title).width, greaterThan(65));
        expect(
          tester.getRect(title).bottom,
          lessThan(tester.getRect(count).top),
        );
        expect(
          tester.getRect(select).bottom,
          lessThanOrEqualTo(tester.getRect(toggle).top),
        );
        expect(tester.widget<Text>(count).data, '123456');
        expect(
          tester.getSemantics(select).getSemanticsData().label,
          contains(name),
        );
        expect(
          tester.getSemantics(select).getSemanticsData().label,
          contains('123456 comics'),
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect((toggles, selections), (1, 0));
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect((toggles, selections), (1, 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'sheet cells use Prism layout, separate selection and expansion: $direction',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 680);
        addTearDown(tester.view.reset);

        bool expanded = false;
        String? selected;
        int closed = 0;
        const parent = ValueKey('parent');
        const child = ValueKey('child');
        const trailing = ValueKey('trailing');
        const parentName = 'A long parent folder name ending in / 正常';
        final parentByKey = find.byKey(parent);
        Finder inside(Finder host, Key key) =>
            find.descendant(of: host, matching: find.byKey(key));
        final expand = inside(
          parentByKey,
          const ValueKey('mobile-folder-sheet-expand'),
        );
        final select = inside(
          parentByKey,
          const ValueKey('mobile-folder-sheet-select'),
        );
        final mark = inside(
          parentByKey,
          const ValueKey('mobile-folder-sheet-selected'),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.6)),
              child: MobileUiTheme(
                glass: 'off',
                child: Directionality(textDirection: direction, child: child!),
              ),
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => SizedBox(
                  width: 238,
                  child: ListView(
                    children: [
                      MobileFolderSheetHeader(onClose: () => closed++),
                      MobileFolderSheetSection(
                        label: 'Local',
                        icon: Icons.folder_outlined,
                        action: MobileToolbarButton(
                          label: 'More',
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () {},
                        ),
                      ),
                      MobileFolderSheetRow(
                        key: parent,
                        label: parentName,
                        icon: Icons.folder_outlined,
                        count: 123456,
                        selected: selected == parentName,
                        expanded: expanded,
                        onToggle: () => update(() => expanded = !expanded),
                        onPressed: () => update(() => selected = parentName),
                      ),
                      if (expanded)
                        const MobileFolderSheetRow(
                          key: child,
                          label: 'Disabled nested folder',
                          nested: true,
                          icon: Icons.folder_outlined,
                        ),
                      MobileFolderSheetRow(
                        key: trailing,
                        label: 'Network library',
                        icon: Icons.cloud_outlined,
                        count: 5,
                        onPressed: () => update(() => selected = 'Network'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: parentByKey,
            matching: find.byType(prism.ListRow),
          ),
          findsOneWidget,
        );
        final surface = find.descendant(
          of: parentByKey,
          matching: find.byType(MobileContentSurface),
        );
        expect(tester.widget<MobileContentSurface>(surface).selected, isFalse);
        expect(find.byKey(child), findsNothing);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(find.byKey(child), findsOneWidget);
        final parentCell = tester.getRect(select);
        final childCell = tester.getRect(
          inside(
            find.byKey(child),
            const ValueKey('mobile-folder-sheet-select'),
          ),
        );
        if (direction == TextDirection.ltr) {
          expect(childCell.left, greaterThan(parentCell.left));
        } else {
          expect(childCell.right, lessThan(parentCell.right));
        }
        await tester.tap(find.text('Disabled nested folder'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        // The actionable node combines the name and count; truncation
        // is visual only, it must retain the entire original folder name.
        expect(
          tester.getSemantics(select).getSemanticsData().label,
          contains(parentName),
        );
        await tester.tap(select);
        await tester.pumpAndSettle();
        expect(mark, findsOneWidget);
        expect(tester.widget<MobileContentSurface>(surface).selected, isTrue);
        expect(selected, parentName);
        expect(find.byKey(child), findsOneWidget);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(find.byKey(child), findsNothing);
        expect(selected, parentName);
        await tester.tap(
          find.byKey(const ValueKey('mobile-folder-sheet-close')),
        );
        await tester.pumpAndSettle();
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
