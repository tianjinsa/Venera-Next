import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:venera_next/features/reader/display_image_provider.dart';
import 'package:venera_next/features/reader/gallery_data.dart';
import 'package:venera_next/features/reader/gallery_view.dart';
import 'package:venera_next/features/reader/image_cache_policy.dart';
import 'package:venera_next/features/reader/page_layout.dart';
import 'package:venera_next/features/reader/reader_controller.dart';
import 'package:venera_next/features/reader/reader_viewport.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class _Read {
  final bytes = Completer<Uint8List>();
  final checks = <VoidCallback>[];
  int loads = 0;
  void complete() {
    if (!bytes.isCompleted) bytes.complete(_png);
  }
}

class _Provider extends ReaderImageProvider {
  _Provider(ReaderImageProvider source, this.read)
    : super(
        source.imageKey,
        source.sourceKey,
        source.cid,
        source.eid,
        source.page,
        diagnostics: source.diagnostics,
        decodePixelBudget: source.decodePixelBudget,
      );
  final _Read read;
  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    read.loads++;
    read.checks.add(checkStop);
    final bytes = await read.bytes.future;
    checkStop();
    return bytes;
  }
}

// Control only source completion. Keep the real provider keys, decoder,
// cancellable native completer, display relay, PhotoView and PageView paths.
class _Cache extends ImageCache {
  final reads = <String, _Read>{};
  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) => super.putIfAbsent(key, () {
    if (key is! ReaderImageProvider) return loader();
    final provider = _Provider(key, reads.putIfAbsent(key.imageKey, _Read.new));
    return provider.loadImage(
      provider,
      PaintingBinding.instance.instantiateImageCodecWithSize,
    );
  }, onError: onError);
}

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _Cache();
}

