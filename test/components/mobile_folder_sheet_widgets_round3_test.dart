import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:prism_ui/popup.dart' as prism show PopupMenu, PopupMenuItem;
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_side_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/favorites/mobile_folder_sheet_widgets.dart';

void main() {
  testWidgets(
    'compact network section drops decoration before its label or action',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 680);
      addTearDown(tester.view.reset);
      final width = ValueNotifier(165.0);
      addTearDown(width.dispose);
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ValueListenableBuilder<double>(
                valueListenable: width,
                builder: (_, value, _) => SizedBox(
                  width: value,
                  child: MobileFolderSheetSection(
                    label: 'Network',
                    icon: Icons.cloud_outlined,
                    action: TextButton(
                      onPressed: () => activations++,
                      child: const Text('…'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final label = find.text('Network');
      final action = find.byType(TextButton);
      final compactLabel = tester.getRect(label);
      final compactAction = tester.getCenter(action);
      expect(find.byIcon(Icons.cloud_outlined), findsNothing);
      expect(label, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      width.value = 240;
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(tester.getTopLeft(label).dx, greaterThan(compactLabel.left));
      expect(tester.getCenter(action).dx, greaterThan(compactAction.dx));
      await tester.tap(action);
      expect(activations, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'ordinary row grows its rounded clip while left content stays fixed: $direction',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 680);
        addTearDown(tester.view.reset);
        const name = 'A long bilingual folder name 正常 / 收藏';
        const sceneKey = ValueKey('folder-row-scene');
        const minimum = 130.0; // 304dp safe width × .50 less the 22dp grip.
        const maximum = 206.0; // 304dp safe width × .75 less the 22dp grip.
        const background = Color(0xffff00ff);
        final width = ValueNotifier(minimum);
        addTearDown(width.dispose);
        var toggles = 0;
        var selections = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.6)),
              child: MobileUiTheme(
                glass: 'off',
                child: Directionality(textDirection: direction, child: child!),
              ),
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: sceneKey,
                child: ColoredBox(
                  color: background,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: MobileSideSheetLayout(
                      minContentWidth: minimum,
                      maxContentWidth: maximum,
                      child: ValueListenableBuilder<double>(
                        valueListenable: width,
                        child: ListView(
                          children: [
                            MobileFolderSheetRow(
                              label: name,
                              icon: Icons.folder_outlined,
                              count: 123456,
                              nested: true,
                              selected: true,
                              subfolders: [
                                prism.PopupMenuItem(
                                  label: 'Choose nested',
                                  onPressed: () => toggles++,
                                ),
                              ],
                              subtitle: 'Nested in another long label',
                              onPressed: () => selections++,
                            ),
                          ],
                        ),
                        builder: (_, value, child) =>
                            SizedBox(width: value, child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text(name);
        final icon = find.byKey(const ValueKey('mobile-folder-sheet-icon'));
        final count = find.byKey(const ValueKey('mobile-folder-sheet-count'));
        final toggle = find.byKey(
          const ValueKey('mobile-folder-sheet-subfolders'),
        );
        final select = find.byKey(const ValueKey('mobile-folder-sheet-select'));
        final mark = find.byKey(const ValueKey('mobile-folder-sheet-selected'));
        final outline = find.byKey(
          const ValueKey('mobile-folder-sheet-row-clip'),
        );
        final fixed = find.byKey(
          const ValueKey('mobile-folder-sheet-fixed-content'),
        );
        final narrow = tester.getRect(outline);
        final inner = tester.getRect(fixed);
        final stableTitle = tester.getRect(title);
        final stableCount = tester.getRect(count);
        expect(narrow.width, minimum - 6);
        expect(inner.width, maximum - 6);
        expect(inner.left, narrow.left);
        expect(stableTitle.left, greaterThan(tester.getRect(icon).right));
        expect(stableTitle.width, greaterThan(35));
        expect(stableTitle.right, lessThan(narrow.right));
        expect(stableCount.left, greaterThanOrEqualTo(narrow.right));
        expect(mark, findsOneWidget);
        expect(narrow.contains(tester.getCenter(mark)), isTrue);
        expect(toggle.hitTestable(), findsOneWidget);
        final anchor = tester.getRect(toggle);
        expect(anchor.center.dy, tester.getCenter(select).dy);
        expect(stableTitle.right, lessThan(anchor.left));
        expect(
          tester.getSemantics(select).getSemanticsData().label,
          allOf(contains(name), contains('123456 comics')),
        );

        Future<void> checkRoundedCorner() async {
          final bounds = tester.getRect(outline);
          final corner = Offset(bounds.right - 2, bounds.top + 2);
          final clipper = tester.widget<ClipPath>(outline).clipper!;
          expect(clipper, isA<ShapeBorderClipper>());
          expect(
            clipper.getClip(bounds.size).contains(corner - bounds.topLeft),
            isFalse,
          );
          final before = selections;
          await tester.tapAt(corner);
          await tester.pumpAndSettle();
          expect(selections, before);
          // Sample the produced picture too: the top-right pixel remains
          // background while a point inside the actual matte is painted.
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(sceneKey),
          );
          final inside = Offset(bounds.right - 3, bounds.center.dy);
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = (await picture.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              int pixel(Offset point) => bytes.getUint32(
                (point.dy.floor() * picture.width + point.dx.floor()) * 4,
              );
              expect(pixel(corner), 0xff00ffff);
              expect(pixel(inside), isNot(0xff00ffff));
            } finally {
              picture.dispose();
            }
          });
        }

        await checkRoundedCorner();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byType(prism.PopupMenu), findsOneWidget);
        expect((toggles, selections), (0, 0));
        await tester.tap(find.text('Choose nested'));
        await tester.pumpAndSettle();
        expect((toggles, selections), (1, 0));
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect((toggles, selections), (1, 1));
        for (final value in [168.0, maximum]) {
          width.value = value;
          await tester.pumpAndSettle();
          final revealed = tester.getRect(outline);
          expect(revealed.left, narrow.left);
          expect(revealed.width, value - 6);
          expect(revealed.height, narrow.height);
          expect(tester.getRect(fixed), inner);
          expect(tester.getRect(title), stableTitle);
          expect(tester.getRect(count), stableCount);
          await checkRoundedCorner();
        }
        expect(stableCount.right, lessThan(tester.getRect(outline).right));
        expect(tester.widget<Text>(count).data, '123456');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'sheet cells use Prism layout and an independent subfolder menu: $direction',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(320, 680);
        addTearDown(tester.view.reset);

        String? selected;
        var pickedChild = 0;
        int closed = 0;
        const parent = ValueKey('parent');
        const trailing = ValueKey('trailing');
        const parentName = 'A long parent folder name ending in / 正常';
        final parentByKey = find.byKey(parent);
        Finder inside(Finder host, Key key) =>
            find.descendant(of: host, matching: find.byKey(key));
        final expand = inside(
          parentByKey,
          const ValueKey('mobile-folder-sheet-subfolders'),
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
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.6)),
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
                        subfolders: [
                          const prism.PopupMenuItem(
                            label: 'Disabled nested folder',
                          ),
                          prism.PopupMenuItem(
                            label: 'Checked nested folder',
                            checked: true,
                            onPressed: () => pickedChild++,
                          ),
                        ],
                        onPressed: () => update(() => selected = parentName),
                      ),
                      MobileFolderSheetRow(
                        key: trailing,
                        label: 'Network library',
                        icon: Icons.cloud_outlined,
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
        final menu = find.byType(prism.PopupMenu);
        final disabled = find.text('Disabled nested folder');
        final checked = find.text('Checked nested folder');
        expect(disabled, findsNothing);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(menu, findsOneWidget);
        final items = tester.widget<prism.PopupMenu>(menu).items;
        expect(items.map((item) => item.label), [
          'Disabled nested folder',
          'Checked nested folder',
        ]);
        expect(items.first.onPressed, isNull);
        expect(items.last.checked, isTrue);
        expect(
          inside(
            find.byKey(trailing),
            const ValueKey('mobile-folder-sheet-count'),
          ),
          findsNothing,
        );
        expect(
          inside(
            find.byKey(trailing),
            const ValueKey('mobile-folder-sheet-subfolders'),
          ),
          findsNothing,
        );
        await tester.tap(disabled);
        await tester.pumpAndSettle();
        expect(menu, findsOneWidget);
        expect(selected, isNull);
        expect(pickedChild, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(menu, findsNothing);
        expect(disabled, findsNothing);
        expect(
          tester.getSemantics(select).getSemanticsData().label,
          contains(parentName),
        );
        await tester.tap(find.text(parentName));
        await tester.pumpAndSettle();
        expect(mark, findsOneWidget);
        expect(tester.widget<MobileContentSurface>(surface).selected, isTrue);
        expect(selected, parentName);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        await tester.tap(checked);
        await tester.pumpAndSettle();
        expect(menu, findsNothing);
        expect(pickedChild, 1);
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
