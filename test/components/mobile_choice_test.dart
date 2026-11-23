import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/item_position.dart' as prism;
import 'package:prism_ui/inherited.dart' as prism;
import 'package:prism_ui/card.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;
import 'package:venera_next/components/mobile_setting_row.dart';
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_ui.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
  home: Scaffold(
    body: Center(child: SizedBox(width: 280, child: child)),
  ),
);

const _short = [
  MobileChoiceOption(1, 'Manual'),
  MobileChoiceOption(2, 'Automatic'),
  MobileChoiceOption(3, 'Unavailable', enabled: false),
];

void main() {
  testWidgets('marks the current short value and commits only a valid pick', (
    tester,
  ) async {
    _phone(tester);
    final changes = <int>[];
    final value = ValueNotifier(1);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: value,
          builder: (context, current, _) => MobileChoice<int>(
            label: 'Mode',
            value: current,
            options: _short,
            onChanged: (picked) {
              changes.add(picked);
              value.value = picked;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    final menu = tester.widget<prism.PopupMenu>(find.byType(prism.PopupMenu));
    expect(menu.items.map((item) => item.checked), [true, false, false]);
    expect(menu.items.last.onPressed, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic').hitTestable());
    await tester.pumpAndSettle();
    expect(changes, [2]);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.byType(prism.PopupMenu), findsNothing);
  });

  for (final width in [244.0, 350.0]) {
    for (final scale in [1.0, 2.5]) {
      testWidgets('trailing choice at width $width and text scale $scale', (
        tester,
      ) async {
        _phone(tester);
        const label = '阅读器图片方向与双页布局选项';
        const selected = '跟随当前漫画设置并自动切换方向';
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: MobileUiTheme(glass: 'off', child: child!),
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: MobileChoiceFormField<int>(
                    label: label,
                    initialValue: 1,
                    options: const [MobileChoiceOption(1, selected)],
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final title = tester.getRect(find.text(label));
        final value = tester.getRect(find.byType(MobileChoiceButton));
        expect(title.right, lessThanOrEqualTo(value.left));
        expect(title.center.dy, closeTo(value.center.dy, 1));
        expect(value.right, closeTo((390 + width) / 2, 1));
        expect(value.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'production setting group joins rows, opens from title and cancels without a write',
    (tester) async {
      _phone(tester);
      final changes = <int>[];
      final toggles = <bool>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: settingGroup(context, [
                SettingChoiceRow(
                  title: const Text('Reading mode'),
                  subtitle: const Text('Only this comic'),
                  choice: MobileChoice<int>(
                    setting: true,
                    value: 1,
                    options: _short,
                    onChanged: changes.add,
                  ),
                ),
                SettingSwitchRow(
                  title: const Text('Dim reader'),
                  value: false,
                  onChanged: toggles.add,
                ),
                const SettingRow(
                  title: Text('Update preferences'),
                  trailing: SettingDisclosure(),
                ),
              ]),
            ),
          ),
        ),
      );
      final rows = find.byType(prism.Card);
      expect(rows, findsNWidgets(3));
      expect(
        rows.evaluate().map((e) => prism.ItemPositionProvider.of(e)!.position),
        [
          prism.ItemPosition.start,
          prism.ItemPosition.middle,
          prism.ItemPosition.end,
        ],
      );
      const groupedCorner = Radius.circular(prism.AppCorner.listGroup);
      expect(
        tester
            .widgetList<prism.Card>(rows)
            .map(
              (card) => (card.shape! as RoundedSuperellipseBorder).borderRadius,
            ),
        [
          const BorderRadius.vertical(top: groupedCorner),
          BorderRadius.zero,
          const BorderRadius.vertical(bottom: groupedCorner),
        ],
      );
      expect(
        tester.getBottomLeft(rows.at(0)).dy,
        tester.getTopLeft(rows.at(1)).dy,
      );
      expect(
        tester.getBottomLeft(rows.at(1)).dy,
        tester.getTopLeft(rows.at(2)).dy,
      );
      final button = find.byType(MobileChoiceButton);
      expect(
        tester.getRect(find.text('Reading mode')).right,
        lessThan(tester.getRect(button).left),
      );
      expect(
        tester.getRect(find.text('Only this comic')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Reading mode')).bottom),
      );
      await tester.tap(find.text('Reading mode'));
      await tester.pumpAndSettle();
      expect(find.byType(prism.PopupMenu), findsOneWidget);
      expect(find.byType(MobileChoiceSheetFrame), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.tap(find.text('Dim reader'));
      await tester.pumpAndSettle();
      expect(toggles, [true]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets('long setting stays at its value and scrolls ($direction)', (
      tester,
    ) async {
      _phone(tester);
      final changes = <int>[];
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: direction,
            child: MobileChoiceFormField<int>(
              label: 'Reader mode',
              initialValue: 2,
              options: [
                for (var i = 0; i < 50; i++) MobileChoiceOption(i, 'Mode $i'),
              ],
              onChanged: changes.add,
            ),
          ),
        ),
      );
      final target = find.byType(MobileChoiceButton);
      final reference = tester.getRect(target);
      final textButton = tester.widget<prism.TextButton>(
        find.descendant(of: target, matching: find.byType(prism.TextButton)),
      );
      expect(find.byType(prism.OutlinedButton), findsNothing);
      expect(
        textButton.style!.foregroundColor!.resolve({}),
        prism.Theme.of(tester.element(target)).colorScheme.onSurfaceVariant,
      );
      expect(
        tester
            .widget<prism.GlyphIcon>(
              find.descendant(
                of: target,
                matching: find.byType(prism.GlyphIcon),
              ),
            )
            .glyph,
        prism.Glyphs.picker,
      );
      // Tap the row label rather than the value. The popup still leaves the value.
      await tester.tap(find.text('Reader mode'));
      await tester.pumpAndSettle();
      final pop = find.byType(prism.PopupMenu);
      final menu = tester.widget<prism.PopupMenu>(pop);
      final menuRect = tester.getRect(pop);
      expect(
        tester
            .widget<prism.PopupAnchor>(find.byType(prism.PopupAnchor))
            .placement,
        direction == TextDirection.ltr
            ? prism.PopupPlacement.overAnchorEnd
            : prism.PopupPlacement.overAnchorStart,
      );
      expect(find.byType(MobileChoiceSheetFrame), findsNothing);
      expect(
        menu.items.where((item) => item.checked == true).single.label,
        'Mode 2',
      );
      expect(menuRect.height, lessThan(420));
      expect(menuRect.width, lessThan(350));
      expect(
        direction == TextDirection.ltr ? menuRect.right : menuRect.left,
        closeTo(
          direction == TextDirection.ltr ? reference.right : reference.left,
          2,
        ),
      );
      await tester.tapAt(const Offset(8, 24));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(pop, findsNothing);
      await tester.tap(target);
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: pop,
        matching: find.byType(Scrollable),
      );
      expect(scroll, findsOneWidget);
      final destination = find.text('Mode 32').hitTestable();
      final viewport = tester.state<ScrollableState>(scroll).position;
      expect(viewport.pixels, 0);
      for (var i = 0; i < 20 && destination.evaluate().isEmpty; i++) {
        await tester.drag(scroll, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      expect(viewport.pixels, greaterThan(0));
      expect(destination, findsOneWidget);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(changes, [32]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('choice form participates in validation, reset, and save', (
    tester,
  ) async {
    _phone(tester);
    final form = GlobalKey<FormState>();
    final field = GlobalKey<FormFieldState<int>>();
    final saved = <int?>[];
    final changes = <int>[];
    await tester.pumpWidget(
      _app(
        Form(
          key: form,
          child: MobileChoiceFormField<int>(
            key: field,
            label: 'Mode',
            placeholder: 'No current value',
            options: _short,
            onChanged: changes.add,
            onSaved: saved.add,
            validator: (value) => value == null ? 'Choose a value' : null,
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Choose a value'), findsOneWidget);

    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual').hitTestable());
    await tester.pumpAndSettle();
    expect(field.currentState!.value, 1);
    expect(changes, [1]);
    expect(form.currentState!.validate(), isTrue);
    form.currentState!.save();
    expect(saved, [1]);

    form.currentState!.reset();
    await tester.pumpAndSettle();
    expect(field.currentState!.value, isNull);
    expect(find.text('No current value'), findsOneWidget);
    expect(find.text('Choose a value'), findsNothing);
    expect(changes, [1]);
  });

  testWidgets(
    'disabled choice form cannot open and does not block validation',
    (tester) async {
      _phone(tester);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        _app(
          Form(
            key: form,
            child: MobileChoiceFormField<int>(
              label: 'Mode',
              initialValue: 1,
              options: _short,
              enabled: false,
              onChanged: (_) => fail('disabled choice committed'),
              validator: (_) => 'disabled choice validated',
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isTrue);
      await tester.tap(find.byType(MobileChoiceButton));
      await tester.pumpAndSettle();
      expect(find.byType(prism.PopupMenu), findsNothing);
      expect(find.text('Manual'), findsOneWidget);
    },
  );

  testWidgets('long lists use a searchable sheet and dismiss without a write', (
    tester,
  ) async {
    _phone(tester);
    final changes = <int>[];
    await tester.pumpWidget(
      _app(
        MobileChoice<int>(
          label: 'Long options',
          options: [
            for (var index = 0; index < 20; index++)
              MobileChoiceOption(
                index,
                'Choice #$index',
                subtitle: index == 13 ? 'Unique alias' : null,
              ),
          ],
          value: 0,
          onChanged: changes.add,
        ),
      ),
    );
    final trigger = find.byType(MobileChoiceButton);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.byType(prism.PopupMenu), findsNothing);
    expect(find.byType(prism.SearchField), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '  UNIQUE alias ');
    await tester.pumpAndSettle();
    expect(find.text('Choice #13'), findsOneWidget);
    expect(find.text('Choice #12'), findsNothing);
    await tester.tap(find.text('Choice #13'));
    await tester.pumpAndSettle();
    expect(changes, [13]);
    expect(find.byType(prism.SearchField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a presented sheet never calls a replacement field handler', (
    tester,
  ) async {
    _phone(tester);
    final owner = ValueNotifier('old target');
    addTearDown(owner.dispose);
    final writes = <(String, int)>[];

    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: owner,
          builder: (context, target, _) => MobileChoice<int>(
            value: 1,
            options: _short,
            searchable: true,
            onChanged: (chosen) {
              if (target == owner.value) writes.add((target, chosen));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    owner.value = 'new target';
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic').hitTestable());
    await tester.pumpAndSettle();
    expect(writes, isEmpty);

    await tester.tap(find.byType(MobileChoiceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic').hitTestable());
    await tester.pumpAndSettle();
    expect(writes, [('new target', 2)]);
  });
}
