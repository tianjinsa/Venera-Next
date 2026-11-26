import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_details/comic_page.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_tile.dart';
import 'package:venera_next/features/comic_widgets/keyword_hidden_notice.dart';
import 'package:venera_next/features/discovery/category_comics_page.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/routing/app_navigation.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

const _tags = {
  'tag': ['Sample tag'],
  'author': ['Sample author'],
  'category': ['Sample category'],
  'listing': ['Sample listing'],
  'views': ['500'],
};

class _TagSource extends Fake implements ComicSource {
  @override
  String get key => 'tags';
  @override
  String get name => 'Test source';
  @override
  CategoryData get categoryData => const CategoryData(
    title: 'Categories',
    categories: [],
    enableRankingPage: false,
    key: 'tags-categories',
  );
  @override
  FavoriteData? get favoriteData => null;
  @override
  CommentsLoader? get commentsLoader => null;
  @override
  ComicThumbnailLoader? get loadComicThumbnail => null;
  @override
  Map<String, Map<String, String>>? get translations => null;
  @override
  bool get enableTagsTranslate => false;
  @override
  LoadComicFunc get loadComicInfo =>
      (id) async => Res(
        ComicDetails.fromJson({
          'title': 'Comic details',
          'cover': '',
          'sourceKey': key,
          'comicId': id,
          'tags': _tags,
          'recommend': [
            {'title': 'Suggested comic', 'cover': '', 'id': 'suggested'},
          ],
        }),
      );
  @override
  HandleClickTagEvent get handleClickTagEvent =>
      (namespace, tag) => namespace == 'listing'
      ? PageJumpTarget(key, 'category', {
          'category': tag,
          'options': ['all'],
          'param': 'sort',
        })
      : PageJumpTarget(key, 'search', {
          'text': '$namespace:$tag',
          'options': ['all'],
        });
}

class _Favorites extends Fake
    with ChangeNotifier
    implements LocalFavoritesManager {
  @override
  bool isExist(String id, ComicType type) => false;
  @override
  bool hasNewUpdate(String id, ComicType type) => false;
  @override
  bool isInReadLater(String id, ComicType type) => false;
}

class _History extends Fake implements HistoryManager {
  @override
  History? find(String id, ComicType type) => null;
}

void main() {
  for (final (mobile, review) in const [
    (false, false),
    (false, true),
    (true, false),
    (true, true),
  ]) {
    testWidgets(
      'detail author, category and tags use the visible navigator: review=$review phone=$mobile',
      (tester) async {
        if (mobile) {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
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
        final source = _TagSource();
        final favorites = _Favorites();
        final history = _History();
        configureComicSourceRegistry(
          all: () => [source],
          find: (key) => key == source.key ? source : null,
          fromIntKey: (_) => null,
          isEmpty: () => false,
        );
        appNavigation.mainNavigatorKey = main;
        addTearDown(() {
          appNavigation.mainNavigatorKey = oldMain;
          appdata.settings['language'] = oldLanguage;
          appdata.settings['blockedWords'] = oldWords;
          appdata.settings['blockedAuthors'] = oldAuthors;
          configureComicWidgets();
          configureComicSourceRegistry(
            all: () => [],
            find: (_) => null,
            fromIntKey: (_) => null,
            isEmpty: () => true,
          );
          favorites.dispose();
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
                return ComicPage(id: id, sourceKey: sourceKey, heroID: heroID);
              },
          tileImageProviderResolver: (_) =>
              const AssetImage('assets/app_icon.png'),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: root,
            navigatorObservers: [rootRoutes],
            localizationsDelegates: const [MobileUiLocalizations.delegate],
            builder: (_, child) => FavoritesScope(
              manager: favorites,
              child: HistoryScope(
                manager: history,
                child: mobile
                    ? MobileUiTheme(glass: 'off', child: child!)
                    : child!,
              ),
            ),
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
        final details = find.byType(ComicPage);
        final readonly = find.ancestor(
          of: find.text('500'),
          matching: find.byType(MobileSearchAnchor),
        );
        expect(find.text('500'), findsOneWidget);
        expect(readonly, findsNothing);
        for (final namespace in ['tag', 'author', 'category', 'listing']) {
          final label = _tags[namespace]!.single;
          final tag = find.text(label);
          final trigger = find.ancestor(
            of: tag,
            matching: find.byType(MobileSearchAnchor),
          );
          expect(trigger, findsOneWidget);
          if (mobile) {
            final entry = tester.widget<MobileSearchAnchor>(trigger);
            expect(entry.cornerRadius, 12);
            expect(
              entry.sourceColor,
              Theme.of(tester.element(trigger)).colorScheme.surfaceContainerLow,
            );
          }
          final pushes = routes.pushed.length;
          await tester.tap(tag);
          expect(routes.pushed.length, pushes + 1);
          final route = routes.pushed.last;
          expect(route.navigator, same(owner.currentState));
          expect(route, isA<AppPageRoute>());
          final pageRoute = route as AppPageRoute;
          expect(
            pageRoute.transitionDuration.inMilliseconds,
            mobile ? 500 : 300,
          );
          if (mobile) {
            expect(pageRoute.reverseTransitionDuration.inMilliseconds, 340);
          }
          // Inspect the destination before mounting its source services.
          final destination = pageRoute.builder(tester.element(details));
          if (namespace == 'listing') {
            final category = destination as CategoryComicsPage;
            expect(category.category, label);
            expect(category.categoryKey, 'tags-categories');
            expect(category.options, ['all']);
            expect(category.param, 'sort');
          } else {
            final search = destination as SearchResultPage;
            expect(search.text, '$namespace:$label');
            expect(search.sourceKey, 'tags');
            expect(search.options, ['all']);
          }
          expect(
            review ? mainRoutes.pushed.length : rootRoutes.pushed.length,
            parentPushes,
          );
          owner.currentState!.removeRoute(route);
          await tester.pumpAndSettle();
          expect(details, findsOneWidget);
        }
        final detailPushes = routes.pushed.length;
        final suggested = find.text('Suggested comic');
        await tester.scrollUntilVisible(
          suggested,
          160,
          scrollable: find
              .descendant(of: details, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(suggested);
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
