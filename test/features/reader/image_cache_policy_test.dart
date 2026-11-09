import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/image_cache_policy.dart';

void main() {
  test('available memory reserves one sixteenth within 32–192 MiB', () {
    expect(ReaderImageCachePolicy.limitForMemory(256 << 20), 32 << 20);
    expect(ReaderImageCachePolicy.limitForMemory(1 << 30), 64 << 20);
    expect(ReaderImageCachePolicy.limitForMemory(2 << 30), 128 << 20);
    expect(ReaderImageCachePolicy.limitForMemory(8 << 30), 192 << 20);
  });

  testWidgets('TV ceiling applies before queries and survives query failure', (
    tester,
  ) async {
    final limits = <int>[];
    final query = Completer<int?>();
    final policy = ReaderImageCachePolicy(
      readAvailableMemory: () => query.future,
      maximumBytes: () => 24 << 20,
      setLimit: limits.add,
      onError: (_, _) {},
    );
    final configured = policy.configure();
    expect(limits, [24 << 20]);
    query.complete(8 << 30);
    await configured;
    expect(limits.last, 24 << 20);
    expect(ReaderImageCachePolicy.allowActivePrecache, isFalse);
    policy.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'pressure pauses precache and a late query cannot increase the budget',
    (tester) async {
      final limits = <int>[];
      final query = Completer<int?>();
      final policy = ReaderImageCachePolicy(
        readAvailableMemory: () => query.future,
        setLimit: limits.add,
        onError: (_, _) => fail('unexpected error'),
      );
      final pending = policy.configure();
      policy.handleMemoryPressure();
      query.complete(8 << 30);
      await pending;
      expect(limits, [32 << 20]);
      expect(ReaderImageCachePolicy.allowActivePrecache, isFalse);
      policy.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(limits.last, 32 << 20);
    },
  );

  testWidgets('quick re-entry cancels delayed shrink from the old session', (
    tester,
  ) async {
    final first = <int>[], second = <int>[];
    ReaderImageCachePolicy create(List<int> writes, int memory) =>
        ReaderImageCachePolicy(
          readAvailableMemory: () async => memory,
          setLimit: writes.add,
          onError: (_, _) {},
        );
    final old = create(first, 8 << 30);
    await old.configure();
    old.dispose();
    expect(first, [192 << 20]);
    final current = create(second, 2 << 30);
    await current.configure();
    await tester.pump(const Duration(seconds: 1));
    expect(first, [192 << 20]);
    expect(second, [128 << 20]);
    current.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(second, [128 << 20, 100 << 20]);
  });

  testWidgets('disposed sessions ignore late memory replies and errors', (
    tester,
  ) async {
    final reply = Completer<int?>();
    final limits = <int>[];
    final policy = ReaderImageCachePolicy(
      readAvailableMemory: () => reply.future,
      setLimit: limits.add,
      onError: (_, _) => fail('obsolete error'),
    );
    final pending = policy.configure();
    policy.dispose();
    reply.completeError(StateError('late platform reply'));
    await pending;
    expect(limits, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(limits, [100 << 20]);
  });
}
