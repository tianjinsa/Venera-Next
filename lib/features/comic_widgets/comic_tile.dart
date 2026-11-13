import 'comic_blocking.dart';
import 'dart:math' as math;
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/keyword_settings_store.dart';
import 'package:venera_next/foundation/keyword_rule.dart';
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/components/settings_save_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/image.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/features/comic_source/comic_source_api.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'rating.dart';

typedef ComicPageBuilder =
    Widget Function({
      required String id,
      required String sourceKey,
      String? cover,
      String? title,
      int? heroID,
    });

typedef AddComicFavoriteHandler =
    Future<void> Function(BuildContext context, List<Comic> comics);
typedef ComicTileStateResolver = ComicTileState Function(Comic comic);
typedef ComicTileImageProviderResolver = ImageProvider? Function(Comic comic);
typedef ComicWidgetListenerRegistrar = void Function(VoidCallback listener);
typedef ComicFavoriteDisplayStateResolver =
    ComicFavoriteDisplayState Function();
typedef ComicKeywordRuleEditor =
    Future<void> Function(BuildContext context, KeywordRule rule);

typedef ComicAuthorRuleEditor =
    Future<void> Function(BuildContext context, String author);

class ComicTileState {
  const ComicTileState({
    this.isFavorite = false,
    this.historyPage,
    this.historyMaxPage,
    this.historyDescription,
    this.historyTooltipDescription,
    this.historyCompactDescription,
    this.descriptionOverride,
    this.hasNewUpdate = false,
  });

  final bool isFavorite;
  final int? historyPage;
  final int? historyMaxPage;
  final String? historyDescription;
  final String? historyTooltipDescription;
  final String? historyCompactDescription;
  final String? descriptionOverride;
  final bool hasNewUpdate;
}

class ComicFavoriteDisplayState {
  const ComicFavoriteDisplayState({
    this.isGallery = false,
    this.galleryColumns,
  });

  final bool isGallery;
  final int? galleryColumns;
}

ComicPageBuilder? _comicPageBuilder;

AddComicFavoriteHandler? _addComicFavoriteHandler;
ComicTileStateResolver? _comicTileStateResolver;
ComicTileImageProviderResolver? _comicTileImageProviderResolver;
ComicWidgetListenerRegistrar? _addComicWidgetStateListener;
ComicWidgetListenerRegistrar? _removeComicWidgetStateListener;
ComicFavoriteDisplayStateResolver? _comicFavoriteDisplayStateResolver;
ComicKeywordRuleEditor? _comicKeywordRuleEditor;
ComicAuthorRuleEditor? _comicAuthorRuleEditor;

void configureComicWidgets({
  ComicPageBuilder? comicPageBuilder,
  AddComicFavoriteHandler? addFavorite,
  ComicTileStateResolver? tileStateResolver,
  ComicTileImageProviderResolver? tileImageProviderResolver,
  ComicWidgetListenerRegistrar? addStateListener,
  ComicWidgetListenerRegistrar? removeStateListener,
  ComicFavoriteDisplayStateResolver? favoriteDisplayStateResolver,
  ComicKeywordRuleEditor? keywordRuleEditor,
  ComicAuthorRuleEditor? authorRuleEditor,
}) {
  _comicPageBuilder = comicPageBuilder;
  _addComicFavoriteHandler = addFavorite;
  _comicTileStateResolver = tileStateResolver;
  _comicTileImageProviderResolver = tileImageProviderResolver;
  _addComicWidgetStateListener = addStateListener;
  _removeComicWidgetStateListener = removeStateListener;
  _comicFavoriteDisplayStateResolver = favoriteDisplayStateResolver;
  _comicKeywordRuleEditor = keywordRuleEditor;
  _comicAuthorRuleEditor = authorRuleEditor;
}

ComicKeywordRuleEditor? get comicKeywordRuleEditor => _comicKeywordRuleEditor;
ComicAuthorRuleEditor? get comicAuthorRuleEditor => _comicAuthorRuleEditor;

void addComicWidgetStateListener(VoidCallback listener) {
  _addComicWidgetStateListener?.call(listener);
}

void removeComicWidgetStateListener(VoidCallback listener) {
  _removeComicWidgetStateListener?.call(listener);
}

ComicFavoriteDisplayState comicFavoriteDisplayState() {
  return _comicFavoriteDisplayStateResolver?.call() ??
      const ComicFavoriteDisplayState();
}

