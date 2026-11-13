import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// Synthetic synchronous byte preparation only: no network, disk, decoder,
// frame timing, process/GPU memory measurement or private images.
Uint8List before(List<Uint8List> chunks) {
  final received = <int>[];
  for (final chunk in chunks) {
    received.addAll(chunk);
  }
  final encoded = Uint8List.fromList(received);
  final snapshot = List<int>.of(encoded);
  return Uint8List.fromList(snapshot);
}

Uint8List after(List<Uint8List> chunks) {
  final received = BytesBuilder();
  for (final chunk in chunks) {
    received.add(chunk);
  }
  final encoded = received.takeBytes();
  return Uint8List.fromList(encoded);
}

int median(List<int> values) => (values.toList()..sort())[values.length ~/ 2];

Future<void> main() async {
  final groups = <Map<String, Object>>[];
  for (final size in [1 << 20, 4 << 20]) {
    final input = Uint8List(size);
    for (var i = 0; i < size; i++) {
      input[i] = i & 255;
    }
    final chunks = [
      for (var start = 0; start < size; start += 64 << 10)
        Uint8List.sublistView(input, start, start + (64 << 10)),
    ];
    final samples = {'before': <int>[], 'after': <int>[]};
    for (var run = 0; run < 9; run++) {
      for (final name
          in run.isEven ? ['before', 'after'] : ['after', 'before']) {
        await Future<void>.delayed(Duration.zero);
        final clock = Stopwatch()..start();
        final bytes = name == 'before' ? before(chunks) : after(chunks);
        clock.stop();
        if (bytes.length != input.length) throw StateError('Length changed');
        for (var i = 0; i < size; i++) {
          if (bytes[i] != input[i]) throw StateError('Byte changed at $i');
        }
        if (run >= 2) samples[name]!.add(clock.elapsedMicroseconds);
      }
    }
    groups.add({
      'encodedBytes': size,
      'chunkBytes': 64 << 10,
      'samplesAfterWarmup': 7,
      'beforeP50Us': median(samples['before']!),
      'afterP50Us': median(samples['after']!),
    });
  }
  print(
    jsonEncode({'kind': 'host-synchronous-byte-preparation', 'groups': groups}),
  );
}
