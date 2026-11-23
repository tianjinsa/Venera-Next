import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venera_next/components/keyword_match_preview.dart';
import 'package:venera_next/components/keyword_rule_labels.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_large_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/keyword_filter.dart';
import 'package:venera_next/foundation/translations.dart';

import 'comic_blocking.dart';
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
  Widget build(BuildContext context) {
    final title = Text(
      'Hidden by keyword filters: @a comics'.tlParams({'a': count}),
    );
    final subtitle = Text('View reasons'.tl);
    const trailing = ExcludeSemantics(child: Icon(Icons.chevron_right));
    void review() => showKeywordFilterReview(
      context,
      comics: comics,
      filterBlockedWords: filterBlockedWords,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: MobileUi.enabledOf(context)
          ? MobileContentRow(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              onTap: review,
            )
          : ListTile(
              contentPadding: EdgeInsets.zero,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              onTap: review,
            ),
    );
  }
}

Future<void> showKeywordFilterReview(
  BuildContext context, {
  required List<Comic> Function() comics,
  bool filterBlockedWords = true,
  String? description,
}) {
  final work = context.getInheritedWidgetOfExactType<SettingsSaveScope>()?.work;
  final mobile = MobileUi.enabledOf(context);
  Widget review(BuildContext _) {
    final body = _KeywordReview(
      comics: comics,
      filterBlockedWords: filterBlockedWords,
      description: description,
      sheet: mobile,
    );
    return work == null ? body : SettingsSaveScope(work: work, child: body);
  }

  if (mobile) {
    // Keep the same navigation owner as the previous root dialog: the cover,
    // details and source-specific searches must all appear above the review.
    return Navigator.of(context, rootNavigator: true).push<void>(
      mobileLargeSheetRoute<void>(context: context, builder: review),
    );
  }
  return showDialog<void>(
    context: context,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: review,
  );
}

class _KeywordReview extends StatefulWidget {
  const _KeywordReview({
    required this.comics,
    required this.filterBlockedWords,
    this.description,
    required this.sheet,
  });
  final bool filterBlockedWords;
  final List<Comic> Function() comics;
  final String? description;
  final bool sheet;

  @override
  State<_KeywordReview> createState() => _KeywordReviewState();
}

class _ReviewEntry {
  _ReviewEntry(this.comic, this.filter, this.filterBlockedWords);
  final Comic comic;
  final ComicBlockFilter filter;
  final bool filterBlockedWords;
  late final author = filter.firstAuthorReason(comic);
  late final match = author == null && filterBlockedWords
      ? filter.keywordMatch(comic)
      : null;
}

class _KeywordReviewState extends State<_KeywordReview> {
  var _hidden = <_ReviewEntry>[];
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
    final filter = ComicBlockFilter.fromSettings(appdata.settings);
    final filterBlockedWords = widget.filterBlockedWords;
    final hidden = <_ReviewEntry>[];
    final comics = widget.comics();
    if (!_scanning) setState(() => _scanning = true);
    // Let the dialog paint, then yield in batches for large library scans.
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < comics.length; i++) {
      if (!mounted || generation != _generation) return;
      final comic = comics[i];
      if (filter.blocks(comic, filterBlockedWords: filterBlockedWords)) {
        hidden.add(_ReviewEntry(comic, filter, filterBlockedWords));
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
        : match == null || comicKeywordRuleEditor == null
        ? null
        : () => comicKeywordRuleEditor!(context, match.rule);
    final cover = Tooltip(
      message: 'Details'.tl,
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => openComicPage(
            context: context,
            id: comic.id,
            sourceKey: comic.sourceKey,
            cover: comic.cover,
            title: comic.title,
          ),
          child: SizedBox(
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
        ),
      ),
    );
    final title = match?.field == KeywordMatchField.title
        ? KeywordMatchPreview(match: match!)
        : Text(
            comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
    final explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (author != null) ...[
          Text('Author blocking'.tl),
          Text('Author: @a'.tlParams({'a': author})),
        ] else if (match != null) ...[
          Text('Matched in @a'.tlParams({'a': match.field.label})),
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
    );
    if (widget.sheet) {
      return MobileContentRow(
        key: ValueKey((comic.sourceKey, comic.id)),
        title: title,
        leading: cover,
        subtitle: explanation,
        onTap: edit,
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: edit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cover,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 8), explanation],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _explanation =>
      widget.description ?? 'Tap a matching reason to edit its rule.'.tl;

  String get _empty => 'No comics in this list are hidden by keywords.'.tl;

  Widget _sheet(BuildContext context) {
    // The header and empty/loading copy participate in this same scroll
    // view, including on a small phone at large text sizes. Do not replace
    // the primary controller when scan results arrive or a rule is edited.
    return CustomScrollView(
      primary: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Keyword filter reasons'.tl,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    MobileToolbarButton(
                      label: 'Close'.tl,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                Text(_explanation),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (_scanning || _hidden.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: _scanning
                  ? const CircularProgressIndicator()
                  : Text(_empty),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            sliver: SliverList.separated(
              itemCount: _hidden.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final entry = _hidden[index];
                return _reason(entry.comic, entry.match, entry.author);
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.sheet
      ? _sheet(context)
      : ContentDialog(
          title: 'Keyword filter reasons'.tl,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_explanation),
                const SizedBox(height: 8),
                SizedBox(
                  width: 560,
                  height: math.min(
                    400,
                    MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: _scanning
                      ? const Center(child: CircularProgressIndicator())
                      : _hidden.isEmpty
                      ? Center(child: Text(_empty))
                      : ListView.separated(
                          itemCount: _hidden.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final entry = _hidden[index];
                            return _reason(
                              entry.comic,
                              entry.match,
                              entry.author,
                            );
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