Widget _buildComicPage({
  required String id,
  required String sourceKey,
  String? cover,
  String? title,
  int? heroID,
}) {
  final builder =
      _comicPageBuilder ??
      (throw StateError("Comic page builder is not configured."));
  return builder(
    id: id,
    sourceKey: sourceKey,
    cover: cover,
    title: title,
    heroID: heroID,
  );
}

/// Open the configured detail page in the supplied navigation context.
void openComicPage({
  BuildContext? context,
  required String id,
  required String sourceKey,
  String? cover,
  String? title,
  int? heroID,
}) {
  final targetContext =
      context ?? appNavigation.mainNavigatorKey?.currentContext;
  targetContext?.to(
    () => _buildComicPage(
      id: id,
      sourceKey: sourceKey,
      cover: cover,
      title: title,
      heroID: heroID,
    ),
  );
}

Future<void> _addComicToFavorites(BuildContext context, List<Comic> comics) {
  final handler =
      _addComicFavoriteHandler ??
      (throw StateError("Add comic favorite handler is not configured."));
  return handler(context, comics);
}

ImageProvider? _findImageProvider(Comic comic) {
  return _comicTileImageProviderResolver?.call(comic);
}

ComicTileState _tileState(Comic comic) {
  return _comicTileStateResolver?.call(comic) ?? const ComicTileState();
}

Widget _buildUpdateBadge(BuildContext context, {double size = 24}) {
  return Container(
    height: size,
    width: size,
    color: Colors.deepOrange.shade700,
    child: Icon(Icons.update, size: size * 2 / 3, color: Colors.white),
  );
}

enum ComicTileDisplayMode { detailed, gallery }

class ComicTile extends StatelessWidget {
  const ComicTile({
    super.key,
    required this.comic,
    this.enableLongPressed = true,
    this.badge,
    this.menuOptions,
    this.onTap,
    this.onLongPressed,
    this.onBlocked,
    this.heroID,
    this.displayMode,
  });

  final Comic comic;

  final bool enableLongPressed;

  final String? badge;

  final List<MenuEntry>? menuOptions;

  final VoidCallback? onTap;

  final VoidCallback? onLongPressed;

  final VoidCallback? onBlocked;

  final int? heroID;

  final ComicTileDisplayMode? displayMode;

