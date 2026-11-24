import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_global_search_bar.dart';
import 'package:venera_next/components/mobile_search_focus.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';

class _Host {
  final root = GlobalKey<NavigatorState>();
  final nested = GlobalKey<NavigatorState>();
  final enabled = ValueNotifier(true);
  final input = TextEditingController();
  final focus = FocusNode();

  Future<void> mount(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    bool reduceMotion = false,
    bool useNested = false,
  }) async {
    addTearDown(focus.dispose);
    addTearDown(input.dispose);
    addTearDown(enabled.dispose);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final launch = Scaffold(
      body: Center(
        child: MobileSearchAnchor(
          builder: (origin) => TextButton(
            onPressed: () => pushSearchFrom<void>(origin, buildSearch),
            child: const Text('Open search fixture'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        theme: ThemeData(platform: platform),
        localizationsDelegates: const [MobileUiLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: MobileUiTheme(glass: 'off', child: child!),
        ),
        home: useNested
            ? Navigator(
                key: nested,
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => launch),
              )
            : launch,
      ),
    );
    await tester.pumpAndSettle();
    tester.testTextInput.log.clear();
  }

  Widget buildSearch() => ValueListenableBuilder(
    valueListenable: enabled,
    builder: (_, value, _) => SearchFocusOnArrival(
      editor: focus,
      enabled: value,
      child: Scaffold(
        body: value
            ? Align(
                alignment: Alignment.topCenter,
                child: MobileGlobalSearchBar(
                  editing: input,
                  topPadding: 0,
                  focusNode: focus,
                  onSubmit: (_) {},
                ),
              )
            : const Text('No sources fixture'),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open search fixture'));
    await tester.pump();
  }
}

int _calls(WidgetTester tester, String method) =>
    tester.testTextInput.log.where((call) => call.method == method).length;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'global search opens the IME once after paint ($platform, $reduced)',
        (tester) async {
          final host = _Host();
          await host.mount(tester, platform: platform, reduceMotion: reduced);
          await host.open(tester);
          if (!reduced) {
            await tester.pump(const Duration(milliseconds: 180));
            expect(host.focus.hasFocus, isFalse);
            expect(_calls(tester, 'TextInput.show'), 0);
          }
          await tester.pumpAndSettle();
          expect(host.focus.hasPrimaryFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(_calls(tester, 'TextInput.setClient'), 1);
          final shows = _calls(tester, 'TextInput.show');
          expect(shows, greaterThan(0));
          tester.view.viewInsets = const FakeViewPadding(bottom: 294);
          await tester.pumpAndSettle();
          expect(host.focus.hasPrimaryFocus, isTrue);
          expect(_calls(tester, 'TextInput.setClient'), 1);
          expect(_calls(tester, 'TextInput.show'), shows);
          expect(_calls(tester, 'TextInput.hide'), 0);
          tester.view.resetViewInsets();
          host.focus.unfocus();
          await tester.pumpAndSettle();
          expect(host.focus.hasFocus, isFalse);
          expect(_calls(tester, 'TextInput.show'), shows);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('root cover invalidates a pending nested search focus', (
    tester,
  ) async {
    final host = _Host();
    await host.mount(tester, useNested: true);
    await host.open(tester);
    await tester.pump(const Duration(milliseconds: 105));
    host.root.currentState!.push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) =>
            const Center(child: Text('Root cover fixture')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Root cover fixture'), findsOneWidget);
    expect(host.focus.hasFocus, isFalse);
    expect(_calls(tester, 'TextInput.show'), 0);
    host.root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(host.focus.hasFocus, isFalse);
    expect(_calls(tester, 'TextInput.show'), 0);
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(host.focus.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'early back never opens the keyboard; a new entry owns its request',
    (tester) async {
      final host = _Host();
      await host.mount(tester);
      await host.open(tester);
      await tester.pump(const Duration(milliseconds: 90));
      host.root.currentState!.pop();
      await tester.pumpAndSettle();
      expect(host.focus.hasFocus, isFalse);
      expect(_calls(tester, 'TextInput.show'), 0);
      await host.open(tester);
      await tester.pumpAndSettle();
      expect(host.focus.hasPrimaryFocus, isTrue);
      expect(_calls(tester, 'TextInput.setClient'), 1);
      expect(_calls(tester, 'TextInput.show'), greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a search without an editor does not autofocus after sources change',
    (tester) async {
      final host = _Host()..enabled.value = false;
      await host.mount(tester);
      await host.open(tester);
      await tester.pumpAndSettle();
      expect(find.text('No sources fixture'), findsOneWidget);
      host.enabled.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
      expect(host.focus.hasFocus, isFalse);
      expect(_calls(tester, 'TextInput.show'), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
