import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/image_cache_policy.dart';
import 'package:venera_next/features/reader/image_precache.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';
import 'package:venera_next/foundation/image_work.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class _Provider extends ReaderImageProvider {
  _Provider(this.bytes) : super('pressure-${_next++}', null, 'book', 'ch', 1);
  static int _next = 0;
  final Future<Uint8List> bytes;
  int loads = 0;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) {
    loads++;
    checkStop();
    return bytes;
  }
}

void main() {
  testWidgets('low memory admits visible images without speculative reads', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache;
    final policy = ReaderImageCachePolicy(
      readAvailableMemory: () async => 256 << 20,
      setLimit: (bytes) => cache.maximumSizeBytes = bytes,
      onError: (error, _) => fail('$error'),
    );
    await policy.configure();
    final work = ImageWork();
    final prefetch = ReaderImagePrecache(work: work);
    final source = _Provider(Future.value(_png));
    prefetch.preload(source, ImageConfiguration.empty);
    expect(source.loads, 0);
    final stream = source.resolve(ImageConfiguration.empty);
    var delivered = false;
    final listener = ImageStreamListener((info, _) {
      info.dispose();
      delivered = true;
    });
    stream.addListener(listener);
    try {
      for (var i = 0; i < 40 && !delivered; i++) {
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump();
      }
      expect(delivered, isTrue);
      expect(source.loads, 1);
      expect(cache.maximumSizeBytes, 32 << 20);
    } finally {
      stream.removeListener(listener);
      await prefetch.dispose();
      await work.dispose();
      cache.clear();
      cache.clearLiveImages();
      policy.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(BaseImageProvider.debugActiveLoadCount, 0);
    }
  });

  testWidgets(
    'pressure cancels queued prefetch while a visible load survives',
    (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      final policy = ReaderImageCachePolicy(
        readAvailableMemory: () async => 2 << 30,
        setLimit: (bytes) => cache.maximumSizeBytes = bytes,
        onError: (error, _) => fail('$error'),
      );
      await policy.configure();
      final work = ImageWork();
      final prefetch = ReaderImagePrecache(work: work);
      final bytes = Completer<Uint8List>();
      final source = _Provider(bytes.future);
      final queued = _Provider(Future.value(_png));
      prefetch.replace([source, queued], ImageConfiguration.empty);
      expect(source.loads, 1);
      expect(queued.loads, 0);
      final stream = source.resolve(ImageConfiguration.empty);
      var delivered = false;
      final listener = ImageStreamListener((info, _) {
        info.dispose();
        delivered = true;
      });
      stream.addListener(listener);
      try {
        policy.handleMemoryPressure();
        bytes.complete(_png);
        for (var i = 0; i < 40 && !delivered; i++) {
          await tester.runAsync(() => pumpEventQueue());
          await tester.pump();
        }
        expect(delivered, isTrue);
        expect(source.loads, 1);
        expect(queued.loads, 0);
        prefetch.preload(queued, ImageConfiguration.empty);
        expect(queued.loads, 0);
        expect(cache.maximumSizeBytes, 32 << 20);
      } finally {
        if (!bytes.isCompleted) bytes.complete(_png);
        stream.removeListener(listener);
        final closing = prefetch.dispose();
        await tester.pump();
        await closing;
        await work.dispose();
        cache.clear();
        cache.clearLiveImages();
        policy.dispose();
        await tester.pump(const Duration(seconds: 1));
        expect(BaseImageProvider.debugActiveLoadCount, 0);
      }
    },
  );
}
