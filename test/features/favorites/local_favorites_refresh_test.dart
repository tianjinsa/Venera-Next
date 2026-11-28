import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/mobile_collection_ui.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart'
    show
        Comic,
        ComicSource,
        FavoriteData,
        configureComicSourceRegistry,
        configureFavoriteDataResolver;
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/favorites/favorites_page.dart';
import 'package:venera_next/features/favorites/favorite_folder_browser.dart';
import 'package:venera_next/features/favorites/local_favorites_page.dart';
import 'package:venera_next/features/favorites/mobile_folder_sheet_widgets.dart';
import 'package:venera_next/features/favorites/network_favorites_page.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/opencc.dart';
import 'package:venera_next/foundation/res.dart';
import 'package:venera_next/routing/app_navigation.dart';

FavoriteItem _comic(String id, String title) => FavoriteItem(
  id: id,
  name: title,
  author: '',
  type: const ComicType(17),
  tags: const [],
  coverPath: '',
);

Finder _tile(String id) => find.byWidgetPredicate(
  (widget) => widget is ComicTile && widget.comic.id == id,
);

class _NetworkSource extends Fake implements ComicSource {
  _NetworkSource(this.favoriteData);

  @override
  final FavoriteData favoriteData;

  @override
  String get key => favoriteData.key;
}

class _CountingHistory extends HistoryManager {
  _CountingHistory() : super.create();
  int reads = 0;
  @override
  History? find(String id, ComicType type) {
    reads++;
    return super.find(id, type);
  }
}

class _Fixture {
  final manager = LocalFavoritesManager.independent();
  final history = _CountingHistory();
  final navigator = appNavigation.rootNavigatorKey;
  double textScale = 1;
  bool dark = false;

  Widget host({
    String folder = 'B',
    bool phone = false,
    bool reduceMotion = true,
    Widget? page,
  }) => FavoritesScope(
    manager: manager,
    child: HistoryScope(
      manager: history,
      child: MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: const [MobileUiLocalizations.delegate],
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        builder: (context, child) => Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.escape): VoidCallbackIntent(
              appNavigation.pop,
            ),
          },
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: phone ? MobileUiTheme(glass: 'off', child: child!) : child!,
          ),
        ),
        home: Scaffold(
          body:
              page ??
              LocalFavoritesPage(
                folder: folder,
                showFolders: () {},
                onFolderSelected: (_, _) {},
                updateFolderList: () {},
              ),
        ),
      ),
    ),
  );
}

