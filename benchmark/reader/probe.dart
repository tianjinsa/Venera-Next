// Copied into exported benchmark sources, never imported by the normal app.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Identical observer for both applications. No timers or forced frames while
/// idle. Bounded numeric records exclude paths, subscription tokens and titles.
class ReaderPerfProbe {
  static const channel = MethodChannel('reader/benchmark');
  static const maxEvents = 30000;
  static bool recording = false;
  static final events = <List<Object?>>[];
  static final frames = <List<int>>[];
  static int dropped = 0, started = 0, stopped = 0;
  static Timer? _deadline;
  static String _directory = '', _name = '';
  static Map<String, Object?> Function()? _state;
  static Future<void> Function(String, Map<dynamic, dynamic>)? _command;
  static Map<String, Object?> before = {};
  static Map<String, Object?> clock = {};
  static bool _finishing = false;

  static void event(String name, [List<Object?> values = const []]) {
    if (!recording) return;
    if (events.length >= maxEvents) {
      dropped++;
      return;
    }
    events.add([developer.Timeline.now, name, ...values]);
    if (kProfileMode) {
      developer.Timeline.instantSync(
        'Reader.$name',
        arguments: {'v': '$values'},
      );
    }
  }

  static Map<String, Object?> memory() {
    final cache = PaintingBinding.instance.imageCache;
    return {
      'rssBytes': ProcessInfo.currentRss,
      'cacheBytes': cache.currentSizeBytes,
      'cacheLimitBytes': cache.maximumSizeBytes,
      'cacheImages': cache.currentSize,
      'liveImages': cache.liveImageCount,
      'pendingImages': cache.pendingImageCount,
      ...?_state?.call(),
    };
  }

  static void _timings(List<FrameTiming> timings) {
    for (final frame in timings) {
      final vsync = frame.timestampInMicroseconds(FramePhase.vsyncStart);
      if (vsync < started || (stopped > 0 && vsync > stopped)) continue;
      if (frames.length >= 10000) continue;
      frames.add([
        vsync,
        frame.timestampInMicroseconds(FramePhase.buildStart),
        frame.timestampInMicroseconds(FramePhase.buildFinish),
        frame.timestampInMicroseconds(FramePhase.rasterStart),
        frame.timestampInMicroseconds(FramePhase.rasterFinish),
      ]);
    }
  }

  static Future<void> init({
    required String directory,
    required Map<String, Object?> Function() state,
    required Future<void> Function(String, Map<dynamic, dynamic>) command,
  }) async {
    _directory = '$directory/reader-bench';
    await Directory(_directory).create(recursive: true);
    _state = state;
    _command = command;
    // Native monotonic and Dart timeline clock calibration. Keep all RTTs so
    // downstream analysis can report uncertainty, rather than assume equality.
    final calibration = <Map<String, Object?>>[];
    for (var i = 0; i < 8; i++) {
      final begin = developer.Timeline.now;
      final native = await channel.invokeMapMethod<String, Object?>('clock');
      final end = developer.Timeline.now;
      calibration.add({'dartBeginUs': begin, 'dartEndUs': end, ...?native});
    }
    clock = {'calibration': calibration};
    channel.setMethodCallHandler((call) async {
      if (call.method != 'command') return;
      final args = call.arguments as Map;
      final command = args['command'] as String? ?? 'ping';
      try {
        switch (command) {
          case 'capture':
            await start(args['name'] as String, args['seconds'] as int? ?? 12);
          case 'stop':
            await stop();
          default:
            await _command!(command, args);
        }
        await status(command);
      } catch (error, stack) {
        await File('$_directory/error.txt').writeAsString('$error\n$stack');
        rethrow;
      }
    });
    await status('ready');
  }

  static Future<void> status(String command) async {
    await File('$_directory/status.json').writeAsString(
      jsonEncode({
        'command': command,
        'recording': recording,
        'finishing': _finishing,
        'timelineUs': developer.Timeline.now,
        ...memory(),
      }),
    );
  }

  static Future<void> start(String name, int seconds) async {
    if (recording || _finishing) throw StateError('Capture is busy');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(name)) {
      throw ArgumentError('Invalid capture name');
    }
    if (seconds < 1 || seconds > 45) throw ArgumentError('1..45 seconds');
    _name = name;
    events.clear();
    frames.clear();
    dropped = 0;
    stopped = 0;
    before = memory();
    await channel.invokeMethod<void>('capture');
    started = developer.Timeline.now;
    recording = true;
    SchedulerBinding.instance.addTimingsCallback(_timings);
    event('captureStart');
    _deadline = Timer(Duration(seconds: seconds), () => unawaited(stop()));
  }

  static Future<void> stop() async {
    if (!recording) return;
    event('captureStop');
    stopped = developer.Timeline.now;
    recording = false;
    _finishing = true;
    _deadline?.cancel();
    final after = memory();
    final native = await channel.invokeMapMethod<String, Object?>('stop');
    // Release delivers timings in batches. Wait for delivery but filter on the
    // actual vsync timestamp. This wait is excluded from the measurement window.
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    final report = {
      'schema': 1,
      'name': _name,
      'mode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'startedUs': started,
      'stoppedUs': stopped,
      'frameColumns': [
        'vsyncStart',
        'buildStart',
        'buildFinish',
        'rasterStart',
        'rasterFinish',
      ],
      'frames': frames,
      'events': events,
      'droppedEvents': dropped,
      'before': before,
      'after': after,
      'native': native,
      ...clock,
    };
    await File('$_directory/$_name.json').writeAsString(jsonEncode(report));
    _finishing = false;
    await status('saved');
  }
}
