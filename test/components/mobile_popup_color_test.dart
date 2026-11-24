import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_setting_row.dart';
import 'package:venera_next/components/mobile_ui.dart';

const _scene = ValueKey('mobile popup scene');
const _trigger = ValueKey('card popup trigger');
const _pageColor = Color(0xff171a22);

void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 700);
  addTearDown(tester.view.reset);
}

Widget _app(
  Widget content, {
  required String glass,
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: Colors.indigo,
    ),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? _pageColor
        : const Color(0xfff8f7fb),
  ),
  builder: (_, child) => RepaintBoundary(
    key: _scene,
    child: MobileUiTheme(glass: glass, child: child!),
  ),
  localizationsDelegates: const [MobileUiLocalizations.delegate],
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 150),
        child: SizedBox(width: 338, child: content),
      ),
    ),
  ),
);

Future<Color> _paintAt(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_scene),
  );
  return (await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await picture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final index = 4 * (point.dy.floor() * picture.width + point.dx.floor());
      return Color.fromARGB(
        bytes.getUint8(index + 3),
        bytes.getUint8(index),
        bytes.getUint8(index + 1),
        bytes.getUint8(index + 2),
      );
    } finally {
      picture.dispose();
    }
  }))!;
}

int _gap(Color one, Color two) => [
  (one.r - two.r).abs(),
  (one.g - two.g).abs(),
  (one.b - two.b).abs(),
].map((channel) => (255 * channel).round()).reduce(math.max);

Finder _menu() => find.byType(prism.PopupMenu);

