import 'dart:async';
import 'comic_blocking.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venera_next/components/keyword_match_preview.dart';
import 'package:venera_next/components/keyword_rule_labels.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/keyword_filter.dart';
import 'package:venera_next/foundation/translations.dart';

import 'comic_tile.dart';

class KeywordHiddenNotice extends StatelessWidget {
  const KeywordHiddenNotice({
    super.key,
    required this.count,
    required this.comics,
    this.filterBlockedWords = true,
  });
  final bool filterBlockedWords;
  final int count;
  final List<Comic> Function() comics;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Hidden by keyword filters: @a comics'.tlParams({'a': count}),
      ),
      subtitle: Text('View reasons'.tl),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: () => showKeywordFilterReview(
        context,
        comics: comics,
        filterBlockedWords: filterBlockedWords,
      ),
    ),
  );
}

Future<void> showKeywordFilterReview(
  BuildContext context, {
  required List<Comic> Function() comics,
  bool filterBlockedWords = true,
  String? description,
}) {
  final work = context.getInheritedWidgetOfExactType<SettingsSaveScope>()?.work;
  return showDialog<void>(
    context: context,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) {
      final dialog = _KeywordHiddenDialog(
        comics: comics,
        filterBlockedWords: filterBlockedWords,
        description: description,
      );
      return work == null
          ? dialog
          : SettingsSaveScope(work: work, child: dialog);
    },
  );
}

class _KeywordHiddenDialog extends StatefulWidget {
  const _KeywordHiddenDialog({
    required this.comics,
    required this.filterBlockedWords,
    this.description,
  });
  final bool filterBlockedWords;
  final List<Comic> Function() comics;
  final String? description;

  @override
  State<_KeywordHiddenDialog> createState() => _KeywordHiddenDialogState();
}

class _KeywordHiddenDialogState extends State<_KeywordHiddenDialog> {
  var _hidden = <(Comic, KeywordMatch?, String?)>[];
  var _scanning = true;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
    _refresh();
  }

  void _refresh() => unawaited(_scan());

  Future<void> _scan() async {
    final generation = ++_generation;
    final filter = KeywordFilter.fromSettings(appdata.settings);
    final authors = ComicBlockFilter.fromSettings(appdata.settings);
    final hidden = <(Comic, KeywordMatch?, String?)>[];
    final comics = widget.comics();
    if (!_scanning) setState(() => _scanning = true);
    // Let the dialog paint, then yield in batches for large library scans.
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < comics.length; i++) {
      if (!mounted || generation != _generation) return;
      final comic = comics[i];
      final author = authors.firstAuthorReason(comic);
      if (author != null) {
        hidden.add((comic, null, author));
      } else if (widget.filterBlockedWords) {
        final match = filter.comicMatch(
          title: comic.title,
          subtitle: comic.subtitle,
          description: comic.description,
          tags: comic.tags ?? const [],
        );
        if (match != null) hidden.add((comic, match, null));
      }
      if (i % 40 == 39) await Future<void>.delayed(Duration.zero);
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _hidden = hidden;
      _scanning = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }

  Widget _reason(Comic comic, KeywordMatch? match, String? author) {
    final edit = author != null
        ? comicAuthorRuleEditor == null
              ? null
              : () => comicAuthorRuleEditor!(context, author)
        : comicKeywordRuleEditor == null
        ? null
        : () => comicKeywordRuleEditor!(context, match!.rule);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: edit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              height: 84,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ComicTile(comic: comic).buildImage(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (match?.field == KeywordMatchField.title)
                    KeywordMatchPreview(match: match!)
                  else
                    Text(
                      comic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),
                  if (author != null) ...[
                    Text('Author blocking'.tl),
                    Text('Author: @a'.tlParams({'a': author})),
                  ] else ...[
                    Text('Matched in @a'.tlParams({'a': match!.field.label})),
                    if (match.field != KeywordMatchField.title)
                      KeywordMatchPreview(match: match),
                    Text(
                      'Keyword: @a'.tlParams({
                        'a': match.rule.keyword.isEmpty
                            ? 'Empty keyword'.tl
                            : match.rule.keyword,
                      }),
                    ),
                    Text(keywordRuleSummary(match.rule)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    title: 'Keyword filter reasons'.tl,
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.description ?? 'Tap a matching reason to edit its rule.'.tl,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 560,
            height: math.min(400, MediaQuery.sizeOf(context).height * 0.5),
            child: _scanning
                ? const Center(child: CircularProgressIndicator())
                : _hidden.isEmpty
                ? Center(
                    child: Text(
                      'No comics in this list are hidden by keywords.'.tl,
                    ),
                  )
                : ListView.separated(
                    itemCount: _hidden.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final (comic, match, author) = _hidden[index];
                      return _reason(comic, match, author);
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text('Close'.tl),
      ),
    ],
  );
}