void main() {
  final cache = _Binding().imageCache as _Cache;

  testWidgets(
    'gallery traces drag, settling and idle without consuming scroll',
    (tester) async {
      final diagnostics = ReaderDiagnostics(
        attachTimings: (_) {},
        detachTimings: (_) {},
      );
      final fixture = _Fixture(cache, 'ltr', diagnostics: diagnostics);
      try {
        await fixture.mount(tester);
        fixture.completeAll();
        await fixture.flush(tester, () => cache.pendingImageCount == 0);
        diagnostics.start(
          mode: ReaderDiagnosticMode.paged,
          processingEnabled: false,
          appVersion: '1.18.4-rc.1+250',
          refreshRate: 120,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        // Match real input's small first movement so PageView wins the arena
        // before PhotoView can interpret a large first event as an image pan.
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(-220, 0));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await fixture.flush(tester, () => cache.pendingImageCount == 0);
        await tester.pumpAndSettle();
        expect(fixture.navigation.state.page, 2);
        diagnostics.stop(ReaderDiagnosticStop.review);
        final data =
            jsonDecode(diagnostics.exportJson()) as Map<String, dynamic>;
        expect(
          (data['scrollFrameSamples']['phases'] as List).map((e) => e['phase']),
          ['drag', 'settle', 'idle'],
        );
      } finally {
        await fixture.dispose(tester);
        diagnostics.dispose();
      }
    },
  );

  for (final direction in ['ltr', 'rtl', 'vertical']) {
    testWidgets(
      'warms the next $direction window after the frame before selection',
      (tester) async {
        final fixture = _Fixture(cache, direction);
        try {
          await fixture.mount(tester);
          expect(fixture.read(2).loads, 1);
          expect(fixture.read(3).loads, 0);
          final position = fixture.gallery.controller.position;
          final origin = position.pixels;
          position.jumpTo(position.pixels + position.viewportDimension * .1);
          expect(fixture.navigation.state.page, 1);
          expect(fixture.read(3).loads, 0);
          await tester.pump();
          expect(fixture.navigation.state.page, 1);
          expect(fixture.read(3).loads, 1);
          position.jumpTo(origin + position.viewportDimension * .6);
          expect(fixture.navigation.state.page, 2);
          expect(fixture.read(3).loads, 1);
          await tester.pump();
          expect(fixture.read(3).loads, 1);
          expect(fixture.read(2).loads, 1);
        } finally {
          await fixture.dispose(tester);
        }
      },
    );

    testWidgets('an animated $direction command warms before selected', (
      tester,
    ) async {
      final fixture = _Fixture(cache, direction);
      try {
        await fixture.mount(tester);
        expect(fixture.navigation.toPage(2), isTrue);
        expect(fixture.navigation.state.page, 1);
        expect(fixture.navigation.state.pendingPage, 2);
        expect(fixture.read(3).loads, 0);
        await tester.pump();
        expect(fixture.navigation.state.page, 1);
        expect(fixture.read(3).loads, 1);
        // A second legal request interrupts the animation and moves forward;
        // the already-running next image load must survive that handoff.
        expect(fixture.navigation.toPage(3), isTrue);
        await tester.pump();
        expect(fixture.navigation.state.page, 3);
        expect(fixture.read(3).loads, 1);
      } finally {
        await fixture.dispose(tester);
      }
    });

    testWidgets('same-frame $direction commands only warm the final window', (
      tester,
    ) async {
      final fixture = _Fixture(cache, direction);
      try {
        await fixture.mount(tester);
        fixture.gallery.toPage(3);
        fixture.gallery.toPage(6);
        expect(fixture.navigation.state.page, 6);
        expect(fixture.read(4).loads, 0);
        expect(fixture.read(7).loads, 0);
        await tester.pump();
        expect(fixture.read(4).loads, 0);
        expect(fixture.read(6).loads, 1);
        expect(fixture.read(7).loads, 1);
      } finally {
        await fixture.dispose(tester);
      }
    });

    testWidgets('retired $direction gallery does not run its queued window', (
      tester,
    ) async {
      final fixture = _Fixture(cache, direction);
      try {
        await fixture.mount(tester);
        fixture.gallery.toPage(6);
        await tester.pumpWidget(const SizedBox());
        expect(fixture.read(5).loads, 0);
        expect(fixture.read(7).loads, 0);
      } finally {
        await fixture.dispose(tester);
      }
    });

    testWidgets(
      'incoming $direction preload survives selection and is reused',
      (tester) async {
        final fixture = _Fixture(cache, direction);
        try {
          await fixture.mount(tester);
          fixture.read(1).complete();
          await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
          final incoming = fixture.provider(2);
          final original = cache.putIfAbsent(
            incoming,
            () => throw StateError('pending'),
          );
          expect(cache.statusForKey(incoming).pending, isTrue);
          fixture.gallery.toPage(2);
          await tester.pump();
          // The old window must not evict/cancel the incoming native load even
          // when PageView has not had a chance to attach its display consumer.
          expect(cache.statusForKey(incoming).pending, isTrue);
          expect(
            cache.putIfAbsent(incoming, () => throw StateError('pending')),
            same(original),
          );
          expect(fixture.read(2).loads, 1);
          fixture.read(2).complete();
          await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
          expect(fixture.read(2).loads, 1);
          expect(cache.statusForKey(incoming).keepAlive, isTrue);
          fixture.gallery.toPage(1);
          await tester.pump();
          await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
          expect(fixture.read(1).loads, 1);
        } finally {
          await fixture.dispose(tester);
        }
      },
    );

    testWidgets(
      'selection retains existing $direction photo widgets and controllers',
      (tester) async {
        final fixture = _Fixture(cache, direction);
        try {
          await fixture.mount(tester);
          fixture.completeAll();
          await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
          final turning = fixture.gallery.animateToPage(2);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          final photo = tester.widget<PhotoView>(fixture.photo(1));
          final controller = fixture.gallery.photoViewControllers[1];
          await tester.pump(const Duration(milliseconds: 95));
          expect(fixture.navigation.state.page, 2);
          expect(tester.widget<PhotoView>(fixture.photo(1)), same(photo));
          expect(fixture.gallery.photoViewControllers[1], same(controller));
          await tester.pumpAndSettle();
          await turning;
        } finally {
          await fixture.dispose(tester);
        }
      },
    );

    testWidgets('touch drag can cancel and complete a $direction turn', (
      tester,
    ) async {
      final fixture = _Fixture(cache, direction);
      try {
        await fixture.mount(tester);
        fixture.completeAll();
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        await fixture.flush(
          tester,
          () => cache.statusForKey(fixture.provider(2)).keepAlive,
        );
        final delta = direction == 'vertical'
            ? const Offset(0, -100)
            : Offset(direction == 'rtl' ? 65 : -65, 0);
        // Let PageView cross its drag threshold before a large move can also
        // cross PhotoView's pan threshold in the same pointer event.
        final slop = direction == 'vertical'
            ? const Offset(0, -20)
            : Offset(direction == 'rtl' ? 20 : -20, 0);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await gesture.moveBy(slop);
        await tester.pump();
        await gesture.moveBy(delta - slop);
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(fixture.navigation.state.page, 1);
        final completing = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await completing.moveBy(slop);
        await tester.pump();
        await completing.moveBy(delta * 4 - slop);
        await tester.pump(const Duration(milliseconds: 200));
        await completing.moveBy(Offset.zero);
        await tester.pump(const Duration(milliseconds: 200));
        await completing.up();
        await tester.pumpAndSettle();
        expect(fixture.navigation.state.page, 2);
        expect(fixture.read(2).loads, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.dispose(tester);
      }
    });
  }

  for (final count in [2, 3]) {
    testWidgets(
      '$count-image cover layout warms both neighbours and comments return',
      (tester) async {
        final fixture = _Fixture(
          cache,
          'rtl',
          imagesPerPage: count,
          initialPage: 2,
        );
        try {
          await fixture.mount(tester);
          fixture.completeAll();
          final neighbours = [
            for (final page in [1, 3]) ...fixture.providers(page),
          ];
          await fixture.flush(
            tester,
            () => neighbours.every((p) => cache.statusForKey(p).keepAlive),
          );
          for (final provider in neighbours) {
            expect(cache.reads[provider.imageKey]!.loads, 1);
          }
          fixture.gallery.toPage(fixture.data.totalPages);
          await tester.pumpAndSettle();
          expect(find.text('Comments'), findsOneWidget);
          final last = fixture.data.totalPages - 1;
          await fixture.flush(
            tester,
            () => fixture
                .providers(last)
                .every((p) => cache.statusForKey(p).keepAlive),
          );
          fixture.gallery.toPage(last);
          await tester.pumpAndSettle();
          expect(fixture.navigation.state.page, last);
          expect(tester.takeException(), isNull);
        } finally {
          await fixture.dispose(tester);
        }
      },
    );
  }

  testWidgets(
    'partial drag cancellation and repeated direction changes share work',
    (tester) async {
      final fixture = _Fixture(cache, 'ltr', initialPage: 3);
      try {
        await fixture.mount(tester);
        fixture.completeAll();
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        final position = fixture.gallery.controller.position;
        final origin = position.pixels;
        for (var i = 0; i < 20; i++) {
          position.jumpTo(origin + position.viewportDimension * .2);
          position.jumpTo(origin);
          position.jumpTo(origin - position.viewportDimension * .2);
          position.jumpTo(origin);
        }
        await tester.pumpAndSettle();
        expect(fixture.navigation.state.page, 3);
        expect(
          fixture.cache.reads.values
              .where((r) => r.loads > 0)
              .map((r) => r.loads),
          everyElement(1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.dispose(tester);
      }
    },
  );

  testWidgets(
    'memory pressure stops speculation and reversible exit resumes it',
    (tester) async {
      final fixture = _Fixture(cache, 'ltr');
      try {
        await fixture.mount(tester);
        fixture.completeAll();
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        VoidCallback? release;
        final preparing = fixture.work.prepareForExit().then(
          (value) => release = value,
        );
        await fixture.flush(tester, () => release != null);
        await preparing;
        release!();
        fixture.gallery.toPage(2);
        await tester.pump();
        expect(fixture.read(3).loads, 1);
        await fixture.flush(
          tester,
          () => cache.statusForKey(fixture.provider(3)).keepAlive,
        );
        fixture.policy.handleMemoryPressure();
        fixture.gallery.toPage(3);
        await tester.pump();
        expect(fixture.read(4).loads, 0);
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        expect(fixture.read(3).loads, 1);
      } finally {
        await fixture.dispose(tester);
      }
    },
  );

  testWidgets(
    'long navigation keeps the final target window across intermediate pages',
    (tester) async {
      final fixture = _Fixture(cache, 'ltr');
      try {
        await fixture.mount(tester);
        fixture.completeAll();
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        expect(fixture.navigation.toPage(8), isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(fixture.navigation.state.pendingPage, 8);
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        expect(fixture.navigation.state.page, 8);
        expect(fixture.read(8).loads, 1);
        await fixture.flush(
          tester,
          () => cache.statusForKey(fixture.provider(9)).keepAlive,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.dispose(tester);
      }
    },
  );

  testWidgets(
    'chapter replacement cancels old loads and releases their native work',
    (tester) async {
      final fixture = _Fixture(cache, 'ltr');
      try {
        await fixture.mount(tester);
        final previous = fixture.read(2);
        final oldProvider = fixture.provider(2);
        expect(previous.loads, 1);
        await fixture.replaceChapter(tester);
        await tester.pump();
        await tester.runAsync(() => pumpEventQueue());
        for (final check in previous.checks) {
          expect(check, throwsA(isA<Exception>()));
        }
        fixture.completeAll();
        await fixture.flush(tester, () => fixture.gallery.autoReadingReady);
        await fixture.flush(
          tester,
          () => cache.statusForKey(fixture.provider(2)).keepAlive,
        );
        expect(cache.statusForKey(oldProvider).keepAlive, isFalse);
        expect(previous.loads, 1);
        expect(fixture.read(2).loads, 1);
      } finally {
        await fixture.dispose(tester);
      }
    },
  );
}

class _Fixture {
  _Fixture(
    this.cache,
    this.direction, {
    this.imagesPerPage = 1,
    this.initialPage = 1,
    ReaderDiagnostics? diagnostics,
  }) : work = ImageWork(diagnostics: diagnostics);
  final _Cache cache;
  final String direction;
  final int imagesPerPage, initialPage;
  final ImageWork work;
  final binding = ReaderViewportBinding();
  final key = GlobalKey<GalleryModeState>();
  final size = const Size(300, 450);
  late ReaderGalleryData data;
  String _prefix = 'page', _chapter = 'chapter';
  late final policy = ReaderImageCachePolicy(
    readAvailableMemory: () async => 2 << 30,
    setLimit: (bytes) => cache.maximumSizeBytes = bytes,
    onError: (error, _) => fail('$error'),
  );
  late final navigation = ReaderController(
    pageCount: () => data.totalPages,
    chapterCount: () => 1,
    animationEnabled: () => true,
    viewport: () => binding.current,
    onChanged: () {},
    onPageChanged: () {},
    onError: (error, stack) => fail('$error'),
  );
  GalleryModeState get gallery => key.currentState!;
  _Read read(int page) => cache.reads.putIfAbsent('$_prefix-$page', _Read.new);
  ReaderImageProvider provider(int page) =>
      ReaderImageProvider('$_prefix-$page', null, 'book', _chapter, page);
  Iterable<ReaderImageProvider> providers(int page) sync* {
    final (start, end) = data.layout.imageRange(page, data.images.length);
    for (var i = start; i < end; i++) {
      yield provider(i + 1);
    }
  }

  Finder photo(int page) => find.byWidgetPredicate(
    (widget) =>
        widget is PhotoView &&
        widget.imageProvider is ReaderDisplayImageProvider &&
        (widget.imageProvider as ReaderDisplayImageProvider).imageKey ==
            '$_prefix-$page',
  );

  Future<void> mount(WidgetTester tester) async {
    await policy.configure();
    await tester.binding.setSurfaceSize(size);
    await _chapterWidget(tester, initialPage);
  }

  Future<void> replaceChapter(WidgetTester tester) async {
    _prefix = 'next';
    _chapter = 'next-chapter';
    await _chapterWidget(tester, 1);
  }

  Future<void> _chapterWidget(WidgetTester tester, int page) async {
    final images = List.generate(12, (i) => '$_prefix-${i + 1}');
    for (var i = 1; i <= images.length; i++) {
      read(i);
    }
    navigation.replaceChapterImages(images);
    navigation.restorePage(page);
    data = ReaderGalleryData(
      content: navigation.content,
      layout: ReaderPageLayout(
        imagesPerPage: imagesPerPage,
        singleImageOnFirstPage: true,
      ),
      vertical: direction == 'vertical',
      reverse: direction == 'rtl',
      commentsAtEnd: true,
      firstChapter: true,
      lastChapter: true,
      preloadCount: 1,
      doubleTapCollect: false,
      centerLongPressZoom: false,
      pageAnimation: true,
      sourceKey: null,
      comicId: 'book',
      chapterId: _chapter,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderGalleryView(
          key: key,
          data: data,
          imageWork: work,
          navigation: navigation,
          onViewportChanged: binding.update,
          onReady: () {},
          onPageReported: (_, _) {},
          onChapterChanged: () {},
          onCollectImage: () {},
          readerSize: () => size,
          readImage: (_) async => _png,
          commentsBuilder: (_) => const Text('Comments'),
        ),
      ),
    );
  }

  void completeAll() {
    for (final read in cache.reads.values) {
      read.complete();
    }
  }

  Future<void> flush(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 100 && !ready(); i++) {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump();
    }
    expect(ready(), isTrue);
  }

  Future<void> dispose(WidgetTester tester) async {
    completeAll();
    await tester.pumpWidget(const SizedBox());
    var done = false;
    final closing = work.dispose().whenComplete(() => done = true);
    await flush(tester, () => done);
    await closing;
    navigation.dispose();
    cache.clear();
    cache.clearLiveImages();
    await tester.pump();
    await tester.runAsync(() => pumpEventQueue());
    cache.reads.clear();
    policy.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.binding.setSurfaceSize(null);
    expect(BaseImageProvider.debugActiveLoadCount, 0);
  }
}
