import 'package:venera_next/foundation/sqlite_transaction.dart';
import 'history_row.dart';
import 'package:sqlite3/sqlite3.dart';
import 'history_model.dart';
import 'package:venera_next/foundation/reading_statistic.dart';
import 'package:venera_next/foundation/comic_type.dart';

/// History schema, queries and writes on a caller-owned connection.
/// The manager owns scheduling, connection lifetime, caching and notifications.
class HistoryRepository {
  HistoryRepository(this.db, {String schema = 'main'})
    : _schema = '"${schema.replaceAll('"', '""')}"';
  final Database db;
  final String _schema;
  String get _table => '$_schema."history"';

  void initialize() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_schema.reading_daily (
        day TEXT NOT NULL, comic_id TEXT NOT NULL, comic_type INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL, last_read_at INTEGER NOT NULL,
        PRIMARY KEY(day, comic_id, comic_type)
      );
    ''');
    db.execute("""
        create table if not exists $_table  (
          id text,
          title text,
          subtitle text,
          cover text,
          time int,
          type int,
          ep int,
          page int,
          readEpisode text,
          max_page int,
          max_chapter int,
          chapter_group int,
          chapter_title text,
          group_title text,
          read_duration_ms integer not null default 0,
          PRIMARY KEY(id, type)
        );
      """);

    var columns = db.select('PRAGMA $_schema.table_info("history");');
    if (!columns.any((element) => element['name'] == 'max_chapter')) {
      db.execute('alter table $_table add column max_chapter int;');
    }
    if (!columns.any((element) => element["name"] == "chapter_group")) {
      db.execute("alter table $_table add column chapter_group int;");
    }
    if (!columns.any((element) => element["name"] == "read_duration_ms")) {
      db.execute(
        "alter table $_table add column read_duration_ms integer not null default 0;",
      );
    }
    for (final name in ['chapter_title', 'group_title']) {
      if (!columns.any((element) => element['name'] == name)) {
        db.execute('alter table $_table add column $name text;');
      }
    }
    columns = db.select('PRAGMA $_schema.table_info("history");');
    if (!columns.any(
      (column) => column['name'] == 'type' && column['pk'] == 2,
    )) {
      runSqliteTransaction(db, () {
        db.execute('''CREATE TABLE $_schema.history_migrated (
          id TEXT NOT NULL, title TEXT, subtitle TEXT, cover TEXT,
          time INT, type INT NOT NULL, ep INT, page INT, readEpisode TEXT,
          max_page INT, max_chapter INT, chapter_group INT, chapter_title TEXT,
          group_title TEXT, read_duration_ms INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(id, type));''');
        const names =
            'id, title, subtitle, cover, time, type, ep, page, readEpisode, '
            'max_page, max_chapter, chapter_group, chapter_title, group_title, read_duration_ms';
        db.execute(
          'INSERT INTO $_schema.history_migrated ($names) SELECT $names FROM $_table;',
        );
        db.execute('DROP TABLE $_table;');
        db.execute('ALTER TABLE $_schema.history_migrated RENAME TO history;');
      }, immediate: true);
    }
    db.execute(
      'CREATE INDEX IF NOT EXISTS $_schema.history_time_identity_idx '
      'ON history(time DESC, id DESC, type DESC);',
    );
  }

  List<History> getAll() {
    var res = db.select("""
      select * from $_table
      order by time DESC;
    """);
    return res.map((element) => historyFromRow(element)).toList();
  }

  /// 获取最近阅读的漫画
  List<History> getRecent() {
    var res = db.select("""
      select * from $_table
      order by time DESC
      limit 20;
    """);
    return res.map((element) => historyFromRow(element)).toList();
  }

  /// 获取历史记录的数量
  int count() {
    var res = db.select("""
      select count(*) AS total from $_table;
    """);
    return res.first['total'] as int;
  }

  int getTotalReadDurationMs() {
    var res = db.select("""
      select coalesce(sum(read_duration_ms), 0) AS total from $_table;
    """);
    return (res.first['total'] as num).round();
  }

  int countWithReadDuration() {
    var res = db.select("""
      select count(*) AS total from $_table where read_duration_ms > 0;
    """);
    return (res.first['total'] as num).round();
  }

  List<History> getAllByReadDuration() {
    var res = db.select("""
      select * from $_table
      where read_duration_ms > 0
      order by read_duration_ms desc, time desc;
    """);
    return res.map(historyFromRow).toList();
  }

  History? find(String id, int type) {
    var res = db.select(
      """
      select * from $_table
      where id == ? and type == ?;
    """,
      [id, type],
    );
    if (res.isEmpty) {
      return null;
    }
    return historyFromRow(res.first);
  }

  void deleteWhere(bool Function(String id, int type) shouldDelete) =>
      runSqliteTransaction(db, () {
        final idAndTypes = db.select("""
      select id, type from $_table;
    """);
        for (var element in idAndTypes) {
          final id = element["id"] as String;
          final type = element["type"] as int;
          if (shouldDelete(id, type)) {
            db.execute(
              """
          delete from $_table
          where id == ? and type == ?;
        """,
              [id, type],
            );
          }
        }
      });

  void remove(String id, int type) {
    db.execute(
      """
      delete from $_table
      where id == ? and type == ?;
    """,
      [id, type],
    );
  }

  void removeMany(Iterable<(String, int)> identities) =>
      runSqliteTransaction(db, () {
        for (final (id, type) in identities) {
          remove(id, type);
        }
      });

  void clearBefore(int cutoff) {
    db.execute(
      """
      delete from $_table
      where time < ?;
    """,
      [cutoff],
    );
  }

  void clear() => db.execute("delete from $_table;");

  List<(String, int)> identities({String? id}) => db
      .select(
        id == null
            ? 'select id, type from $_table;'
            : 'select id, type from $_table where id = ?;',
        id == null ? const [] : [id],
      )
      .map((row) => (row['id'] as String, row['type'] as int))
      .toList();

  String get _insertHistorySql =>
      """
        insert or replace into $_table (id, title, subtitle, cover, time, type, ep, page, readEpisode, max_page, max_chapter, chapter_group, chapter_title, group_title)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """;

  /// Metadata refreshes never replace progress or recreate deleted records.
  bool updateMetadata(
    String id,
    int type, {
    String? title,
    String? subtitle,
    String? cover,
  }) {
    final fields = <String, String>{
      'title': ?title,
      'subtitle': ?subtitle,
      'cover': ?cover,
    };
    if (fields.isEmpty) return false;
    db.execute(
      'UPDATE $_table SET ${fields.keys.map((field) => '$field = ?').join(', ')} '
      'WHERE id = ? AND type = ?;',
      [...fields.values, id, type],
    );
    return db.updatedRows > 0;
  }

  String get _updateHistorySql =>
      """
        update $_table set
          time = ?,
          ep = ?,
          page = ?,
          readEpisode = ?,
          max_page = ?,
          max_chapter = ?,
          chapter_group = ?,
          chapter_title = ?,
          group_title = ?
        where id = ? and type = ?;
      """;

  String get _insertReadDurationSql =>
      """
        insert or replace into $_table (id, title, subtitle, cover, time, type, ep, page, readEpisode, max_page, max_chapter, chapter_group, chapter_title, group_title, read_duration_ms)
        values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      """;

  String get _incrementReadDurationSql =>
      """
        update $_table
        set read_duration_ms = read_duration_ms + ?
        where id = ? and type = ?;
      """;

  static List<Object?> _historyValues(History item) {
    return [
      item.id,
      item.title,
      item.subtitle,
      item.cover,
      item.time.millisecondsSinceEpoch,
      item.type.value,
      item.ep,
      item.page,
      item.readEpisode.join(','),
      item.maxPage,
      item.maxChapter,
      item.group,
      item.chapterTitle,
      item.groupTitle,
    ];
  }

  // Legacy databases do not consistently expose a single-column UNIQUE(id).
  void writeProgress(History item) =>
      _writeHistory(item, replaceMetadata: false);

  /// Imports deliberately replace metadata as well as progress. Duration keeps
  /// the existing import policy and is not replaced by a progress snapshot.
  void importHistory(History item) =>
      _writeHistory(item, replaceMetadata: true);

  /// Undo restores the full deleted snapshot, without changing a newer record
  /// created while the undo was waiting for admission.
  void restoreHistory(History item) {
    db.execute(
      '''
      INSERT OR IGNORE INTO $_table
        (id, title, subtitle, cover, time, type, ep, page, readEpisode,
         max_page, max_chapter, chapter_group, chapter_title, group_title,
         read_duration_ms)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''',
      [..._historyValues(item), item.readDurationMs],
    );
  }

  void _writeHistory(History item, {required bool replaceMetadata}) {
    runSqliteTransaction(db, () {
      db.execute(_updateHistorySql, [
        item.time.millisecondsSinceEpoch,
        item.ep,
        item.page,
        item.readEpisode.join(','),
        item.maxPage,
        item.maxChapter,
        item.group,
        item.chapterTitle,
        item.groupTitle,
        item.id,
        item.type.value,
      ]);
      if (db.updatedRows == 0) {
        db.execute(_insertHistorySql, _historyValues(item));
      } else if (replaceMetadata) {
        updateMetadata(
          item.id,
          item.type.value,
          title: item.title,
          subtitle: item.subtitle,
          cover: item.cover,
        );
      }
    }, immediate: true);
  }

  void addReadDuration(History item, int durationMs) {
    runSqliteTransaction(db, () {
      db.execute(_incrementReadDurationSql, [
        durationMs,
        item.id,
        item.type.value,
      ]);
      if (db.updatedRows == 0) {
        db.execute(_insertReadDurationSql, [
          ..._historyValues(item),
          durationMs,
        ]);
      }
      final end = DateTime.now();
      var start = end.subtract(Duration(milliseconds: durationMs));
      while (start.isBefore(end)) {
        final midnight = DateTime(start.year, start.month, start.day + 1);
        final stop = midnight.isBefore(end) ? midnight : end;
        final day =
            '${start.year.toString().padLeft(4, '0')}-'
            '${start.month.toString().padLeft(2, '0')}-'
            '${start.day.toString().padLeft(2, '0')}';
        db.execute(
          '''
          INSERT INTO $_schema.reading_daily VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(day, comic_id, comic_type) DO UPDATE SET
            duration_ms = duration_ms + excluded.duration_ms,
            last_read_at = MAX(last_read_at, excluded.last_read_at);
        ''',
          [
            day,
            item.id,
            item.type.value,
            stop.difference(start).inMilliseconds,
            stop.millisecondsSinceEpoch,
          ],
        );
        start = stop;
      }
    }, immediate: true);
  }

  List<ReadingStatistic> readingStatistics(int days) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days.clamp(1, 365) - 1))
        .toIso8601String()
        .substring(0, 10);
    return db
        .select(
          '''
      SELECT d.*, h.title, h.subtitle, h.cover FROM $_schema.reading_daily d
      JOIN $_table h ON h.id = d.comic_id AND h.type = d.comic_type
      WHERE d.day >= ? ORDER BY d.day, d.comic_id, d.comic_type;
    ''',
          [cutoff],
        )
        .map(
          (row) => ReadingStatistic(
            day: row['day'] as String,
            comicId: row['comic_id'] as String,
            comicType: ComicType(row['comic_type'] as int),
            title: row['title'] as String,
            author: row['subtitle'] as String,
            cover: row['cover'] as String,
            durationSeconds: (row['duration_ms'] as int) ~/ 1000,
            lastReadAt: DateTime.fromMillisecondsSinceEpoch(
              row['last_read_at'] as int,
            ),
          ),
        )
        .toList();
  }
}