Future<_Fixture> _prepare(WidgetTester tester, int count) async {
  final root = Directory('build').absolute.createTempSync('favorite-refresh-');
  final buildRoot = Directory('build').resolveSymbolicLinksSync();
  final previousPath = App.dataPath;
  final previousCachePath = App.cachePath;
  final settings = Map<String, dynamic>.from(
    appdata.toJson()['settings'] as Map,
  );
  final implicit = appdata.implicitData;
  final fixture = _Fixture();
  App.dataPath = root.path;
  App.cachePath = root.path;
  appdata.settings['language'] = 'en-US';
  appdata.settings[FavoritePreferences.newFavoriteAddTo.key] = 'start';
  appdata.settings['blockedWords'] = <String>[];
  appdata.settings[KeywordPreferences.comics.key] = <String>[];
  appdata.settings['showFavoriteStatusOnTile'] = false;
  appdata.settings['showHistoryStatusOnTile'] = false;
  appdata.settings['showUpdateStatusOnTile'] = false;
  appdata.implicitData = {'local_favorites_read_filter': 'All'};
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (_) async => false,
  );
  configureComicWidgets(
    addStateListener: (listener) {
      fixture.manager.addListener(listener);
      fixture.history.addListener(listener);
    },
    removeStateListener: (listener) {
      fixture.manager.removeListener(listener);
      fixture.history.removeListener(listener);
    },
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await fixture.manager.closeAndWait();
      fixture.history.close();
    });
    configureComicWidgets();
    settings.forEach((key, value) => appdata.settings[key] = value);
    appdata.implicitData = implicit;
    App.dataPath = previousPath;
    App.cachePath = previousCachePath;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    );
    expect(
      root.resolveSymbolicLinksSync(),
      startsWith('$buildRoot${Platform.pathSeparator}'),
    );
    root.deleteSync(recursive: true);
  });
  await tester.runAsync(() async {
    await OpenCC.init();
    await fixture.manager.init();
    await fixture.history.init();
    await fixture.manager.createFolder('A');
    await fixture.manager.createFolder('B');
    if (count > 0) {
      await fixture.manager.addComics(
        'B',
        List.generate(count, (i) => _comic('seed-$i', 'Existing $i')),
      );
    }
  });
  return fixture;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (
    var i = 0;
    i < 1000 &&
        find
            .byType(CircularProgressIndicator, skipOffstage: false)
            .evaluate()
            .isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    find.byType(CircularProgressIndicator, skipOffstage: false),
    findsNothing,
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseAction(WidgetTester tester, String label) async {
  final direct = find.byTooltip(label);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct);
    await tester.pumpAndSettle();
    return;
  }
  final menu = find.byWidgetPredicate(
    (widget) =>
        widget is MenuButton &&
        widget.entries.any((entry) => entry.text == label),
  );
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  App.dataPath = Directory.systemTemp.path;
  App.cachePath = Directory.systemTemp.path;

  testWidgets(
    'favorite title opens left modal with independent subfolder dropdown and direct search',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final fixture = await _prepare(tester, 1);
      const nested = 'A very long / named folder that requires truncation';
      const second = 'Second nested';

      await tester.runAsync(() async {
        await fixture.manager.createChildFolder(
          nested,
          fixture.manager.folderTree.named('B')!.id,
        );
        await fixture.manager.addComic(
          nested,
          _comic('nested-one', 'Nested book'),
        );
        await fixture.manager.createChildFolder(
          second,
          fixture.manager.folderTree.named('B')!.id,
        );
        await fixture.manager.addComic(
          second,
          _comic('second', 'Another book'),
        );
      });
      await tester.pumpWidget(
        fixture.host(phone: true, page: const FavoritesPage()),
      );
      await _settle(tester);
      final chevron = find.byKey(const ValueKey('favorite-path-open-sheet'));
      final local = find.byType(LocalFavoritesPage);
      final panel = find.byKey(const ValueKey('mobile-side-sheet-surface'));
      Finder option(String label) =>
          find.descendant(of: panel, matching: find.text(label)).hitTestable();

      expect(find.byIcon(Icons.menu), findsNothing);
      await tester.tap(find.text('Unselected'));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      await tester.tap(option('B'));
      await _settle(tester);
      expect(panel, findsNothing);
      expect(
        tester.getCenter(chevron).dx,
        greaterThan(tester.getCenter(find.text('B')).dx),
      );
      final original = tester.state(local);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('mobile-side-sheet-viewport')),
            )
            .dx,
        8,
      );
      final browser = find.byType(FavoriteFolderBrowser);
      expect(browser, findsOneWidget);
      Finder control(Key key) =>
          find.descendant(of: panel, matching: find.byKey(key));
      expect(
        control(const ValueKey('mobile-folder-sheet-local-all')),
        findsOneWidget,
      );
      expect(
        control(const ValueKey('mobile-folder-sheet-close')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.byType(ListTile)),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.byType(Chip)),
        findsNothing,
      );
      final rootRow = find.descendant(
        of: panel,
        matching: find.byWidgetPredicate(
          (widget) => widget is MobileFolderSheetRow && widget.label == 'B',
        ),
      );
      final check = find.descendant(
        of: rootRow,
        matching: find.byKey(const ValueKey('mobile-folder-sheet-selected')),
      );
      final expand = find.descendant(
        of: rootRow,
        matching: find.byKey(const ValueKey('mobile-folder-sheet-subfolders')),
      );
      final popup = find.byType(prism.PopupMenu);
      Finder menuChoice(String label) =>
          find.descendant(of: popup, matching: find.text(label));
      Finder row(String label) => find.descendant(
        of: panel,
        matching: find.byWidgetPredicate(
          (widget) => widget is MobileFolderSheetRow && widget.label == label,
        ),
      );
      expect(check, findsOneWidget);
      expect(tester.widget<MobileFolderSheetRow>(rootRow).count, 1);
      expect(option(nested), findsNothing);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(row(nested), findsNothing);
      expect(menuChoice(nested), findsOneWidget);
      expect(menuChoice(second), findsOneWidget);
      expect(tester.widget<prism.PopupMenu>(popup).items.map((e) => e.label), [
        nested,
        second,
      ]);
      expect(panel, findsOneWidget);
      expect(tester.state(local), same(original));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popup, findsNothing);
      expect(panel, findsOneWidget);

      await tester.tap(
        control(const ValueKey('mobile-folder-sheet-local-more')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create Folder'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);

      await tester.tap(option('B'));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(tester.state(local), same(original));
      expect(_tile('seed-0'), findsOneWidget);

      await tester.dragFrom(const Offset(48, 520), const Offset(148, 0));
      await tester.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(tester.getSize(panel).width, (390 - 16) * .50);
      final search = find.descendant(
        of: panel,
        matching: find.byType(EditableText),
      );
      await tester.enterText(search, 'requires truncation');
      await tester.pumpAndSettle();
      expect(row(nested), findsOneWidget);
      expect(
        find.descendant(of: row(nested), matching: find.text('B / $nested')),
        findsOneWidget,
      );
      final input = tester.widget<EditableText>(search);
      expect(input.focusNode.hasPrimaryFocus, isTrue);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(popup, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(search).controller,
        same(input.controller),
      );
      expect(input.controller.text, 'requires truncation');
      expect(input.focusNode.hasPrimaryFocus, isTrue);
      expect(popup, findsNothing);
      await tester.tap(option(nested));
      await _settle(tester);
      expect(panel, findsNothing);
      expect(_tile('nested-one'), findsOneWidget);
      expect(find.byTooltip(nested), findsOneWidget);
      expect(chevron, findsOneWidget);

      await tester.tap(find.text(nested));
      await tester.pumpAndSettle();
      expect(row(nested), findsNothing);
      expect(tester.widget<MobileFolderSheetRow>(rootRow).subtitle, nested);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final childItems = tester.widget<prism.PopupMenu>(popup).items;
      expect(
        childItems.singleWhere((item) => item.checked == true).label,
        nested,
      );
      await tester.tap(menuChoice(second));
      await _settle(tester);
      expect(panel, findsNothing);
      expect(popup, findsNothing);
      expect(_tile('second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px actual favorite sheet resizes its rounded rows and keeps the fixed inner layout and IME',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 720)
        ..padding = const FakeViewPadding(
          left: 12,
          top: 22,
          right: 10,
          bottom: 18,
        );
      addTearDown(tester.view.reset);
      final fixture = await _prepare(tester, 1);
      fixture.textScale = 1.6;
      const nested = 'Long nested collection from the search result';
      await tester.runAsync(() async {
        await fixture.manager.createChildFolder(
          nested,
          fixture.manager.folderTree.named('B')!.id,
        );
        await fixture.manager.addComic(
          nested,
          _comic('nested-book', 'Nested book'),
        );
        for (var i = 0; i < 12; i++) {
          await fixture.manager.createFolder('Scrolling fixture folder $i');
        }
      });
      appdata.implicitData['favoriteFolder'] = {
        'name': 'B',
        'isNetwork': false,
      };
      await tester.pumpWidget(
        fixture.host(phone: true, page: const FavoritesPage()),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('favorite-path-current')));
      await tester.pumpAndSettle();

      final panel = find.byKey(const ValueKey('mobile-side-sheet-surface'));
      final grip = find.byKey(const ValueKey('mobile-side-sheet-handle'));
      final viewport = find.byKey(const ValueKey('mobile-side-sheet-viewport'));
      final browser = find.byType(FavoriteFolderBrowser);
      Finder inside(Finder target) =>
          find.descendant(of: panel, matching: target);
      final narrow = tester.getRect(viewport);
      expect(narrow.left, 12);
      expect(narrow.width, closeTo((320 - 12 - 10) * .50, .01));
      expect(narrow.height, lessThan(720 - 22 - 18));
      expect(tester.getRect(panel), narrow);
      expect(
        inside(find.byKey(const ValueKey('mobile-folder-sheet-close')))
            .hitTestable(),
        findsOneWidget,
      );
      final owner = tester.state(browser);
      final view = inside(find.byType(Scrollable)).first;
      final scroll = tester.state<ScrollableState>(view);
      final position = scroll.position;
      await tester.drag(view, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(viewport), narrow);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      final editor = inside(find.byType(EditableText));
      final field = inside(
        find.byKey(const ValueKey('favorite-folder-search')),
      );
      final close = inside(
        find.byKey(const ValueKey('mobile-folder-sheet-close')),
      );
      await tester.enterText(editor, 'from the search');
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      await tester.pumpAndSettle();
      final oldEditor = tester.widget<EditableText>(editor);
      final withIme = tester.getRect(viewport);
      final narrowScroll = tester.getSize(view);
      final narrowField = tester.getSize(field);
      final narrowClose = tester.getCenter(close);
      final label = inside(find.text(nested));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final unchangedLabel = tester.getSize(label);
      final labelLeft = tester.getTopLeft(label).dx;
      expect(withIme.height, lessThan(narrow.height));
      final fingers = await tester.startGesture(tester.getCenter(grip));
      await fingers.moveBy(const Offset(28, 0));
      await fingers.moveBy(const Offset(42, 0));
      await tester.pump(const Duration(milliseconds: 70));
      final middle = tester.getRect(viewport);
      expect(middle.width, greaterThan(withIme.width));
      expect(middle.height, greaterThan(withIme.height));
      expect(tester.getRect(panel), middle);
      expect(tester.getSize(view).width, greaterThan(narrowScroll.width));
      expect(tester.getSize(field).width, greaterThan(narrowField.width));
      expect(tester.getCenter(close).dx, greaterThan(narrowClose.dx));
      expect(tester.getSize(label), unchangedLabel);
      expect(tester.getTopLeft(label).dx, labelLeft);
      await fingers.moveBy(const Offset(125, 0));
      await fingers.up();
      await tester.pumpAndSettle();
      final wide = tester.getRect(viewport);
      expect(wide.left, narrow.left);
      expect(wide.width, closeTo(298 * .75, .01));
      expect(wide.top, 22);
      expect(wide.bottom, 720 - 210 - 18);
      expect(tester.getRect(panel), wide);
      expect(tester.getSize(field).width, greaterThan(narrowField.width));
      expect(tester.getSize(label), unchangedLabel);
      expect(tester.getTopLeft(label).dx, labelLeft);
      expect(tester.state(browser), same(owner));
      expect(tester.state<ScrollableState>(view).position, same(position));
      final newEditor = tester.widget<EditableText>(editor);
      expect(newEditor.controller, same(oldEditor.controller));
      expect(newEditor.focusNode, same(oldEditor.focusNode));
      expect(newEditor.focusNode.hasPrimaryFocus, isTrue);
      expect(newEditor.controller.text, 'from the search');
      final choice = inside(find.text(nested));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      tester.view.resetViewInsets();
      await _settle(tester);
      expect(_tile('nested-book'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final multiFolder in [false, true]) {
    testWidgets(
      'network favorite roots open the selector by name: multi=$multiFolder',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final fixture = await _prepare(tester, 0);
        final data = FavoriteData(
          key: 'shallow-network-test',
          title: 'Network Library',
          multiFolder: multiFolder,
          loadComic: (_, [_]) async => const Res<List<Comic>>([], subData: 1),
          loadNext: null,
          loadFolders: ([_]) async => const Res({'sub': 'Network list'}),
        );
        configureFavoriteDataResolver((key) => key == data.key ? data : null);
        final source = _NetworkSource(data);
        configureComicSourceRegistry(
          all: () => [source],
          find: (key) => key == source.key ? source : null,
          fromIntKey: (_) => null,
          isEmpty: () => false,
        );
        appdata.settings[DiscoveryPreferences.favoritePages.key] = [data.key];
        addTearDown(() {
          configureFavoriteDataResolver(null);
          configureComicSourceRegistry(
            all: () => [],
            find: (_) => null,
            fromIntKey: (_) => null,
            isEmpty: () => true,
          );
        });
        appdata.implicitData['favoriteFolder'] = {
          'name': data.key,
          'isNetwork': true,
        };
        await tester.pumpWidget(
          fixture.host(phone: true, page: const FavoritesPage()),
        );
        await _settle(tester);
        final panel = find.byKey(const ValueKey('mobile-side-sheet-surface'));
        final name = find.text(data.title);
        final chevron = find.byKey(const ValueKey('favorite-path-open-sheet'));
        expect(
          tester.getCenter(chevron).dx,
          greaterThan(tester.getCenter(name).dx),
        );
        expect(find.byIcon(Icons.menu), findsNothing);
        await tester.tap(name);
        await tester.pumpAndSettle();
        expect(panel, findsOneWidget);
        final networkRow = find.descendant(
          of: panel,
          matching: find.byKey(
            ValueKey('mobile-folder-sheet-network-${data.key}'),
          ),
        );
        expect(networkRow, findsOneWidget);
        expect(
          tester.widget<MobileFolderSheetRow>(networkRow).selected,
          isTrue,
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.byKey(
              const ValueKey('mobile-folder-sheet-network-settings'),
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: panel,
            matching: find.byKey(const ValueKey('mobile-folder-sheet-close')),
          ),
        );
        await tester.pumpAndSettle();
        expect(panel, findsNothing);
        expect(find.byType(NetworkFavoritePage), findsOneWidget);
        expect(name.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final nested in [false, true]) {
    testWidgets(
      'favorites tab: local search morph keeps the pinned header and snapshot '
      '(nested=$nested)',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        // The real async threshold is 500; closing search must not swap a
        // large, already loaded grid for a spinner while the field retracts.
        final fixture = await _prepare(tester, nested ? 0 : 501);
        await tester.runAsync(() async {
          await fixture.manager.createChildFolder(
            'Sub',
            fixture.manager.folderTree.named('B')!.id,
          );
          await fixture.manager.addComic('Sub', _comic('sub', 'Existing sub'));
        });
        appdata.implicitData['favoriteFolder'] = {
          'name': nested ? 'Sub' : 'B',
          'isNetwork': false,
        };
        await tester.pumpWidget(
          fixture.host(
            phone: true,
            reduceMotion: false,
            page: const FavoritesPage(),
          ),
        );
        await _settle(tester);
        final page = find.byType(LocalFavoritesPage);
        Finder local(Finder target) =>
            find.descendant(of: page, matching: target);
        Finder button(String name) => local(
          find.byWidgetPredicate(
            (w) => w is MobileToolbarButton && w.label == name,
          ),
        ).hitTestable();
        final bar = local(find.byType(MobileCollectionSearchToolbar));
        final pane = local(
          find.byKey(const ValueKey('collection-search-pane')),
        );
        final grid = local(find.byType(SliverGridComics));
        final scroll = local(find.byType(CustomScrollView));
        // Linux starts in mouse-wheel mode. Establish touch physics before
        // measuring whether opening search preserves the scroll position.
        final touch = await tester.startGesture(
          tester.getCenter(button('Search')),
        );
        await touch.cancel();
        await tester.pump();
        final barOwner = tester.state(bar);
        final gridOwner = tester.state(grid);
        final position = tester
            .widget<CustomScrollView>(scroll)
            .controller!
            .position;
        final buttonRect = tester.getRect(button('Search'));
        final barRect = tester.getRect(bar);
        final editor = local(find.byType(EditableText));
        tester.testTextInput.log.clear();
        int shows() => tester.testTextInput.log
            .where((m) => m.method == 'TextInput.show')
            .length;
        void stillMounted() {
          expect(tester.state(bar), same(barOwner));
          expect(tester.state(grid), same(gridOwner));
          expect(
            tester.widget<CustomScrollView>(scroll).controller!.position,
            same(position),
          );
          expect(tester.getRect(bar), barRect);
          expect(local(find.byType(CircularProgressIndicator)), findsNothing);
        }

        await tester.tap(button('Search'));
        await tester.pump();
        stillMounted(); // Round 2 lost both owners on this very first frame.
        final first = tester.getRect(pane);
        expect(first.width, closeTo(buttonRect.width, 1));
        expect(first.center.dx, closeTo(buttonRect.center.dx, 1));
        await tester.pump(const Duration(milliseconds: 35));
        final early = tester.getRect(pane).width;
        expect(early, greaterThan(first.width + 2));
        expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isFalse);
        expect(shows(), 0);
        await tester.pump(const Duration(milliseconds: 55));
        final later = tester.getRect(pane).width;
        expect(later, greaterThan(early + 6));
        expect(shows(), 0);
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        final full = tester.getRect(pane);
        expect(full.width, greaterThan(later));
        final input = tester.widget<EditableText>(editor);
        expect(input.focusNode.hasPrimaryFocus, isTrue);
        expect(shows(), greaterThan(0));
        expect(
          tester.testTextInput.log.where(
            (m) => m.method == 'TextInput.setClient',
          ),
          hasLength(1),
        );
        final query = nested ? 'Existing sub' : 'Existing 499';
        await tester.enterText(editor, query);
        await tester.pump();
        var gridWidget = tester.widget<SliverGridComics>(grid);
        var gridUpdates = 0;
        for (final inset in [70.0, 140.0, 215.0, 290.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump(const Duration(milliseconds: 16));
          final next = tester.widget<SliverGridComics>(grid);
          if (!identical(next, gridWidget)) gridUpdates++;
          gridWidget = next;
        }
        expect(gridUpdates, 0, reason: 'during keyboard insets');
        final resized = tester.widget<EditableText>(editor);
        expect(resized.controller, same(input.controller));
        expect(resized.focusNode, same(input.focusNode));
        expect(resized.focusNode.hasPrimaryFocus, isTrue);
        expect(resized.controller.text, query);
        expect(local(_tile(nested ? 'sub' : 'seed-499')), findsOneWidget);
        expect(button('More'), findsOneWidget);
        stillMounted();

        await tester.tap(button('Cancel'));
        await tester.pump();
        expect(tester.getRect(pane).width, closeTo(full.width, 1));
        stillMounted();
        tester.view.resetViewInsets();
        await tester.pump(const Duration(milliseconds: 45));
        final folding = tester.getRect(pane).width;
        expect(folding, lessThan(full.width - 3));
        await tester.pump(const Duration(milliseconds: 45));
        expect(tester.getRect(pane).width, lessThan(folding - 3));
        stillMounted();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(pane, findsNothing);
        expect(tester.getRect(button('Search')), buttonRect);
        expect(button('More'), findsOneWidget);
        stillMounted();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact favorites enters batch only from More and restores the filtered search on back',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final fixture = await _prepare(tester, 3);
      await tester.pumpWidget(fixture.host(phone: true));
      await _settle(tester);
      Finder button(String label) => find
          .byWidgetPredicate(
            (w) => w is MobileToolbarButton && w.label == label,
          )
          .hitTestable();
      expect(button('Select comics'), findsNothing);
      expect(_tile('seed-0'), findsOneWidget);
      final pane = find.byKey(const ValueKey('collection-search-pane'));
      final source = tester.getRect(button('Search'));
      await tester.tap(button('Search'));
      // This fixture has Reduce Motion on: reach the editable width on the
      // first frame, even though the very same sliver animates without it.
      await tester.pump();
      expect(tester.getRect(pane).width, greaterThan(source.width * 2));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Existing 2');
      await _settle(tester);
      expect(_tile('seed-2'), findsOneWidget);
      expect(_tile('seed-0'), findsNothing);
      await tester.tap(button('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select comics'));
      await tester.pumpAndSettle();
      expect(find.byType(prism.SearchField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('favorites-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Selected 1 comics'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Existing 2',
      );
      expect(_tile('seed-0'), findsNothing);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(prism.SearchField), findsNothing);
      expect(_tile('seed-0'), findsOneWidget);
      expect(button('Search'), findsOneWidget);
    },
  );

  testWidgets(
    'wide selection toolbar exposes common actions and Escape exits local modes',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await _prepare(tester, 3);
      await tester.pumpWidget(fixture.host());
      await _settle(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Existing 1');
      await tester.pumpAndSettle();
      await tester.longPress(_tile('seed-1'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('favorites-select-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('favorites-invert-selection')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('favorites-deselect')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('favorites-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Selected 1 comics'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Selected 1 comics'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(_tile('seed-0'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(_tile('seed-0'), findsOneWidget);
      expect(_tile('seed-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Escape dismisses a deletion dialog before clearing selection', (
    tester,
  ) async {
    final fixture = await _prepare(tester, 2);
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    await tester.tap(find.byTooltip('Select comics'));
    await tester.pumpAndSettle();
    await _chooseAction(tester, 'Select All');
    await _chooseAction(tester, 'Delete Comic');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 comics?'), findsNothing);
    expect(find.text('Selected 2 comics'), findsOneWidget);
    expect(fixture.manager.getFolderComics('B'), hasLength(2));
  });

  for (final size in [
    const Size(375, 800),
    const Size(812, 375),
    const Size(1024, 600),
  ]) {
    testWidgets(
      'page menu opens current subfolders and persists only their order at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final count = size.width == 1024 ? 1 : 0;
        final fixture = await _prepare(tester, count);
        fixture.textScale = count == 0 ? 2 : 1;
        fixture.dark = size.width == 375;
        final manager = fixture.manager;
        final parent = manager.folderTree.named('B')!;
        await tester.runAsync(() async {
          await manager.createChildFolder('First child', parent.id);
          await manager.createChildFolder('Second child', parent.id);
          await manager.addComic(
            'First child',
            _comic('child-comic', 'Child comic'),
          );
        });
        final roots = manager.folderTree.roots
            .map((folder) => folder.id)
            .toList();
        final identities = {
          for (final folder in manager.folderTree.flattened)
            folder.name: (folder.id, folder.parentId),
        };
        await tester.pumpWidget(fixture.host());
        await _settle(tester);
        await _chooseAction(tester, 'Sort subfolders');
        expect(
          tester
              .widget<FavoriteFolderSelect>(find.byType(FavoriteFolderSelect))
              .current,
          'B',
        );
        expect(
          tester
              .widget<ReorderableListView>(find.byType(ReorderableListView))
              .itemCount,
          2,
        );
        await tester.tap(find.byTooltip('Move down').first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.arrow_back_sharp),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => AppDataOperations.instance.run(() async {}),
        );
        await _settle(tester);
        expect(
          manager.folderTree.childrenOf(parent.id).map((folder) => folder.name),
          ['Second child', 'First child'],
        );
        expect(manager.folderTree.roots.map((folder) => folder.id), roots);
        expect({
          for (final folder in manager.folderTree.flattened)
            folder.name: (folder.id, folder.parentId),
        }, identities);
        expect(
          manager.getFolderComics('B').map((comic) => comic.id),
          count == 0 ? isEmpty : ['seed-0'],
        );
        expect(manager.getFolderComics('First child').single.id, 'child-comic');
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await manager.closeAndWait();
          await manager.init();
        });
        expect(
          manager.folderTree.childrenOf(parent.id).map((folder) => folder.name),
          ['Second child', 'First child'],
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('old folder action cannot open a different page hierarchy', (
    tester,
  ) async {
    final fixture = await _prepare(tester, 1);
    await tester.runAsync(
      () => fixture.manager.createChildFolder(
        'Child',
        fixture.manager.folderTree.named('B')!.id,
      ),
    );
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    final retained = tester
        .widget<MenuButton>(find.byType(MenuButton))
        .entries
        .singleWhere((entry) => entry.text == 'Sort subfolders')
        .onClick;
    await tester.pumpWidget(fixture.host(folder: 'A'));
    await _settle(tester);
    retained();
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(375, 800), const Size(1024, 600)]) {
    testWidgets('explicit selection entry and confirmed deletion at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await _prepare(tester, 3);
      await tester.pumpWidget(fixture.host());
      await _settle(tester);
      if (size.width < 600) {
        await _chooseAction(tester, 'Select comics');
      } else {
        await tester.tap(find.byTooltip('Select comics'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Selected 0 comics'), findsOneWidget);
      expect(
        tester
            .widget<MenuButton>(find.byType(MenuButton))
            .entries
            .any((entry) => entry.text == 'Delete Comic'),
        isFalse,
      );
      await _chooseAction(tester, 'Select All');
      expect(find.text('Selected 3 comics'), findsOneWidget);
      await _chooseAction(tester, 'Delete Comic');
      expect(find.text('Delete 3 comics?'), findsOneWidget);
      expect(fixture.manager.getFolderComics('B'), hasLength(3));
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(fixture.manager.getFolderComics('B'), hasLength(3));
      expect(find.text('Selected 3 comics'), findsOneWidget);
      await _chooseAction(tester, 'Delete Comic');
      await tester.tap(find.text('Confirm').last);
      await _settle(tester);
      expect(fixture.manager.getFolderComics('B'), isEmpty);
      expect(find.text('Selected 3 comics'), findsNothing);
      expect(find.text('Selected 0 comics'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keyword changes do not hide favorites or change their selection',
    (tester) async {
      final fixture = await _prepare(tester, 3);
      appdata.settings[KeywordPreferences.comics.key] = <String>['Existing 1'];
      await tester.pumpWidget(fixture.host());
      await _settle(tester);
      await tester.tap(find.byTooltip('Select comics'));
      await tester.pumpAndSettle();
      await _chooseAction(tester, 'Select All');
      expect(find.text('Selected 3 comics'), findsOneWidget);
      final grid = tester.widget<SliverGridComics>(
        find.byType(SliverGridComics),
      );
      expect(
        grid.selections!.keys.map((comic) => comic.id),
        unorderedEquals(['seed-0', 'seed-1', 'seed-2']),
      );
      await _chooseAction(tester, 'Invert Selection');
      expect(find.text('Selected 0 comics'), findsOneWidget);
      await _chooseAction(tester, 'Invert Selection');
      expect(find.text('Selected 3 comics'), findsOneWidget);
      await tester.tap(_tile('seed-0'));
      await tester.pumpAndSettle();
      expect(find.text('Selected 2 comics'), findsOneWidget);
      appdata.settings[KeywordPreferences.comics.key] = <String>['Existing 2'];
      await tester.pumpAndSettle();
      expect(find.text('Selected 2 comics'), findsOneWidget);
      expect(
        tester
            .widget<SliverGridComics>(find.byType(SliverGridComics))
            .selections,
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selection entry clears on back and on folder changes', (
    tester,
  ) async {
    final fixture = await _prepare(tester, 2);
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    await tester.tap(find.byTooltip('Select comics'));
    await tester.pumpAndSettle();
    expect(find.text('Selected 0 comics'), findsOneWidget);
    await fixture.navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Selected 0 comics'), findsNothing);
    await tester.tap(find.byTooltip('Select comics'));
    await tester.pumpAndSettle();
    await tester.tap(_tile('seed-0'));
    await tester.pumpAndSettle();
    expect(find.text('Selected 1 comics'), findsOneWidget);
    await tester.pumpWidget(fixture.host(folder: 'A'));
    await _settle(tester);
    expect(find.text('Selected 1 comics'), findsNothing);
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    expect(find.text('Selected 1 comics'), findsNothing);
    expect(
      tester.widget<SliverGridComics>(find.byType(SliverGridComics)).selections,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press range selection retains keyword matches', (
    tester,
  ) async {
    final fixture = await _prepare(tester, 3);
    appdata.settings[KeywordPreferences.comics.key] = <String>['Existing 1'];
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    await tester.longPress(_tile('seed-0'));
    await tester.pumpAndSettle();
    await tester.longPress(_tile('seed-2'));
    await tester.pumpAndSettle();
    expect(find.text('Selected 3 comics'), findsOneWidget);
    expect(
      tester
          .widget<SliverGridComics>(find.byType(SliverGridComics))
          .selections!
          .keys
          .map((comic) => comic.id),
      unorderedEquals(['seed-0', 'seed-1', 'seed-2']),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reading-status exclusions and active search constrain selection',
    (tester) async {
      final fixture = await _prepare(tester, 3);
      appdata.implicitData['local_favorites_read_filter'] = 'Completed';
      await tester.pumpWidget(fixture.host());
      await _settle(tester);
      expect(_tile('seed-0'), findsNothing);
      expect(
        find.text('Hidden by reading-status filter: 3 comics'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.checklist_rounded),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(_tile('seed-0'), findsOneWidget);
      expect(
        find.text('Hidden by reading-status filter: 3 comics'),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'Existing 1');
      await tester.pumpAndSettle();
      await tester.longPress(_tile('seed-1'));
      await tester.pumpAndSettle();
      await _chooseAction(tester, 'Select All');
      expect(find.text('Selected 1 comics'), findsOneWidget);
      expect(
        tester
            .widget<SliverGridComics>(find.byType(SliverGridComics))
            .selections!
            .keys
            .single
            .id,
        'seed-1',
      );
      await _chooseAction(tester, 'Invert Selection');
      expect(find.text('Selected 0 comics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [0, 499, 500]) {
    for (final query in ['', 'New']) {
      for (final covered in [false, true]) {
        testWidgets(
          'search follows additions and deletions: count=$count query=$query covered=$covered',
          (tester) async {
            final fixture = await _prepare(tester, count);
            await tester.pumpWidget(fixture.host());
            await _settle(tester);
            await tester.tap(find.byTooltip('Search'));
            await tester.pumpAndSettle();
            if (query.isNotEmpty) {
              await tester.enterText(find.byType(TextField), query);
            }
            await tester.pumpAndSettle();
            if (covered) {
              unawaited(
                fixture.navigator.currentState!.push<void>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('Details')),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            }
            await tester.runAsync(
              () => fixture.manager.addComic(
                'B',
                _comic('new', 'New matching comic'),
              ),
            );
            await _settle(tester);
            if (covered) {
              fixture.navigator.currentState!.pop();
              await tester.pumpAndSettle();
            }
            expect(_tile('new'), findsOneWidget);
            expect(
              tester
                  .widget<EditableText>(find.byType(EditableText))
                  .controller
                  .text,
              query,
            );
            await tester.runAsync(
              () => fixture.manager.deleteComicWithId(
                'B',
                'new',
                const ComicType(17),
              ),
            );
            await _settle(tester);
            expect(_tile('new'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('switching folders replaces the active search results', (
    tester,
  ) async {
    final fixture = await _prepare(tester, 500);
    await tester.runAsync(() async {
      await fixture.manager.addComic('B', _comic('from-b', 'New comic B'));
      await fixture.manager.addComic('A', _comic('from-a', 'New comic A'));
    });
    await tester.pumpWidget(fixture.host());
    await _settle(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New');
    await tester.pumpAndSettle();
    expect(_tile('from-b'), findsOneWidget);
    await tester.pumpWidget(fixture.host(folder: 'A'));
    await _settle(tester);
    expect(_tile('from-a'), findsOneWidget);
    expect(_tile('from-b'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local search matches the same terms across title, author and tags',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final fixture = await _prepare(tester, 0);
      await tester.runAsync(() async {
        await fixture.manager.addComics('B', [
          _comic('mixed', '繁體 Title')..author = 'Writer',
          _comic('simplified', '简体 Heading'),
          _comic('tag', 'Different')..tags = ['female:Glasses:detail'],
          _comic('author', 'Example')..author = 'Writer Alias',
        ]);
      });
      await tester.pumpWidget(fixture.host(phone: true));
      await _settle(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      await tester.pump();
      final input = find.byType(EditableText);
      Future<void> expectSearch(String inputText, List<String> ids) async {
        await tester.enterText(input, inputText);
        await tester.pump();
        final tiles = tester.widgetList<ComicTile>(find.byType(ComicTile));
        expect(
          tiles.map((tile) => tile.comic.id),
          unorderedEquals(ids),
          reason: 'for query $inputText',
        );
      }

      await expectSearch('不存在', []);
      await expectSearch('繁体  writer', ['mixed']);
      await expectSearch('繁体  writer ', ['mixed']);
      await expectSearch('繁体 Title', ['mixed']);
      await expectSearch('繁体 TITLE', []);
      await expectSearch('簡體 heading', ['simplified']);
      await expectSearch('glasses', ['tag']);
      await expectSearch('glass', []);
      await expectSearch('Glass', []);
      await expectSearch('detail', []);
      await expectSearch('writer', ['mixed', 'author']);
      await expectSearch('  ', ['mixed', 'simplified', 'tag', 'author']);
    },
  );

  testWidgets(
    '1200 favorites skip keyword matching and per-comic history queries',
    (tester) async {
      final fixture = await _prepare(tester, 1200);
      appdata.settings['blockedWords'] = ['Existing'];
      await tester.pumpWidget(fixture.host());
      await _settle(tester);
      final grid = tester.widget<SliverGridComics>(
        find.byType(SliverGridComics),
      );
      expect(grid.filterBlockedComics, isFalse);
      expect(grid.comics, hasLength(1200));
      expect(fixture.history.reads, 0);
      appdata.settings['readerBrightness'] = 75;
      await tester.pump();
      expect(fixture.history.reads, 0);
      await tester.tap(find.byTooltip('Select comics'));
      await tester.pumpAndSettle();
      await _chooseAction(tester, 'Select All');
      expect(find.text('Selected 1200 comics'), findsOneWidget);
      expect(fixture.history.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'return from details keeps the large phone folder snapshot and cover hero',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final fixture = await _prepare(tester, 1000);
      final previous = appNavigation.mainNavigatorKey;
      appNavigation.mainNavigatorKey = fixture.navigator;
      addTearDown(() => appNavigation.mainNavigatorKey = previous);
      appdata.settings['onClickFavorite'] = 'viewDetail';
      await tester.pumpWidget(fixture.host(phone: true, reduceMotion: false));
      await _settle(tester);
      final grid = find.byType(SliverGridComics);
      final originalGrid = tester.state(grid);
      final originalComics = tester.widget<SliverGridComics>(grid).comics;
      expect(originalComics, hasLength(1000));
      expect(find.byType(ComicTile).evaluate().length, lessThan(40));
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(450);
      await tester.pumpAndSettle();
      final visible = find.byType(ComicTile).hitTestable().first;
      final tile = tester.widget<ComicTile>(visible);
      await tester.tap(visible);
      await tester.pump();
      expect(fixture.navigator.currentState!.canPop(), isTrue);
      expect(
        tester
            .widget<ComicPage>(find.byType(ComicPage, skipOffstage: false))
            .heroID,
        tile.heroID,
      );
      fixture.navigator.currentState!.pop();
      await _settle(tester);
      expect(tester.state(grid), same(originalGrid));
      expect(
        tester.widget<SliverGridComics>(grid).comics,
        same(originalComics),
      );
      expect(scroll.offset, 450);
      expect(
        tester.widget<ComicTile>(_tile(tile.comic.id)).heroID,
        tile.heroID,
      );
      expect(fixture.history.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
