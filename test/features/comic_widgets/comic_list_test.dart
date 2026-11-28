import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/res.dart';

void main() {
  testWidgets('large comic grid prepares row menus only when opened', (
    tester,
  ) async {
    final settings = {
      for (final key in [
        'showFavoriteStatusOnTile',
        'showHistoryStatusOnTile',
        'showUpdateStatusOnTile',
      ])
        key: appdata.settings[key],
    };
    for (final key in settings.keys) {
      appdata.settings[key] = false;
    }
    addTearDown(() {
      for (final entry in settings.entries) {
        appdata.settings[entry.key] = entry.value;
      }
    });
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final comics = [
      for (var i = 0; i < 1000; i++)
        Comic('Comic $i', '', '$i', null, null, '', 'fixture', null, null),
    ];
    final menuRequests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverGridComics(
                comics: comics,
                filterBlockedComics: false,
                menuBuilder: (comic) {
                  menuRequests.add(comic.id);
                  return [
                    MenuEntry(
                      text: 'Action for ${comic.title}',
                      icon: Icons.check,
                      onClick: () {},
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(ComicTile).evaluate(), hasLength(lessThan(40)));
    expect(menuRequests, isEmpty, reason: 'on the initial grid frame');
    final first = find.byType(ComicTile).hitTestable().first;
    await tester.longPress(first);
    await tester.pumpAndSettle();
    expect(menuRequests, ['0']);
    expect(find.text('Action for Comic 0'), findsOneWidget);
  });

  testWidgets('ComicList stores mutable page data from unmodifiable results', (
    tester,
  ) async {
    final key = GlobalKey<ComicListState>();
    const comic = Comic(
      'Cat Eye',
      '',
      'cat-eye',
      null,
      null,
      '',
      'webdav_library',
      null,
      null,
    );
    final oldListMode = appdata.settings['comicListDisplayMode'];
    final oldDisplayMode = appdata.settings['comicDisplayMode'];
    final oldBlockedWords = appdata.settings['blockedWords'];
    final oldFavoriteStatus = appdata.settings['showFavoriteStatusOnTile'];
    final oldHistoryStatus = appdata.settings['showHistoryStatusOnTile'];
    final oldUpdateStatus = appdata.settings['showUpdateStatusOnTile'];

    appdata.settings['comicListDisplayMode'] = 'paging';
    appdata.settings['comicDisplayMode'] = 'brief';
    appdata.settings['blockedWords'] = <String>[];
    appdata.settings['showFavoriteStatusOnTile'] = false;
    appdata.settings['showHistoryStatusOnTile'] = false;
    appdata.settings['showUpdateStatusOnTile'] = false;
    addTearDown(() {
      appdata.settings['comicListDisplayMode'] = oldListMode;
      appdata.settings['comicDisplayMode'] = oldDisplayMode;
      appdata.settings['blockedWords'] = oldBlockedWords;
      appdata.settings['showFavoriteStatusOnTile'] = oldFavoriteStatus;
      appdata.settings['showHistoryStatusOnTile'] = oldHistoryStatus;
      appdata.settings['showUpdateStatusOnTile'] = oldUpdateStatus;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: PageStorageBucket(),
            child: ComicList(
              key: key,
              enablePageStorage: true,
              loadPage: (_) async =>
                  Res(List<Comic>.unmodifiable([comic]), subData: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Cat Eye'), findsOneWidget);
    expect(() => key.currentState!.remove(comic), returnsNormally);
    await tester.pump();
    expect(find.text('Cat Eye'), findsNothing);
  });
}
