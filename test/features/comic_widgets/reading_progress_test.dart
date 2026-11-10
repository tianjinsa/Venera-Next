import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/comic_widgets/comic_tile.dart';
import 'package:venera_next/foundation/appdata.dart';

void main() {
  const description = '第二部 - 第100话：重新开始 - P23';
  const comic = Comic(
    'Book',
    '',
    'book',
    '',
    [],
    '',
    'missing-source',
    null,
    null,
  );

  setUp(() {
    configureComicWidgets(
      tileStateResolver: (_) => const ComicTileState(
        isFavorite: true,
        hasNewUpdate: true,
        historyPage: 23,
        historyMaxPage: 50,
        historyDescription: description,
      ),
    );
  });
  tearDown(configureComicWidgets);

  for (final maxPage in <int?>[null, 30]) {
    testWidgets(
      'compact progress preserves fallback and completion: $maxPage',
      (tester) async {
        configureComicWidgets(
          tileStateResolver: (_) => ComicTileState(
            historyPage: 30,
            historyMaxPage: maxPage,
            historyDescription: description,
          ),
        );
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SimpleComicTile(comic: comic)),
          ),
        );
        expect(tester.getSize(find.byTooltip(description)), const Size(24, 24));
        if (maxPage == null) {
          expect(find.text('30'), findsOneWidget);
          expect(find.byIcon(Icons.check), findsNothing);
        } else {
          expect(find.text('30'), findsNothing);
          expect(find.byIcon(Icons.check), findsOneWidget);
        }
        expect(find.text('/30'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final values in [(3, 30), (162, 233), (1001, 1200)]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('page counts occupy separate rows: $values at scale $scale', (
        tester,
      ) async {
        configureComicWidgets(
          tileStateResolver: (_) => ComicTileState(
            historyPage: values.$1,
            historyMaxPage: values.$2,
            historyDescription: description,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: Wrap(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 180,
                      child: ComicTile(
                        comic: comic,
                        displayMode: ComicTileDisplayMode.gallery,
                      ),
                    ),
                    SimpleComicTile(comic: comic),
                  ],
                ),
              ),
            ),
          ),
        );
        for (var index = 0; index < 2; index++) {
          final badge = tester.getRect(find.byTooltip(description).at(index));
          final page = tester.getRect(find.text('${values.$1}').at(index));
          final total = tester.getRect(find.text('/${values.$2}').at(index));
          expect(badge.size, const Size(24, 24));
          expect(page.bottom, lessThanOrEqualTo(total.top));
          expect(page.left, lessThanOrEqualTo(total.left));
          expect(badge.contains(page.topLeft), isTrue);
          expect(badge.contains(page.bottomRight), isTrue);
          expect(badge.contains(total.topLeft), isTrue);
          expect(badge.contains(total.bottomRight), isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'compact indicator retains progress details with dark=$dark and text scale=$scale',
        (tester) async {
          final oldMode = appdata.settings['comicDisplayMode'];
          appdata.settings['comicDisplayMode'] = 'brief';
          addTearDown(() => appdata.settings['comicDisplayMode'] = oldMode);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const Scaffold(
                    body: Wrap(
                      children: [
                        SizedBox(
                          width: 72,
                          height: 180,
                          child: ComicTile(
                            comic: comic,
                            displayMode: ComicTileDisplayMode.gallery,
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          height: 240,
                          child: ComicTile(comic: comic),
                        ),
                        SizedBox(
                          width: 375,
                          height: 220,
                          child: ComicTile(
                            comic: comic,
                            displayMode: ComicTileDisplayMode.detailed,
                          ),
                        ),
                        SimpleComicTile(comic: comic),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(find.text(description), findsNothing);
            expect(find.byTooltip(description), findsNWidgets(4));
            expect(find.bySemanticsLabel(description), findsNWidgets(4));
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('disabling history badges hides progress', (tester) async {
    configureComicWidgets(tileStateResolver: (_) => const ComicTileState());
    await tester.pumpWidget(
      const MaterialApp(home: SimpleComicTile(comic: comic)),
    );
    expect(find.text(description), findsNothing);
  });
}
