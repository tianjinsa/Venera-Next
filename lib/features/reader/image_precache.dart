import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:venera_next/foundation/image_provider/base_image_provider.dart';
import 'package:venera_next/foundation/image_provider/image_provider_lifecycle.dart';
import 'package:venera_next/foundation/image_provider/reader_image.dart';

import 'package:venera_next/foundation/image_work.dart';

import 'image_cache_policy.dart';

/// One speculative decode at a time, including native cleanup. Queued requests
/// belong to the reading session and never resolve after cancellation.
class ReaderImagePrecache {
  ReaderImagePrecache({required ImageWork work}) : _work = work {
    ReaderImageCachePolicy.precacheAllowed.addListener(_onPermissionChanged);
  }

  static const maximumPending = 4;
  final ImageWork _work;
  final _pending = <ReaderImageProvider, _ReaderPrecacheEntry>{};
  _ReaderPrecacheEntry? _active;
  Future<void>? _disposal;

  /// Replace the look-ahead window when the viewport/page changes. Stale work
  /// releases only its own subscription; visible consumers retain their load.
  void replace(
    Iterable<ReaderImageProvider> providers,
    ImageConfiguration configuration,
  ) {
    if (_disposal != null) return;
    final wanted = providers.take(maximumPending).toSet();
    for (final entry in _pending.values.toList()) {
      if (!wanted.contains(entry.provider)) entry.task.cancel();
    }
    for (final provider in wanted) {
      preload(provider, configuration);
    }
  }

  void preload(ReaderImageProvider provider, ImageConfiguration configuration) {
    if (!ReaderImageCachePolicy.allowActivePrecache ||
        _disposal != null ||
        _pending.containsKey(provider) ||
        _pending.length >= maximumPending ||
        PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive) {
      return;
    }
    _ReaderPrecacheEntry? entry;
    final task = _work.start(onCancel: () => entry?.release());
    if (task == null) return;
    entry = _ReaderPrecacheEntry(provider, task, configuration, () {
      _pending.remove(provider);
      if (identical(_active, entry)) _active = null;
      _startNext();
    });
    _pending[provider] = entry;
    _startNext();
  }

  void _startNext() {
    if (_disposal != null ||
        _active != null ||
        !ReaderImageCachePolicy.allowActivePrecache) {
      return;
    }
    for (final entry in _pending.values) {
      if (entry.task.isCancelled) continue;
      _active = entry;
      entry.resolve();
      break;
    }
  }

  void _onPermissionChanged() {
    if (ReaderImageCachePolicy.allowActivePrecache) return;
    for (final entry in _pending.values.toList()) {
      entry.task.cancel();
    }
  }

  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    ReaderImageCachePolicy.precacheAllowed.removeListener(_onPermissionChanged);
    final pending = _pending.values.toList();
    final completion = Completer<void>();
    _disposal = completion.future;
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
    this.onFinished,
  );

  final ReaderImageProvider provider;
  final ImageWorkTask task;
  final ImageConfiguration configuration;
  final void Function() onFinished;
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
    _initializing = true;
    try {
      final stream = _stream = provider.resolve(configuration);
      final listener = _listener = ImageStreamListener(
        (image, synchronous) {
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
      onFinished();
      task.finish();
    }
  }
}
