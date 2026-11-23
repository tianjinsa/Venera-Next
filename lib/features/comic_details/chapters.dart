import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/layout.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/features/history/history_api.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class ComicChaptersView extends StatefulWidget {
  const ComicChaptersView({
    super.key,
    required this.chapters,
    this.history,
    required this.readChapter,
  });

  final ComicChapters chapters;

  final History? history;

  final void Function(int chapter) readChapter;

  @override
  State<ComicChaptersView> createState() => _ComicChaptersViewState();
}

class _ComicChaptersViewState extends SettingsSaveState<ComicChaptersView> {
  bool? _preview;
  int _request = 0;
  late bool _committed;

  bool get reverse => _preview ?? _committed;

  bool _readOrder() =>
      GlobalPreferenceStore(appdata.settings)
          .read(AppPreferences.reverseChapterOrder);

  @override
  void initState() {
    super.initState();
    _committed = _readOrder();
    appdata.settings.addListener(_refresh);
  }

  void _refresh() {
    final saved = _readOrder();
    if (!mounted || saved == _committed) return;
    final previous = reverse;
    _committed = saved;
    if (reverse != previous) setState(() {});
  }

  void _setReverse(bool value) {
    if (!acceptsSettingsChanges || value == reverse) return;
    final request = ++_request;
    setState(() => _preview = value);
    saveSetting(
      AppPreferences.reverseChapterOrder.key,
      () => appdata.updateSettings((draft) {
        GlobalPreferenceStore(draft)
            .write(AppPreferences.reverseChapterOrder, value);
      }),
      onSaved: () {
        if (request == _request) setState(() => _preview = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ChapterBody(
      chapters: widget.chapters,
      history: widget.history,
      readChapter: widget.readChapter,
      reverse: reverse,
      header: protectSettings(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Chapters".tl,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _ChapterOrderSegment(
                    reverse: reverse,
                    onChanged: _setReverse,
                  ),
                ],
              ),
              // A pending save used to insert a 42px spinner alongside the
              // segments. At phone widths it wrapped the entire header and
              // moved every visible chapter twice on one tap.
              SizedBox(
                height: 2,
                child: savingSettings
                    ? LinearProgressIndicator(semanticsLabel: 'Save'.tl)
                    : null,
              ),
              if (hasSettingsSaveError)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: acceptsSettingsChanges
                        ? retrySettingsSave
                        : null,
                    child: Text('Retry'.tl),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }
}

/// The same grid, extent, group tab and scroll position survive an order
/// reversal. Identity is (group, source chapter ID), not a display slot or
/// flattened reader index. IDs in different groups need not be unique.
class _ChapterBody extends StatefulWidget {
  const _ChapterBody({
    required this.chapters,
    required this.history,
    required this.readChapter,
    required this.reverse,
    required this.header,
  });
  final ComicChapters chapters;
  final History? history;
  final ValueChanged<int> readChapter;
  final bool reverse;
  final Widget header;

  @override
  State<_ChapterBody> createState() => _ChapterBodyState();
}

class _ChapterKey extends ValueKey<(String?, String)> {
  const _ChapterKey(super.value);
}

class _ChapterBodyState extends State<_ChapterBody>
    with TickerProviderStateMixin {
  TabController? _tabs;
  List<String> _groups = const [];
  int _groupIndex = 0;
  final _expanded = <String?>{};
  late Map<String, String> _entries;
  late List<String> _ids;
  late Map<String, int> _sourceIndex;
  late int _groupOffset;

  String? get _group => _groups.elementAtOrNull(_groupIndex);

  @override
  void initState() {
    super.initState();
    _loadTabs(initial: true);
    _loadGroup();
  }

  @override
  void didUpdateWidget(covariant _ChapterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chapters, widget.chapters)) {
      _loadTabs();
      _loadGroup();
    }
  }

