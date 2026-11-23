import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';

void main() {
  testWidgets(
    'leaf commits at pop start, not after return; next route survives',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      var actions = 0;
      late bool sourceCurrent;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Builder(
            builder: (owner) => Material(
              child: Align(
                alignment: Alignment.topRight,
                child: MobileMenuButton(
                  items: [
                    prism.PopupMenuItem(
                      label: 'Open detail',
                      onPressed: () {
                        actions++;
                        sourceCurrent = ModalRoute.of(owner)!.isCurrent;
                        Navigator.of(owner).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const Material(child: Text('New page')),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(MobileMenuButton));
      await tester.pumpAndSettle();
      final row = find.text('Open detail').hitTestable().last;
      final finger = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 80));
      expect(actions, 0);
      await finger.up();
      // No pump, delay or waiting for a route Future.
      expect(actions, 1);
      expect(sourceCurrent, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('New page'), findsOneWidget);
      expect(actions, 1);
    },
  );

  testWidgets(
    'an anchor drag previews; cancel, reverse outside and disabled rows do not commit',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Material(
            child: Align(
              alignment: Alignment.topRight,
              child: MobileMenuButton(
                items: [
                  prism.PopupMenuItem(
                    label: 'First',
                    onPressed: () => actions.add('first'),
                  ),
                  const prism.PopupMenuItem(label: 'Disabled'),
                  prism.PopupMenuItem(
                    label: 'Last',
                    onPressed: () => actions.add('last'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final anchor = find.byType(MobileMenuButton);
      Future<TestGesture> startOverLast() async {
        final finger = await tester.startGesture(tester.getCenter(anchor));
        await tester.pump();
        await tester.pumpAndSettle();
        await finger.moveTo(
          tester.getCenter(find.text('Last').hitTestable().last),
        );
        await tester.pump();
        expect(actions, isEmpty);
        return finger;
      }

      final cancelled = await startOverLast();
      await cancelled.cancel();
      expect(actions, isEmpty);
      await tester.tap(find.text('Disabled').hitTestable().last);
      await tester.pump();
      expect(actions, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final outside = await startOverLast();
      await outside.moveTo(const Offset(5, 720));
      await outside.up();
      expect(actions, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final picked = await startOverLast();
      await picked.up();
      expect(actions, ['last']);
      await tester.pumpAndSettle();
      expect(actions, ['last']);
    },
  );
}
