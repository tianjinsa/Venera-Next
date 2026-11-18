import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/persistence_failure.dart';

import 'image_favorites_repository_test.dart' show comic;
import '../reader/image_favorite_actions_test.dart' show selection;

void main() {
  late Directory root;
  late HistoryManager history;
  late ImageFavoriteManager manager;
  late AppDataOperations operations;
  late String previousData, previousCache;

  setUpAll(() {
    App.dataPath = Directory.systemTemp.path;
    App.cachePath = Directory.systemTemp.path;
  });

  setUp(() async {
    previousData = App.dataPath;
    previousCache = App.cachePath;
    root = Directory.systemTemp.createTempSync('favorite-status-');
    App.dataPath = root.path;
    App.cachePath = root.path;
    operations = AppDataOperations();
    history = HistoryManager.create(operations: operations);
    manager = ImageFavoriteManager.create(history: history);
    await history.init();
  });

  tearDown(() async {
    await history.waitForAsyncWrites();
    manager.dispose();
    if (history.isInitialized) history.close();
    history.dispose();
    App.dataPath = previousData;
    App.cachePath = previousCache;
    root.deleteSync(recursive: true);
  });

  Future<void> seed([String source = 'source']) => history.accessImageFavorites(
    (repository, _) => repository.save(comic('comic', source: source)),
  );
  Future<bool> read(
    int page, {
    String eid = 'chapter',
    String source = 'source',
  }) => manager.isCollected('comic', source, eid, page);

  test('page reads reuse SQL results; chapter and source changes do not', () async {
    await seed();
    await seed('other');
    final db = history.imageFavoritesDatabase;
    // A real SQLite view counts materializations without a production test hook.
    // These rows are read-only for this test; mutation tests use the real table.
    var sqlReads = 0;
    db.createFunction(
      functionName: 'count_status_read',
      argumentCount: const AllowedArgumentCount(1),
      directOnly: false,
      function: (args) {
        sqlReads++;
        return args.single;
      },
    );
    db.execute('ALTER TABLE image_favorites RENAME TO stored_favorites');
    db.execute(
      '''CREATE VIEW image_favorites AS SELECT id,
      count_status_read(title) AS title, sub_title, author, tags, translated_tags,
      time, max_page, source_key, image_favorites_ep, other FROM stored_favorites''',
    );
    expect(await read(1), isTrue);
    expect(sqlReads, 1);
    final pages = await Future.wait([for (var p = 2; p <= 100; p++) read(p)]);
    expect(pages, everyElement(isFalse));
    expect(sqlReads, 1);
    db.execute('CREATE TABLE unrelated(value INTEGER)');
    db.execute('INSERT INTO unrelated VALUES (1)');
    expect(await read(1), isTrue);
    expect(sqlReads, 1);
    expect(await read(1, eid: 'another'), isFalse);
    expect(sqlReads, 2);
    expect(await read(2, eid: 'another'), isFalse);
    expect(sqlReads, 2);
    expect(await read(1, source: 'other'), isTrue);
    expect(sqlReads, 3);
    expect(await read(1), isTrue);
    expect(sqlReads, 4);
  });

  test(
    'empty chapter status invalidates on a write from another manager',
    () async {
      expect(await read(2), isFalse);
      final other = ImageFavoriteManager.create(history: history);
      try {
        expect(await other.toggle(selection()), ImageFavoriteResult.collected);
        expect(await read(2), isTrue);
        await other.deleteImageFavorite(
          (await other.find('comic', 'source'))!.images,
        );
        expect(await read(2), isFalse);
      } finally {
        other.dispose();
      }
    },
  );

  test(
    'repository writes invalidate before a same-queue cached read',
    () async {
      await seed();
      expect(await read(1), isTrue);
      final write = history.accessImageFavorites((repository, _) {
        final changed = comic('comic');
        changed.imageFavoritesEp.single.imageFavorites.single.page = 7;
        repository.save(changed);
      });
      final fresh = read(7);
      await write;
      expect(await fresh, isTrue);
      expect(await read(1), isFalse);
    },
  );

  test('rollback does not publish partially removed favorites', () async {
    await seed();
    expect(await read(1), isTrue);
    await expectLater(
      history.accessImageFavorites((repository, _) {
        repository.db.execute('BEGIN IMMEDIATE');
        try {
          repository.removeImages(repository.find('comic', 'source')!.images);
        } finally {
          repository.db.execute('ROLLBACK');
        }
      }),
      completes,
    );
    expect(await read(1), isTrue);
  });

  test(
    'a committed removal invalidates even when cache cleanup fails',
    () async {
      await seed();
      expect(await read(1), isTrue);
      final failing = ImageFavoriteManager.create(
        history: history,
        deleteCache: (_) async => throw StateError('injected cleanup'),
      );
      try {
        await expectLater(
          failing.deleteImageFavorite(
            (await failing.find('comic', 'source'))!.images,
          ),
          throwsA(isA<PersistenceFailure>()),
        );
        expect(await read(1), isFalse);
      } finally {
        failing.dispose();
      }
    },
  );

  test(
    'explicit store notification invalidates external and truncate writes',
    () async {
      await seed();
      expect(await read(1), isTrue);
      final external = sqlite3.open('${root.path}/history.db');
      try {
        external.execute('DELETE FROM image_favorites');
      } finally {
        external.dispose();
      }
      manager.notifyChanges();
      expect(await read(1), isFalse);
      await seed();
      expect(await read(1), isTrue);
    },
  );

  test('warm captured access cannot read a replacement database', () async {
    await seed();
    final access = manager.capture();
    expect(await access.isCollected('comic', 'source', 'chapter', 1), isTrue);
    await history.waitForAsyncWrites();
    history.close();
    App.dataPath = (Directory('${root.path}/replacement')..createSync()).path;
    await history.init();
    await expectLater(
      access.isCollected('comic', 'source', 'chapter', 1),
      throwsStateError,
    );
    expect(await read(1), isFalse);
    await seed();
    expect(await read(1), isTrue);
  });

  test('failed JSON read remains retryable', () async {
    await seed();
    expect(await read(1), isTrue);
    history.imageFavoritesDatabase.execute(
      "UPDATE image_favorites SET image_favorites_ep = 'invalid'",
    );
    await expectLater(read(1), throwsFormatException);
    await seed();
    expect(await read(1), isTrue);
  });

  test(
    'dispose does not attach observers for a previously queued read',
    () async {
      await seed();
      final release = Completer<void>();
      final blocked = operations.run(() => release.future);
      final retired = ImageFavoriteManager.create(history: history);
      final result = retired.isCollected('comic', 'source', 'chapter', 1);
      retired.dispose();
      release.complete();
      await blocked;
      expect(await result, isTrue);
      await seed('other');
      expect(await read(1, source: 'other'), isTrue);
    },
  );
}
