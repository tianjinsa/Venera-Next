import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/null_status.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:sliver_tools/sliver_tools.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/file_save_task.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/loading.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/mobile_choice.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_setting_row.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/global_state.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/routing/app_links.dart';
import 'package:venera_next/routing/settings.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'package:venera_next/features/comic_details/comic_details.dart';

import 'aggregated_search_page.dart';
import 'mobile_search_widgets.dart';
import 'search_result_page.dart';
import 'search_shortcuts.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.focusOnArrival = false});

  /// Global entry only. Results opened from a tag are for reading, not editing.
  final bool focusOnArrival;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchBarController controller;

  late List<String> searchSources;

  String searchTarget = "";

  List<SearchOptions> get _sourceOptions =>
      ComicSource.find(searchTarget)?.searchPageData?.searchOptions ?? [];

  bool aggregatedSearch = false;

  final focusNode = FocusNode();
  Animation<double>? _arrival;
  bool _requestedFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.focusOnArrival || _requestedFocus) return;
    final next = ModalRoute.of(context)?.animation;
    if (_arrival != next) {
      _arrival?.removeStatusListener(_onArrival);
      _arrival = next;
      next?.addStatusListener(_onArrival);
    }
    _onArrival(next?.status ?? AnimationStatus.completed);
  }

  void _onArrival(AnimationStatus status) {
    if (_requestedFocus || status != AnimationStatus.completed) return;
    _requestedFocus = true;
    _arrival?.removeStatusListener(_onArrival);
    // Do not make keyboard insets resize the expanding page, or request
    // input/a11y focus if the push was cancelled or there is no search field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          searchSources.isNotEmpty &&
          !MediaQuery.accessibleNavigationOf(context) &&
          ModalRoute.isCurrentOf(context) == true) {
        focusNode.requestFocus();
      }
    });
  }

  var options = <String>[];

  void update() {
    setState(() {});
  }

  void search([String? text, BuildContext? origin]) {
    final keyword = text ?? controller.text;
    final source = searchTarget;
    final parameters = List<String>.of(options);
    final combine = aggregatedSearch;
    if (!combine && ComicSource.find(source)?.searchPageData == null) return;
    Widget destination() => combine
        ? AggregatedSearchPage(keyword: keyword)
        : SearchResultPage(
            text: keyword,
            sourceKey: source,
            options: parameters,
          );
    final returning = origin == null
        ? context.to<void>(destination)
        : pushSearchFrom<void>(origin, destination);
    returning.then((_) {
      if (mounted) update();
    });
  }

  var suggestions = <Pair<String, TranslationType>>[];

  bool canHandleUrl(String text) {
    if (!text.isURL) return false;
    for (var source in ComicSource.all()) {
      if (source.linkHandler != null) {
        var uri = Uri.parse(text);
        if (source.linkHandler!.domains.contains(uri.host)) {
          return true;
        }
      }
    }
    return false;
  }

  void findSuggestions() {
    var text = controller.text.split(" ").last;
    var suggestions = this.suggestions;

    suggestions.clear();

    if (canHandleUrl(controller.text)) {
      suggestions.add(Pair("**URL**", TranslationType.other));
    } else {
      var text = controller.text;

      for (var comicSource in ComicSource.all()) {
        if (comicSource.idMatcher?.hasMatch(text) ?? false) {
          suggestions.add(
            Pair("**${comicSource.key}**", TranslationType.other),
          );
        }
      }
    }

    if (ComicSource.find(searchTarget)?.enableTagsSuggestions != true) {
      update();
      return;
    }

    bool check(String text, String key, String value) {
      if (text.removeAllBlank == "") {
        return false;
      }
      if (key.length >= text.length && key.substring(0, text.length) == text ||
          (key.contains(" ") &&
              key.split(" ").last.length >= text.length &&
              key.split(" ").last.substring(0, text.length) == text)) {
        return true;
      } else if (value.length >= text.length && value.contains(text)) {
        return true;
      }
      return false;
    }

    void find(Map<String, String> map, TranslationType type) {
      for (var element in map.entries) {
        if (suggestions.length > 100) {
          break;
        }
        if (check(text, element.key, element.value)) {
          suggestions.add(Pair(element.key, type));
        }
      }
    }

    find(TagsTranslation.femaleTags, TranslationType.female);
    find(TagsTranslation.maleTags, TranslationType.male);
    find(TagsTranslation.parodyTags, TranslationType.parody);
    find(TagsTranslation.characterTranslations, TranslationType.character);
    find(TagsTranslation.otherTags, TranslationType.other);
    find(TagsTranslation.mixedTags, TranslationType.mixed);
    find(TagsTranslation.languageTranslations, TranslationType.language);
    find(TagsTranslation.artistTags, TranslationType.artist);
    find(TagsTranslation.groupTags, TranslationType.group);
    find(TagsTranslation.cosplayerTags, TranslationType.cosplayer);
    update();
  }

  @override
  void initState() {
    findSearchSources();
    var defaultSearchTarget = GlobalPreferenceStore(appdata.settings)
        .read(DiscoveryPreferences.defaultSearchTarget);
    if (defaultSearchTarget == "_aggregated_") {
      aggregatedSearch = true;
    } else if (defaultSearchTarget != null &&
        searchSources.contains(defaultSearchTarget)) {
      searchTarget = defaultSearchTarget;
    }
    controller = SearchBarController(onSearch: search);
    appdata.settings.addListener(updateSearchSourcesIfNeeded);
    super.initState();
  }

  @override
  void dispose() {
    _arrival?.removeStatusListener(_onArrival);
    focusNode.dispose();
    appdata.settings.removeListener(updateSearchSourcesIfNeeded);
    super.dispose();
  }

  void findSearchSources() {
    var all = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings =
        GlobalPreferenceStore(appdata.settings)
            .read(DiscoveryPreferences.searchSources) ??
        const <String>[];
    var sources = <String>[];
    for (var source in settings) {
      if (all.contains(source)) {
        sources.add(source);
      }
    }
    searchSources = sources;
    if (!searchSources.contains(searchTarget)) {
      searchTarget = searchSources.firstOrNull ?? "";
    }
  }

  void updateSearchSourcesIfNeeded() {
    var old = searchSources;
    final oldTarget = searchTarget;
    findSearchSources();
    if (old.isEqualTo(searchSources)) {
      return;
    }
    if (oldTarget != searchTarget) options = [];
    setState(() {});
  }

  void manageSearchSources() {
    showPopUpWidget(appNavigation.rootContext, setSearchSourcesWidget());
  }

  Widget buildEmpty() {
    final title = 'No Search Sources'.tl;
    final description = ComicSource.isEmpty
        ? 'Please add some sources'.tl
        : 'Please check your settings'.tl;
    VoidCallback onTap;
    if (ComicSource.isEmpty) {
      onTap = () {
        context.to(() => ComicSourcePage());
      };
    } else {
      onTap = manageSearchSources;
    }
    if (MobileUi.enabledOf(context)) {
      return Scaffold(
        body: Column(
          children: [
            MobileToolbar(title: Text('Search'.tl), showBack: true),
            Expanded(
              child: prism.NullStatus(
                illustration: prism.Illustration.search,
                label: title,
                description: description,
                action: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    prism.FilledButton(
                      onPressed: onTap,
                      child: Text('Manage'.tl),
                    ),
                    prism.TextButton(
                      onPressed: () => saveFileForWindow(
                        context,
                        data: utf8.encode(Log().toString()),
                        filename: 'log.txt',
                      ),
                      child: Text('Export logs'.tl),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return NetworkError(
      message: '$title\n$description',
      retry: onTap,
      withAppbar: true,
      buttonText: "Manage".tl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchSources.isEmpty) {
      return buildEmpty();
    }
    return Scaffold(
      body: SmoothCustomScrollView(slivers: buildSlivers().toList()),
    );
  }

  Iterable<Widget> buildSlivers() sync* {
    yield SliverSearchBar(
      controller: controller,
      onSubmitFrom: (value, origin) => search(value, origin),
      onChanged: (s) {
        findSuggestions();
      },
      focusNode: focusNode,
    );
    if (suggestions.isNotEmpty) {
      yield buildSuggestions(context);
    } else {
      yield buildSearchTarget();
      yield SliverAnimatedPaintExtent(
        duration: const Duration(milliseconds: 200),
        child: buildSearchOptions(),
      );
      yield const SearchShortcutsSliver();
      yield _SearchHistory(search);
    }
  }

  Widget buildSearchTarget() {
    final sources = searchSources.map(ComicSource.find).nonNulls;
    if (MobileUi.enabledOf(context)) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              MobileSearchSectionHeader(
                'Search in'.tl,
                leading: const prism.GlyphIcon(prism.Glyphs.search, size: 20),
                action: MobileToolbarButton(
                  label: 'Search Sources'.tl,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: manageSearchSources,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in sources)
                    MobileSearchChoiceChip(
                      key: ValueKey(source.key),
                      label: source.name,
                      selected: aggregatedSearch || searchTarget == source.key,
                      onPressed: aggregatedSearch
                          ? null
                          : () => setState(() {
                              searchTarget = source.key;
                              useDefaultOptions();
                            }),
                    ),
                ],
              ),
              SettingSwitchRow(
                title: Text('Aggregated Search'.tl),
                value: aggregatedSearch,
                onChanged: (value) => setState(() => aggregatedSearch = value),
              ),
            ],
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text("Search in".tl),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: manageSearchSources,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources.map((e) {
                return OptionChip(
                  text: e.name,
                  isSelected: searchTarget == e.key || aggregatedSearch,
                  onTap: () {
                    if (aggregatedSearch) return;
                    setState(() {
                      searchTarget = e.key;
                      useDefaultOptions();
                    });
                  },
                );
              }).toList(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Aggregated Search".tl),
              leading: Checkbox(
                value: aggregatedSearch,
                onChanged: (value) {
                  setState(() {
                    aggregatedSearch = value ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void useDefaultOptions() {
    options = _sourceOptions.map((e) => e.defaultValue).toList();
  }

  Widget buildSearchOptions() {
    if (aggregatedSearch) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    var children = <Widget>[];

    final searchOptions = _sourceOptions;
    if (searchOptions.length != options.length) {
      useDefaultOptions();
    }
    if (searchOptions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(
        SearchOptionWidget(
          key: ValueKey((searchTarget, i)),
          option: option,
          value: options[i],
          onChanged: (value) {
            options[i] = value;
            update();
          },
          sourceKey: searchTarget,
        ),
      );
    }

    if (MobileUi.enabledOf(context)) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Column(children: settingGroup(context, children)),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget buildSuggestions(BuildContext context) {
    bool check(String text, String key, String value) {
      if (text.removeAllBlank == "") {
        return false;
      }
      if (key.length >= text.length && key.substring(0, text.length) == text ||
          (key.contains(" ") &&
              key.split(" ").last.length >= text.length &&
              key.split(" ").last.substring(0, text.length) == text)) {
        return true;
      } else if (value.length >= text.length && value.contains(text)) {
        return true;
      }
      return false;
    }

    void onSelected(String text, TranslationType? type) {
      var words = controller.text.split(" ");
      if (words.length >= 2 &&
          check(
            "${words[words.length - 2]} ${words[words.length - 1]}",
            text,
            text.translateTagsToCN,
          )) {
        controller.text = controller.text.replaceLast(
          "${words[words.length - 2]} ${words[words.length - 1]}",
          "",
        );
      } else {
        controller.text = controller.text.replaceLast(
          words[words.length - 1],
          "",
        );
      }
      final source = ComicSource.find(searchTarget);
      String insert;
      if (source?.onTagSuggestionSelected != null) {
        insert = source!.onTagSuggestionSelected!(type?.name ?? '', text);
      } else {
        var t = text;
        if (t.contains(' ')) t = "'$t'";
        insert = type != null ? "${type.name}:$t" : t;
      }
      controller.text += "$insert ";
      suggestions.clear();
      update();
      focusNode.requestFocus();
    }

    final mobile = MobileUi.enabledOf(context);
    final showMethod = MediaQuery.sizeOf(context).width < 600;
    final showTranslation = appLocale.languageCode == 'zh';
    void clear() => setState(suggestions.clear);

    Widget buildItem(Pair<String, TranslationType> value) {
      if (value.left == "**URL**") {
        void openLink() {
          clear();
          handleAppLink(Uri.parse(controller.text));
        }

        if (mobile) {
          return MobileSearchRow(
            title: 'Open link'.tl,
            subtitle: controller.text,
            leading: const Icon(Icons.link, size: 20),
            trailing: const SettingDisclosure(),
            onTap: openLink,
          );
        }
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text("Open link".tl),
          subtitle: Text(
            controller.text,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
          trailing: const Icon(Icons.arrow_right),
          onTap: openLink,
        );
      }

      if (RegExp(r"^\*\*.*\*\*$").hasMatch(value.left)) {
        var key = value.left.substring(2, value.left.length - 2);
        var comicSource = ComicSource.find(key);
        if (comicSource == null) {
          return const SizedBox();
        }
        final title = '${'Open comic'.tl}: ${comicSource.name}';
        void openComic() =>
            context.to(() => ComicPage(sourceKey: key, id: controller.text));
        if (mobile) {
          return MobileSearchRow(
            title: title,
            subtitle: controller.text,
            leading: const Icon(Icons.link, size: 20),
            trailing: const SettingDisclosure(),
            onTap: openComic,
          );
        }
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(title),
          subtitle: Text(
            controller.text,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
          trailing: const Icon(Icons.arrow_right),
          onTap: openComic,
        );
      }

      var subTitle = TagsTranslation.translationTagWithNamespace(
        value.left,
        value.right.name,
      );
      if (mobile) {
        return MobileSearchTagSuggestion(
          tag: value.left,
          namespace: value.right.name,
          translation: showTranslation ? subTitle : null,
          onSelected: () => onSelected(value.left, value.right),
        );
      }
      return ListTile(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Text(value.left)),
            if (!showMethod) const SizedBox(width: 12),
            if (!showMethod && showTranslation)
              Text(
                subTitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
        subtitle: (showMethod && showTranslation) ? Text(subTitle) : null,
        trailing: Text(value.right.name, style: const TextStyle(fontSize: 13)),
        onTap: () => onSelected(value.left, value.right),
      );
    }

    final slivers = SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: mobile
              ? MobileSearchSectionHeader(
                  'Suggestions'.tl,
                  leading: const Icon(Icons.hub_outlined, size: 20),
                  action: MobileToolbarButton(
                    label: 'Clear'.tl,
                    icon: const prism.GlyphIcon(prism.Glyphs.clearField),
                    onPressed: clear,
                  ),
                )
              : ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text("Suggestions".tl),
                  trailing: Tooltip(
                    message: "Clear".tl,
                    child: IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: clear,
                    ),
                  ),
                ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = buildItem(suggestions[index]);
            return mobile
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: item,
                  )
                : item;
          }, childCount: suggestions.length),
        ),
      ],
    );
    return mobile ? slivers.sliverPaddingHorizontal(16) : slivers;
  }
}

class SearchOptionWidget extends StatelessWidget {
  const SearchOptionWidget({
    super.key,
    required this.option,
    required this.value,
    required this.onChanged,
    required this.sourceKey,
  });

  final SearchOptions option;

  final String value;

  final void Function(String) onChanged;

  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    if (MobileUi.enabledOf(context)) {
      final label = option.label.ts(sourceKey);
      if (option.type == 'select' || option.type == 'dropdown') {
        return SettingChoiceRow(
          title: Text(label),
          choice: MobileChoice<String>(
            key: ValueKey((sourceKey, option.label)),
            label: label,
            value: value,
            options: [
              for (final entry in option.options.entries)
                MobileChoiceOption(entry.key, entry.value.ts(sourceKey)),
            ],
            setting: true,
            onChanged: onChanged,
          ),
        );
      }
      if (option.type == 'multi-select') {
        final values = (jsonDecode(value) as List).whereType<String>().toList();
        return SettingRow(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(label),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in option.options.entries)
                    MobileSearchChoiceChip(
                      key: ValueKey(entry.key),
                      label: entry.value.ts(sourceKey),
                      selected: values.contains(entry.key),
                      onPressed: () {
                        final edited = List<String>.of(values);
                        if (!edited.remove(entry.key)) edited.add(entry.key);
                        onChanged(jsonEncode(edited));
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      }
      return SettingRow(title: Text(label));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(option.label.ts(sourceKey)),
        ),
        if (option.type == 'select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: value == e.key,
                onTap: () {
                  onChanged(e.key);
                },
              );
            }).toList(),
          ),
        if (option.type == 'multi-select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: (jsonDecode(value) as List).contains(e.key),
                onTap: () {
                  var list = jsonDecode(value) as List;
                  if (list.contains(e.key)) {
                    list.remove(e.key);
                  } else {
                    list.add(e.key);
                  }
                  onChanged(jsonEncode(list));
                },
              );
            }).toList(),
          ),
        if (option.type == 'dropdown')
          Select(
            current: option.options[value],
            values: option.options.values.toList(),
            onTap: (index) {
              onChanged(option.options.keys.elementAt(index));
            },
            minWidth: 96,
          ),
      ],
    );
  }
}

