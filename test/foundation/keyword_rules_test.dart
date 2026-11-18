import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/app_data_sync_fields.dart';
import 'package:venera_next/foundation/keyword_filter.dart';
import 'package:venera_next/foundation/literal_substring_matcher.dart';
import 'package:venera_next/foundation/reader_preference_settings.dart';
import 'package:venera_next/foundation/unicode_simple_case_folding.dart';

class _Settings implements ReaderPreferenceSettings {
  _Settings(this.values);
  final Map<String, Object?> values;
  @override
  Object? operator [](String key) => values[key];
  @override
  void operator []=(String key, Object? value) => values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

KeywordMatch? _title(String title, KeywordRule rule) =>
    KeywordFilter.rules([rule]).comicMatch(title: title, description: '');

void main() {
  test('sync exclusions keep keyword lists and their options together', () {
    for (final (words, options) in [
      ('blockedWords', 'blockedWordRules'),
      ('blockedCommentWords', 'blockedCommentWordRules'),
    ]) {
      expect(splitAppDataFields(words), [words, options]);
      expect(splitAppDataFields(options), [options, words]);
      expect(splitAppDataFields('$words, $options'), [words, options]);
    }
    expect(splitAppDataFields('other, other'), ['other', 'other']);
  });
  const whole = KeywordRule('bl', mode: KeywordMatchMode.wholeWord);
  for (final (text, matches) in <(String, bool)>[
    ('BL', true),
    ('[BL] Short stories', true),
    ('artist.bl.part01.zip', true),
    ('BL_stories', true),
    ('BL-stories', true),
    ('😀BL😀', true),
    ('black and white', false),
    ('able', false),
    ('2bl', false),
    ('bl2', false),
    ('ébl', false),
    ('blé', false),
    ('bl\u0301', false),
    ('𐐀bl', false),
    ('BL漫画', false),
    ('中文 BL 故事', true),
    ('black.bl.zip', true),
  ]) {
    test('whole word boundaries: $text', () {
      expect(_title(text, whole) != null, matches);
    });
  }

  test(
    'a rejected first occurrence does not hide a later independent word',
    () {
      final match = _title('black and BL', whole)!;
      expect(match.start, 10);
      expect(match.end, 12);
      expect(match.text.substring(match.start, match.end), 'BL');
      expect(match.field, KeywordMatchField.title);
    },
  );

  test('Unicode word search advances past a rejected supplementary letter', () {
    final filter = KeywordFilter.rules([
      const KeywordRule('𐐨', mode: KeywordMatchMode.wholeWord),
    ]);
    expect(filter.blocksComic(title: '𐐀bl', description: ''), isFalse);
    final match = filter.comicMatch(title: '𐐀bl (𐐀)', description: '')!;
    expect(match.text.substring(match.start, match.end), '𐐀');
    expect(match.start, 6);
    expect(filter.blocksComic(title: match.text, description: ''), isTrue);
  });

  test(
    'literal text detection follows matching suffixes of shared prefixes',
    () {
      final filter = KeywordFilter.rules([
        const KeywordRule.legacy('abcdx'),
        const KeywordRule.legacy('bc'),
      ]);
      expect(filter.blocksComic(title: 'abc', description: ''), isTrue);
      expect(filter.blocksComic(title: 'abxd', description: ''), isFalse);
    },
  );

  test('insensitive literal detection follows Unicode RegExp folding', () {
    final unpairedLead = String.fromCharCode(0xd801);
    final unpairedTrail = String.fromCharCode(0xdc28);
    for (final (pattern, input, expected) in [
      ('s', 'xſx', true),
      ('s', 'Ｓ', false),
      ('i', 'İ', false),
      ('i', 'ı', false),
      ('σ', 'ς', true),
      ('k', 'K', true),
      ('ß', 'ẞ', true),
      ('ß', 'SS', false),
      ('𐐨', '𐐀', true),
      ('é', 'e\u0301', false),
      (unpairedLead, '𐐨', false),
      (unpairedTrail, '𐐨', false),
      (unpairedLead, 'x${unpairedLead}x', true),
    ]) {
      final native = RegExp(
        RegExp.escape(pattern),
        caseSensitive: false,
        unicode: true,
      );
      final automaton = LiteralSubstringMatcher([
        pattern,
      ], unicodeIgnoreCase: true);
      final filter = KeywordFilter.rules([KeywordRule(pattern)]);
      final reason = '$pattern against $input';
      expect(native.hasMatch(input), expected, reason: reason);
      expect(automaton.hasMatch(input), expected, reason: reason);
      expect(
        filter.blocksComic(title: input, description: ''),
        expected,
        reason: reason,
      );
    }
    for (final (pattern, input) in [
      ('ﬅ', 'ﬆ'),
      ('\u0390', '\u1fd3'),
      ('\u1c89', '\u1c8a'),
      ('\ua7dc', '\u019b'),
      ('\u{10d50}', '\u{10d70}'),
      ('\ua7ce', '\ua7cf'),
    ]) {
      final expected = RegExp(
        pattern,
        caseSensitive: false,
        unicode: true,
      ).hasMatch(input);
      final filter = KeywordFilter.rules([KeywordRule(pattern)]);
      expect(filter.blocksComic(title: input, description: ''), expected);
      if (hasCompatibleUnicodeCaseFolding) {
        expect(
          LiteralSubstringMatcher([
            pattern,
          ], unicodeIgnoreCase: true).hasMatch(input),
          expected,
        );
      }
    }
    if (hasCompatibleUnicodeCaseFolding) {
      final automaton = LiteralSubstringMatcher([
        'Abcdx',
        'bC',
        'ﬅ',
      ], unicodeIgnoreCase: true);
      expect(automaton.hasMatch('aBc'), isTrue);
      expect(automaton.hasMatch('abxd'), isFalse);
      expect(automaton.hasMatch('ﬆ'), isTrue);
    }
  });

  test('fast detection agrees with reasons across Unicode and tag modes', () {
    final texts = [
      '',
      'able BL-stories',
      'black and white',
      'BL漫画',
      '校园恋爱故事',
      '千年の旅',
      'xſx Ｓ s S',
      'Kelvin story',
      'ÄBC Äbc',
      'İstanbul ı ß SS',
      '𐐀bl 😀 𐐨',
      'bl\u0301',
      'literal [a+b].',
      'literal axb',
      'a-a-a',
      'x${String.fromCharCode(0xd800)}y',
    ];
    final words = [
      'bl',
      '校园',
      'の旅',
      's',
      'kelvin',
      'äbc',
      'i',
      'ß',
      '𐐨',
      '[a+b].',
      'a-a',
      String.fromCharCode(0xd800),
      '',
    ];
    final tags = [
      <String>[],
      ['genre:BL'],
      ['genre:bl:extra'],
      ['genre:extra:BL'],
      ['genre:'],
      ['genre: BL '],
      ['genre:ÄBC'],
      ['artist:[a+b].'],
      ['genre:kelvin:'],
      ['artist:𐐨'],
      ['genre:校园'],
      ['genre:の旅'],
      ['genre:Kelvin'],
      ['a:b:c'],
    ];
    for (final mode in KeywordMatchMode.values) {
      for (final sensitive in [false, true]) {
        // Singletons catch false positives even when another rule would hide
        // the same comic. Batches exercise the text and tag indexes.
        for (final set in [
          words,
          for (final word in words) [word],
        ]) {
          final filter = KeywordFilter.rules([
            for (final word in set)
              KeywordRule(word, mode: mode, caseSensitive: sensitive),
          ]);
          for (final title in texts) {
            for (final comicTags in tags) {
              expect(
                filter.blocksComic(
                  title: title,
                  description: '',
                  tags: comicTags,
                ),
                filter.comicMatch(
                      title: title,
                      description: '',
                      tags: comicTags,
                    ) !=
                    null,
                reason: '$mode, sensitive=$sensitive, $set, $title, $comicTags',
              );
            }
          }
        }
      }
    }
  });

  test(
    'a rule in a later batch still matches subtitle, description or tag',
    () {
      final filter = KeywordFilter.rules([
        for (var i = 0; i < 256; i++) KeywordRule('missing word #$i'),
        const KeywordRule('校园'),
        const KeywordRule('genre:BL:licensed', mode: KeywordMatchMode.exactTag),
      ]);
      expect(
        filter.blocksComic(title: 'foo', subtitle: '校园日记', description: ''),
        isTrue,
      );
      expect(filter.blocksComic(title: 'foo', description: '校园日记'), isTrue);
      expect(
        filter.blocksComic(
          title: 'foo',
          description: '',
          tags: ['Genre:BL:licensed'],
        ),
        isTrue,
      );
      expect(filter.blocksComic(title: 'foo', description: ''), isFalse);
    },
  );

  test('literal punctuation never becomes regular expression syntax', () {
    for (final keyword in ['[BL]', 'a+b', 'a.b', r'\d+', '(cat|dog)']) {
      final rule = KeywordRule(keyword);
      final match = _title('prefix $keyword suffix', rule)!;
      expect(match.text.substring(match.start, match.end), keyword);
    }
    expect(_title('axb', const KeywordRule('a.b')), isNull);
    expect(_title('1234', const KeywordRule(r'\d+')), isNull);
    expect(_title('dog', const KeywordRule('(cat|dog)')), isNull);
  });

  test('case sensitivity is per rule and offsets use original text', () {
    const sensitive = KeywordRule(
      'bl',
      mode: KeywordMatchMode.wholeWord,
      caseSensitive: true,
    );
    expect(_title('[BL]', sensitive), isNull);
    expect(_title('[bl]', sensitive), isNotNull);
    final match = _title('😀ÄBC story', const KeywordRule('äbc'))!;
    expect(match.start, 2);
    expect(match.end, 5);
    expect(match.text.substring(match.start, match.end), 'ÄBC');
  });

  test(
    'contains supports Chinese phrases without pretending to segment them',
    () {
      expect(_title('校园恋爱故事', const KeywordRule('校园')), isNotNull);
      expect(
        _title(
          '校园恋爱故事',
          const KeywordRule('校园', mode: KeywordMatchMode.wholeWord),
        ),
        isNull,
      );
    },
  );

  test('tag-only rules never match the title, subtitle or description', () {
    final filter = KeywordFilter.rules([
      const KeywordRule('bl', mode: KeywordMatchMode.exactTag),
    ]);
    expect(
      filter.comicMatch(
        title: 'BL',
        subtitle: 'BL',
        description: 'BL',
        tags: ['black'],
      ),
      isNull,
    );
    for (final tag in ['BL', 'genre:BL', 'genre:BL:other']) {
      final match = filter.comicMatch(
        title: 'Visible title',
        description: '',
        tags: [tag],
      )!;
      expect(match.field, KeywordMatchField.tag);
      expect(match.text.substring(match.start, match.end), 'BL');
    }
    expect(
      filter.comicMatch(title: 'BL', description: '', tags: ['genre:other:BL']),
      isNull,
    );
  });

  test(
    'text modes retain exact tag matching and report the actual hit field',
    () {
      final filter = KeywordFilter.rules([whole]);
      for (final (field, subtitle, description, tags) in [
        (KeywordMatchField.subtitle, '[BL] Artist', '', <String>[]),
        (KeywordMatchField.description, null, '[BL] Story', <String>[]),
        (KeywordMatchField.tag, null, '', ['genre:BL']),
      ]) {
        expect(
          filter
              .comicMatch(
                title: 'black and white',
                subtitle: subtitle,
                description: description,
                tags: tags,
              )
              ?.field,
          field,
        );
      }
      expect(
        filter.comicMatch(title: '', description: '', tags: ['BL stories']),
        isNull,
      );
    },
  );

  test('old and new rules survive JSON without changing legacy behavior', () {
    final values = <String, Object?>{
      'blockedWords': ['bl', ' BL ', '', 'bl'],
      'blockedCommentWords': ['BL'],
      'blockedWordRules': <String, String>{},
      'blockedCommentWordRules': <String, String>{},
    };
    final raw = jsonEncode(values);
    final settings = _Settings(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
    final old = KeywordFilter.fromSettings(settings);
    expect(old.firstComicMatch(title: 'black', description: ''), 'bl');
    expect(old.rules.map((rule) => rule.keyword), ['bl', ' BL ', '', 'bl']);
    expect(
      old.rules.every((rule) => rule.isLegacy && rule.caseSensitive),
      isTrue,
    );
    expect(
      KeywordFilter.fromSettings(
        settings,
        comments: true,
      ).blocksComment('black'),
      isTrue,
    );
    expect(jsonEncode(settings.values), raw);

    settings['blockedWords'] = ['bl'];
    settings['blockedWordRules'] = {
      'bl': whole.storageOptions,
      'orphan': 'contains:insensitive',
    };
    final roundTrip = _Settings(
      Map<String, Object?>.from(jsonDecode(jsonEncode(settings.values)) as Map),
    );
    final updated = KeywordFilter.fromSettings(roundTrip);
    expect(updated.firstComicMatch(title: 'black', description: ''), isNull);
    expect(updated.firstComicMatch(title: '[BL]', description: ''), 'bl');
    expect(updated.firstComicMatch(title: 'orphan', description: ''), isNull);
    expect(old.firstComicMatch(title: 'black', description: ''), 'bl');
  });

  test(
    'invalid or unknown options fall back to the original policy on read',
    () {
      for (final value in [
        null,
        false,
        <String, Object?>{'bl': 1},
        {'bl': 'unknown:insensitive'},
        {'bl': 'wholeWord:unknown'},
        {'bl': 'wholeWord:insensitive:extra'},
      ]) {
        final settings = _Settings({
          'blockedWords': ['bl'],
          'blockedWordRules': value,
        });
        final raw = jsonEncode(settings.values);
        final filter = KeywordFilter.fromSettings(settings);
        expect(filter.firstComicMatch(title: 'black', description: ''), 'bl');
        expect(filter.firstComicMatch(title: 'BLACK', description: ''), isNull);
        expect(jsonEncode(settings.values), raw);
      }
    },
  );

  test('comment options support independent words with the old fallback', () {
    final settings = _Settings({
      'blockedCommentWords': ['bl'],
      'blockedCommentWordRules': {'bl': whole.storageOptions},
    });
    final filter = KeywordFilter.fromSettings(settings, comments: true);
    expect(filter.blocksComment('black'), isFalse);
    expect(filter.blocksComment('[BL] comment'), isTrue);
    settings['blockedCommentWordRules'] = {'bl': 'exactTag:sensitive'};
    expect(
      KeywordFilter.fromSettings(
        settings,
        comments: true,
      ).blocksComment('BLACK'),
      isTrue,
    );
  });

  test('option defaults are detached and rule snapshots are immutable', () {
    final first = applicationPreferenceDefaults;
    (first[KeywordPreferences.comicRules.key] as Map)['bl'] =
        whole.storageOptions;
    expect(
      applicationPreferenceDefaults[KeywordPreferences.comicRules.key],
      isEmpty,
    );
    final rules = [whole];
    final filter = KeywordFilter.rules(rules);
    rules.clear();
    expect(filter.firstComicMatch(title: '[BL]', description: ''), 'bl');
    expect(() => filter.rules.clear(), throwsUnsupportedError);
  });
}
