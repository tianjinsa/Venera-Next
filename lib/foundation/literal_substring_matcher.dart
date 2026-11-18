/// Aho–Corasick matcher for any literal substring in UTF-16 code units.
class LiteralSubstringMatcher {
  LiteralSubstringMatcher(Iterable<String> patterns) {
    for (final pattern in patterns) {
      var state = 0;
      for (var i = 0; i < pattern.length; i++) {
        state = _nodes[state].edges.putIfAbsent(pattern.codeUnitAt(i), () {
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
    var state = 0;
    for (var i = 0; i < text.length; i++) {
      state = _step(state, text.codeUnitAt(i));
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
