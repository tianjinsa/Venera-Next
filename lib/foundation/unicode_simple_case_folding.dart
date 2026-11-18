part 'unicode_simple_case_folding_data.dart';

/// Simple and common folding for a supported RegExp engine, one code point at a time.
int foldUnicodeSimpleCase(int codePoint) {
  if (codePoint < 0x80) {
    return codePoint >= 0x41 && codePoint <= 0x5a ? codePoint + 32 : codePoint;
  }
  return _activeFolds[codePoint] ?? codePoint;
}

// The standalone Dart 3.11.1 VM and Flutter 3.41.4 engine use different
// Unicode data. The ligature pair was added in 15.1, the Cyrillic pair in
// 16.0, and the Latin pair in 17.0.
final hasCompatibleUnicodeCaseFolding =
    _equivalent('\ufb05', '\ufb06') && !_equivalent('\ua7ce', '\ua7cf');

final _activeFolds = _equivalent('\u1c89', '\u1c8a')
    ? const {..._simpleFolds, ..._unicode16Additions}
    : _simpleFolds;

bool _equivalent(String a, String b) =>
    RegExp(a, unicode: true, caseSensitive: false).hasMatch(b);
