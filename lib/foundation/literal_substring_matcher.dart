import 'unicode_simple_case_folding.dart';

/// Aho–Corasick matcher for literal UTF-16 or case-folded Unicode code points.
class LiteralSubstringMatcher {
  LiteralSubstringMatcher(
    Iterable<String> patterns, {
    this.unicodeIgnoreCase = false,
  }) {
    for (final pattern in patterns) {
      var state = 0;
      final symbols = unicodeIgnoreCase
          ? pattern.runes.map(foldUnicodeSimpleCase)
          : pattern.codeUnits;
      for (final symbol in symbols) {
        state = _nodes[state].edges.putIfAbsent(symbol, () {
          _nodes.add(_Node());
          return _nodes.length - 1;
        });
      }
      _nodes[state].matched = true;
    }

    // A failed transition follows the longest suffix present in the trie.
    // Breadth-first order ensures the suffix's match state is already known.
    final queue = _nodes.first.edges.values.toList();
    for (var i = 0; i < queue.length; i++) {
      final node = _nodes[queue[i]];
      for (final MapEntry(key: unit, value: child) in node.edges.entries) {
        final failure = _step(node.failure, unit);
        _nodes[child]
          ..failure = failure
          ..matched |= _nodes[failure].matched;
        queue.add(child);
      }
    }
  }

  final bool unicodeIgnoreCase;
  final _nodes = [_Node()];

  int _step(int state, int unit) {
    var next = _nodes[state].edges[unit];
    while (next == null && state != 0) {
      state = _nodes[state].failure;
      next = _nodes[state].edges[unit];
    }
    return next ?? 0;
  }

  bool hasMatch(String text) {
    if (_nodes.first.matched) return true;
    if (unicodeIgnoreCase) return _hasFoldedMatch(text);
    var state = 0;
    for (var i = 0; i < text.length; i++) {
      state = _step(state, text.codeUnitAt(i));
      if (_nodes[state].matched) return true;
    }
    return false;
  }

  bool _hasFoldedMatch(String text) {
    var state = 0;
    // A supplementary character is one symbol, including in the patterns.
    for (final codePoint in text.runes) {
      state = _step(state, foldUnicodeSimpleCase(codePoint));
      if (_nodes[state].matched) return true;
    }
    return false;
  }
}

class _Node {
  final edges = <int, int>{};
  int failure = 0;
  bool matched = false;
}
