import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/image_provider/image_provider_lifecycle.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';

import 'package:venera_next/foundation/image_work.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';

import 'image_cache_policy.dart';

/// Bounded speculative work, including native cleanup. A window can contain
/// several multi-image pages, but only four requests are admitted at a time.
class ReaderImagePrecache {
  ReaderImagePrecache({required ImageWork work, this.maximumConcurrent = 1})
    : _work = work {
    RangeError.checkValueInInterval(
      maximumConcurrent,
      1,
      2,
      'maximumConcurrent',
    );
    ReaderImageCachePolicy.precacheMode.addListener(_onModeChanged);
  }

  static const maximumPending = 4;
  final int maximumConcurrent;
  bool get _limited =>
      ReaderImageCachePolicy.precacheMode.value == ReaderPrecacheMode.limited;
  int get concurrencyLimit => _limited ? 1 : maximumConcurrent;
  int get _pendingLimit => _limited ? 1 : maximumPending;
  final ImageWork _work;
  final _pending = <ReaderImageProvider, _ReaderPrecacheEntry>{};
  final _active = <_ReaderPrecacheEntry>{};
  final _attempted = <ReaderImageProvider>{};
  List<ReaderImageProvider> _wanted = const [];
  ImageConfiguration _configuration = ImageConfiguration.empty;
  bool _pumping = false;
  Future<void>? _disposal;

  /// Replace the look-ahead window when the viewport/page changes. Stale work
  /// releases only its own subscription; visible consumers retain their load.
  void replace(
    Iterable<ReaderImageProvider> providers,
    ImageConfiguration configuration, {
    Iterable<ReaderImageProvider> retain = const [],
  }) {
    if (_disposal != null) return;
    final wanted = providers.toSet().toList();
    if (!listEquals(wanted, _wanted) || configuration != _configuration) {
      _attempted.clear();
    }
    _wanted = wanted;
    _configuration = configuration;
    final retained = retain.toSet();
    for (final entry in _pending.values.toList()) {
      if (!wanted.contains(entry.provider) &&
          !(_active.contains(entry) && retained.contains(entry.provider))) {
        entry.task.cancel();
      }
    }
    _startNext();
  }

  void preload(ReaderImageProvider provider, ImageConfiguration configuration) {
    if (!ReaderImageCachePolicy.allowActivePrecache ||
        _disposal != null ||
        _pending.containsKey(provider) ||
        _pending.length >= _pendingLimit ||
        PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive) {
      return;
    }
    _enqueue(provider, configuration);
    _startNext();
  }

  bool _enqueue(
    ReaderImageProvider provider,
    ImageConfiguration configuration,
  ) {
    _ReaderPrecacheEntry? entry;
    final task = _work.start(onCancel: () => entry?.release());
    if (task == null) return false;
    entry = _ReaderPrecacheEntry(provider, task, configuration, () {
      if (identical(_pending[provider], entry)) _pending.remove(provider);
      _active.remove(entry);
      if (!task.isCancelled && _wanted.contains(provider)) {
        _attempted.add(provider);
      }
      _startNext();
    }, diagnostics: _work.diagnostics);
    _pending[provider] = entry;
    return true;
  }

  void _startNext() {
    if (_disposal != null ||
        _pumping ||
        !ReaderImageCachePolicy.allowActivePrecache) {
      return;
    }
    _pumping = true;
    try {
      final cache = PaintingBinding.instance.imageCache;
      for (final provider in _wanted) {
        if (_pending.length >= _pendingLimit) break;
        if (_pending.containsKey(provider) ||
            _attempted.contains(provider) ||
            cache.statusForKey(provider).keepAlive) {
          continue;
        }
        if (!_enqueue(provider, _configuration)) break;
      }
      // Use the latest direction's order, rather than old insertion order.
      final ordered = {
        for (final provider in _wanted) ?_pending[provider],
        ..._pending.values,
      };
      for (final entry in ordered) {
        if (_active.length >= concurrencyLimit) break;
        if (entry.task.isCancelled || _active.contains(entry)) continue;
        _active.add(entry);
        entry.resolve();
      }
    } finally {
      _pumping = false;
    }
  }