  void _loadTabs({bool initial = false}) {
    final names = widget.chapters.groups.toList(growable: false);
    if (!initial && listEquals(_groups, names)) return;
    final previous = _group;
    _tabs?.removeListener(_onTab);
    _tabs?.dispose();
    _groups = names;
    _expanded.removeWhere((name) => name != null && !names.contains(name));
    _groupIndex = initial
        ? ((widget.history?.group ?? 1) - 1).clamp(
            0,
            math.max(0, names.length - 1),
          )
        : math.max(0, names.indexOf(previous ?? ''));
    // An empty grouped source has no valid tab; don't create a zero-length
    // AppTabBar or ask the source for its first group.
    _tabs = names.isEmpty
        ? null
        : (TabController(
            vsync: this,
            length: names.length,
            initialIndex: _groupIndex,
          )..addListener(_onTab));
  }

  void _onTab() {
    final next = _tabs?.index;
    if (next == null || next == _groupIndex) return;
    setState(() {
      _groupIndex = next;
      _loadGroup();
    });
  }

  // Make the selected group's source order indexable once, not by walking
  // a linked map and counting preceding groups for every visible cell.
  void _loadGroup() {
    final group = _group;
    final chapters = widget.chapters;
    _entries = group != null
        ? chapters.getGroup(group)
        : chapters.isGrouped
        ? const {}
        : chapters.allChapters;
    _ids = _entries.keys.toList(growable: false);
    _sourceIndex = {for (var i = 0; i < _ids.length; i++) _ids[i]: i};
    _groupOffset = 0;
    for (var i = 0; i < _groupIndex; i++) {
      _groupOffset += chapters.getGroup(_groups[i]).length;
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTab);
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final visited = widget.history?.readEpisode;
    final grouped = group != null;
    final count = _ids.length;
    final radius = BorderRadius.circular(grouped ? 12 : 16);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final slots = math.max(
          1,
          ((constraints.crossAxisExtent - 16) / 200).ceil(),
        );
        final length = _expanded.contains(group)
            ? count
            : math.min(count, slots * 8);
        int reorder(int i) => widget.reverse ? count - 1 - i : i;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(child: widget.header),
            if (_tabs case final tabs?) ...[
              SliverToBoxAdapter(
                child: AppTabBar(
                  withUnderLine: false,
                  controller: tabs,
                  tabs: [for (final name in _groups) Tab(text: name)],
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 8)),
            ],
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final source = reorder(i);
                  final id = _ids[source];
                  final readerIndex = _groupOffset + source + 1;
                  final read =
                      visited != null &&
                      (visited.contains('$readerIndex') ||
                          (grouped &&
                              visited.contains(
                                '${_groupIndex + 1}-${source + 1}',
                              )));
                  return Padding(
                    key: _ChapterKey((group, id)),
                    padding: const EdgeInsets.all(4),
                    child: Material(
                      color: grouped
                          ? context.colorScheme.surfaceContainerLow
                          : context.colorScheme.surfaceContainer,
                      borderRadius: radius,
                      child: ClickInkWell(
                        onTap: () => widget.readChapter(readerIndex),
                        borderRadius: radius,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: Text(
                              _entries[id]!,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: read
                                    ? context.colorScheme.outline
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: length,
                findChildIndexCallback: (key) {
                  if (key is! _ChapterKey || key.value.$1 != group) return null;
                  final source = _sourceIndex[key.value.$2];
                  if (source == null) return null;
                  final display = reorder(source);
                  return display < length ? display : null;
                },
              ),
              gridDelegate: const SliverGridDelegateWithFixedHeight(
                maxCrossAxisExtent: 250,
                itemHeight: 48,
              ),
            ).sliverPadding(const EdgeInsets.symmetric(horizontal: 8)),
            if (length < count)
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () => setState(() => _expanded.add(group)),
                    label: Text("${"Show all".tl} ($count)"),
                  ).paddingTop(12),
                ),
              ),
            const SliverToBoxAdapter(child: Divider()),
          ],
        );
      },
    );
  }
}

class _ChapterOrderSegment extends StatelessWidget {
  const _ChapterOrderSegment({required this.reverse, required this.onChanged});

  final bool reverse;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Order".tl,
      child: SegmentedButton<bool>(
        selected: {reverse},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        ),
        segments: [
          ButtonSegment<bool>(value: false, label: Text("Ascending".tl)),
          ButtonSegment<bool>(value: true, label: Text("Descending".tl)),
        ],
        onSelectionChanged: (selected) {
          onChanged(selected.first);
        },
      ),
    );
  }
}
