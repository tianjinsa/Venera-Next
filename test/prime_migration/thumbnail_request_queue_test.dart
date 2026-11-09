import 'dart:async';
import 'dart:typed_data';
import 'package:venera_next/network/request_scope.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/network/thumbnail_request_queue.dart';

void main() {
  test('simultaneous callers share a cover download', () async {
    final queue = ThumbnailRequestQueue();
    final response = Completer<Uint8List>();
    var calls = 0;
    Future<Uint8List> load() {
      calls++;
      return response.future;
    }

    final first = queue.load('cover', load);
    final second = queue.load('cover', load);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    response.complete(Uint8List.fromList([1, 2, 3]));
    expect(await first, [1, 2, 3]);
    expect(await second, [1, 2, 3]);
  });

  test('queued covers respect concurrency and start in order', () async {
    final queue = ThumbnailRequestQueue(maxConcurrent: 2);
    final responses = List.generate(5, (_) => Completer<Uint8List>());
    final started = <int>[];
    final futures = [
      for (var i = 0; i < 5; i++)
        queue.load('$i', () {
          started.add(i);
          return responses[i].future;
        }),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1]);
    for (var i = 0; i < 5; i++) {
      responses[i].complete(Uint8List.fromList([i]));
      await futures[i];
      await Future<void>.delayed(Duration.zero);
      expect(started.length, (i + 3).clamp(0, 5));
    }
  });

  test(
    'failed covers cool down, then recover after connectivity returns',
    () async {
      var now = DateTime(2026);
      final queue = ThumbnailRequestQueue(now: () => now);
      var calls = 0;
      Future<Uint8List> fail() {
        calls++;
        throw StateError('offline');
      }

      await expectLater(queue.load('cover', fail), throwsStateError);
      for (var i = 0; i < 20; i++) {
        await expectLater(queue.load('cover', fail), throwsStateError);
      }
      expect(calls, 1);
      now = now.add(const Duration(seconds: 31));
      expect(
        await queue.load('cover', () async {
          calls++;
          return Uint8List.fromList([7]);
        }),
        [7],
      );
      expect(calls, 2);
    },
  );

  test('failure releases the slot for unrelated covers', () async {
    final queue = ThumbnailRequestQueue(maxConcurrent: 1);
    final failure = expectLater(
      queue.load('broken', () => throw StateError('offline')),
      throwsStateError,
    );
    final success = queue.load('working', () async => Uint8List.fromList([9]));
    await failure;
    expect(await success, [9]);
  });

  test(
    'offscreen queued covers are skipped without blocking later requests',
    () async {
      final queue = ThumbnailRequestQueue(maxConcurrent: 1);
      final first = Completer<Uint8List>();
      final active = queue.load('active', () => first.future);
      var cancelled = false;
      var calls = 0;
      final skipped = expectLater(
        queue.load('offscreen', () async {
          calls++;
          return Uint8List(0);
        }, isCancelled: () => cancelled),
        throwsA(isA<ThumbnailRequestCancelled>()),
      );
      await Future<void>.delayed(Duration.zero);
      cancelled = true;
      first.complete(Uint8List(0));
      await active;
      await skipped;
      expect(calls, 0);
      expect(
        await queue.load('offscreen', () async => Uint8List.fromList([1])),
        [1],
      );
    },
  );

  test('a visible consumer keeps a shared queued cover alive', () async {
    final queue = ThumbnailRequestQueue(maxConcurrent: 1);
    final first = Completer<Uint8List>();
    final active = queue.load('active', () => first.future);
    final offscreen = queue.load(
      'shared',
      () async => Uint8List.fromList([1]),
      isCancelled: () => true,
    );
    final visible = queue.load('shared', () async => Uint8List.fromList([2]));
    first.complete(Uint8List(0));
    await active;
    expect(await visible, [1]);
    expect(await offscreen, [1]);
  });
  test(
    'stream queue cancels a waiter before its active request finishes',
    () async {
      final queue = ThumbnailRequestQueue(maxConcurrent: 1);
      final activeScope = RequestScope();
      final queuedScope = RequestScope();
      final started = Completer<void>();
      final input = StreamController<int>(onListen: () => started.complete());
      var queuedCalls = 0;
      final active = queue
          .stream('active', () => input.stream, activeScope)
          .toList();
      await started.future;
      final queued = expectLater(
        queue.stream('queued', () {
          queuedCalls++;
          return Stream.value(2);
        }, queuedScope).toList(),
        throwsA(isA<RequestCancelled>()),
      );
      await pumpEventQueue();
      queuedScope.cancel();
      await queued;
      expect(queuedCalls, 0);
      input.add(1);
      await input.close();
      expect(await active, [1]);
      final nextScope = RequestScope();
      expect(
        await queue.stream('queued', () => Stream.value(3), nextScope).toList(),
        [3],
      );
      activeScope.dispose();
      queuedScope.dispose();
      nextScope.dispose();
    },
  );

  test('stream failures release capacity and observe the cooldown', () async {
    final queue = ThumbnailRequestQueue(maxConcurrent: 1);
    final scope = RequestScope();
    var calls = 0;
    Stream<int> fail() {
      calls++;
      return Stream.error(StateError('offline'));
    }

    await expectLater(
      queue.stream('bad', fail, scope).toList(),
      throwsStateError,
    );
    await expectLater(
      queue.stream('bad', fail, scope).toList(),
      throwsStateError,
    );
    expect(calls, 1);
    expect(await queue.stream('other', () => Stream.value(1), scope).toList(), [
      1,
    ]);
    scope.dispose();
  });
}