  void _onModeChanged() {
    if (ReaderImageCachePolicy.precacheMode.value ==
        ReaderPrecacheMode.normal) {
      return;
    }
    // Release the old window. Native cleanup still occupies its slots.
    _wanted = const [];
    _attempted.clear();
    for (final entry in _pending.values.toList()) {
      entry.task.cancel();
    }
  }

  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    ReaderImageCachePolicy.precacheMode.removeListener(_onModeChanged);
    final pending = _pending.values.toList();
    final completion = Completer<void>();
    _disposal = completion.future;
    _wanted = const [];
    _attempted.clear();
    for (final entry in pending) {
      entry.task.cancel();
    }
    completion.complete(
      Future.wait(pending.map((e) => e.task.done)).then((_) {}),
    );
    return completion.future;
  }
}

class _ReaderPrecacheEntry {
  _ReaderPrecacheEntry(
    this.provider,
    this.task,
    this.configuration,
    this.onFinished, {
    ReaderDiagnostics? diagnostics,
  }) : _diagnostics = diagnostics {
    _queued = diagnostics?.beginImageSpan(
      provider.hashCode,
      ReaderDiagnosticStage.precacheQueueWait,
    );
  }

  final ReaderImageProvider provider;
  final ImageWorkTask task;
  final ImageConfiguration configuration;
  final void Function() onFinished;
  final ReaderDiagnostics? _diagnostics;
  ReaderDiagnosticSpan? _queued, _decoding;
  final _reported = Set<Object>.identity();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _initializing = false;
  bool _released = false;
  bool _received = false;

  void _record(Object error, StackTrace stack) {
    if (BaseImageProvider.isCancellation(error) || !_reported.add(error)) {
      return;
    }
    if (error is ImageProviderPreparationFailure) {
      for (final failure in error.failures) {
        _record(failure.error, failure.stack);
      }
      return;
    }
    task.recordFailure(error, stack);
  }

  void resolve() {
    _queued?.finish();
    _decoding = _diagnostics?.beginImageSpan(
      provider.hashCode,
      ReaderDiagnosticStage.precacheWait,
    );
    _initializing = true;
    try {
      final stream = _stream = provider.resolve(configuration);
      final listener = _listener = ImageStreamListener(
        (image, synchronous) {
          _decoding?.finish(
            width: image.image.width,
            height: image.image.height,
          );
          try {
            image.dispose();
          } catch (error, stack) {
            _record(error, stack);
          }
          if (_received) return;
          _received = true;
          // Retain the decoded image for one frame so a visible widget can use it.
          SchedulerBinding.instance.addPostFrameCallback((_) => release());
          SchedulerBinding.instance.ensureVisualUpdate();
        },
        onError: (Object error, StackTrace? stack) {
          if (task.isCancelled || BaseImageProvider.isCleanupFailure(error)) {
            _record(error, stack ?? StackTrace.current);
          }
          release();
        },
      );
      stream.addListener(listener);
    } catch (error, stack) {
      _record(error, stack);
      release();
    } finally {
      _initializing = false;
      if (_released) _releaseNow();
    }
  }

  void release() {
    if (_released) return;
    _queued?.finish(success: false);
    _decoding?.finish(success: false);
    _released = true;
    if (!_initializing) _releaseNow();
  }

  void _releaseNow() {
    final stream = _stream;
    try {
      final cache = PaintingBinding.instance.imageCache;
      if (stream != null && cache.statusForKey(provider).pending) {
        // The synchronous pending branch only reads the existing completer.
        // An old entry must not evict a replacement registered under this key.
        final pending = cache.putIfAbsent(
          provider,
          () => throw StateError('Pending precache stream disappeared'),
        );
        if (identical(pending, stream.completer)) {
          cache.evict(provider, includeLive: false);
        }
      }
    } catch (error, stack) {
      _record(error, stack);
    }
    try {
      final listener = _listener;
      if (stream != null && listener != null) stream.removeListener(listener);
    } catch (error, stack) {
      _record(error, stack);
    }
    unawaited(_finish(stream));
  }

  Future<void> _finish(ImageStream? stream) async {
    try {
      if (stream != null) {
        await BaseImageProvider.waitForReleasedStream(stream);
      }
    } catch (error, stack) {
      _record(error, stack);
    } finally {
      task.finish();
      onFinished();
    }
  }
}
