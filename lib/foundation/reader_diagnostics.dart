import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:math' as math;
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

enum ReaderDiagnosticMode { paged, continuous, waterfall }

enum ReaderDiagnosticStage {
  localRead,
  sourceRead,
  processingWait,
  codecInitWait,
  firstDecodeWait,
  displayWait,
  precacheQueueWait,
  precacheWait,
}

enum ReaderDiagnosticPagePhase { requested, selected }

enum ReaderDiagnosticNavigationPhase {
  requested,
  precacheScheduled,
  precacheStarted,
  animationCompleted,
  jumpApplied,
}

enum ReaderDiagnosticScrollPhase { drag, settle, idle }

enum ReaderDiagnosticCacheReason {
  inherited,
  availableMemory,
  platformCeiling,
  memoryPressure,
  exitShrink,
}

enum ReaderDiagnosticMemoryQuery {
  notQueried,
  pending,
  available,
  unavailable,
  failed,
}

/// Numeric policy evidence only; no platform error messages or device identity.
class ReaderDiagnosticCacheBudget {
  const ReaderDiagnosticCacheBudget({
    required this.reason,
    required this.memoryQuery,
    required this.limitBytes,
    required this.underPressure,
    required this.pressureEvents,
    required this.precacheAllowed,
    this.availableBytes,
    this.ceilingBytes,
  });

  final ReaderDiagnosticCacheReason reason;
  final ReaderDiagnosticMemoryQuery memoryQuery;
  final int limitBytes, pressureEvents;
  final int? availableBytes, ceilingBytes;
  final bool underPressure, precacheAllowed;

  Map<String, Object> toJson() => {
    'reason': reason.name,
    'memoryQuery': memoryQuery.name,
    'limitBytes': limitBytes,
    'underPressure': underPressure,
    'pressureEvents': pressureEvents,
    'precacheAllowed': precacheAllowed,
    'availableBytes': ?availableBytes,
    'ceilingBytes': ?ceilingBytes,
  };
}

enum ReaderDiagnosticStop { timeout, review, background, interrupted, disposed }

/// An opt-in, in-memory capture. Its input API accepts no private text.
/// Durations are elapsed waits, not CPU time or proof of UI-thread blocking.
class ReaderDiagnostics extends ChangeNotifier {
  ReaderDiagnostics({
    int Function()? nowMicros,
    void Function(TimingsCallback)? attachTimings,
    void Function(TimingsCallback)? detachTimings,
    this.maxEvents = 480,
    this.maxFrames = 6000,
    this.maxImages = 256,
  }) : assert(maxEvents > 0 && maxFrames > 0 && maxImages > 0),
       _nowMicros = nowMicros ?? (() => Timeline.now),
       _attachTimings =
           attachTimings ??
           ((callback) =>
               SchedulerBinding.instance.addTimingsCallback(callback)),
       _detachTimings =
           detachTimings ??
           ((callback) =>
               SchedulerBinding.instance.removeTimingsCallback(callback));

  static const captureDuration = Duration(seconds: 45);
  static const maxReportCharacters = 60000;
  static const maxScrollPhases = 96;
  final int maxEvents, maxFrames, maxImages;
  final int Function() _nowMicros;
  final void Function(TimingsCallback) _attachTimings, _detachTimings;
  final _events = ListQueue<Map<String, Object>>();
  final _frames = ListQueue<List<int>>();
  final _scrollPhases = ListQueue<(int, ReaderDiagnosticScrollPhase)>();
  final _imageIds = <int, int>{};
  Timer? _timer;
  int _generation = 0, _startedAt = 0, _duration = 0;
  int? _pageOrigin;
  int _droppedEvents = 0, _droppedFrames = 0, _ignoredImages = 0;
  int _droppedScrollPhases = 0;
  ReaderDiagnosticScrollPhase? _lastScrollPhase;
  int _inFlight = 0, _inFlightAtStop = 0;
  bool _recording = false, _hasCapture = false, _disposed = false;
  double _frameBudgetUs = 1000000 / 60;
  Map<String, Object> _configuration = {};
  Map<String, int> _cacheBefore = {}, _cacheAfter = {};
  ReaderDiagnosticCacheBudget? _cacheBudget;
  Map<String, Object>? _cacheBudgetBefore, _cacheBudgetAfter;
  ReaderDiagnosticStop? _stopReason;
  late final TimingsCallback _onFrames = _recordFrames;

