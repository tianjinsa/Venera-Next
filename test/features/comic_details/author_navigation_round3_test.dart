import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_details/actions.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/features/discovery/category_comics_page.dart';
import 'package:venera_next/features/search/search_shortcut.dart';
import 'package:venera_next/features/search/search_shortcuts.dart';
import 'package:venera_next/foundation/appdata.dart';

class _Source extends Fake implements ComicSource {
  final calls = <(String, String)>[];

  @override
  String get key => 'special-author-source';

  @override
  CategoryData get categoryData => const CategoryData(
    title: 'Browse',
    categories: [],
    enableRankingPage: false,
    key: 'source-category',
  );

  @override
  CategoryComicsData get categoryComicsData =>
      CategoryComicsData(load: (_, _, _, _) => throw StateError('no I/O'));

  @override
  HandleClickTagEvent get handleClickTagEvent => (namespace, tag) {
    calls.add((namespace, tag));
    return PageJumpTarget.parse(key, {
      'page': 'category',
      'attributes': {
        'category': 'Works: $tag',
        'param': 'creator/734?sort=id',
        'options': ['recent', 'all'],
      },
    });
  };
}

class _Actions extends Fake with ComicPageActions {
  _Actions(this.context, this.comicSource);

  @override
  final BuildContext context;
  @override
  final ComicSource comicSource;
}

void main() {
  testWidgets(
    'author, saved author and explicit category chips reveal the exact source result',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 750);
      addTearDown(tester.view.reset);
      final source = _Source();
      final language = appdata.settings['language'];
      appdata.settings['language'] = 'en-US';
      configureComicSourceRegistry(
        all: () => [source],
        find: (key) => key == source.key ? source : null,
        fromIntKey: (_) => null,
        isEmpty: () => false,
      );
      addTearDown(() {
        appdata.settings['language'] = language;
        configureComicSourceRegistry(
          all: () => [],
          find: (_) => null,
          fromIntKey: (_) => null,
          isEmpty: () => true,
        );
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          localizationsDelegates: const [MobileUiLocalizations.delegate],
          builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
          home: Scaffold(
            body: Builder(
              builder: (detail) => Column(
                children: [
                  for (final label in ['畫師', 'genre', 'saved'])
                    MobileSearchAnchor(
                      builder: (chip) => TextButton(
                        onPressed: () {
                          if (label == 'saved') {
                            openSearchShortcut(
                              chip,
                              SearchShortcut(
                                kind: SearchShortcutKind.author,
                                sourceKey: source.key,
                                namespace: 'artist',
                                value: 'X/Y',
                              ),
                            );
                          } else {
                            _Actions(
                              detail,
                              source,
                            ).onTapTag('X/Y', label, chip);
                          }
                        },
                        child: Text(label),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      // Explicit source tags and saved author lookups each preserve the
      // original category result and animate from their own control.
      for (final label in ['畫師', 'saved', 'genre', '畫師']) {
        final button = find.widgetWithText(TextButton, label);
        final original = tester.getRect(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(source.calls.last, (label == 'saved' ? 'artist' : label, 'X/Y'));
        final surface = find.byType(SearchMorphSurface);
        final frame = tester.widget<SearchMorphSurface>(surface).frame;
        expect(frame.center.dx, closeTo(original.center.dx, .01));
        expect(frame.center.dy, closeTo(original.center.dy, .01));
        expect(frame.radius, lessThan(4));
        await tester.pump(const Duration(milliseconds: 550));
        final destination = tester.widget<CategoryComicsPage>(
          find.byType(CategoryComicsPage),
        );
        expect(destination.categoryKey, source.categoryData.key);
        expect(destination.category, 'Works: X/Y');
        expect(destination.param, 'creator/734?sort=id');
        expect(destination.options, ['recent', 'all']);
        expect(find.byType(EditableText), findsNothing);
        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pump();
        expect(button.hitTestable(), findsOneWidget);
      }
      expect(source.calls, [
        ('畫師', 'X/Y'),
        ('artist', 'X/Y'),
        ('genre', 'X/Y'),
        ('畫師', 'X/Y'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