Widget _content({
  required String source,
  required VoidCallback choose,
  bool stockAnchor = false,
}) {
  if (source == 'standalone settings') {
    return Material(
      color: const Color(0x702b2538),
      child: MobileChoiceFormField<int>(
        label: 'Network',
        initialValue: 0,
        onChanged: (_) => choose(),
        options: const [
          MobileChoiceOption(0, 'First setting'),
          MobileChoiceOption(1, 'Next setting!'),
          MobileChoiceOption(2, 'Third value'),
        ],
      ),
    );
  }
  if (source == 'setting row') {
    var value = 0;
    return StatefulBuilder(
      builder: (context, setState) => SettingChoiceRow(
        title: const Text('Network'),
        choice: MobileChoice<int>(
          setting: true,
          value: value,
          onChanged: (next) {
            setState(() => value = next);
            choose();
          },
          options: const [
            MobileChoiceOption(0, 'First setting'),
            MobileChoiceOption(1, 'Next setting!'),
            MobileChoiceOption(2, 'Third value'),
          ],
        ),
      ),
    );
  }
  final items = [
    const prism.PopupMenuItem(label: 'First setting', checked: true),
    prism.PopupMenuItem(label: 'Next value', onPressed: choose),
    const prism.PopupMenuItem(label: 'Third value'),
  ];
  Widget target(VoidCallback open) => MobileToolbarButton(
    label: 'Options',
    icon: const Icon(Icons.more_horiz, size: 16),
    onPressed: open,
  );
  return MobileContentSurface(
    selected: true,
    margin: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
    child: SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: stockAnchor
              ? prism.PopupAnchor(
                  key: _trigger,
                  targetBuilder: target,
                  popupBuilder: (_) => prism.PopupMenu(items: items),
                )
              : MobilePopupAnchor(
                  key: _trigger,
                  targetBuilder: target,
                  items: items,
                ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (source, glass, dismissal, brightness) in [
    ('setting row', 'off', 'selection', Brightness.dark),
    ('setting row', 'standard', 'outside', Brightness.dark),
    ('gradient card', 'standard', 'back', Brightness.dark),
    ('gradient card', 'ultra', 'back', Brightness.light),
    ('standalone settings', 'off', 'back', Brightness.dark),
  ]) {
    testWidgets(
      'painted $source opens and folds: $glass, $dismissal, $brightness',
      (tester) async {
        _phone(tester);
        var choices = 0;
        await tester.pumpWidget(
          _app(
            _content(source: source, choose: () => choices++),
            glass: glass,
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final trigger = source == 'gradient card'
            ? find.byKey(_trigger)
            : find.byType(MobileChoiceButton);
        final rect = tester.getRect(trigger);
        final materialPoint = rect.center.translate(0, -15);
        final rest = await _paintAt(tester, materialPoint);
        final unrelatedPoint = const Offset(20, 220);
        final outside = await _paintAt(tester, unrelatedPoint);

        // The pointer captures the trigger and runs the real native springs.
        // Sample clean paint above the icon or value text.
        await tester.tap(trigger);
        await tester.pump();
        await tester.pump();
        final launch = await _paintAt(tester, materialPoint);
        // The ultra path has a finer outline; use a frame where the clean
        // sample still lies on that early drop, not the card behind it.
        await tester.pump(
          Duration(milliseconds: brightness == Brightness.light ? 45 : 58),
        );
        final expanding = await _paintAt(tester, materialPoint);
        await tester.pumpAndSettle();
        final open = await _paintAt(tester, materialPoint);
        expect(_menu(), findsOneWidget);
        expect(_gap(rest, open), greaterThan(12));
        expect(_gap(rest, launch), lessThanOrEqualTo(2));
        expect(_gap(rest, expanding), greaterThan(2));
        expect(_gap(open, expanding), greaterThan(2));
        expect(_gap(open, expanding), lessThan(_gap(open, launch)));

        switch (dismissal) {
          case 'selection':
            await tester.tap(find.text('Next setting!').hitTestable());
          case 'outside':
            await tester.tapAt(const Offset(20, 570));
          case 'back':
            await tester.binding.handlePopRoute();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 86));
        final folding = await _paintAt(tester, materialPoint);
        await tester.pump(const Duration(milliseconds: 405));
        expect(_menu(), findsOneWidget); // still the animated overlay
        final handoff = await _paintAt(tester, materialPoint);
        await tester.pumpAndSettle();
        final closed = await _paintAt(tester, materialPoint);
        expect(_menu(), findsNothing);
        expect(_gap(rest, folding), greaterThan(2));
        expect(_gap(open, folding), greaterThan(2));
        expect(_gap(open, folding), lessThan(_gap(open, rest)));
        expect(_gap(rest, handoff), lessThanOrEqualTo(2));
        expect(_gap(handoff, closed), lessThanOrEqualTo(2));
        expect(closed, rest);
        expect(await _paintAt(tester, unrelatedPoint), outside);
        expect(choices, dismissal == 'selection' ? 1 : 0);
        if (dismissal == 'selection') {
          expect(find.text('Next setting!'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final glass in ['off', 'standard', 'ultra']) {
    testWidgets('full-open $glass matches stock Prism pixels', (tester) async {
      _phone(tester);
      Future<(Rect, List<Color>)> visibleMenu({required bool stock}) async {
        await tester.pumpWidget(
          _app(
            _content(
              source: 'gradient card',
              choose: () {},
              stockAnchor: stock,
            ),
            glass: glass,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_trigger));
        await tester.pumpAndSettle();
        final bounds = tester.getRect(_menu());
        final colors = [
          await _paintAt(tester, bounds.centerLeft.translate(18, 0)),
          await _paintAt(tester, bounds.topCenter.translate(0, 5)),
          await _paintAt(tester, bounds.bottomCenter.translate(0, -5)),
        ];
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        return (bounds, colors);
      }

      final (bounds, colors) = await visibleMenu(stock: false);
      final (stockBounds, stockColors) = await visibleMenu(stock: true);
      expect(bounds, stockBounds);
      expect(colors, stockColors);
    });
  }

  testWidgets(
    'reduced-motion settings keep the settled paint and select once',
    (tester) async {
      _phone(tester);
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
      var choices = 0;
      await tester.pumpWidget(
        _app(
          _content(source: 'setting row', choose: () => choices++),
          glass: 'off',
        ),
      );
      final trigger = find.byType(MobileChoiceButton);
      final point = tester.getCenter(trigger).translate(0, -15);
      final rest = await _paintAt(tester, point);
      await tester.tap(trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      expect(_menu(), findsOneWidget);
      expect(_gap(rest, await _paintAt(tester, point)), greaterThan(12));
      await tester.tap(find.text('Next setting!').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      expect(_menu(), findsNothing);
      expect(await _paintAt(tester, point), rest);
      expect(choices, 1);
    },
  );
}