  bool get isRecording => _recording;
  bool get hasCapture => _hasCapture;
  int get _elapsed => math.max(0, _nowMicros() - _startedAt);

  void _notifyChanged() {
    if (_disposed) return;
    // A delayed deadline can be detected while an image resolves during build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  bool _acceptSample() {
    if (_recording && _elapsed >= captureDuration.inMicroseconds) {
      stop(ReaderDiagnosticStop.timeout);
    }
    return _recording;
  }

  static Map<String, int> _cacheSnapshot() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'decodedBytes': cache.currentSizeBytes,
      'keepAliveImages': cache.currentSize,
      'liveImages': cache.liveImageCount,
      'pendingImages': cache.pendingImageCount,
      'maximumBytes': cache.maximumSizeBytes,
      'maximumImages': cache.maximumSize,
    };
  }

  void start({
    required ReaderDiagnosticMode mode,
    required bool processingEnabled,
    required String appVersion,
    required double refreshRate,
  }) {
    if (_disposed) return;
    stop(ReaderDiagnosticStop.interrupted);
    clear(notify: false);
    final hz = refreshRate.isFinite && refreshRate >= 1 && refreshRate <= 1000
        ? refreshRate
        : 60.0;
    _frameBudgetUs = 1000000 / hz;
    _configuration = {
      'appVersion':
          appVersion.length <= 64 &&
              RegExp(
                r'^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?(?:\+\d+)?$',
              ).hasMatch(appVersion)
          ? appVersion
          : 'unknown',
      'platform': defaultTargetPlatform.name,
      'buildMode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'readerMode': mode.name,
      'customProcessingEnabled': processingEnabled,
      'displayRefreshHz': hz,
    };
    _cacheBefore = _cacheSnapshot();
    _cacheBudgetBefore = _cacheBudget?.toJson();
    _startedAt = _nowMicros();
    _recording = _hasCapture = true;
    _attachTimings(_onFrames);
    _timer = Timer(captureDuration, () => stop(ReaderDiagnosticStop.timeout));
    _notifyChanged();
  }

  void stop(ReaderDiagnosticStop reason) {
    if (!_recording) return;
    _duration = math.min(_elapsed, captureDuration.inMicroseconds);
    _recording = false;
    _timer?.cancel();
    _timer = null;
    _detachTimings(_onFrames);
    _cacheAfter = _cacheSnapshot();
    _cacheBudgetAfter = _cacheBudget?.toJson();
    _inFlightAtStop = _inFlight;
    _imageIds.clear();
    _stopReason = reason;
    _notifyChanged();
  }

  void clear({bool notify = true}) {
    if (_recording) stop(ReaderDiagnosticStop.interrupted);
    _generation++;
    _hasCapture = false;
    _events.clear();
    _frames.clear();
    _scrollPhases.clear();
    _lastScrollPhase = null;
    _pageOrigin = null;
    _droppedScrollPhases = 0;
    _imageIds.clear();
    _droppedEvents = _droppedFrames = _ignoredImages = _inFlight =
        _inFlightAtStop = 0;
    _duration = 0;
    _stopReason = null;
    _configuration = {};
    _cacheBefore = {};
    _cacheAfter = {};
    _cacheBudgetBefore = _cacheBudgetAfter = null;
    if (notify) _notifyChanged();
  }

  int? _imageId(int identity) {
    final existing = _imageIds[identity];
    if (existing != null) return existing;
    if (_imageIds.length >= maxImages) {
      _ignoredImages++;
      return null;
    }
    return _imageIds[identity] = _imageIds.length + 1;
  }

  ReaderDiagnosticSpan? beginImageSpan(
    int identity,
    ReaderDiagnosticStage stage,
  ) {
    if (!_acceptSample()) return null;
    final image = _imageId(identity);
    if (image == null) return null;
    _inFlight++;
    return ReaderDiagnosticSpan._(this, _generation, image, stage, _elapsed);
  }

  void recordCache(
    int identity, {
    required bool pending,
    required bool keepAlive,
    required bool live,
  }) {
    if (!_acceptSample()) return;
    final image = _imageId(identity);
    if (image == null) return;
    _append({
      'atUs': _elapsed,
      'image': image,
      'stage': 'cacheLookup',
      'pending': pending,
      'keepAlive': keepAlive,
      'live': live,
    });
  }

  /// Only relative movement is retained, never a chapter or source page ID.
  void recordPageTurn({
    required ReaderDiagnosticPagePhase phase,
    required int direction,
    required int distance,
  }) {
    if (!_acceptSample()) return;
    _append({
      'atUs': _elapsed,
      'stage': 'pageTurn',
      'phase': phase.name,
      'direction': direction.sign,
      'distance': distance.abs(),
    });
  }

  void recordPrecacheWindow({
    required bool allowed,
    required int candidates,
    required int concurrencyLimit,
  }) {
    if (!_acceptSample()) return;
    _append({
      'atUs': _elapsed,
      'stage': 'precacheWindow',
      'allowed': allowed,
      'candidates': candidates,
      'concurrencyLimit': concurrencyLimit,
      'budgetBytes': PaintingBinding.instance.imageCache.maximumSizeBytes,
    });
  }

  /// Capture-relative page coordinates correlate intent, work and handoff
  /// without retaining the reader's absolute chapter/source page numbers.
  void recordNavigation({
    required ReaderDiagnosticNavigationPhase phase,
    required int page,
    required int target,
    required int? pendingPage,
    required double? position,
  }) {
    if (!_acceptSample()) return;
    final origin = _pageOrigin ??= page;
    final event = <String, Object>{
      'atUs': _elapsed,
      'stage': 'navigation',
      'phase': phase.name,
      'pageOffset': page - origin,
      'targetOffset': target - origin,
      if (pendingPage != null) 'pendingOffset': pendingPage - origin,
      if (position != null && position.isFinite)
        'positionOffset': position - origin,
    };
    _append(event);
    if (kProfileMode) {
      Timeline.instantSync('Reader.navigation', arguments: event);
    }
  }

  // Keep the latest decision even outside capture: pressure commonly arrives
  // before the user opens diagnostics. Only capture-relative changes are events.
  void recordCacheBudget(ReaderDiagnosticCacheBudget budget) {
    if (_disposed) return;
    _cacheBudget = budget;
    if (!_acceptSample()) return;
    _append({'atUs': _elapsed, 'stage': 'cacheBudget', ...budget.toJson()});
  }

  void recordScrollPhase(ReaderDiagnosticScrollPhase phase) {
    if (phase == _lastScrollPhase || !_acceptSample()) return;
    _lastScrollPhase = phase;
    if (_scrollPhases.length == maxScrollPhases) {
      _scrollPhases.removeFirst();
      _droppedScrollPhases++;
    }
    _scrollPhases.add((_elapsed, phase));
  }

  void _append(Map<String, Object> event) {
    if (_events.length == maxEvents) {
      _events.removeFirst();
      _droppedEvents++;
    }
    _events.add(event);
  }

  void _recordFrames(List<FrameTiming> timings) {
    if (!_acceptSample()) return;
    final receivedAt = _elapsed;
    for (final frame in timings) {
      if (_frames.length == maxFrames) {
        _frames.removeFirst();
        _droppedFrames++;
      }
      _frames.add([
        receivedAt,
        frame.buildDuration.inMicroseconds,
        frame.rasterDuration.inMicroseconds,
        frame.totalSpan.inMicroseconds,
        // Flutter's native engine uses Dart's timeline clock for TimePoint
        // (DartVMInitializer / DartTimelineTicksSinceEpoch). Subtract the same
        // origin as image spans; never use callback delivery time as frame time.
        // A negative value denotes a batched frame begun before capture.
        for (final phase in const [
          FramePhase.vsyncStart,
          FramePhase.buildStart,
          FramePhase.buildFinish,
          FramePhase.rasterStart,
          FramePhase.rasterFinish,
        ])
          frame.timestampInMicroseconds(phase) - _startedAt,
      ]);
    }
  }

  Map<String, Object> _summary(Iterable<int> source) {
    final values = source.toList()..sort();
    if (values.isEmpty) return {'count': 0};
    return {
      'count': values.length,
      'medianUs': values[values.length ~/ 2],
      'p95Us': values[(values.length * .95).ceil() - 1],
      'maxUs': values.last,
    };
  }

  Map<String, Object> _scrollSummary() {
    final phases = _scrollPhases.toList();
    final frames = _frames.toList()..sort((a, b) => a[4].compareTo(b[4]));
    final until = _recording ? _elapsed : _duration;
    final largestGaps = <Map<String, Object>>[];
    final summaries = <String, Object>{};
    for (final phase in [
      ReaderDiagnosticScrollPhase.drag,
      ReaderDiagnosticScrollPhase.settle,
    ]) {
      final ui = <int>[], raster = <int>[], gaps = <int>[];
      var overUI = 0, overRaster = 0, maxRun = 0;
      for (var i = 0; i < phases.length; i++) {
        final (from, current) = phases[i];
        if (current != phase) continue;
        final to = i + 1 < phases.length ? phases[i + 1].$1 : until;
        int? previous;
        var run = 0;
        for (final frame in frames) {
          final at = frame[4];
          if (at < from || at >= to) continue;
          ui.add(frame[1]);
          raster.add(frame[2]);
          final slowUI = frame[1] > _frameBudgetUs;
          final slowRaster = frame[2] > _frameBudgetUs;
          if (slowUI) overUI++;
          if (slowRaster) overRaster++;
          run = slowUI || slowRaster ? run + 1 : 0;
          maxRun = math.max(run, maxRun);
          if (previous != null && at > previous) {
            final gap = at - previous;
            gaps.add(gap);
            largestGaps.add({
              'phase': phase.name,
              'fromVsyncAtUs': previous,
              'toVsyncAtUs': at,
              'gapUs': gap,
            });
          }
          previous = at;
        }
      }
      summaries[phase.name] = {
        'ui': _summary(ui),
        'raster': _summary(raster),
        'uiOverBudget': overUI,
        'rasterOverBudget': overRaster,
        'maxConsecutiveOverBudgetSamples': maxRun,
        'vsyncInterval': _summary(gaps),
      };
    }
    largestGaps.sort(
      (a, b) => (b['gapUs'] as int).compareTo(a['gapUs'] as int),
    );
    return {
      'measurement':
          'Produced-frame vsync intervals within each scroll notification phase. Drag/settle boundaries are notification times, not exact input or presentation times. Idle gaps and gaps across phase boundaries are excluded only from this auxiliary summary. Global frame statistics retain all samples. Not presented FPS or input-to-display latency.',
      'droppedPhases': _droppedScrollPhases,
      'phases': [
        for (final (at, phase) in phases) {'atUs': at, 'phase': phase.name},
      ],
      ...summaries,
      'largestVsyncGaps': largestGaps.take(12).toList(),
    };
  }

  String exportJson() {
    final slow =
        _frames
            .where(
              (frame) => frame[1] > _frameBudgetUs || frame[2] > _frameBudgetUs,
            )
            .toList()
          ..sort(
            (a, b) => math.max(b[1], b[2]).compareTo(math.max(a[1], a[2])),
          );
    final events = _events.toList();
    final data = <String, Object?>{
      'schema': 2,
      'privacy':
          'No comic content, titles, paths, URLs, accounts, scripts, or error text.',
      'measurement':
          'Elapsed waits are not CPU time or UI-thread blocking. Source reads include encoded cache and source callbacks. Processing wait measures only custom image processing. Frame samples are not measured FPS. Frame phase timestamps and image/page events share the capture-relative Dart timeline clock; negative frame times precede capture. receivedAtUs is batched callback delivery, not frame occurrence. Schema 2 preserves the first four schema 1 frame columns and appends phase times.',
      'configuration': _configuration,
      'durationUs': _recording ? _elapsed : _duration,
      'stopReason': _stopReason?.name,
      'limits': {
        'seconds': captureDuration.inSeconds,
        'events': maxEvents,
        'frames': maxFrames,
        'images': maxImages,
        'scrollPhases': maxScrollPhases,
        'reportCharacters': maxReportCharacters,
      },
      'droppedEvents': _droppedEvents,
      'droppedFrames': _droppedFrames,
      'ignoredImageLookups': _ignoredImages,
      'retainedEventCount': _events.length,
      'omittedEventsForCopy': 0,
      'inFlightStagesAtStop': _inFlightAtStop,
      'globalImageCacheBefore': _cacheBefore,
      'globalImageCacheAfter': _cacheAfter,
      'readerCacheBudgetAtStart': _cacheBudgetBefore,
      'readerCacheBudgetLatest': _recording
          ? _cacheBudget?.toJson()
          : _cacheBudgetAfter,
      'scrollFrameSamples': _scrollSummary(),
      'retainedFrameSamples': {
        'ui': _summary(_frames.map((frame) => frame[1])),
        'raster': _summary(_frames.map((frame) => frame[2])),
        'totalSpan': _summary(_frames.map((frame) => frame[3])),
        'frameBudgetUs': _frameBudgetUs.round(),
        'overBudget': slow.length,
        'uiOverBudget': _frames
            .where((frame) => frame[1] > _frameBudgetUs)
            .length,
        'rasterOverBudget': _frames
            .where((frame) => frame[2] > _frameBudgetUs)
            .length,
        'slowest': slow.take(40).toList(),
        'slowestColumns': [
          'receivedAtUs',
          'uiUs',
          'rasterUs',
          'totalSpanUs',
          'vsyncStartAtUs',
          'buildStartAtUs',
          'buildFinishAtUs',
          'rasterStartAtUs',
          'rasterFinishAtUs',
        ],
      },
      'retainedStageSamples': {
        for (final stage in ReaderDiagnosticStage.values)
          stage.name: _summary(
            _events
                .where((event) => event['stage'] == stage.name)
                .map((event) => event['waitUs'] as int),
          ),
      },
      'imageEvents': events,
    };
    var omitted = 0;
    while (true) {
      data['omittedEventsForCopy'] = omitted;
      final report = const JsonEncoder.withIndent('  ').convert(data);
      if (report.length <= maxReportCharacters || events.isEmpty) return report;
      // Keep copies within an issue comment; preserve the newest event details.
      final remove = math.max(
        1,
        ((report.length - maxReportCharacters) * events.length / report.length)
            .ceil(),
      );
      events.removeRange(0, remove);
      omitted += remove;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop(ReaderDiagnosticStop.disposed);
    clear(notify: false);
    super.dispose();
  }
}

class ReaderDiagnosticSpan {
  ReaderDiagnosticSpan._(
    this._owner,
    this._generation,
    this._image,
    this._stage,
    this._start,
  );
  final ReaderDiagnostics _owner;
  final int _generation, _image, _start;
  final ReaderDiagnosticStage _stage;
  bool _finished = false;

  void finish({bool success = true, int? bytes, int? width, int? height}) {
    if (_finished) return;
    _finished = true;
    if (_generation != _owner._generation || !_owner._acceptSample()) return;
    _owner._inFlight--;
    _owner._append({
      'atUs': _start,
      'image': _image,
      'stage': _stage.name,
      'waitUs': math.max(0, _owner._elapsed - _start),
      'success': success,
      if (bytes != null && bytes >= 0) 'bytes': bytes,
      if (width != null && width > 0) 'width': width,
      if (height != null && height > 0) 'height': height,
    });
  }
}
