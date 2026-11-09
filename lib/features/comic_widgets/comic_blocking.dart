import 'dart:convert';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/foundation/keyword_filter.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/reader_preference_settings.dart';

/// Shared immutable rules; Next's per-rule match modes remain authoritative.
class ComicBlockFilter {
  ComicBlockFilter({
    required Iterable<String> words,
    required Iterable<String> authors,
    KeywordFilter? keywordFilter,
  }) : words = List.unmodifiable(words),
       authors = List.unmodifiable(authors),
       _keywords = keywordFilter ?? KeywordFilter(words);
  final List<String> words;
  final List<String> authors;
  final KeywordFilter _keywords;
  late final _authors = authors
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  static String? _fingerprint;
  static ComicBlockFilter? _snapshot;
  static ComicBlockFilter fromSettings(ReaderPreferenceSettings settings) {
    final preferences = GlobalPreferenceStore(settings);
    final words = preferences.read(KeywordPreferences.comics);
    final authors = preferences.read(KeywordPreferences.authors);
    final fingerprint = jsonEncode([
      words,
      authors,
      preferences.read(KeywordPreferences.comicRules),
    ]);
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _snapshot = ComicBlockFilter(
        words: words,
        authors: authors,
        keywordFilter: KeywordFilter.fromSettings(settings),
      );
    }
    return _snapshot!;
  }

  bool blocks(Comic comic, {bool filterBlockedWords = true}) =>
      firstReason(comic, filterBlockedWords: filterBlockedWords) != null;
  String? firstReason(Comic comic, {bool filterBlockedWords = true}) {
    if (_authors.isEmpty && (!filterBlockedWords || words.isEmpty)) return null;
    final data = _BlockingData(comic);
    for (final author in authors) {
      if (author.trim().isNotEmpty && data.authors.contains(author.trim())) {
        return author;
      }
    }
    if (!filterBlockedWords || words.isEmpty) return null;
    return _keywords.firstComicMatch(
      title: data.title,
      subtitle: data.subtitle,
      description: data.description,
      tags: data.tags,
    );
  }

  String? firstAuthorReason(Comic comic) {
    final data = _BlockingData(comic);
    for (final author in authors) {
      if (author.trim().isNotEmpty && data.authors.contains(author.trim())) {
        return author;
      }
    }
    return null;
  }

  static Set<String> authorsOf(Comic comic) => _BlockingData(comic).authors;
  static String? authorFromTag(String tag) => _BlockingData._authorFromTag(tag);
}

class _BlockingData {
  _BlockingData(this.comic);

  final Comic comic;
  late final String title = comic.title;
  late final String? subtitle = comic.subtitle;
  late final String description = comic.description;
  late final List<String> tags = comic.tags ?? const [];
  late final Set<String> authors = {
    if (subtitle?.trim().isNotEmpty ?? false) subtitle!.trim(),
    for (final tag in tags)
      if (_authorFromTag(tag) case final String author) author,
  };
  late final Set<String> tagWords = {
    for (final tag in tags) ...[
      tag,
      // Keep the legacy tag.split(':')[1] semantics, including empty values.
      if (tag.contains(':')) tag.split(':')[1],
    ],
  };

  static String? _authorFromTag(String tag) {
    final separator = tag.indexOf(':');
    if (separator < 0) return null;
    final namespace = tag.substring(0, separator).trim().toLowerCase();
    if (namespace != 'artist' && namespace != 'author') return null;
    final author = tag.substring(separator + 1).trim();
    return author.isEmpty ? null : author;
  }
}
