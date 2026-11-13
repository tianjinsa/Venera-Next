import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/comic_details/actions.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/comic_widgets/comic_tile.dart';
import 'package:venera_next/features/comic_widgets/keyword_hidden_notice.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/routing/app_navigation.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

class _Actions extends Fake with ComicPageActions {
  _Actions(this.context);
  @override
  final BuildContext context;
  @override
  PageJumpTarget searchTargetForTag(String tag, String namespace) =>
      PageJumpTarget('tags', 'search', {
        'text': '$namespace:$tag',
        'options': ['all'],
      });
}

class _Details extends StatelessWidget {
  const _Details();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Comic details'),
        for (final namespace in ['tag', 'author'])
          TextButton(
            onPressed: () => _Actions(context).onTapTag('sample', namespace),
            child: Text('Search $namespace'),
          ),
        const SizedBox(
          width: 120,
          height: 200,
          child: ComicTile(
            displayMode: ComicTileDisplayMode.gallery,
            comic: Comic(
              'Suggested comic',
              '',
              'suggested',
              null,
              null,
              '',
              'tags',
              null,
              null,
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  for (final review in [false, true]) {
    testWidgets(
      'tag and author use the visible detail navigator: review=$review',
      (tester) async {
        final oldMain = appNavigation.mainNavigatorKey;
        final oldLanguage = appdata.settings['language'];
        final oldWords = appdata.settings['blockedWords'];
        final oldAuthors = appdata.settings['blockedAuthors'];
        appdata.settings['language'] = 'en-US';
        appdata.settings['blockedWords'] = ['Blocked'];
        appdata.settings['blockedAuthors'] = <String>[];
        final root = GlobalKey<NavigatorState>();
        final main = GlobalKey<NavigatorState>();
        final rootRoutes = _Routes();
        final mainRoutes = _Routes();
        final opened = <String>[];
        appNavigation.mainNavigatorKey = main;
        addTearDown(() {
          appNavigation.mainNavigatorKey = oldMain;
          appdata.settings['language'] = oldLanguage;
          appdata.settings['blockedWords'] = oldWords;
          appdata.settings['blockedAuthors'] = oldAuthors;
          configureComicWidgets();
        });
        const comic = Comic(
          'Blocked comic',
          '',
          'book',
          null,
          null,
          '',
          'tags',
          null,
          null,
        );
        configureComicWidgets(
          comicPageBuilder:
              ({required id, required sourceKey, cover, title, heroID}) {
                opened.add(id);
                return const _Details();
              },
          tileImageProviderResolver: (_) =>
              const AssetImage('assets/app_icon.png'),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: root,
            navigatorObservers: [rootRoutes],
            home: Navigator(
              key: main,
              observers: [mainRoutes],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      if (review) {
                        showKeywordFilterReview(context, comics: () => [comic]);
                      } else {
                        openComicPage(
                          context: context,
                          id: comic.id,
                          sourceKey: comic.sourceKey,
                        );
                      }
                    },
                    child: const Text('Open comic'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open comic'));
        await tester.pumpAndSettle();
        if (review) {
          await tester.tap(
            find.descendant(
              of: find.byTooltip('Details'),
              matching: find.byType(InkWell),
            ),
          );
          await tester.pumpAndSettle();
        }
        final owner = review ? root : main;
        final routes = review ? rootRoutes : mainRoutes;
        final parentPushes = review
            ? mainRoutes.pushed.length
            : rootRoutes.pushed.length;
        for (final namespace in ['tag', 'author']) {
          final pushes = routes.pushed.length;
          await tester.tap(find.text('Search $namespace'));
          expect(routes.pushed.length, pushes + 1);
          final route = routes.pushed.last;
          expect(route.navigator, same(owner.currentState));
          expect(route, isA<AppPageRoute>());
          // Inspect the real search destination before mounting its data services.
          final search =
              (route as AppPageRoute).builder(
                    tester.element(find.text('Comic details')),
                  )
                  as SearchResultPage;
          expect(search.text, '$namespace:sample');
          expect(search.sourceKey, 'tags');
          expect(search.options, ['all']);
          expect(
            review ? mainRoutes.pushed.length : rootRoutes.pushed.length,
            parentPushes,
          );
          owner.currentState!.removeRoute(route);
          await tester.pumpAndSettle();
          expect(find.text('Comic details'), findsOneWidget);
        }
        final detailPushes = routes.pushed.length;
        await tester.tap(find.text('Suggested comic'));
        await tester.pumpAndSettle();
        expect(routes.pushed.length, detailPushes + 1);
        expect(opened.last, 'suggested');
        expect(
          review ? mainRoutes.pushed.length : rootRoutes.pushed.length,
          parentPushes,
        );
        owner.currentState!.pop();
        await tester.pumpAndSettle();
        owner.currentState!.pop();
        await tester.pumpAndSettle();
        expect(
          find.text(review ? 'Keyword filter reasons' : 'Open comic'),
          findsOneWidget,
        );
        expect(main.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
