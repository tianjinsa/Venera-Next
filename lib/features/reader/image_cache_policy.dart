import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';

/// Budget and memory-pressure lifetime for one reader. Late platform replies
/// and delayed exit work cannot change a newer reader's cache.
class ReaderImageCachePolicy {
  ReaderImageCachePolicy({
    required this.readAvailableMemory,
    required this.setLimit,
    required this.onError,
    this.onConfigured,
    this.maximumBytes,
    this.onChanged,
  }) : _session = ++_currentSession {
    _restore?.cancel();
    _restore = null;
    _activeUnderPressure = false;
    _limit = _activeBudget;
    _updatePrecachePermission();
  }

  static const defaultLimit = 100 << 20;
  static const _step = 32 << 20;
  static const _maximumLimit = 192 << 20;
  static const _memoryDivisor = 16;
  static const _growthHeadroom = 128 << 20;
  static const _sampleInterval = Duration(seconds: 30);
  static const _pressureCooldown = Duration(seconds: 30);

  static int limitForMemory(int availableBytes) =>
      (availableBytes ~/ (_memoryDivisor * _step) * _step).clamp(
        _step,
        _maximumLimit,
      );
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
  final void Function(ReaderDiagnosticCacheBudget)? onChanged;
  final int _session;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;
  bool _configured = false;
  bool _reading = false;
  bool _hasSampledMemory = false;
  bool _underPressure = false;
  bool _coolingDown = false;
  Timer? _nextSample;
  int _limit = defaultLimit;
  int _pressureEvents = 0;
  int? _availableBytes, _ceilingBytes;
  var _reason = ReaderDiagnosticCacheReason.inherited;
  var _memoryQuery = ReaderDiagnosticMemoryQuery.notQueried;
  bool get _current => !_disposed && _session == _currentSession;

  ReaderDiagnosticCacheBudget get snapshot => ReaderDiagnosticCacheBudget(
    reason: _reason,
    memoryQuery: _memoryQuery,
    limitBytes: _limit,
    underPressure: _underPressure,
    pressureEvents: _pressureEvents,
    precacheAllowed: allowActivePrecache,
    availableBytes: _availableBytes,
    ceilingBytes: _ceilingBytes,
  );

  void _setLimit(int value, ReaderDiagnosticCacheReason reason) {
    _limit = value;
    _reason = reason;
    _activeBudget = value;
    setLimit(value);
    _updatePrecachePermission();
    onChanged?.call(snapshot);
  }

  void _cancelSample() {
    _nextSample?.cancel();
    _nextSample = null;
  }

  void _scheduleSample() {
    if (!_current || !_foreground || !_configured || _nextSample != null) {
      return;
    }
    _nextSample = Timer(_coolingDown ? _pressureCooldown : _sampleInterval, () {
      _nextSample = null;
      _coolingDown = false;
      unawaited(configure());
    });
  }

  void setForeground(bool foreground) {
    if (!_current || _foreground == foreground) return;
    _foreground = foreground;
    ++_generation;
    _cancelSample();
    if (_memoryQuery == ReaderDiagnosticMemoryQuery.pending) {
      _memoryQuery = ReaderDiagnosticMemoryQuery.notQueried;
    }
    if (foreground && _configured) unawaited(configure());
  }

  Future<void> configure() async {
    if (!_current) return;
    _configured = true;
    final generation = _generation;
    final previousQuery = _memoryQuery;
    var startedRead = false;
    try {
      final ceiling = maximumBytes?.call();
      _ceilingBytes = ceiling;
      if (ceiling != null && ceiling < _limit) {
        _setLimit(
          ceiling,
          _underPressure
              ? ReaderDiagnosticCacheReason.memoryPressure
              : ReaderDiagnosticCacheReason.platformCeiling,
        );
      }
      if (!_current || !_foreground || _coolingDown || _reading) return;
      _cancelSample();
      _reading = startedRead = true;
      _memoryQuery = ReaderDiagnosticMemoryQuery.pending;
      _availableBytes = null;
      onChanged?.call(snapshot);
      final memory = await readAvailableMemory();
      if (!_current || generation != _generation) return;
      _availableBytes = memory != null && memory > 0 ? memory : null;
      _memoryQuery = _availableBytes == null
          ? ReaderDiagnosticMemoryQuery.unavailable
          : ReaderDiagnosticMemoryQuery.available;
      if (_availableBytes case final int available) {
        _updateLimitForAvailableMemory(available);
      } else {
        onChanged?.call(snapshot);
      }
    } catch (error, stack) {
      if (_current && generation == _generation) {
        _memoryQuery = ReaderDiagnosticMemoryQuery.failed;
        onChanged?.call(snapshot);
        if (previousQuery != ReaderDiagnosticMemoryQuery.failed) {
          onError(error, stack);
        }
      }
    } finally {
      if (startedRead) _reading = false;
      _scheduleSample();
    }
  }

  void _updateLimitForAvailableMemory(int available) {
    final ceiling = _ceilingBytes ?? _maximumLimit;
    final detected = limitForMemory(available);
    final target = math.min(ceiling, detected);
    final wasUnderPressure = _underPressure;
    final initial = !_hasSampledMemory;
    _hasSampledMemory = true;
    final nextTier = math.min(target, (_limit ~/ _step + 1) * _step);

    if (wasUnderPressure) {
      // Recover only once the system can fund the first useful preload tier
      // (or the smaller platform ceiling) with room for fluctuations.
      final recoveryTier = math.min(2 * _step, ceiling);
      if (available < recoveryTier * _memoryDivisor + _growthHeadroom) {
        onChanged?.call(snapshot);
        return;
      }
      _underPressure = _activeUnderPressure = false;
    }

    // Drop to the measured target on a low sample. Growth needs extra headroom
    // and happens one tier at a time after the initial sizing.
    final targetLimit = target <= _limit || (initial && !wasUnderPressure)
        ? target
        : available >= nextTier * _memoryDivisor + _growthHeadroom
        ? nextTier
        : _limit;
    final reason = _ceilingBytes != null && targetLimit == ceiling
        ? ReaderDiagnosticCacheReason.platformCeiling
        : ReaderDiagnosticCacheReason.availableMemory;
    if (targetLimit != _limit || reason != _reason || wasUnderPressure) {
      _setLimit(targetLimit, reason);
      onConfigured?.call(available, targetLimit);
    } else {
      onChanged?.call(snapshot);
    }
  }

  void handleMemoryPressure() {
    if (!_current) return;
    _underPressure = true;
    _coolingDown = true;
    _pressureEvents++;
    _activeUnderPressure = true;
    ++_generation;
    _cancelSample();
    if (_memoryQuery == ReaderDiagnosticMemoryQuery.pending) {
      _memoryQuery = ReaderDiagnosticMemoryQuery.notQueried;
    }
    _setLimit(
      math.min(_limit, _step),
      ReaderDiagnosticCacheReason.memoryPressure,
    );
    _scheduleSample();
  }

  void dispose() {
    _cancelSample();
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
      _setLimit(
        math.min(_limit, defaultLimit),
        ReaderDiagnosticCacheReason.exitShrink,
      );
    });
  }
}
