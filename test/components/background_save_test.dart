import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/background_save.dart';
import 'package:venera_next/features/reader/exit_guard.dart';

void main() {
  testWidgets(
    'reader returns immediately while a root save survives navigation',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final guard = GlobalKey<ReaderExitGuardState>();
      final saved = Completer<void>();
      var releases = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Details')),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderExitGuard(
              key: guard,
              prepare: () => throw StateError('Foreground save must not run'),
              holdForLeave: () =>
                  () => releases++,
              saveInBackground: () => saved.future,
              onError: (error, _) => fail('$error'),
              child: const Scaffold(body: Text('Reader')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await guard.currentState!.requestExit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Reader'), findsNothing);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Saving...'), findsNothing);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);
      expect(releases, 1);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another comic')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.save_outlined), findsNothing);
      expect(find.text('Another comic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed save stays red until its details are reviewed and closed',
    (tester) async {
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold(body: Text('Details'));
            },
          ),
        ),
      );
      BackgroundSave.run(page, () async => throw StateError('Disk is full'));
      await tester.pumpAndSettle();
      final error = find.byIcon(Icons.error_outline);
      expect(error, findsOneWidget);
      expect(
        tester.widget<Icon>(error).color,
        Theme.of(page).colorScheme.error,
      );
      BackgroundSave.run(page, () async {});
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 10));
      expect(error, findsOneWidget);
      await tester.tap(error);
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Disk is full'),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reviewing an earlier error cannot dismiss a newer save failure',
    (tester) async {
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      BackgroundSave.run(page, () async => throw StateError('First save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();
      BackgroundSave.run(page, () async => throw StateError('Second save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Second save'),
      );
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        isNot(contains('First save')),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsNothing);
    },
  );
}
