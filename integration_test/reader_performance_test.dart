import 'dart:async';
import 'dart:convert';
import 'dart:developer' show TimelineTask;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/window_frame.dart';
import 'package:venera_next/features/comic_source/models.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/gallery_view.dart';
import 'package:venera_next/features/reader/platform_effects.dart';
import 'package:venera_next/features/reader/reader_page.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/routing/app_navigation.dart';

/// Device-only probe, using the same 32 generated 2048x3072 pages as Prime.
/// FrameTiming describes produced frames, never actual presentation FPS.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const rtl = bool.fromEnvironment('READER_RTL');
  const imagesPerPage = int.fromEnvironment(
    'READER_IMAGES_PER_PAGE',
    defaultValue: 1,
  );
  const statusInfo = bool.fromEnvironment('READER_STATUS_INFO');

  testWidgets('ordinary pages: gestures, idle, pressure and reader reentry', (
    tester,
  ) async {
    expect(imagesPerPage, inInclusiveRange(1, 3));
    await App.init();
    final root = await Directory(
      App.cachePath,
    ).createTemp('reader-performance-');
    // Never load or edit the installed user's settings/library.
    App.dataPath = App.cachePath = root.path;
    await AppTranslation.init();
    final settings = appdata.settings;
    settings['language'] = 'en-US';
    settings['readerMode'] = rtl ? 'galleryRightToLeft' : 'galleryLeftToRight';
    settings['autoReaderMode'] = false;
    settings['readerScreenPicNumberForLandscape'] = imagesPerPage;
    settings['readerScreenPicNumberForPortrait'] = imagesPerPage;
    settings['showSingleImageOnFirstPage'] = false;
    settings['enablePageAnimation'] = true;
    settings['preloadImageCount'] = 4;
    settings['enableClockAndBatteryInfoInReader'] = statusInfo;
    settings['enableTurnPageByVolumeKey'] = false;
    settings['recordReadingStatistics'] = false;
    settings['removeReadLaterOnComplete'] = false;
    settings['enableCustomImageProcessing'] = false;
    settings['cropWhiteBorders'] = false;
    settings['splitDualPage'] = false;
    settings['showSystemStatusBar'] = true;
    settings['webdav'] = [];
    final localRoot = await Directory('${root.path}/local').create();
    await File('${root.path}/local_path').writeAsString(localRoot.path);
    final directory = await Directory(
      '${localRoot.path}/fixture/one',
    ).create(recursive: true);
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
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    for (var page = 1; page <= 32; page++) {
      await File(
        '${directory.path}/$page.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    }
    image.dispose();
    picture.dispose();

    final local = LocalManager(initializeSources: () async {});
    final favorites = LocalFavoritesManager.independent();
    final historyStore = HistoryManager.create();
    final imageFavorites = ImageFavoriteManager.create(history: historyStore);
    final samples = <Map<String, Object>>[];
    final captures = <String, Object>{};
    binding.reportData = {
      'fixture': {
        'pages': 32,
        'width': 2048,
        'height': 3072,
        'rtl': rtl,
        'imagesPerPage': imagesPerPage,
        'statusInfo': statusInfo,
      },
      'memorySamples': samples,
      'readerDiagnostics': captures,
    };
    final key = GlobalKey<ReaderState>();
    try {
      await local.init();
      await favorites.init();
      await historyStore.init();
      final chapters = ComicChapters({'one': 'Generated'});
      final comic = LocalComic(
        id: 'ordinary-performance-fixture',
        title: 'Ordinary performance fixture',
        subtitle: 'Generated shapes',
        tags: const [],
        directory: 'fixture',
        chapters: chapters,
        cover: 'one/1.png',
        comicType: ComicType.local,
        downloadedChapters: const ['one'],
        createdAt: DateTime(2026),
      );
      await local.add(comic);
      final history = History.fromModel(model: comic, ep: 1, page: 1);
      void sample(String phase) {
        final cache = PaintingBinding.instance.imageCache;
        samples.add({
          'phase': phase,
          'rss': ProcessInfo.currentRss,
          'cacheBytes': cache.currentSizeBytes,
          'cacheLimit': cache.maximumSizeBytes,
          'liveImages': cache.liveImageCount,
          'pendingImages': cache.pendingImageCount,
          'activeImageLoads': BaseImageProvider.debugActiveLoadCount,
        });
      }

      await tester.pumpWidget(
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
              home: Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => unawaited(
                      appNavigation.rootNavigatorKey.currentState!.push(
                        MaterialPageRoute<void>(
                          builder: (_) => Reader(
                            key: key,
                            type: ComicType.local,
                            cid: comic.id,
                            name: comic.title,
                            chapters: chapters,
                            history: history,
                            initialPage: 1,
                            author: comic.subtitle,
                            tags: const [],
                            onClosed: () {},
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Continue test reader'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      sample('before');
      Future<void> enter() async {
        await tester.tap(find.text('Continue test reader'));
        await tester.pumpAndSettle();
        expect(key.currentState?.images, hasLength(32));
        sample('entry');
      }

      Future<void> leave() async {
        final reader = key.currentState!;
        await reader.requestExit();
        await tester.pumpAndSettle();
        await reader.imageWork.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(key.currentState, isNull);
        expect(BaseImageProvider.debugActiveLoadCount, 0);
        expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
        sample('exit');
      }

      Future<void> swipe(bool forward) async {
        final rect = tester.getRect(find.byType(Reader));
        final negative = forward != rtl;
        final start = Offset(
          rect.left + rect.width * (negative ? .8 : .2),
          rect.center.dy,
        );
        final before = key.currentState!.page;
        await tester.flingFrom(
          start,
          Offset(rect.width * (negative ? -.65 : .65), 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(
          key.currentState!.page,
          forward ? greaterThan(before) : lessThan(before),
        );
        sample(forward ? 'forward' : 'reverse');
      }

      Future<void> measure(String name, Future<void> Function() action) async {
        final reader = key.currentState!;
        await binding.watchPerformance(() async {
          reader.readerDiagnostics.start(
            mode: ReaderDiagnosticMode.paged,
            processingEnabled: false,
            appVersion: App.buildVersion,
            refreshRate: View.of(reader.context).display.refreshRate,
          );
          final trace = TimelineTask()..start('Reader $name');
          try {
            await action();
          } finally {
            trace.finish();
          }
        }, reportKey: name);
        reader.readerDiagnostics.stop(ReaderDiagnosticStop.review);
        captures[name] = jsonDecode(reader.readerDiagnostics.exportJson());
      }

      await enter();
      await measure('normal_forward', () async {
        for (var i = 0; i < 6; i++) {
          await swipe(true);
        }
      });
      await measure('normal_reverse', () async {
        for (var i = 0; i < 6; i++) {
          await swipe(false);
        }
      });
      await measure('idle_swipes', () async {
        for (final milliseconds in [1200, 3200, 6200]) {
          await Future<void>.delayed(Duration(milliseconds: milliseconds));
          await swipe(true);
          sample('idle-$milliseconds');
        }
      });
      await measure('cancel_and_reverse', () async {
        final reader = key.currentState!;
        final rect = tester.getRect(find.byType(Reader));
        final before = reader.page;
        final gesture = await tester.startGesture(rect.center);
        final slop = Offset(rtl ? 20 : -20, 0);
        await gesture.moveBy(slop);
        await tester.pump();
        await gesture.moveBy(Offset(rect.width * (rtl ? .2 : -.2), 0) - slop);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await gesture.moveBy(Offset.zero);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(reader.page, before);
        for (var i = 0; i < 3; i++) {
          await swipe(true);
          await swipe(false);
        }
        expect(reader.imageViewController, isA<GalleryModeState>());
      });
      final delivered = Completer<void>();
      tester.binding.channelBuffers.push(
        SystemChannels.system.name,
        SystemChannels.system.codec.encodeMessage({'type': 'memoryPressure'}),
        (_) => delivered.complete(),
      );
      await delivered.future;
      expect(PaintingBinding.instance.imageCache.maximumSizeBytes, 32 << 20);
      sample('pressure');
      await measure('pressure_forward', () async {
        for (var i = 0; i < 6; i++) {
          await swipe(true);
        }
      });
      await measure('pressure_reverse', () async {
        for (var i = 0; i < 6; i++) {
          await swipe(false);
        }
      });
      await leave();
      await binding.watchPerformance(() async {
        for (var i = 0; i < 4; i++) {
          await enter();
          await leave();
        }
      }, reportKey: 'reader_reentry');
      expect(tester.takeException(), isNull);
      print('READER_MEMORY ${jsonEncode(samples)}');
    } finally {
      if (key.currentState != null) {
        await key.currentState!.requestExit();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await AppDataOperations.instance.run(() {});
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      local.dispose();
      favorites.close();
      await historyStore.closeAfterReads();
      imageFavorites.dispose();
      await root.delete(recursive: true);
    }
  });
}
