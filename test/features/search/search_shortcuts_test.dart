import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/features/search/search_entry.dart';
import 'package:venera_next/features/search/search_shortcut.dart';
import 'package:venera_next/foundation/appdata.dart';

class _SearchSource extends Fake implements ComicSource {
  @override
  String get name => 'Fixture';

  @override
  String get key => 'fixture';

  @override
  SearchPageData get searchPageData => const SearchPageData(null, null, null);
}

void main() {
  test('search shortcuts round-trip author metadata', () {
    const shortcut = SearchShortcut(
      kind: SearchShortcutKind.author,
      sourceKey: 'example',
      namespace: 'artist',
      value: 'Author Name',
    );

    final restored = SearchShortcut.fromJson(shortcut.toJson());

    expect(restored?.kind, SearchShortcutKind.author);
    expect(restored?.sourceKey, 'example');
    expect(restored?.namespace, 'artist');
    expect(restored?.value, 'Author Name');
    expect(restored?.identity, shortcut.identity);
  });

  test('search shortcut identity keeps sources and kinds separate', () {
    const author = SearchShortcut(
      kind: SearchShortcutKind.author,
      sourceKey: 'source-a',
      namespace: 'author',
      value: 'same name',
    );
    const tag = SearchShortcut(
      kind: SearchShortcutKind.tag,
      sourceKey: 'source-a',
      namespace: 'artist',
      value: 'same name',
    );
    const otherSource = SearchShortcut(
      kind: SearchShortcutKind.author,
      sourceKey: 'source-b',
      namespace: 'author',
      value: 'same name',
    );

    expect({author.identity, tag.identity, otherSource.identity}, hasLength(3));
  });

  test('invalid search shortcut data is ignored', () {
    expect(SearchShortcut.fromJson(null), isNull);
    expect(SearchShortcut.fromJson({'kind': 'unknown'}), isNull);
    expect(
      SearchShortcut.fromJson({
        'kind': 'author',
        'sourceKey': 'example',
        'namespace': 'author',
        'value': '',
      }),
      isNull,
    );
  });

  testWidgets('home search prepares only nearby shortcuts before IME handoff', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final previous = {
      for (final key in ['searchSources', 'searchShortcuts', 'language'])
        key: appdata.settings[key],
    };
    final source = _SearchSource();
    var shortcutLookups = 0;
    configureComicSourceRegistry(
      all: () => [source],
      find: (key) {
        if (key == source.key) return source;
        if (key == 'saved-source') shortcutLookups++;
        return null;
      },
      fromIntKey: (_) => null,
      isEmpty: () => false,
    );
    addTearDown(() {
      configureComicSourceRegistry(
        all: () => [],
        find: (_) => null,
        fromIntKey: (_) => null,
        isEmpty: () => true,
      );
      for (final entry in previous.entries) {
        appdata.settings[entry.key] = entry.value;
      }
    });
    appdata.settings['language'] = 'en-US';
    appdata.settings['searchSources'] = [source.key];
    appdata.settings['searchShortcuts'] = [
      for (var i = 0; i < 400; i++)
        SearchShortcut(
          kind: i == 0 ? SearchShortcutKind.author : SearchShortcutKind.tag,
          sourceKey: 'saved-source',
          namespace: i == 0 ? 'author' : 'tag',
          value: 'Saved $i',
        ).toJson(),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [MobileUiLocalizations.delegate],
        builder: (_, child) => MobileUiTheme(glass: 'off', child: child!),
        home: const Scaffold(body: CustomScrollView(slivers: [SearchEntry()])),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byType(SearchMorphSurface), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(shortcutLookups, lessThan(30), reason: 'during the reveal');

    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Saved 0').hitTestable(), findsOneWidget);
    expect(find.text('Saved 1').hitTestable(), findsOneWidget);
    expect(find.text('Saved 399'), findsNothing);
    final beforeInsets = shortcutLookups;
    for (final inset in [70.0, 140.0, 210.0, 280.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shortcutLookups, beforeInsets);
    expect(
      tester.testTextInput.log.where(
        (call) => call.method == 'TextInput.setClient',
      ),
      hasLength(1),
    );
  });
}