class _SearchHistory extends StatefulWidget {
  const _SearchHistory(this.search);

  final void Function(String, [BuildContext?]) search;

  @override
  State<_SearchHistory> createState() => _SearchHistoryState();
}

class _SearchHistoryState extends State<_SearchHistory> {
  bool _saving = false;

  Future<bool> _editHistory(Future<void> Function() edit) async {
    if (_saving || !mounted) return false;
    setState(() => _saving = true);
    try {
      await edit();
      return true;
    } catch (error, stack) {
      Log.error('Search history', error, stack);
      if (mounted) context.showMessage(message: error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MobileUi.enabledOf(context)) {
      return _buildMobile();
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return const SizedBox(height: 16);
        }
        if (index == 1) {
          return ListTile(
            leading: const Icon(Icons.history),
            contentPadding: EdgeInsets.zero,
            title: Text("Search History".tl),
            trailing: Flyout(
              flyoutBuilder: (context) {
                var saving = false;
                return StatefulBuilder(
                  builder: (context, update) => FlyoutContent(
                    title: "Clear Search History".tl,
                    actions: [
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final route = ModalRoute.of(context);
                                update(() => saving = true);
                                final saved = await _editHistory(
                                  appdata.clearSearchHistory,
                                );
                                if (saved &&
                                    context.mounted &&
                                    route?.isCurrent != false) {
                                  context.pop();
                                }
                                if (context.mounted) {
                                  update(() => saving = false);
                                }
                              },
                        child: saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text("Clear".tl),
                      ),
                    ],
                  ),
                );
              },
              child: Builder(
                builder: (context) {
                  return Tooltip(
                    message: "Clear".tl,
                    child: IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: () {
                        context.findAncestorStateOfType<FlyoutState>()!.show();
                      },
                    ),
                  );
                },
              ),
            ),
          );
        }
        return buildItem(index - 2);
      }, childCount: 2 + appdata.searchHistory.length),
    ).sliverPaddingHorizontal(16);
  }

  Widget _buildMobile() {
    final words = appdata.searchHistory;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: MobileSearchSectionHeader(
              'Search History'.tl,
              leading: const Icon(Icons.history, size: 20),
              action: words.isEmpty || _saving
                  ? null
                  : MobileMenuButton(
                      label: 'Clear'.tl,
                      icon: const prism.GlyphIcon(prism.Glyphs.clearField),
                      items: [
                        prism.PopupMenuItem(
                          label: 'Clear Search History'.tl,
                          danger: true,
                          onPressed: () =>
                              _editHistory(appdata.clearSearchHistory),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: words.length,
          itemBuilder: (context, index) => _mobileItem(words[index]),
        ),
        const SliverToBoxAdapter(
          child: SafeArea(top: false, child: SizedBox(height: 12)),
        ),
      ],
    ).sliverPaddingHorizontal(16);
  }

  Widget _mobileItem(String keyword) => Padding(
    key: ValueKey(keyword),
    padding: const EdgeInsets.only(bottom: 6),
    child: MobileSearchMenuRow(
      title: keyword,
      leading: const Icon(Icons.history, size: 20),
      onSearch: (origin) => widget.search(keyword, origin),
      items: [
        prism.PopupMenuItem(
          label: 'Copy'.tl,
          glyph: prism.Glyphs.copy,
          onPressed: () => Clipboard.setData(ClipboardData(text: keyword)),
        ),
        prism.PopupMenuItem(
          label: 'Delete'.tl,
          danger: true,
          onPressed: _saving
              ? null
              : () => _editHistory(() => appdata.removeSearchHistory(keyword)),
        ),
      ],
    ),
  );

  Widget buildItem(int index) {
    final keyword = appdata.searchHistory[index];
    void showMenu(
      BuildContext context,
      MenuRouteController menus,
      Offset offset,
    ) {
      menus.show(context, offset, [
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy'.tl,
          onClick: () {
            Clipboard.setData(ClipboardData(text: keyword));
          },
        ),
        MenuEntry(
          icon: Icons.delete,
          text: 'Delete'.tl,
          onClick: () async {
            await _editHistory(() => appdata.removeSearchHistory(keyword));
          },
        ),
      ]);
    }

    return ContextMenuRegion(
      identity: keyword,
      builder: (context, menus) {
        return ClickInkWell(
          onTap: () {
            widget.search(keyword);
          },
          onLongPress: () {
            var renderBox = context.findRenderObject() as RenderBox;
            var offset = renderBox.localToGlobal(Offset.zero);
            showMenu(
              context,
              menus,
              Offset(
                offset.dx + renderBox.size.width / 2 - 121,
                offset.dy + renderBox.size.height - 8,
              ),
            );
          },
          onSecondaryTapUp: (details) {
            showMenu(context, menus, details.globalPosition);
          },
          child: Container(
            decoration: BoxDecoration(
              // color: context.colorScheme.surfaceContainer,
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(keyword, style: ts.s14),
          ),
        ).paddingBottom(8).paddingHorizontal(4);
      },
    );
  }
}
