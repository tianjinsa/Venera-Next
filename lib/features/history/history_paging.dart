import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'history_model.dart';
import 'history_row.dart';

final _historyQuerySeparator = RegExp(r'\s+');

/// A searchable snapshot; rebuild it when saved history changes.
class HistorySearchIndex {
  HistorySearchIndex(List<History> histories)
    : histories = List.unmodifiable(histories);

  final List<History> histories;
  // Opening or refreshing the page without a query needs no search metadata.
  late final List<String> _texts = [
    for (final history in histories) history.searchText,
  ];

  List<History> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return histories;
    final words = normalized.split(_historyQuerySeparator);
    return [
      for (var i = 0; i < histories.length; i++)
        if (words.every(_texts[i].contains)) histories[i],
    ];
  }
}

class HistoryCursor {
  const HistoryCursor(this.time, this.id, this.type);

  HistoryCursor.fromHistory(History history)
    : time = history.time.millisecondsSinceEpoch,
      id = history.id,
      type = history.type.value;

  final int time;
  final String id;
  final int type;
}

class HistoryPageResult {
  const HistoryPageResult(this.items, {this.nextCursor});

  final List<History> items;
  final HistoryCursor? nextCursor;
}

String _historySearchCondition(
  Database db,
  String query,
  Map<int, String> sources,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return '1';
  final words = normalized.split(_historyQuerySeparator);
  // SQLite's built-in lower() only handles ASCII. Keep the existing Dart
  // search semantics, including source names, on the database worker.
  db.createFunction(
    functionName: 'history_matches',
    argumentCount: const AllowedArgumentCount(4),
    deterministic: true,
    function: (arguments) {
      final type = arguments[3] as int;
      final source = type == 0 ? 'local' : sources[type] ?? 'Unknown:$type';
      final text = [
        arguments[0] ?? '',
        arguments[1] ?? '',
        arguments[2],
        source,
      ].join('\n').toLowerCase();
      return words.every(text.contains) ? 1 : 0;
    },
  );
  return 'history_matches(title, subtitle, id, type) = 1';
}

Future<HistoryPageResult> readHistoryPage(
  String dbPath,
  String query,
  Map<int, String> sources,
  HistoryCursor? cursor,
  int limit,
) => Isolate.run(() {
  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA busy_timeout = 1000;');
    final condition = _historySearchCondition(db, query, sources);
    final rows = db.select(
      '''
      SELECT * FROM history
      WHERE $condition
        ${cursor == null ? '' : 'AND (time, id, type) < (?, ?, ?)'}
      ORDER BY time DESC, id DESC, type DESC
      LIMIT ?;
    ''',
      [
        if (cursor != null) ...[cursor.time, cursor.id, cursor.type],
        limit + 1,
      ],
    );
    final items = rows.take(limit).map(historyFromRow).toList();
    return HistoryPageResult(
      items,
      nextCursor: rows.length > limit
          ? HistoryCursor.fromHistory(items.last)
          : null,
    );
  } finally {
    db.dispose();
  }
});

Future<Set<ComicID>> readHistoryIds(
  String dbPath,
  String query,
  Map<int, String> sources,
) => Isolate.run(() {
  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA busy_timeout = 1000;');
    final condition = _historySearchCondition(db, query, sources);
    return {
      for (final row in db.select(
        'SELECT id, type FROM history WHERE $condition;',
      ))
        ComicID(ComicType(row['type'] as int), row['id'] as String),
    };
  } finally {
    db.dispose();
  }
});
