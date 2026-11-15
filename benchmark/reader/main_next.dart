// Ordinary engine binding and the real reader: no integration-test frame pump.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/window_frame.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/platform_effects.dart';
import 'package:venera_next/features/reader/reader_page.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'probe.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/routing/app_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await App.init();
  // This entrypoint must only be installed with the isolated benchmark ID.
  if (!App.dataPath.contains('readerbenchmark')) {
    throw StateError('Refusing to use the installed application data');
  }
  await AppTranslation.init();
  final settings = appdata.settings;
  settings['language'] = 'en-US';
  settings['readerMode'] = const String.fromEnvironment(
    'READER_MODE',
    defaultValue: 'galleryLeftToRight',
  );
  settings['autoReaderMode'] = false;
  settings['readerScreenPicNumberForLandscape'] = const int.fromEnvironment(
    'READER_IMAGES_PER_PAGE',
    defaultValue: 1,
  );
  settings['readerScreenPicNumberForPortrait'] = const int.fromEnvironment(
    'READER_IMAGES_PER_PAGE',
    defaultValue: 1,
  );
  settings['showSingleImageOnFirstPage'] = false;
  settings['enablePageAnimation'] = true;
  settings['preloadImageCount'] = 4;
  settings['enableClockAndBatteryInfoInReader'] = false;
  settings['enableTurnPageByVolumeKey'] = true;
  settings['recordReadingStatistics'] = false;
  settings['removeReadLaterOnComplete'] = false;
  settings['enableCustomImageProcessing'] = false;
  settings['cropWhiteBorders'] = false;
  settings['splitDualPage'] = false;
  settings['showSystemStatusBar'] = true;
  settings['webdav'] = [];
  final localRoot = await Directory(
    '${App.dataPath}/local',
  ).create(recursive: true);
  await File('${App.dataPath}/local_path').writeAsString(localRoot.path);
  final directory = await Directory(
    '${localRoot.path}/fixture/one',
  ).create(recursive: true);
  if (!await File('${directory.path}/512.png').exists()) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(Colors.indigo.shade50, BlendMode.src);
    for (var row = 0; row < 12; row++) {
      canvas.drawRect(
        Rect.fromLTWH(64, 64 + row * 240, 1920, 160),
        Paint()..color = row.isEven ? Colors.indigo : Colors.teal,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(2048, 3072);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    for (var page = 1; page <= 512; page++) {
      await File('${directory.path}/$page.png').writeAsBytes(bytes);
    }
    image.dispose();
    picture.dispose();
  }
  final local = LocalManager(initializeSources: () async {});
  final favorites = LocalFavoritesManager.independent();
  final historyStore = HistoryManager.create();
  final imageFavorites = ImageFavoriteManager.create(history: historyStore);
  await local.init();
  await favorites.init();
  await historyStore.init();
  final chapters = ComicChapters({'one': 'Generated'});
  final comic = LocalComic(
    id: 'reader-benchmark-fixture',
    title: 'Generated reader benchmark',
    subtitle: 'Local 2048 x 3072 shapes',
    tags: const [],
    directory: 'fixture',
    chapters: chapters,
    cover: 'one/1.png',
    comicType: ComicType.local,
    downloadedChapters: const ['one'],
    createdAt: DateTime(2026),
  );
  await local.add(comic);
  final history = History.fromModel(model: comic, ep: 1, page: 160);
  final key = GlobalKey<ReaderState>();
  runApp(
    FavoritesScope(
      manager: favorites,
      child: HistoryScope(
        manager: historyStore,
        imageFavorites: imageFavorites,
        child: MaterialApp(
          navigatorKey: appNavigation.rootNavigatorKey,
          builder: (context, child) => WindowFrame(
            ReaderPlatformEffectsScope(child: OverlayWidget(child!)),
          ),
          home: Reader(
            key: key,
            type: ComicType.local,
            cid: comic.id,
            name: comic.title,
            chapters: chapters,
            history: history,
            initialPage: 160,
            author: comic.subtitle,
            tags: const [],
            onClosed: () {},
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 4));
  await ReaderPerfProbe.init(
    directory: App.externalStoragePath!,
    state: () => {
      'page': key.currentState?.page,
      'pending': key.currentState?.controller.state.pendingPage,
      'pageCount': key.currentState?.maxPage,
      'refreshHz': key.currentContext == null
          ? null
          : View.of(key.currentContext!).display.refreshRate,
    },
    command: (command, args) async {
      if (command == 'position') {
        key.currentState!.toPage(args['page'] as int, animated: false);
      } else if (command == 'pressure') {
        WidgetsBinding.instance.handleMemoryPressure();
      }
    },
  );
}
