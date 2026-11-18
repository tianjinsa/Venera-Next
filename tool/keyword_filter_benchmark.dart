import 'dart:math';

import 'package:venera_next/foundation/keyword_filter.dart';
import 'package:venera_next/foundation/literal_substring_matcher.dart';

typedef _Comic = ({
  String title,
  String subtitle,
  String description,
  List<String> tags,
});

const _samples = 15;
const _comicCount = 1200;
const _tagCount = 20;
const _ruleCount = 128;

const _alphabets = [
  'abcdefghijklmnopqrstuvwxyz',
  '神話物語戦国魔法冒険学園探偵青春旅猫',
  'あいうえおかきくけこさしすせそアイウエオ',
  'αβγδεζηθικλμνξοπρστυφχψω',
];

const _phrases = [
  'At the edge of the old town, a traveller opens the black notebook.',
  '图书馆闭馆后，旅行者发现了通往月球的门。',
  '夏休みの終わり、主人公は海の向こうへ続く道を見つける。',
  'Οι φίλοι βρίσκουν ένα παλιό ημερολόγιο κοντά στη θάλασσα.',
];

String _token(Random random, int alphabet, int length) {
  final letters = _alphabets[alphabet];
  return String.fromCharCodes(
    List.generate(
      length,
      (_) => letters.codeUnitAt(random.nextInt(letters.length)),
    ),
  );
}

List<KeywordRule> _makeRules(Random random) => List.generate(_ruleCount, (i) {
  final length = i < 64
      ? 7
      : i < 115
      ? 15
      : i < 122
      ? 25
      : 36;
  return KeywordRule(
    i == 0 ? 'bl' : _token(random, i % _alphabets.length, length),
    mode: i == 0 ? KeywordMatchMode.wholeWord : KeywordMatchMode.values[i % 3],
    caseSensitive: i.isEven,
  );
});

List<_Comic> _makeComics(Random random, List<KeywordRule> rules) =>
    List.generate(_comicCount, (i) {
      final alphabet = i % _alphabets.length;
      final phrase = _phrases[alphabet];
      final label = _token(random, alphabet, 9);
      var title = '$label $i';
      var subtitle = _phrases[(alphabet + 2) % _phrases.length];
      var description = '$phrase $subtitle $phrase';
      final tags = List.generate(
        _tagCount,
        (j) => 'genre:${_token(random, j % _alphabets.length, 10)}',
      );
      if (i % 8 == 0) {
        final rule = rules[random.nextInt(rules.length)];
        final word = rule.caseSensitive
            ? rule.keyword
            : rule.keyword.toUpperCase();
        if (rule.mode == KeywordMatchMode.exactTag || i % 3 == 0) {
          tags[_tagCount - 1] = 'genre:$word:extra';
        } else if (i % 3 == 1) {
          title = '$title [$word]';
        } else {
          description = '$description [$word]';
        }
      }
      return (
        title: title,
        subtitle: subtitle,
        description: description,
        tags: tags,
      );
    });

bool _detailed(KeywordFilter filter, _Comic comic) =>
    filter.comicMatch(
      title: comic.title,
      subtitle: comic.subtitle,
      description: comic.description,
      tags: comic.tags,
    ) !=
    null;

bool _boolean(KeywordFilter filter, _Comic comic) => filter.blocksComic(
  title: comic.title,
  subtitle: comic.subtitle,
  description: comic.description,
  tags: comic.tags,
);

int _measure<T>(List<T> data, bool Function(T) match, int expected) {
  final watch = Stopwatch()..start();
  var hits = 0;
  for (final item in data) {
    if (match(item)) hits++;
  }
  watch.stop();
  if (hits != expected) throw StateError('Expected $expected hits, got $hits');
  return watch.elapsedMicroseconds;
}

void _report(String label, List<int> times) {
  times.sort();
  final median = times[times.length ~/ 2] / 1000;
  final p95 = times[(times.length * 0.95).ceil() - 1] / 1000;
  print(
    '$label  median ${median.toStringAsFixed(3)} ms  '
    'p95 ${p95.toStringAsFixed(3)} ms',
  );
}

void _compare({
  required String name,
  required int Function() first,
  required int Function() second,
  required String firstLabel,
  required String secondLabel,
}) {
  print(name);
  final firstTimes = <int>[];
  final secondTimes = <int>[];
  for (var i = 0; i < _samples; i++) {
    if (i.isEven) {
      firstTimes.add(first());
      secondTimes.add(second());
    } else {
      secondTimes.add(second());
      firstTimes.add(first());
    }
  }
  _report(firstLabel, firstTimes);
  _report(secondLabel, secondTimes);
}

void main() {
  final random = Random(178);
  final rules = _makeRules(random);
  final comics = _makeComics(random, rules);
  final detailed = KeywordFilter.rules(rules);
  final boolean = KeywordFilter.rules(rules);
  var hits = 0;
  for (final comic in comics) {
    final expected = _detailed(detailed, comic);
    if (_boolean(boolean, comic) != expected) {
      throw StateError('Comic mismatch for ${comic.title}');
    }
    if (expected) hits++;
  }
  print(
    '${comics.length} comics × $_tagCount tags × ${rules.length} rules, '
    '$hits matched, $_samples scans per variant',
  );
  _compare(
    name: 'Mixed rules, reused matching snapshot',
    first: () => _measure(comics, (comic) => _detailed(detailed, comic), hits),
    second: () => _measure(comics, (comic) => _boolean(boolean, comic), hits),
    firstLabel: 'Detailed sequential',
    secondLabel: 'Indexed Boolean',
  );
  _compare(
    name: 'Mixed rules, first scan of a new snapshot',
    first: () {
      final filter = KeywordFilter.rules(rules);
      return _measure(comics, (comic) => _detailed(filter, comic), hits);
    },
    second: () {
      final filter = KeywordFilter.rules(rules);
      return _measure(comics, (comic) => _boolean(filter, comic), hits);
    },
    firstLabel: 'Detailed sequential',
    secondLabel: 'Indexed Boolean',
  );

  // Same UTF-16 literal-substring semantics for both text engines. The
  // automaton in this probe does not implement case folding or word boundaries.
  final patterns = rules.map((rule) => rule.keyword).toList();
  final regex = RegExp('(?:${patterns.map(RegExp.escape).join('|')})');
  final automaton = LiteralSubstringMatcher(patterns);
  final fields = [
    for (final comic in comics) ...[
      comic.title,
      comic.subtitle,
      comic.description,
    ],
  ];
  var fieldHits = 0;
  for (final field in fields) {
    final expected = patterns.any(field.contains);
    if (regex.hasMatch(field) != expected ||
        automaton.hasMatch(field) != expected) {
      throw StateError('Text engine mismatch for $field');
    }
    if (expected) fieldHits++;
  }
  _compare(
    name:
        'Case-sensitive substring engines on ${fields.length} fields ($fieldHits matched)',
    first: () => _measure(fields, regex.hasMatch, fieldHits),
    second: () => _measure(fields, automaton.hasMatch, fieldHits),
    firstLabel: 'Literal regex',
    secondLabel: 'Sparse Aho–Corasick',
  );
}
