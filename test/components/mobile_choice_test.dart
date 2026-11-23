import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
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
}