  void _onTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    openComicPage(
      context: context,
      id: comic.id,
      sourceKey: comic.sourceKey,
      cover: comic.cover,
      title: comic.title,
      heroID: heroID,
    );
  }

  void _onLongPressed(BuildContext context) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    onLongPress(context);
  }

  void onLongPress(BuildContext context) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    ContextMenuRegion.of(context).show(context, location, [
      MenuEntry(
        icon: Icons.chrome_reader_mode_outlined,
        text: 'Details'.tl,
        onClick: () {
          openComicPage(
            id: comic.id,
            sourceKey: comic.sourceKey,
            cover: comic.cover,
            title: comic.title,
          );
        },
      ),
      MenuEntry(
        icon: Icons.copy,
        text: 'Copy Title'.tl,
        onClick: () {
          Clipboard.setData(ClipboardData(text: comic.title));
          appNavigation.rootContext.showMessage(message: 'Title copied'.tl);
        },
      ),
      MenuEntry(
        icon: Icons.stars_outlined,
        text: 'Add to favorites'.tl,
        onClick: () {
          _addComicToFavorites(context, [comic]);
        },
      ),
      MenuEntry(
        icon: Icons.block,
        text: 'Block'.tl,
        onClick: () => block(context),
      ),
      for (final author in ComicBlockFilter.authorsOf(comic))
        MenuEntry(
          icon: Icons.person_off_outlined,
          text: 'Author: @a'.tlParams({'a': author}),
          onClick: () async {
            if (!NavigationAdmission.allows(context)) return;
            try {
              await appdata.updateSettings((draft) {
                final preferences = GlobalPreferenceStore(draft);
                final authors =
                    preferences.read(KeywordPreferences.authors).toSet()
                      ..add(author);
                preferences.write(KeywordPreferences.authors, authors.toList());
              });
              if (context.mounted) {
                onBlocked?.call();
                context.showMessage(message: 'Blocked'.tl);
              }
            } catch (error) {
              if (context.mounted) {
                context.showMessage(message: error.toString());
              }
            }
          },
        ),
      ...?menuOptions,
    ]);
  }

  @override
  Widget build(BuildContext context) => ContextMenuRegion(
    identity: comic,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final state = _tileState(comic);
    final type = switch (displayMode) {
      ComicTileDisplayMode.detailed => 'detailed',
      ComicTileDisplayMode.gallery => 'gallery',
      null => GlobalPreferenceStore(
        appdata.settings,
      ).read(DiscoveryPreferences.comicDisplayMode),
    };

    Widget child = switch (type) {
      'detailed' => _buildDetailedMode(context, state),
      'gallery' => _buildGalleryMode(context),
      _ => _buildBriefMode(context, state),
    };

    final historyPage = state.historyPage == 0 ? 1 : state.historyPage;
    if (!state.isFavorite && historyPage == null && !state.hasNewUpdate) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = type == 'gallery' && constraints.maxWidth < 88;
        // Keep all statuses on the cover, including at narrow grid widths.
        return Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: type == 'detailed' ? 16 : (compact ? 4 : 6),
              top: compact ? 6 : 8,
              right: type == 'detailed'
                  ? math.max(
                      16.0,
                      constraints.maxWidth -
                          16 -
                          (constraints.maxHeight - 16) * 0.68,
                    )
                  : (compact ? 4 : 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isFavorite)
                        const SizedBox.square(
                          dimension: 24,
                          child: ColoredBox(
                            color: Colors.green,
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (historyPage != null)
                        _ReadingHistoryBadge(
                          page: historyPage,
                          maxPage: state.historyMaxPage,
                          description:
                              state.historyTooltipDescription ??
                              state.historyDescription,
                        ),
                      if (state.hasNewUpdate) _buildUpdateBadge(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildImage(BuildContext context) {
    var image = _findImageProvider(comic);
    if (image == null) {
      return const SizedBox();
    }
    final detailed =
        displayMode == ComicTileDisplayMode.detailed ||
        (displayMode == null &&
            GlobalPreferenceStore(
                  appdata.settings,
                ).read(DiscoveryPreferences.comicDisplayMode) ==
                'detailed');
    return AnimatedImage(
      image: ResizeImage(
        image,
        width: detailed ? 320 : 384,
        height: detailed ? 384 : 512,
        policy: ResizeImagePolicy.fit,
      ),
      gaplessPlayback: true,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildDetailedMode(BuildContext context, ComicTileState state) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final height = constrains.maxHeight - 16;

        Widget image = Container(
          width: height * 0.68,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: context.colorScheme.outlineVariant,
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: buildImage(context),
        );

        if (heroID != null) {
          image = Hero(tag: "cover$heroID", child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onTap(context),
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(size: const Size(16, 5)),
                Expanded(
                  child: _ComicDescription(
                    title: comic.maxPage == null
                        ? comic.title.replaceAll("\n", "")
                        : "[${comic.maxPage}P]${comic.title.replaceAll("\n", "")}",
                    subtitle: comic.subtitle ?? '',
                    description: state.descriptionOverride ?? comic.description,
                    descriptionTooltip:
                        state.historyTooltipDescription ??
                        state.descriptionOverride,
                    badge: badge ?? comic.language,
                    tags: comic.tags,
                    maxLines: 2,
                    enableTranslate:
                        ComicSource.find(
                          comic.sourceKey,
                        )?.enableTagsTranslate ??
                        false,
                    rating: comic.stars,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBriefMode(BuildContext context, ComicTileState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget image = Container(
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: buildImage(context),
        );

        if (heroID != null) {
          image = Hero(tag: "cover$heroID", child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onTap(context),
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: image),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: (() {
                        final subtitle = comic.subtitle
                            ?.replaceAll('\n', '')
                            .trim();
                        final description = state.descriptionOverride == null
                            ? comic.description
                            : state.historyCompactDescription ??
                                  state.descriptionOverride!;
                        final text = description.isNotEmpty
                            ? description.split('|').join('\n')
                            : (subtitle?.isNotEmpty == true ? subtitle : null);
                        final fortSize = constraints.maxWidth < 80
                            ? 8.0
                            : constraints.maxWidth < 150
                            ? 10.0
                            : 12.0;

                        if (text == null) {
                          return const SizedBox();
                        }

                        var children = <Widget>[];
                        var lines = text.split('\n');
                        lines.removeWhere((e) => e.trim().isEmpty);
                        if (lines.length > 3) {
                          lines = lines.sublist(0, 3);
                        }
                        for (var line in lines) {
                          children.add(
                            Container(
                              margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                              padding: constraints.maxWidth < 80
                                  ? const EdgeInsets.fromLTRB(3, 1, 3, 1)
                                  : constraints.maxWidth < 150
                                  ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
                                  : const EdgeInsets.fromLTRB(5, 2, 5, 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.toOpacity(0.5),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: Text(
                                line,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: fortSize,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }
                        final labels = Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: children,
                        );
                        if (state.descriptionOverride == null) return labels;
                        final tooltip =
                            state.historyTooltipDescription ??
                            state.descriptionOverride!;
                        return Tooltip(
                          message: tooltip,
                          child: Semantics(
                            label: tooltip,
                            excludeSemantics: true,
                            child: labels,
                          ),
                        );
                      })(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  comic.title.replaceAll('\n', ''),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ).paddingHorizontal(6).paddingVertical(8),
        );
      },
    );
  }

  Widget _buildGalleryMode(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 88;
        Widget image = Container(
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.16),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: buildImage(context),
        );

        if (heroID != null) {
          image = Hero(tag: 'cover$heroID', child: image);
        }

        return ClickInkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onTap(context),
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(4, 5, 4, 4)
                : const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: image),
                SizedBox(height: compact ? 3 : 5),
                SizedBox(
                  height: compact ? 24 : 36,
                  child: Text(
                    comic.title.replaceAll('\n', ''),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _splitText(String text) {
    // split text by comma, brackets
    var words = <String>[];
    var buffer = StringBuffer();
    var inBracket = false;
    String? prevBracket;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (c == '[' || c == '(') {
        if (inBracket) {
          buffer.write(c);
        } else {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = true;
          prevBracket = c;
        }
      } else if (c == ']' || c == ')') {
        if (prevBracket == '[' && c == ']' || prevBracket == '(' && c == ')') {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = false;
        } else {
          buffer.write(c);
        }
      } else if (c == ',') {
        if (inBracket) {
          buffer.write(c);
        } else {
          words.add(buffer.toString().trim());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) {
      words.add(buffer.toString().trim());
    }
    words.removeWhere((element) => element == "");
    words = words.toSet().toList();
    return words;
  }

  void block(BuildContext comicTileContext) {
    if (!NavigationAdmission.allows(comicTileContext)) return;
    final owner = comicTileContext.widget;
    final route = ModalRoute.of(comicTileContext);
    bool ownerCurrent() =>
        comicTileContext.mounted &&
        identical(comicTileContext.widget, owner) &&
        (route == null || route.isActive) &&
        NavigationAdmission.allows(comicTileContext);
    final tags = List<String>.of(comic.tags ?? const []);
    final words = [
      ..._splitText(comic.title),
      if (comic.subtitle != null && comic.subtitle != '') comic.subtitle!,
      ...tags,
    ];
    final work = comicTileContext
        .getInheritedWidgetOfExactType<SettingsSaveScope>()
        ?.work;
    showDialog<void>(
      context: comicTileContext,
      builder: (_) {
        final dialog = _BlockComicDialog(
          words: words,
          tags: tags,
          ownerCurrent: ownerCurrent,
          onBlocked: onBlocked,
        );
        return work == null
            ? dialog
            : SettingsSaveScope(work: work, child: dialog);
      },
    );
  }
}

class _BlockComicDialog extends StatefulWidget {
  const _BlockComicDialog({
    required this.words,
    required this.tags,
    required this.ownerCurrent,
    this.onBlocked,
  });
  final List<String> words, tags;
  final bool Function() ownerCurrent;
  final VoidCallback? onBlocked;
  @override
  State<_BlockComicDialog> createState() => _BlockComicDialogState();
}

class _BlockComicDialogState extends SettingsSaveState<_BlockComicDialog> {
  final _words = <String>[];
  final _settings = KeywordSettingsStore(
    readSettings: () => appdata.settings,
    updateSettings: (change) => appdata.updateSettings(change),
  );

  void _block() {
    if (!acceptsSettingsChanges ||
        savingSettings ||
        hasSettingsSaveError ||
        _words.isEmpty ||
        !widget.ownerCurrent()) {
      return;
    }
    final rules = List<KeywordRule>.unmodifiable([
      for (final word in _words)
        KeywordRule.suggested(word, tag: widget.tags.contains(word)),
    ]);
    final callback = widget.onBlocked;
    saveSetting(
      BlockedKeywordList.comics,
      () => _settings.blockRules(BlockedKeywordList.comics, rules),
      onSaved: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !acceptsSettingsChanges ||
              !NavigationAdmission.allows(context) ||
              ModalRoute.of(context)?.isCurrent != true) {
            return;
          }
          if (widget.ownerCurrent()) {
            context.showMessage(message: 'Blocked'.tl);
            callback?.call();
          }
          if (mounted) leaveSettings();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) => protectSettings(
    ContentDialog(
      title: 'Block'.tl,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(0, math.min(400, context.height - 136)),
        ),
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: savingSettings || hasSettingsSaveError,
            child: ExcludeFocus(
              excluding: savingSettings || hasSettingsSaveError,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New tags use Exact tag; short English abbreviations use Whole word. Existing rules are kept. Edit rules in Keyword blocking.'
                        .tl,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (final word in widget.words)
                        if (word.trim().isNotEmpty)
                          OptionChip(
                            text: widget.tags.contains(word)
                                ? word.translateTagIfNeed
                                : word,
                            isSelected: _words.contains(word),
                            onTap: () {
                              if (savingSettings || hasSettingsSaveError) {
                                return;
                              }
                              setState(() {
                                if (!_words.remove(word)) _words.add(word);
                              });
                            },
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ).paddingHorizontal(16),
      ),
      actions: [
        settingsSaveStatus,
        FilledButton(
          onPressed: savingSettings || hasSettingsSaveError || _words.isEmpty
              ? null
              : _block,
          child: Text('Block'.tl),
        ),
      ],
    ),
  );
}

class _ComicDescription extends StatelessWidget {
  const _ComicDescription({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.enableTranslate,
    this.descriptionTooltip,
    this.badge,
    this.maxLines = 2,
    this.tags,
    this.rating,
  });

  final String title;
  final String subtitle;
  final String description;
  final String? descriptionTooltip;
  final String? badge;
  final List<String>? tags;
  final int maxLines;
  final bool enableTranslate;
  final double? rating;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: _buildDescription);

  Widget _buildDescription(BuildContext context, BoxConstraints constraints) {
    final displayTags = [
      for (final tag in tags ?? const <String>[])
        if (tag.removeAllBlank.isNotEmpty) tag.replaceAll('\n', ' '),
    ];
    double textHeight(String value, TextStyle style, int lines) {
      if (value.isEmpty) return 0;
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines,
      )..layout(maxWidth: constraints.maxWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    const titleStyle = TextStyle(fontWeight: FontWeight.w500, fontSize: 14);
    const descriptionStyle = TextStyle(fontSize: 12);
    final lineHeight = textHeight('Mg', descriptionStyle, 1);
    final badgeText = badge == null || badge!.isEmpty
        ? null
        : '${badge![0].toUpperCase()}${badge!.substring(1).toLowerCase()}';
    final badgeHeight = badgeText == null
        ? 0.0
        : textHeight(badgeText, descriptionStyle, 1) + 8;
    final minimumDescriptionHeight = description.isEmpty ? 0.0 : lineHeight;
    final minimumFooterHeight = math.max(minimumDescriptionHeight, badgeHeight);
    var titleLines = maxLines;
    var titleHeight = textHeight(title.trim(), titleStyle, titleLines);
    while (titleLines > 1 &&
        titleHeight + 4 + minimumFooterHeight > constraints.maxHeight) {
      titleLines--;
      titleHeight = textHeight(title.trim(), titleStyle, titleLines);
    }
    final subtitleHeight = textHeight(
      subtitle,
      const TextStyle(fontSize: 10),
      1,
    );
    final showSubtitle =
        subtitle.isNotEmpty &&
        titleHeight + subtitleHeight + 4 + minimumFooterHeight <=
            constraints.maxHeight;
    final gap = math.min(
      4.0,
      math.max(0.0, constraints.maxHeight - titleHeight),
    );
    final footerSpace = math.max(
      0.0,
      constraints.maxHeight -
          titleHeight -
          (showSubtitle ? subtitleHeight : 0) -
          gap,
    );
    final showRating =
        rating != null &&
        footerSpace >=
            math.max(minimumFooterHeight, minimumDescriptionHeight + 18);
    final availableLines = footerSpace.isFinite && lineHeight > 0
        ? ((footerSpace - (showRating ? 18 : 0)) / lineHeight).floor()
        : 3;
    final descriptionLines = description.isEmpty
        ? 0
        : math.max(0, math.min(availableLines, displayTags.isEmpty ? 3 : 2));
    final showBadge = badgeText != null && footerSpace >= badgeHeight;
    Widget descriptionText = Text(
      description,
      style: descriptionStyle,
      maxLines: math.max(1, descriptionLines),
      overflow: TextOverflow.ellipsis,
    );
    if (descriptionTooltip != null) {
      descriptionText = Tooltip(
        message: descriptionTooltip!,
        excludeFromSemantics: true,
        child: Semantics(
          label: descriptionTooltip,
          excludeSemantics: true,
          child: descriptionText,
        ),
      );
    }
    var enableTranslate =
        appLocale.languageCode == 'zh' && this.enableTranslate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight),
          child: Text(
            title.trim(),
            style: titleStyle,
            maxLines: titleLines,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        if (showSubtitle)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.0,
              color: context.colorScheme.onSurface.toOpacity(0.7),
            ),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        SizedBox(height: gap),
        if (displayTags.isNotEmpty)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxHeight < 22) {
                  return Container();
                }
                int cnt = (constraints.maxHeight - 22).toInt() ~/ 25;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  height: 21 + cnt * 24,
                  width: double.infinity,
                  decoration: const BoxDecoration(),
                  child: Wrap(
                    runAlignment: WrapAlignment.start,
                    clipBehavior: Clip.antiAlias,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      for (var s in displayTags)
                        Container(
                          height: 21,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.45,
                          ),
                          decoration: BoxDecoration(
                            color: s == "Unavailable"
                                ? context.colorScheme.errorContainer
                                : context.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              enableTranslate
                                  ? TagsTranslation.translateTag(s)
                                  : s.split(':').last,
                              style: const TextStyle(fontSize: 12),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).toAlign(Alignment.topCenter);
              },
            ),
          )
        else
          const Spacer(),
        if (descriptionLines > 0 || showRating || showBadge)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRating) StarRating(value: rating!, size: 18),
                    if (descriptionLines > 0) descriptionText,
                  ],
                ),
              ),
              if (showBadge)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Center(
                    child: Text(
                      badgeText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ReadingHistoryBadge extends StatelessWidget {
  const _ReadingHistoryBadge({
    required this.page,
    this.maxPage,
    this.description,
  });
  final int page;
  final int? maxPage;
  final String? description;

  Widget _number(String text, double fontSize, Alignment alignment) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: fontSize, height: 1, color: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) => Tooltip(
    message: description ?? 'P$page',
    child: Semantics(
      label: description ?? 'P$page',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 24,
        child: ColoredBox(
          color: Colors.blue.withValues(alpha: 0.9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: maxPage == null
                ? _number('$page', 14, Alignment.center)
                : page == maxPage
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _number('$page', 14, Alignment.topLeft),
                      ),
                      Expanded(
                        flex: 2,
                        child: _number('/$maxPage', 9, Alignment.bottomRight),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

class SimpleComicTile extends StatelessWidget {
  const SimpleComicTile({
    super.key,
    required this.comic,
    this.onTap,
    this.withTitle = false,
    this.heroID,
    this.gaplessPlayback = false,
  });

  final Comic comic;

  final void Function()? onTap;

  final bool withTitle;

  final int? heroID;

  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    var image = _findImageProvider(comic);

    Widget child = image == null
        ? const SizedBox()
        : AnimatedImage(
            image: image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: gaplessPlayback,
          );

    child = Container(
      width: 98,
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    final state = _tileState(comic);
    if (state.hasNewUpdate || state.historyPage != null) {
      child = Stack(
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.historyPage case final page?)
                    _ReadingHistoryBadge(
                      page: page == 0 ? 1 : page,
                      maxPage: state.historyMaxPage,
                      description:
                          state.historyTooltipDescription ??
                          state.historyDescription,
                    ),
                  if (state.hasNewUpdate) _buildUpdateBadge(context),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (heroID != null) {
      child = Hero(tag: "cover$heroID", child: child);
    }

    child = AnimatedTapRegion(
      borderRadius: 8,
      onTap:
          onTap ??
          () {
            openComicPage(
              context: context,
              id: comic.id,
              sourceKey: comic.sourceKey,
              cover: comic.cover,
              title: comic.title,
              heroID: heroID,
            );
          },
      child: child,
    );

    if (withTitle) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Center(
              child: Text(
                comic.title.replaceAll('\n', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}
