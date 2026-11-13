import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Budget and memory-pressure lifetime for one reader. Late platform replies
/// and delayed exit work cannot change a newer reader's cache.
class ReaderImageCachePolicy {
  ReaderImageCachePolicy({
    required this.readAvailableMemory,
    required this.setLimit,
    required this.onError,
    this.onConfigured,
    this.maximumBytes,
  }) : _session = ++_currentSession {
    _restore?.cancel();
    _restore = null;
    _activeUnderPressure = false;
    _limit = _activeBudget;
    _updatePrecachePermission();
  }

  static const defaultLimit = 100 << 20;
  static int limitForMemory(int availableBytes) =>
      (availableBytes ~/ 16).clamp(32 << 20, 192 << 20);
  static int _currentSession = 0;
  static Timer? _restore;
  static bool _activeUnderPressure = false;
  static int _activeBudget = defaultLimit;
  static final _precacheAllowed = ValueNotifier(true);
  static ValueListenable<bool> get precacheAllowed => _precacheAllowed;
  static bool get allowActivePrecache => _precacheAllowed.value;

  static void _updatePrecachePermission() {
    _precacheAllowed.value = !_activeUnderPressure && _activeBudget >= 64 << 20;
  }

  final Future<int?> Function() readAvailableMemory;
  final void Function(int bytes) setLimit;
  final void Function(Object, StackTrace) onError;
  final void Function(int availableBytes, int limit)? onConfigured;
  final int? Function()? maximumBytes;
  final int _session;
  int _generation = 0;
  bool _disposed = false;
  bool _underPressure = false;
  int _limit = defaultLimit;
  bool get _current => !_disposed && _session == _currentSession;

  void _setLimit(int value) {
    _limit = value;
    _activeBudget = value;
    setLimit(value);
    _updatePrecachePermission();
  }

  Future<void> configure() async {
    if (!_current) return;
    final generation = ++_generation;
    try {
      final ceiling = maximumBytes?.call();
      if (ceiling != null) {
        _setLimit(_underPressure ? math.min(ceiling, 32 << 20) : ceiling);
      }
      final memory = await readAvailableMemory();
      if (!_current ||
          generation != _generation ||
          _underPressure ||
          memory == null ||
          memory <= 0) {
        return;
      }
      final detected = limitForMemory(memory);
      final limit = ceiling == null ? detected : math.min(ceiling, detected);
      _setLimit(limit);
      onConfigured?.call(memory, limit);
    } catch (error, stack) {
      if (_current && generation == _generation) onError(error, stack);
    }
  }

  void handleMemoryPressure() {
    if (!_current) return;
    _underPressure = true;
    _activeUnderPressure = true;
    _setLimit(math.min(_limit, 32 << 20));
  }

  void dispose() {
    if (!_current) {
      _disposed = true;
      return;
    }
    _disposed = true;
    ++_generation;
    // Let the closing frame and a quick re-entry reuse decoded images.
    _restore = Timer(const Duration(seconds: 1), () {
      _restore = null;
      if (_session != _currentSession) return;
      _setLimit(math.min(_limit, defaultLimit));
    });
  }
}
