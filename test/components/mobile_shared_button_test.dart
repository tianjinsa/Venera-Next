import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/common_button.dart' as prism;
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/mobile_ui.dart';

Widget _host(Widget child, {required bool phone}) => MaterialApp(
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  builder: phone
      ? (_, child) => MobileUiTheme(glass: 'off', child: child!)
      : null,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('mobile label button keeps size, origin and single activation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final calls = <Object>[];
    final loading = ValueNotifier(false);
    addTearDown(loading.dispose);

    await tester.pumpWidget(
      _host(
        ValueListenableBuilder(
          valueListenable: loading,
          builder: (_, value, _) => Button.outlined(
            width: 120,
            height: 44,
            isLoading: value,
            onPressed: () => calls.add('pressed'),
            onPressedAt: calls.add,
            child: const Text('Save it'),
          ),
        ),
        phone: true,
      ),
    );

    final button = find.byType(prism.OutlinedButton);
    expect(tester.getSize(button), const Size(120, 44));
    final origin = tester.getTopLeft(button);
    await tester.tap(button);
    expect(calls, ['pressed', origin]);

    loading.value = true;
    await tester.pump();
    expect(tester.getSize(button), const Size(120, 44));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<prism.OutlinedButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    expect(calls, ['pressed', origin]);

    loading.value = false;
    await tester.pump();
    await tester.tap(button);
    expect(calls, ['pressed', origin, 'pressed', origin]);
  });

  testWidgets('shared icon keeps size and switches on the same themed host', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var presses = 0;
    final loading = ValueNotifier(false);
    addTearDown(loading.dispose);
    await tester.pumpWidget(
      _host(
        ValueListenableBuilder(
          valueListenable: loading,
          builder: (_, value, _) => Button.icon(
            icon: const Icon(Icons.star),
            size: 18,
            tooltip: 'Star it',
            isLoading: value,
            onPressed: () => presses++,
          ),
        ),
        phone: true,
      ),
    );
    final icon = find.byType(prism.IconButton);
    expect(tester.getSize(icon), const Size.square(30));
    expect(tester.widget<prism.IconButton>(icon).tooltip, 'Star it');
    await tester.tap(icon);
    expect(presses, 1);

    loading.value = true;
    await tester.pump();
    expect(tester.getSize(icon), const Size.square(30));
    expect(tester.widget<prism.IconButton>(icon).onPressed, isNull);
    await tester.tap(icon, warnIfMissed: false);
    expect(presses, 1);

    loading.value = false;
    await tester.pump();
    await tester.tap(icon);
    expect(presses, 2);

    tester.view.physicalSize = const Size(820, 844);
    await tester.pump();
    expect(icon, findsNothing);
    await tester.tap(find.byIcon(Icons.star));
    expect(presses, 3);
  });

  testWidgets('desktop host still renders the original shared button', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      _host(
        Button.icon(icon: const Icon(Icons.star), onPressed: () => presses++),
        phone: false,
      ),
    );
    expect(find.byType(prism.IconButton), findsNothing);
    await tester.tap(find.byIcon(Icons.star));
    expect(presses, 1);
  });
}
