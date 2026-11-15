import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/features/reader/image_cache_policy.dart';
import 'package:venera_next/foundation/reader_diagnostics.dart';

void main() {
  testWidgets(
    '32 MiB decisions distinguish low RAM, pressure and query failure',
    (tester) async {
      final changes = <ReaderDiagnosticCacheBudget>[];
      final low = ReaderImageCachePolicy(
        readAvailableMemory: () async => 256 << 20,
        setLimit: (_) {},
        onChanged: changes.add,
        onError: (_, _) => fail('unexpected error'),
      );
      await low.configure();
      expect(low.snapshot.reason, ReaderDiagnosticCacheReason.availableMemory);
      expect(low.snapshot.availableBytes, 256 << 20);
      expect(low.snapshot.precacheAllowed, isFalse);
      expect(low.snapshot.pressureEvents, 0);
      low.dispose();
      final query = Completer<int?>();
      final pressure = ReaderImageCachePolicy(
        readAvailableMemory: () => query.future,
        setLimit: (_) {},
        onChanged: changes.add,
        onError: (_, _) => fail('unexpected error'),
      );
      final pending = pressure.configure();
      pressure.handleMemoryPressure();
      query.complete(8 << 30);
      await pending;
      expect(pressure.snapshot.limitBytes, 32 << 20);
      expect(
        pressure.snapshot.reason,
        ReaderDiagnosticCacheReason.memoryPressure,
      );
      expect(pressure.snapshot.availableBytes, 8 << 30);
      expect(
        pressure.snapshot.memoryQuery,
        ReaderDiagnosticMemoryQuery.available,
      );
      expect(pressure.snapshot.pressureEvents, 1);
      expect(pressure.snapshot.underPressure, isTrue);
      pressure.dispose();
      final failed = ReaderImageCachePolicy(
        readAvailableMemory: () async =>
            throw StateError('private platform error'),
        setLimit: (_) {},
        onChanged: changes.add,
        onError: (_, _) {},
      );
      await failed.configure();
      expect(failed.snapshot.reason, ReaderDiagnosticCacheReason.inherited);
      expect(failed.snapshot.memoryQuery, ReaderDiagnosticMemoryQuery.failed);
      expect(failed.snapshot.limitBytes, 32 << 20);
      expect(failed.snapshot.toJson().toString(), isNot(contains('private')));
      failed.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(changes.last.reason, ReaderDiagnosticCacheReason.exitShrink);
    },
  );

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
        maximumBytes: () => 192 << 20,
        setLimit: limits.add,
        onError: (_, _) => fail('unexpected error'),
      );
      final pending = policy.configure();
      policy.handleMemoryPressure();
      query.complete(8 << 30);
      await pending;
      expect(limits, [192 << 20, 32 << 20]);
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

  testWidgets('pressure cannot increase an inherited smaller TV budget', (
    tester,
  ) async {
    final old = ReaderImageCachePolicy(
      readAvailableMemory: () async => 8 << 30,
      maximumBytes: () => 16 << 20,
      setLimit: (_) {},
      onError: (error, _) => fail('$error'),
    );
    await old.configure();
    old.dispose();
    final limits = <int>[];
    final current = ReaderImageCachePolicy(
      readAvailableMemory: () async => null,
      setLimit: limits.add,
      onError: (error, _) => fail('$error'),
    );
    current.handleMemoryPressure();
    expect(limits, [16 << 20]);
    current.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
