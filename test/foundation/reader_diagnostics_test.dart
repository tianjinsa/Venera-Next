import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/display_image_provider.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';
import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';

FrameTiming _frame(int ui, int raster, {int start = 0}) => FrameTiming(
  vsyncStart: start,
  buildStart: start,
  buildFinish: start + ui,
  rasterStart: start + ui,
  rasterFinish: start + ui + raster,
  rasterFinishWallTime: start + ui + raster,
);

Future<void> _drawFrame() async {
  SchedulerBinding.instance.handleBeginFrame(Duration.zero);
  SchedulerBinding.instance.handleDrawFrame();
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReaderDiagnostics diagnostics;
  late int now, attaches, detaches, clockReads;
  TimingsCallback? frames;
  void start({String version = '1.18.2-rc.4+240'}) => diagnostics.start(
    mode: ReaderDiagnosticMode.continuous,
    processingEnabled: false,
    appVersion: version,
    refreshRate: 120,
  );
  Map<String, dynamic> report() =>
      jsonDecode(diagnostics.exportJson()) as Map<String, dynamic>;
  setUp(() {
    now = attaches = detaches = clockReads = 0;
    frames = null;
    diagnostics = ReaderDiagnostics(
      nowMicros: () {
        clockReads++;
        return now;
      },
      attachTimings: (callback) {
        attaches++;
        frames = callback;
      },
      detachTimings: (callback) {
        expectSync(callback, frames);
        detaches++;
      },
    );
  });
  tearDown(() => diagnostics.dispose());

  test('disabled capture registers no callbacks and reads no clock', () {
    expect(
      diagnostics.beginImageSpan(42, ReaderDiagnosticStage.localRead),
      isNull,
    );
    diagnostics.recordCache(42, pending: false, keepAlive: false, live: false);
    diagnostics.recordPageTurn(
      phase: ReaderDiagnosticPagePhase.requested,
      direction: 1,
      distance: 1,
    );
    diagnostics.recordPrecacheWindow(
      allowed: false,
      candidates: 0,
      concurrencyLimit: 2,
    );
    diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.drag);
    diagnostics.recordNavigation(
      phase: ReaderDiagnosticNavigationPhase.requested,
      page: 160,
      target: 161,
      pendingPage: 161,
      position: 160.25,
    );
    expect(diagnostics.hasCapture, isFalse);
    expect(attaches, 0);
    expect(detaches, 0);
    expect(clockReads, 0);
  });

  test('navigation positions are relative and reset for each capture', () {
    start();
    diagnostics.recordNavigation(
      phase: ReaderDiagnosticNavigationPhase.requested,
      page: 160,
      target: 161,
      pendingPage: 161,
      position: 160.25,
    );
    final event = report()['imageEvents'].single;
    expect(event['pageOffset'], 0);
    expect(event['targetOffset'], 1);
    expect(event['pendingOffset'], 1);
    expect(event['positionOffset'], .25);
    start();
    diagnostics.recordNavigation(
      phase: ReaderDiagnosticNavigationPhase.jumpApplied,
      page: 75,
      target: 75,
      pendingPage: null,
      position: 75,
    );
    expect(report()['imageEvents'].single['positionOffset'], 0);
    expect(
      report()['imageEvents'].single.containsKey('pendingOffset'),
      isFalse,
    );
  });

  test('pressure before capture retains its cause and query evidence', () {
    const budget = ReaderDiagnosticCacheBudget(
      reason: ReaderDiagnosticCacheReason.memoryPressure,
      memoryQuery: ReaderDiagnosticMemoryQuery.available,
      limitBytes: 32 << 20,
      availableBytes: 8 << 30,
      pressureEvents: 1,
      underPressure: true,
      precacheAllowed: false,
    );
    diagnostics.recordCacheBudget(budget);
    expect(clockReads, 0);
    start();
    final data = report();
    expect(data['readerCacheBudgetAtStart'], budget.toJson());
    expect(data['readerCacheBudgetLatest'], budget.toJson());
    expect(data['imageEvents'], isEmpty);
    diagnostics.recordCacheBudget(budget);
    expect(report()['imageEvents'].single['stage'], 'cacheBudget');
    diagnostics.stop(ReaderDiagnosticStop.review);
    const nextBudget = ReaderDiagnosticCacheBudget(
      reason: ReaderDiagnosticCacheReason.availableMemory,
      memoryQuery: ReaderDiagnosticMemoryQuery.available,
      limitBytes: 192 << 20,
      pressureEvents: 0,
      underPressure: false,
      precacheAllowed: true,
    );
    diagnostics.recordCacheBudget(nextBudget);
    expect(report()['readerCacheBudgetLatest'], budget.toJson());
    start();
    expect(report()['readerCacheBudgetAtStart'], nextBudget.toJson());
  });

  test(
    'vsync cadence and slow runs use frame time within drag/settle episodes',
    () {
      now = 1000000;
      start();
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.drag);
      now += 20000;
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.settle);
      now += 60000;
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.idle);
      now += 2000000;
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.drag);
      now += 20000;
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.idle);
      now += 1000000;
      frames!([
        _frame(9000, 1000, start: 1000000),
        _frame(9000, 1000, start: 1008333),
        _frame(1000, 10000, start: 1020000),
        _frame(9000, 1000, start: 1045000),
        _frame(1000, 1000, start: 1070000),
        _frame(9000, 1000, start: 3080000),
        _frame(1000, 1000, start: 3088333),
      ]);
      diagnostics.stop(ReaderDiagnosticStop.review);
      final data = report();
      final scroll = data['scrollFrameSamples'];
      expect(scroll['drag']['ui']['count'], 4);
      expect(scroll['drag']['maxConsecutiveOverBudgetSamples'], 2);
      expect(scroll['drag']['vsyncInterval']['count'], 2);
      expect(scroll['drag']['vsyncInterval']['maxUs'], 8333);
      expect(scroll['settle']['rasterOverBudget'], 1);
      expect(scroll['settle']['uiOverBudget'], 1);
      expect(scroll['settle']['maxConsecutiveOverBudgetSamples'], 2);
      expect(scroll['settle']['vsyncInterval']['maxUs'], 25000);
      expect(scroll['largestVsyncGaps'].first['fromVsyncAtUs'], 20000);
      // The gap between two gestures is not a presentation stall. The original
      // global sample count/slow-frame threshold still includes every frame.
      expect(data['retainedFrameSamples']['ui']['count'], 7);
      expect(data['retainedFrameSamples']['overBudget'], 5);
      expect(data['retainedFrameSamples']['uiOverBudget'], 4);
    },
  );

  test(
    'scroll phases are deduplicated without clocks and have a separate cap',
    () {
      start();
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.drag);
      final before = clockReads;
      diagnostics.recordScrollPhase(ReaderDiagnosticScrollPhase.drag);
      expect(clockReads, before);
      for (var i = 0; i < 110; i++) {
        now++;
        diagnostics.recordScrollPhase(
          i.isEven
              ? ReaderDiagnosticScrollPhase.idle
              : ReaderDiagnosticScrollPhase.drag,
        );
      }
      final data = report();
      expect(data['scrollFrameSamples']['phases'], hasLength(96));
      expect(data['scrollFrameSamples']['droppedPhases'], 15);
      start();
      expect(report()['scrollFrameSamples']['phases'], isEmpty);
    },
  );

  test(
    'precache admission and cache limits are visible without private keys',
    () {
      start();
      diagnostics.recordPrecacheWindow(
        allowed: false,
        candidates: 0,
        concurrencyLimit: 2,
      );
      final data = report();
      expect(data['imageEvents'], [
        {
          'atUs': 0,
          'stage': 'precacheWindow',
          'allowed': false,
          'candidates': 0,
          'concurrencyLimit': 2,
          'budgetBytes': PaintingBinding.instance.imageCache.maximumSizeBytes,
        },
      ]);
      expect(
        data['globalImageCacheBefore']['maximumBytes'],
        PaintingBinding.instance.imageCache.maximumSizeBytes,
      );
    },
  );

  test(
    'batched frame phases share the image clock and preserve legacy columns',
    () {
      now = 1000000;
      start();
      now += 20000;
      diagnostics.recordPageTurn(
        phase: ReaderDiagnosticPagePhase.selected,
        direction: -1,
        distance: 1,
      );
      final image = diagnostics.beginImageSpan(
        7,
        ReaderDiagnosticStage.precacheWait,
      )!;
      now += 50000;
      image.finish();
      now = 2000000;
      frames!([
        _frame(9000, 1000, start: 1020000),
        _frame(1000, 10000, start: 1100000),
        _frame(12000, 1000, start: 990000),
      ]);
      diagnostics.stop(ReaderDiagnosticStop.review);
      final data = report();
      expect(data['schema'], 2);
      final samples = data['retainedFrameSamples'];
      expect(samples['overBudget'], 3);
      expect((samples['slowestColumns'] as List).take(4), [
        'receivedAtUs',
        'uiUs',
        'rasterUs',
        'totalSpanUs',
      ]);
      final rows = samples['slowest'] as List;
      expect(rows.map((row) => row[0]), everyElement(1000000));
      expect(rows.map((row) => row[4]), [-10000, 100000, 20000]);
      expect(rows.last, [
        1000000,
        9000,
        1000,
        10000,
        20000,
        20000,
        29000,
        29000,
        30000,
      ]);
      expect(samples['totalSpan']['maxUs'], 13000);
      final events = data['imageEvents'] as List;
      expect(events.first['atUs'], 20000);
      expect(events.first['direction'], -1);
      expect(events.last['atUs'], 20000);
      expect(events.last['waitUs'], 50000);
    },
  );

  test(
    'spans use session-local image numbers and elapsed waits, not private keys',
    () {
      start();
      final span = diagnostics.beginImageSpan(
        987654321,
        ReaderDiagnosticStage.localRead,
      )!;
      now = 2300;
      span.finish(bytes: 512);
      span.finish(bytes: 999);
      diagnostics.recordCache(
        987654321,
        pending: false,
        keepAlive: true,
        live: true,
      );
      frames!([_frame(6000, 6000), _frame(9000, 1000)]);
      diagnostics.stop(ReaderDiagnosticStop.review);
      final data = report();
      final events = data['imageEvents'] as List;
      expect(events, hasLength(2));
      expect(events[0]['image'], 1);
      expect(events[0]['waitUs'], 2300);
      expect(events[0]['bytes'], 512);
      expect(events[1]['image'], 1);
      expect(data['retainedFrameSamples']['overBudget'], 1);
      expect(data['retainedFrameSamples']['frameBudgetUs'], 8333);
      expect(data['configuration']['appVersion'], '1.18.2-rc.4+240');
      expect(diagnostics.exportJson(), isNot(contains('987654321')));
      expect(detaches, 1);
      expect(data['inFlightStagesAtStop'], 0);
    },
  );

  testWidgets('capture times out once and unregisters the frame callback', (
    tester,
  ) async {
    start();
    await tester.pump(const Duration(seconds: 44));
    expect(diagnostics.isRecording, isTrue);
    now = const Duration(seconds: 45).inMicroseconds;
    await tester.pump(const Duration(seconds: 1));
    expect(diagnostics.isRecording, isFalse);
    expect(report()['stopReason'], 'timeout');
    expect(report()['durationUs'], 45000000);
    expect(detaches, 1);
    frames!([_frame(99999, 99999)]);
    expect(report()['retainedFrameSamples']['ui']['count'], 0);
    await tester.pump(const Duration(seconds: 60));
    expect(detaches, 1);
  });

  test(
    'late work cannot append to a stopped, cleared or replacement capture',
    () {
      start();
      final old = diagnostics.beginImageSpan(
        1,
        ReaderDiagnosticStage.codecInitWait,
      )!;
      diagnostics.stop(ReaderDiagnosticStop.background);
      expect(report()['inFlightStagesAtStop'], 1);
      old.finish();
      expect(report()['imageEvents'], isEmpty);
      start();
      old.finish();
      expect(report()['imageEvents'], isEmpty);
      final pending = diagnostics.beginImageSpan(
        2,
        ReaderDiagnosticStage.firstDecodeWait,
      )!;
      diagnostics.clear();
      pending.finish();
      expect(diagnostics.hasCapture, isFalse);
      expect(report()['imageEvents'], isEmpty);
      expect(detaches, 2);
    },
  );

  test(
    'deadline rejects late samples even before a delayed timer callback',
    () {
      start();
      now = const Duration(seconds: 46).inMicroseconds;
      expect(
        diagnostics.beginImageSpan(1, ReaderDiagnosticStage.localRead),
        isNull,
      );
      expect(diagnostics.isRecording, isFalse);
      expect(report()['durationUs'], 45000000);
      expect(report()['stopReason'], 'timeout');
    },
  );

  test(
    'event, frame and identity buffers are bounded and truncation is explicit',
    () {
      diagnostics.dispose();
      diagnostics = ReaderDiagnostics(
        maxEvents: 3,
        maxFrames: 2,
        maxImages: 2,
        nowMicros: () => now,
        attachTimings: (callback) => frames = callback,
        detachTimings: (_) {},
      );
      start(version: 'https://private.example/account');
      for (var i = 0; i < 5; i++) {
        diagnostics.recordCache(
          i % 2,
          pending: false,
          keepAlive: false,
          live: false,
        );
      }
      diagnostics.recordCache(3, pending: false, keepAlive: false, live: false);
      frames!([_frame(1, 1), _frame(2, 2), _frame(3, 3)]);
      diagnostics.stop(ReaderDiagnosticStop.review);
      final data = report();
      expect(data['imageEvents'], hasLength(3));
      expect(data['droppedEvents'], 2);
      expect(data['droppedFrames'], 1);
      expect(data['ignoredImageLookups'], 1);
      expect(data['retainedFrameSamples']['ui']['count'], 2);
      expect(data['configuration']['appVersion'], 'unknown');
      expect(diagnostics.exportJson(), isNot(contains('private.example')));
    },
  );

  testWidgets('a deadline detected during image build defers UI notification', (
    tester,
  ) async {
    start();
    now = const Duration(seconds: 46).inMicroseconds;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: diagnostics,
              builder: (_, _) => Text('${diagnostics.isRecording}'),
            ),
            Builder(
              builder: (_) {
                diagnostics.recordCache(
                  1,
                  pending: false,
                  keepAlive: false,
                  live: false,
                );
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(diagnostics.isRecording, isFalse);
    expect(find.text('false'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(detaches, 1);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'a full capture stays copyable and explicitly counts omitted details',
    () {
      start();
      for (var i = 0; i < diagnostics.maxEvents; i++) {
        diagnostics
            .beginImageSpan(1, ReaderDiagnosticStage.firstDecodeWait)!
            .finish(
              bytes: 0x7fffffffffffffff,
              width: 0x7fffffffffffffff,
              height: 0x7fffffffffffffff,
            );
        now += 100;
      }
      frames!(
        List.generate(diagnostics.maxFrames, (_) => _frame(50000, 50000)),
      );
      diagnostics.stop(ReaderDiagnosticStop.review);
      final encoded = diagnostics.exportJson();
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      expect(
        encoded.length,
        lessThanOrEqualTo(ReaderDiagnostics.maxReportCharacters),
      );
      expect(data['retainedEventCount'], diagnostics.maxEvents);
      expect(data['omittedEventsForCopy'], greaterThan(0));
      expect(
        (data['imageEvents'] as List).length +
            (data['omittedEventsForCopy'] as int),
        diagnostics.maxEvents,
      );
      expect(
        data['retainedStageSamples']['firstDecodeWait']['count'],
        diagnostics.maxEvents,
      );
      expect(data['droppedEvents'], 0);
      expect(
        data['retainedFrameSamples']['ui']['count'],
        diagnostics.maxFrames,
      );
      expect(data['retainedFrameSamples']['slowest'], hasLength(40));
      expect(
        diagnostics.exportJson(),
        encoded,
        reason: 'preview must not prune retained samples',
      );
      start(version: '1.2.3-${'private' * 100}');
      expect(report()['configuration']['appVersion'], 'unknown');
    },
  );

  test(
    'reader work hold stops sampling without changing work admission rules',
    () async {
      final work = ImageWork(diagnostics: diagnostics);
      start();
      final release = work.holdForExit();
      expect(diagnostics.isRecording, isFalse);
      expect(report()['stopReason'], 'interrupted');
      expect(work.start(), isNull);
      release();
      final task = work.start()!;
      task.finish();
      await work.dispose();
      expect(detaches, 1);
    },
  );

  test(
    'local reader pipeline records read, codec, first decode and cache/display without private data',
    () async {
      final root = Directory.systemTemp.createTempSync('reader-diagnostics-');
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      final file = File('${root.path}/private-comic.png')
        ..writeAsBytesSync(bytes);
      final previous = appdata.settings['enableCustomImageProcessing'];
      appdata.settings['enableCustomImageProcessing'] = false;
      final work = ImageWork(diagnostics: diagnostics);
      final provider = ReaderImageProvider(
        'file://${file.path}',
        'private-source',
        'private-title',
        'private-chapter',
        1,
        diagnostics: diagnostics,
      );
      final plain = ReaderImageProvider(
        'file://${file.path}',
        'private-source',
        'private-title',
        'private-chapter',
        1,
      );
      expect(provider, plain);
      expect(provider.hashCode, plain.hashCode);
      start();
      final stream = ReaderDisplayImageProvider(
        provider,
        work,
      ).resolve(ImageConfiguration.empty);
      final ready = Completer<void>();
      final listener = ImageStreamListener(
        (info, _) {
          info.dispose();
          if (!ready.isCompleted) ready.complete();
        },
        onError: (error, stack) {
          if (!ready.isCompleted) ready.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      ImageStream? cachedStream;
      ImageStreamListener? cachedListener;
      try {
        for (var i = 0; i < 80 && !ready.isCompleted; i++) {
          await pumpEventQueue();
          await _drawFrame();
        }
        await ready.future.timeout(const Duration(seconds: 5));
        diagnostics.stop(ReaderDiagnosticStop.review);
        final events = report()['imageEvents'] as List;
        expect(
          events.map((event) => event['stage']),
          containsAll([
            'cacheLookup',
            'localRead',
            'codecInitWait',
            'firstDecodeWait',
            'displayWait',
          ]),
        );
        expect(
          events
              .where((event) => event['stage'] == 'localRead')
              .single['bytes'],
          bytes.length,
        );
        final encoded = diagnostics.exportJson();
        for (final private in [
          root.path,
          'private-comic',
          'private-source',
          'private-title',
          'private-chapter',
          base64Encode(bytes),
        ]) {
          expect(encoded, isNot(contains(private)));
        }

        expect(
          PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive,
          isTrue,
        );
        start();
        cachedStream = ReaderDisplayImageProvider(
          plain,
          work,
        ).resolve(ImageConfiguration.empty);
        final cachedReady = Completer<void>();
        cachedListener = ImageStreamListener((info, _) {
          info.dispose();
          if (!cachedReady.isCompleted) cachedReady.complete();
        });
        cachedStream.addListener(cachedListener);
        for (var i = 0; i < 80 && !cachedReady.isCompleted; i++) {
          await pumpEventQueue();
          await _drawFrame();
        }
        await cachedReady.future.timeout(const Duration(seconds: 5));
        diagnostics.stop(ReaderDiagnosticStop.review);
        final cachedEvents = report()['imageEvents'] as List;
        expect(
          cachedEvents.map((event) => event['stage']),
          containsAll(['cacheLookup', 'displayWait']),
        );
        expect(
          cachedEvents.map((event) => event['stage']),
          isNot(contains('localRead')),
        );
        expect(
          cachedEvents.map((event) => event['stage']),
          isNot(contains('codecInitWait')),
        );
        final cacheLookup = cachedEvents.singleWhere(
          (event) => event['stage'] == 'cacheLookup',
        );
        expect(cacheLookup['keepAlive'], isTrue);
      } finally {
        stream.removeListener(listener);
        if (cachedListener != null) {
          cachedStream!.removeListener(cachedListener);
        }
        PaintingBinding.instance.imageCache.evict(provider);
        final released = BaseImageProvider.waitForReleasedStream(
          stream,
          waitForCurrentFrame: true,
        );
        final closing = work.dispose();
        await _drawFrame();
        await released;
        await closing;
        PaintingBinding.instance.imageCache.clearLiveImages();
        await _drawFrame();
        appdata.settings['enableCustomImageProcessing'] = previous;
        root.deleteSync(recursive: true);
      }
    },
  );
}
