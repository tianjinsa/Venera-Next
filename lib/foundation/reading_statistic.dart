import 'comic_type.dart';

/// Daily foreground time recorded alongside the history database.
class ReadingStatistic {
  const ReadingStatistic({
    required this.day,
    required this.comicId,
    required this.comicType,
    required this.title,
    required this.author,
    required this.cover,
    required this.durationSeconds,
    required this.lastReadAt,
  });
  final String day;
  final String comicId;
  final ComicType comicType;
  final String title;
  final String author;
  final String cover;
  final int durationSeconds;
  final DateTime lastReadAt;
}
