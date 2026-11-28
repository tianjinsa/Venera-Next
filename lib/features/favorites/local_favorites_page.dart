import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/history/history_manager.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/components/file_save_task.dart';

import 'favorite_models.dart';
import 'favorite_folder.dart';
import 'favorite_folder_path.dart';
import 'folder_move_dialog.dart';
import 'folder_order_dialog.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_collection_ui.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/components/window_selection_task.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_actions.dart';
import 'package:venera_next/features/favorites/favorites_display.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/comic_reorder_page.dart';
import 'package:venera_next/features/favorites/folder_rename_dialog.dart';
import 'package:venera_next/features/favorites/favorite_confirmation_dialog.dart';
import 'package:venera_next/features/favorites/favorite_transfer_dialog.dart';
import 'package:venera_next/features/favorites/favorite_metadata_dialog.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/reader.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/selection_operation.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/opencc.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// If the number of comics in a folder exceeds this limit, it will be
/// fetched asynchronously.
const _asyncDataFetchLimit = 500;

class LocalFavoritesPage extends StatefulWidget {
  const LocalFavoritesPage({
    required this.folder,
    required this.showFolders,
    required this.onFolderSelected,
    required this.updateFolderList,
    this.importFolder = importNetworkFolder,
    super.key,
  });

  final String folder;
  final VoidCallback showFolders;
  final void Function(bool isNetwork, String? folder) onFolderSelected;
  final VoidCallback updateFolderList;
  final Future<void> Function(
    BuildContext context,
    String source,
    int pages,
    String folder,
    String remoteFolder,
  )
  importFolder;

  @override
  State<LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<LocalFavoritesPage> {
  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  Map<Comic, bool> selectedComics = {};

  String keyword = "";
  static final _uppercaseSearch = RegExp(r'[A-Z]');

  bool searchMode = false;
  final _searchController = TextEditingController();

  bool multiSelectMode = false;
  final _shortcutFocus = FocusNode(debugLabel: 'Local favorites shortcuts');

  void _startSelection() {
    multiSelectMode = true;
    _shortcutFocus.requestFocus();
  }

  int? lastSelectedIndex;

  bool get isAllFolder => widget.folder == localAllFolderLabel;

  LocalFavoritesManager get manager => _store.manager;

  late final FavoriteStoreBinding _store;

  late final LocalFavoritesManager _observedManager;
  late final HistoryManager _observedHistory;
  late final int _observedGeneration;
  late final String _observedDataPath;
  WindowSelectionTask? _queryOwner;
  final _metadataTasks = <WindowSelectionTask>{};

  bool get _canReadObservedFolder =>
      mounted &&
      _queryOwner?.active == true &&
      _store.isCurrent &&
      _observedManager.connectionGeneration == _observedGeneration &&
      App.dataPath == _observedDataPath;

  bool isLoading = false;
  int _queryGeneration = 0;
  int _filterRequest = 0;
  ModalRoute<dynamic>? _updateFlyoutRoute;
  Object? _loadError;

  late String readFilterSelect;

  var searchResults = <FavoriteItem>[];

  void _refreshSearchResults() {
    final query = keyword;
    if (query.trim().isEmpty) {
      searchResults = comics;
      return;
    }
    List<String> splitTerms(String text) => text
        .split(' ')
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final terms = splitTerms(query);
    // Convert only if a direct match fails, then reuse the resulting terms
    // for every remaining comic in this folder snapshot.
    late final traditional = OpenCC.hasChineseSimplified(query)
        ? splitTerms(OpenCC.simplifiedToTraditional(query))
        : null;
    late final simplified = OpenCC.hasChineseTraditional(query)
        ? splitTerms(OpenCC.traditionalToSimplified(query))
        : null;
    final caseSensitive = _uppercaseSearch.hasMatch(query);
    final translateTags = appLocale.languageCode != 'en';
    String fold(String text) => caseSensitive ? text : text.toLowerCase();

    bool matchesTag(String term, String tag) {
      final raw = fold(tag);
      if (term == raw) return true;
      final colon = raw.indexOf(':');
      if (colon != -1) {
        final end = raw.indexOf(':', colon + 1);
        if (term == raw.substring(colon + 1, end == -1 ? null : end)) {
          return true;
        }
      }
      return translateTags && term == fold(tag.translateTagsToCN);
    }

    bool matches(FavoriteItem comic) {
      final title = fold(comic.title);
      late final subtitle = fold(comic.subtitle ?? '');
      late final author = fold(comic.author);
      bool matchesAll(List<String>? words) =>
          words != null &&
          words.every(
            (term) =>
                title.contains(term) ||
                subtitle.contains(term) ||
                comic.tags.any((tag) => matchesTag(term, tag)) ||
                term == author,
          );
      return matchesAll(terms) ||
          matchesAll(traditional) ||
          matchesAll(simplified);
    }

    searchResults = comics.where(matches).toList();
  }

  void _replaceComics(List<FavoriteItem> value) {
    comics = value;
    if (searchMode) _refreshSearchResults();
    _reconcileSelection();
  }

  List<FavoriteItem> get _visibleComics =>
      searchMode ? searchResults : filterComics(comics);

  List<FavoriteItem>? _filteredInput, _filteredComics;
  String? _filteredReadState;

  void _onHistoryChanged() {
    _filteredInput = null;
    if (_canReadObservedFolder && readFilterSelect != readFilterList[0]) {
      setState(_reconcileSelection);
    }
  }

  void _reconcileSelection() {
    lastSelectedIndex = null;
    if (selectedComics.isEmpty) return;
    selectedComics = {
      for (final comic in _visibleComics)
        if (selectedComics[comic] == true) comic: true,
    };
    if (selectedComics.isEmpty) multiSelectMode = false;
  }

  void updateComics() {
    if (!_canReadObservedFolder) return;
    final manager = _observedManager;
    final generation = ++_queryGeneration;
    final folder = widget.folder;
    _loadError = null;
    isLoading = false;
    try {
      final count = isAllFolder
          ? manager.totalComics
          : manager.folderComics(folder);
      if (!isAllFolder && !manager.existsFolder(folder)) {
        _replaceComics([]);
      } else if (count < _asyncDataFetchLimit) {
        _replaceComics(
          isAllFolder
              ? manager.getAllComics()
              : manager.getFolderComics(folder),
        );
      } else {
        isLoading = true;
        final reading = isAllFolder
            ? manager.getAllComicsAsync()
            : manager.getFolderComicsAsync(folder);
        unawaited(
          reading.then<void>(
            (value) {
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                _replaceComics(value);
              });
            },
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites query', error, stack);
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                _loadError = error;
              });
            },
          ),
        );
      }
    } catch (error, stack) {
      Log.error('Favorites query', error, stack);
      _loadError = error;
    }
    setState(() {});
  }

  List<FavoriteItem> filterComics(List<FavoriteItem> curComics) {
    if (readFilterSelect != 'Completed' && readFilterSelect != 'UnCompleted') {
      return curComics;
    }
    if (identical(_filteredInput, curComics) &&
        _filteredReadState == readFilterSelect) {
      return _filteredComics!;
    }
    final histories = _observedHistory;
    _filteredInput = curComics;
    _filteredReadState = readFilterSelect;
    return _filteredComics = curComics.where((comic) {
      final history = histories.find(comic.id, comic.type);
      if (readFilterSelect == "UnCompleted") {
        return history == null || history.page != history.maxPage;
      } else if (readFilterSelect == "Completed") {
        return history != null && history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _store = FavoritesScope.capture(context);
    _observedManager = _store.manager;
    _observedGeneration = _observedManager.connectionGeneration;
    _observedDataPath = App.dataPath;
    readFilterSelect =
        appdata.implicitData["local_favorites_read_filter"] ??
        readFilterList[0];
    if (!isAllFolder) {
      var (a, b) = _observedManager.findLinked(widget.folder);
      networkSource = a;
      networkFolder = b;
    } else {
      networkSource = null;
      networkFolder = null;
    }
    comics = [];
    _observedManager.addListener(updateComics);
    _observedHistory = HistoryScope.read(context);
    _observedHistory.addListener(_onHistoryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queryOwner != null) return;
    _queryOwner = WindowSelectionTask(context);
    updateComics();
  }

  void _retireUpdateFlyout() {
    final route = _updateFlyoutRoute;
    _updateFlyoutRoute = null;
    scheduleMicrotask(() {
      final navigator = route?.navigator;
      if (navigator?.mounted == true && route!.isActive) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void didUpdateWidget(LocalFavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder != widget.folder) {
      _cancelMetadataUpdates();
      _filterRequest++;
      selectedComics.clear();
      lastSelectedIndex = null;
      multiSelectMode = false;
      searchMode = false;
      keyword = '';
      final linked = isAllFolder || !_canReadObservedFolder
          ? (null, null)
          : _observedManager.findLinked(widget.folder);
      networkSource = linked.$1;
      networkFolder = linked.$2;
      updateComics();
    }
    if (oldWidget.folder != widget.folder ||
        oldWidget.importFolder != widget.importFolder) {
      _retireUpdateFlyout();
    }
  }

  @override
  void dispose() {
    _cancelMetadataUpdates();
    _retireUpdateFlyout();
    _observedManager.removeListener(updateComics);
    _observedHistory.removeListener(_onHistoryChanged);
    _shortcutFocus.dispose();
    _searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void selectAll() {
    if (!_canReadObservedFolder) return;
    setState(() {
      selectedComics = {for (final comic in _visibleComics) comic: true};
      lastSelectedIndex = null;
    });
  }

  void invertSelection() {
    if (!_canReadObservedFolder) return;
    setState(() {
      selectedComics = {
        for (final comic in _visibleComics)
          if (selectedComics[comic] != true) comic: true,
      };
      lastSelectedIndex = null;
    });
  }

  bool _dismissLocalMode() {
    if (!_canReadObservedFolder || _queryOwner?.canPresent != true) {
      return false;
    }
    if (multiSelectMode) {
      _cancel();
      lastSelectedIndex = null;
      return true;
    }
    if (searchMode) {
      setState(() {
        searchMode = false;
        keyword = '';
        // Search only filtered the current snapshot. Querying again here
        // would briefly replace large folders with the loading sliver.
        searchResults = [];
      });
      return true;
    }
    return false;
  }

  bool downloadComic(FavoriteItem c) {
    final library = LocalManager();
    var source = c.type.comicSource;
    if (source != null) {
      bool isDownloaded = library.isDownloaded(c.id, (c).type);
      if (isDownloaded) {
        return false;
      }
      library.addTask(
        ImagesDownloadTask(
          storage: library,
          source: source,
          comicId: c.id,
          comicTitle: c.title,
        ),
      );
      return true;
    }
    return false;
  }

  void downloadSelected() {
    int count = 0;
    for (var c in selectedComics.keys) {
      if (downloadComic(c as FavoriteItem)) {
        count++;
      }
    }
    if (count > 0) {
      context.showMessage(
        message: "Added @c comics to download queue.".tlParams({"c": count}),
      );
    }
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final mobile = MobileUi.enabledOf(context);
    // The compact toolbar does not use the desktop inline-action width.
    // Reuse its slivers when only the keyboard changes the viewport height.
    final mobileBody = mobile
        ? _build(context, mobile: true, inlineSelectionActions: true)
        : null;
    return LayoutBuilder(
      builder: (context, constraints) =>
          mobileBody ??
          _build(
            context,
            mobile: false,
            inlineSelectionActions:
                constraints.maxWidth >=
                440 + MediaQuery.textScalerOf(context).scale(20) * 4,
          ),
    );
  }

  Widget _build(
    BuildContext context, {
    required bool mobile,
    required bool inlineSelectionActions,
  }) {
    final target = widget;
    final selection = selectedComics.keys.cast<FavoriteItem>().toList();
    final selectedItems = selection.map((comic) => comic.detached()).toList();
    bool isCurrentSelection() =>
        _canReadObservedFolder &&
        widget.folder == target.folder &&
        multiSelectMode &&
        selection.isNotEmpty &&
        listEquals(selectedComics.keys.toList(), selection);
    var title = widget.folder;
    if (title == localAllFolderLabel) {
      title = "All".tl;
    }
    final folderTree = _canReadObservedFolder
        ? _observedManager.folderTree
        : FavoriteFolderTree.flat(const []);
    final currentFolder = folderTree.named(widget.folder);
    final childFolders = currentFolder == null
        ? const <FavoriteFolder>[]
        : folderTree.childrenOf(currentFolder.id);
    final parentFolder = currentFolder?.parentId == null
        ? null
        : folderTree.identified(currentFolder!.parentId!);
    void goToParent() {
      if (!_canReadObservedFolder ||
          _queryOwner?.canPresent != true ||
          widget.folder != target.folder ||
          currentFolder == null ||
          parentFolder == null) {
        return;
      }
      final latest = _observedManager.folderTree;
      final child = latest.named(target.folder);
      final parent = latest.identified(parentFolder.id);
      if (child?.id != currentFolder.id ||
          child?.parentId != parent?.id ||
          parent == null) {
        return;
      }
      target.onFolderSelected(false, parent.name);
    }

    final displayedComics = searchMode ? searchResults : filterComics(comics);
    final compactActions = context.width < changePoint && !isAllFolder;
    final canSelect =
        _canReadObservedFolder && !isLoading && displayedComics.isNotEmpty;
    void enterSelection() {
      if (!_canReadObservedFolder ||
          _queryOwner?.canPresent != true ||
          widget.folder != target.folder ||
          isLoading ||
          _visibleComics.isEmpty) {
        return;
      }
      setState(() {
        selectedComics.clear();
        lastSelectedIndex = null;
        _startSelection();
      });
    }

    bool isCurrentFolder() =>
        _canReadObservedFolder &&
        widget.folder == target.folder &&
        currentFolder != null &&
        _observedManager.folderTree.named(target.folder)?.id ==
            currentFolder.id;

    final folderEntries = !searchMode && !multiSelectMode && !isAllFolder
        ? <MenuEntry>[
            if (!mobile && compactActions && canSelect)
              MenuEntry(
                icon: Icons.checklist_rounded,
                text: 'Select comics'.tl,
                onClick: enterSelection,
              ),
            if (currentFolder?.parentId == null)
              MenuEntry(
                icon: Icons.create_new_folder_outlined,
                text: 'Create subfolder'.tl,
                onClick: () {
                  if (!_canReadObservedFolder ||
                      currentFolder == null ||
                      _queryOwner?.canPresent != true) {
                    return;
                  }
                  newFolder(
                    context,
                    parentId: currentFolder.id,
                    onChanged: (_) => target.updateFolderList(),
                  );
                },
              ),
            MenuEntry(
              icon: Icons.drive_file_move_outline,
              text: 'Move folder'.tl,
              onClick: () {
                if (!_canReadObservedFolder ||
                    _queryOwner?.canPresent != true) {
                  return;
                }
                moveFavoriteFolder(
                  context,
                  folder: target.folder,
                  isCurrent: () =>
                      _canReadObservedFolder && widget.folder == target.folder,
                  onCommitted: target.updateFolderList,
                );
              },
            ),
            MenuEntry(
              icon: Icons.edit_outlined,
              text: "Rename".tl,
              onClick: () {
                renameFavoriteFolder(
                  context,
                  manager: _observedManager,
                  folder: target.folder,
                  isCurrent: () =>
                      _canReadObservedFolder && widget.folder == target.folder,
                  onRenamed: (name) {
                    target.updateFolderList();
                    if (_canReadObservedFolder &&
                        _queryOwner?.canPresent == true &&
                        widget.folder == target.folder) {
                      target.onFolderSelected(false, name);
                    }
                  },
                );
              },
            ),
            if (childFolders.isNotEmpty)
              MenuEntry(
                icon: Icons.folder_copy_outlined,
                text: 'Sort subfolders'.tl,
                onClick: () {
                  if (!isCurrentFolder() || _queryOwner?.canPresent != true) {
                    return;
                  }
                  sortFolders(
                    context,
                    initialParentId: currentFolder!.id,
                    isCurrent: isCurrentFolder,
                  ).then<void>(
                    (_) {
                      if (isCurrentFolder() &&
                          _queryOwner?.canPresent == true) {
                        target.updateFolderList();
                      }
                    },
                    onError: (Object error, StackTrace stack) {
                      Log.error('Favorite subfolder order', error, stack);
                    },
                  );
                },
              ),
            MenuEntry(
              icon: Icons.reorder,
              text: 'Reorder comics'.tl,
              onClick: () {
                if (_queryOwner?.canPresent != true) return;
                reorderFavoriteComics(
                  context,
                  manager: _observedManager,
                  folder: target.folder,
                  isCurrent: () =>
                      _canReadObservedFolder && widget.folder == target.folder,
                );
              },
            ),
            MenuEntry(
              icon: Icons.upload_file,
              text:
                  (childFolders.isEmpty
                          ? 'Export'
                          : 'Export this folder only (no subfolders)')
                      .tl,
              onClick: () {
                if (!_canReadObservedFolder ||
                    _queryOwner?.canPresent != true ||
                    widget.folder != target.folder) {
                  return;
                }
                final json = _observedManager.folderToJson(target.folder);
                saveFileForWindow(
                  context,
                  data: utf8.encode(json),
                  filename: "${target.folder}.json",
                );
              },
            ),
            MenuEntry(
              icon: Icons.update,
              text: "Update Comics Info".tl,
              onClick: () {
                if (_queryOwner?.canPresent != true ||
                    !_canReadObservedFolder ||
                    widget.folder != target.folder) {
                  return;
                }
                _refreshMetadata(context, target.folder);
              },
            ),
            MenuEntry(
              icon: Icons.delete_outline,
              text: "Delete Folder".tl,
              color: context.colorScheme.error,
              onClick: () {
                if (_queryOwner?.canPresent != true) return;
                if (childFolders.isNotEmpty) {
                  context.showMessage(
                    message: 'Move subfolders before deleting this folder'.tl,
                  );
                  return;
                }
                confirmFavoriteMutation(
                  context: context,
                  manager: _observedManager,
                  folder: target.folder,
                  title: "Delete".tl,
                  content:
                      '${"Delete folder '@f' ?".tlParams({"f": target.folder})}\n${'Only favorite records in this folder are removed; comic files are kept.'.tl}',
                  btnColor: context.colorScheme.error,
                  isCurrent: () =>
                      _canReadObservedFolder && widget.folder == target.folder,
                  mutate: () => _observedManager.deleteFolder(target.folder),
                  onCommitted: () {
                    target.updateFolderList();
                    if (_canReadObservedFolder &&
                        _queryOwner?.canPresent == true &&
                        widget.folder == target.folder) {
                      target.onFolderSelected(false, null);
                    }
                  },
                );
              },
            ),
          ]
        : const <MenuEntry>[];
    final batchEntries = multiSelectMode
        ? <MenuEntry>[
            if (mobile)
              MenuEntry(
                icon: Icons.deselect,
                text: 'Deselect'.tl,
                onClick: _cancel,
              ),
            if (!isAllFolder && selectedItems.isNotEmpty)
              MenuEntry(
                icon: Icons.drive_file_move,
                text: "Move to folder".tl,
                onClick: () {
                  if (_queryOwner?.canPresent != true ||
                      !isCurrentSelection()) {
                    return;
                  }
                  showFavoriteTransferDialog(
                    context: context,
                    manager: _observedManager,
                    source: target.folder,
                    comics: selectedItems,
                    move: true,
                    isCurrent: isCurrentSelection,
                    onCommitted: _cancel,
                  );
                },
              ),
            if (!isAllFolder && selectedItems.isNotEmpty)
              MenuEntry(
                icon: Icons.copy,
                text: "Copy to folder".tl,
                onClick: () {
                  if (_queryOwner?.canPresent != true ||
                      !isCurrentSelection()) {
                    return;
                  }
                  showFavoriteTransferDialog(
                    context: context,
                    manager: _observedManager,
                    source: target.folder,
                    comics: selectedItems,
                    move: false,
                    isCurrent: isCurrentSelection,
                    onCommitted: _cancel,
                  );
                },
              ),
            if (!mobile && !inlineSelectionActions) ...[
              MenuEntry(
                icon: Icons.select_all,
                text: "Select All".tl,
                onClick: selectAll,
              ),
              MenuEntry(
                icon: Icons.deselect,
                text: "Deselect".tl,
                onClick: _cancel,
              ),
              MenuEntry(
                icon: Icons.flip,
                text: "Invert Selection".tl,
                onClick: invertSelection,
              ),
            ],
            if (!isAllFolder && selectedItems.isNotEmpty)
              MenuEntry(
                icon: Icons.delete_outline,
                text: "Delete Comic".tl,
                color: context.colorScheme.error,
                onClick: () {
                  if (_queryOwner?.canPresent != true ||
                      !isCurrentSelection()) {
                    return;
                  }
                  confirmFavoriteMutation(
                    context: context,
                    manager: _observedManager,
                    folder: target.folder,
                    title: "Delete".tl,
                    content: "Delete @c comics?".tlParams({
                      "c": selectedItems.length,
                    }),
                    btnColor: context.colorScheme.error,
                    isCurrent: isCurrentSelection,
                    mutate: () => _observedManager.batchDeleteComics(
                      target.folder,
                      selectedItems,
                    ),
                    onCommitted: _cancel,
                  );
                },
              ),
            if (selectedItems.isNotEmpty)
              MenuEntry(
                icon: Icons.download,
                text: "Download".tl,
                onClick: downloadSelected,
              ),
            if (selectedComics.length == 1)
              MenuEntry(
                icon: Icons.copy,
                text: "Copy Title".tl,
                onClick: () {
                  Clipboard.setData(
                    ClipboardData(text: selectedComics.keys.first.title),
                  );
                  context.showMessage(message: "Copied".tl);
                },
              ),
            if (selectedComics.length == 1)
              MenuEntry(
                icon: Icons.chrome_reader_mode_outlined,
                text: "Read".tl,
                onClick: () {
                  final c = selectedComics.keys.first as FavoriteItem;
                  appNavigation.rootContext.to(
                    () => ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                    mobileTransition: false,
                  );
                },
              ),
            if (selectedComics.length == 1)
              MenuEntry(
                icon: Icons.arrow_forward_ios,
                text: "Jump to Detail".tl,
                onClick: () {
                  final c = selectedComics.keys.first as FavoriteItem;
                  context.to(() => ComicPage(id: c.id, sourceKey: c.sourceKey));
                },
              ),
          ]
        : const <MenuEntry>[];

    void openSearch() {
      _searchController.clear();
      setState(() {
        keyword = "";
        searchMode = true;
        _refreshSearchResults();
      });
    }

    void applySearch(String value) {
      if (!searchMode || keyword == value) return;
      setState(() {
        keyword = value;
        _refreshSearchResults();
      });
    }

    prism.PopupMenuItem selectEntry() => collectionSelectionEntry(
      canSelect ? enterSelection : null,
      label: 'Select comics'.tl,
    );

    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!multiSelectMode && (mobile || !searchMode))
          SliverAppbar(
            mobileSearch: mobile
                ? CollectionBarSearch(
                    open: searchMode,
                    controller: _searchController,
                    onOpen: openSearch,
                    onClose: _dismissLocalMode,
                    onChanged: applySearch,
                    more: MobileMenuButton(items: [selectEntry()]),
                  )
                : null,
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            mobileShowBack: false,
            leading: !mobile && context.width <= favoritesTwoPanelChangeWidth
                ? Tooltip(
                    message: 'Folders'.tl,
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: widget.showFolders,
                    ),
                  )
                : mobile
                ? null
                : const SizedBox(),
            title: FavoriteFolderPath(
              currentName: title,
              showFolderChevron: mobile,
              parentName: parentFolder?.name,
              onParentSelected: parentFolder == null ? null : goToParent,
              onCurrentSelected:
                  mobile || context.width < favoritesTwoPanelChangeWidth
                  ? () {
                      if (_queryOwner?.canPresent == true &&
                          widget.folder == target.folder) {
                        target.showFolders();
                      }
                    }
                  : null,
            ),
            mobileMore: mobile
                ? FavoriteDisplayButton.mobileMore(
                    readingFilter: readFilterSelect,
                    isCurrent: () =>
                        _canReadObservedFolder &&
                        widget.folder == target.folder &&
                        !multiSelectMode &&
                        !searchMode,
                    onReadingFilterSaved: (value) {
                      setState(() => readFilterSelect = value);
                      updateComics();
                    },
                    mobileItems: [
                      selectEntry(),
                      if (folderEntries.isNotEmpty)
                        prism.PopupMenuItem(
                          label: 'Folders'.tl,
                          subItems: [
                            for (final entry in folderEntries)
                              collectionMenuAction(context, entry),
                          ],
                        ),
                    ],
                  )
                : null,
            actions: [
              if (networkSource != null && !isAllFolder)
                Tooltip(
                  message: "Sync".tl,
                  child: Flyout(
                    flyoutBuilder: (context) {
                      final source = networkSource;
                      final remoteFolder = networkFolder;
                      if (source == null || remoteFolder == null) {
                        return const SizedBox.shrink();
                      }
                      final folder = widget.folder;
                      final importFolder = widget.importFolder;
                      final generation = _observedManager.connectionGeneration;
                      final route = ModalRoute.of(context);
                      if (!identical(_updateFlyoutRoute, route)) {
                        _updateFlyoutRoute = route;
                        route?.completed.then((_) {
                          if (identical(_updateFlyoutRoute, route)) {
                            _updateFlyoutRoute = null;
                          }
                        });
                      }
                      bool isCurrent() =>
                          _canReadObservedFolder &&
                          widget.folder == folder &&
                          widget.importFolder == importFolder &&
                          _observedManager.connectionGeneration == generation &&
                          _observedManager.findLinked(folder) ==
                              (source, remoteFolder) &&
                          NavigationAdmission.allows(this.context);
                      return _FavoriteFolderSyncPanel(
                        networkSource: source,
                        networkFolder: remoteFolder,
                        onUpdate: (pages) async {
                          if (!isCurrent()) return;
                          await importFolder(
                            this.context,
                            source,
                            pages,
                            folder,
                            remoteFolder,
                          );
                          if (isCurrent()) updateComics();
                        },
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        return collectionShortcut(
                          context,
                          label: "Sync".tl,
                          icon: const Icon(Icons.sync),
                          onPressed: () {
                            if (_updateFlyoutRoute == null &&
                                NavigationAdmission.allows(context)) {
                              Flyout.of(context).show();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              if (!mobile) const FavoriteDisplayButton(),
              if (!mobile)
                Tooltip(
                  message: "Filter".tl,
                  child: IconButton(
                    icon: const Icon(Icons.sort_rounded),
                    color: readFilterSelect != readFilterList[0]
                        ? context.colorScheme.primaryContainer
                        : null,
                    onPressed: () {
                      final folder = widget.folder;
                      final request = ++_filterRequest;
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _LocalFavoritesFilterDialog(
                            initReadFilterSelect: readFilterSelect,
                            updateConfig: (readFilter) {
                              if (!mounted ||
                                  widget.folder != folder ||
                                  request != _filterRequest) {
                                return;
                              }
                              setState(() {
                                readFilterSelect = readFilter;
                              });
                              updateComics();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              if (!mobile)
                collectionShortcut(
                  context,
                  label: "Search".tl,
                  icon: const Icon(Icons.search),
                  onPressed: openSearch,
                ),
              if (!mobile && !compactActions)
                collectionShortcut(
                  context,
                  label: 'Select comics'.tl,
                  icon: const Icon(Icons.checklist_rounded),
                  onPressed: canSelect ? enterSelection : null,
                ),
              if (!mobile && !isAllFolder)
                MenuButton(
                  menuIdentity: (
                    _observedManager,
                    _observedGeneration,
                    target.folder,
                    currentFolder?.id,
                    currentFolder?.parentId,
                    childFolders.length,
                    compactActions,
                    canSelect,
                  ),
                  entries: folderEntries,
                ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: collectionShortcut(
              context,
              label: "Cancel".tl,
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  multiSelectMode = false;
                  selectedComics.clear();
                });
              },
            ),
            title: Text(
              "Selected @c comics".tlParams({"c": selectedComics.length}),
            ),
            mobileMore: mobile && batchEntries.length == 1
                ? MobileToolbarButton(
                    label: batchEntries.single.text,
                    icon: Icon(batchEntries.single.icon),
                    onPressed: batchEntries.single.onClick,
                  )
                : mobile && batchEntries.isNotEmpty
                ? MobileMenuButton(
                    key: ValueKey(Object.hashAll(selection)),
                    items: [
                      for (final entry in batchEntries)
                        collectionMenuAction(context, entry),
                    ],
                  )
                : null,
            actions: [
              if (mobile || inlineSelectionActions) ...[
                collectionShortcut(
                  context,
                  key: const ValueKey('favorites-select-all'),
                  label: 'Select All'.tl,
                  icon: const Icon(Icons.select_all),
                  onPressed: canSelect ? selectAll : null,
                ),
                collectionShortcut(
                  context,
                  key: const ValueKey('favorites-invert-selection'),
                  label: 'Invert Selection'.tl,
                  icon: const Icon(Icons.flip),
                  onPressed: canSelect ? invertSelection : null,
                ),
                if (!mobile)
                  collectionShortcut(
                    context,
                    key: const ValueKey('favorites-deselect'),
                    label: 'Deselect'.tl,
                    icon: const Icon(Icons.deselect),
                    onPressed: _cancel,
                  ),
              ],
              if (!mobile)
                MenuButton(
                  menuIdentity: (
                    _observedManager,
                    _observedGeneration,
                    target.folder,
                    Object.hashAll(selection),
                  ),
                  entries: batchEntries,
                ),
            ],
          )
        else if (searchMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: collectionShortcut(
              context,
              label: "Cancel".tl,
              icon: const Icon(Icons.close),
              onPressed: _dismissLocalMode,
            ),
            title: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: UnderlineInputBorder(),
              ),
              onChanged: applySearch,
            ).paddingBottom(8).paddingRight(8),
          ),
        if (!searchMode && !multiSelectMode && childFolders.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Subfolders are separate. Comics below belong directly to this folder.'
                    .tl,
              ),
            ),
          ),
          SliverList.builder(
            itemCount: childFolders.length,
            itemBuilder: (context, index) {
              final folder = childFolders[index];
              void openFolder() {
                if (_canReadObservedFolder && _queryOwner?.canPresent == true) {
                  target.onFolderSelected(false, folder.name);
                }
              }

              return mobile
                  ? MobileCollectionFolder(
                      label: folder.name,
                      onOpen: openFolder,
                    )
                  : ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(folder.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: openFolder,
                    );
            },
          ),
        ],
        if (_loadError != null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Text(_loadError.toString()),
                TextButton(onPressed: updateComics, child: Text('Retry'.tl)),
              ],
            ),
          )
        else if (isLoading)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: const Center(child: CircularProgressIndicator()),
            ),
          )
        else ...[
          if (!searchMode && displayedComics.length < comics.length)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Hidden by reading-status filter: @a comics'.tlParams({
                    'a': comics.length - displayedComics.length,
                  }),
                ),
              ),
            ),
          SliverGridComics(
            key: const ValueKey('local-favorites-comics'),
            filterBlockedComics: false,
            comics: displayedComics,
            showHiddenCount: true,
            selections: selectedComics,
            useFavoriteDisplaySettings: true,
            mobileCollection: true,
            selectionMode: multiSelectMode,
            menuBuilder: (c) {
              return [
                if (!isAllFolder)
                  MenuEntry(
                    icon: Icons.delete,
                    text: "Delete".tl,
                    onClick: () async {
                      if (!_canReadObservedFolder ||
                          _queryOwner?.canPresent != true ||
                          widget.folder != target.folder) {
                        return;
                      }
                      final item = (c as FavoriteItem).detached();
                      final owner = WindowSelectionTask(context);
                      try {
                        await owner.run<void>((operation) async {
                          operation.checkActive();
                          await AppDataOperations.instance.access(() async {
                            // An accepted deletion may outlive its page, but
                            // cannot enter a replacement database after queuing.
                            if (!_store.isCurrent ||
                                _observedManager.connectionGeneration !=
                                    _observedGeneration ||
                                App.dataPath != _observedDataPath ||
                                !_observedManager.existsFolder(target.folder)) {
                              throw const SelectionCancelled();
                            }
                            await _observedManager.deleteComicWithId(
                              target.folder,
                              item.id,
                              item.type,
                            );
                          });
                        }, reportFailureOnClose: true);
                      } on SelectionCancelled {
                        // The original caller or database retired before admission.
                      } catch (error, stack) {
                        Log.error('Delete favorite', error, stack);
                        if (context.mounted &&
                            owner.canPresent &&
                            _canReadObservedFolder &&
                            widget.folder == target.folder) {
                          context.showMessage(message: error.toString());
                        }
                      }
                    },
                  ),
                MenuEntry(
                  icon: Icons.check,
                  text: "Select".tl,
                  onClick: () {
                    setState(() {
                      if (!multiSelectMode) {
                        _startSelection();
                      }
                      if (selectedComics.containsKey(c as FavoriteItem)) {
                        selectedComics.remove(c);
                        _checkExitSelectMode();
                      } else {
                        selectedComics[c] = true;
                      }
                      lastSelectedIndex = _visibleComics.indexOf(c);
                    });
                  },
                ),
                MenuEntry(
                  icon: Icons.download,
                  text: "Download".tl,
                  onClick: () {
                    downloadComic(c as FavoriteItem);
                    context.showMessage(message: "Download started".tl);
                  },
                ),
                if (GlobalPreferenceStore(
                      appdata.settings,
                    ).read(FavoritePreferences.onClickFavorite) ==
                    "viewDetail")
                  MenuEntry(
                    icon: Icons.menu_book_outlined,
                    text: "Read".tl,
                    onClick: () {
                      context.to(
                        () =>
                            ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                        mobileTransition: false,
                      );
                    },
                  ),
              ];
            },
            onTap: (c, heroID) {
              if (multiSelectMode) {
                setState(() {
                  if (selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics.remove(c);
                    _checkExitSelectMode();
                  } else {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = _visibleComics.indexOf(c);
                });
              } else if (GlobalPreferenceStore(
                    appdata.settings,
                  ).read(FavoritePreferences.onClickFavorite) ==
                  "viewDetail") {
                context.to(
                  () => ComicPage(
                    id: c.id,
                    sourceKey: c.sourceKey,
                    cover: c.cover,
                    title: c.title,
                    heroID: heroID,
                  ),
                );
              } else {
                context.to(
                  () => ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                  mobileTransition: false,
                );
              }
            },
            onLongPressed: (c, heroID) {
              final visible = _visibleComics;
              setState(() {
                if (!multiSelectMode) {
                  _startSelection();
                  if (!selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = visible.indexOf(c);
                } else {
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = visible.indexOf(c as FavoriteItem);
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }

                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;

                      var comic = visible[i];
                      if (selectedComics.containsKey(comic)) {
                        selectedComics.remove(comic);
                      } else {
                        selectedComics[comic] = true;
                      }
                    }
                  }
                  lastSelectedIndex = visible.indexOf(c as FavoriteItem);
                }
                _checkExitSelectMode();
              });
            },
          ),
        ],
      ],
    );
    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    // Keep the scroll position, header Element and search animation alive.
    // Inserting a wrapper only while searching remounts the entire sliver
    // tree, so the newly created search controller starts *at* its endpoint.
    body = CallbackShortcuts(
      bindings: {
        if (multiSelectMode || searchMode)
          const SingleActivator(LogicalKeyboardKey.escape): _dismissLocalMode,
      },
      child: Focus(focusNode: _shortcutFocus, skipTraversal: true, child: body),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode && parentFolder == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_dismissLocalMode()) {
          goToParent();
        }
      },
      child: body,
    );
  }

  void _cancelMetadataUpdates() {
    for (final task in _metadataTasks.toList()) {
      task.cancel();
    }
  }

  void _refreshMetadata(BuildContext context, String folder) {
    final owner = WindowSelectionTask(context);
    _metadataTasks.add(owner);
    final result = showFavoriteMetadataDialog(
      context: context,
      owner: owner,
      manager: _observedManager,
      folder: folder,
      isCurrent: () => _canReadObservedFolder && widget.folder == folder,
    );
    unawaited(
      result.then<void>(
        (_) {
          _metadataTasks.remove(owner);
        },
        onError: (Object error, StackTrace stack) {
          // Presentation reports its original error and host; consume this page's
          // completion without transferring that failure to another page.
          _metadataTasks.remove(owner);
        },
      ),
    );
  }

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
    });
  }
}

class _FavoriteFolderSyncPanel extends StatefulWidget {
  const _FavoriteFolderSyncPanel({
    required this.networkSource,
    required this.networkFolder,
    required this.onUpdate,
  });

  final Future<void> Function(int pages) onUpdate;
  final String networkFolder;
  final String networkSource;

  @override
  State<_FavoriteFolderSyncPanel> createState() =>
      _FavoriteFolderSyncPanelState();
}

class _FavoriteFolderSyncPanelState
    extends SettingsSaveState<_FavoriteFolderSyncPanel> {
  int updatePageNum = 9999999;
  bool startingUpdate = false;
  late final Future<void> Function(int) _update;

  Future<void> _submit() async {
    if (startingUpdate || !acceptsSettingsChanges) return;
    final pages = updatePageNum;
    final update = _update;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() => startingUpdate = true);
    try {
      await waitForSettingsSave();
      if (!mounted ||
          !acceptsSettingsChanges ||
          route?.isCurrent != true ||
          !NavigationAdmission.allows(context)) {
        return;
      }
      if (!await navigator.maybePop() || route?.isCurrent == true) return;
      await update(pages);
    } catch (error, stack) {
      Log.error('Favorite update settings', error, stack);
      if (mounted) context.showMessage(message: error.toString());
    } finally {
      if (mounted) setState(() => startingUpdate = false);
    }
  }

  String get _allPageText => 'All'.tl;

  static const pageCounts = [1, 2, 3, 5, 10, 20, 50, 100, 200, 9999999];

  @override
  void initState() {
    _update = widget.onUpdate;
    final stored = appdata.implicitData['local_favorites_update_page_num'];
    updatePageNum = stored is int && stored > 0 ? stored : 9999999;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(widget.networkSource);
    final sourceName = source?.name ?? widget.networkSource;
    var text = "The folder is Linked to @source".tlParams({
      "source": sourceName,
    });
    if (widget.networkFolder.isNotEmpty) {
      text += "\n${"Source Folder".tl}: ${widget.networkFolder}";
    }

    final target = (widget.networkSource, widget.networkFolder);
    return protectSettings(
      FlyoutContent(
        title: 'Sync'.tl,
        actions: [
          FilledButton(
            onPressed: startingUpdate ? null : _submit,
            child: Text('Update'.tl),
          ),
        ],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("Update the page number by the latest collection".tl),
                Select(
                  current: updatePageNum.toString() == '9999999'
                      ? _allPageText
                      : updatePageNum.toString(),
                  values: [
                    for (final value in pageCounts)
                      value == 9999999 ? _allPageText : '$value',
                  ],
                  minWidth: 48,
                  onTap: (index) {
                    if (!mounted ||
                        !acceptsSettingsChanges ||
                        startingUpdate ||
                        target !=
                            (widget.networkSource, widget.networkFolder) ||
                        index < 0 ||
                        index >= pageCounts.length) {
                      return;
                    }
                    final value = pageCounts[index];
                    setState(() {
                      updatePageNum = value;
                    });
                    saveSetting(
                      'local_favorites_update_page_num',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_update_page_num'] = value;
                      }),
                    );
                  },
                ),
              ],
            ),
            settingsSaveStatus,
          ],
        ),
      ),
    );
  }
}

class _LocalFavoritesFilterDialog extends StatefulWidget {
  const _LocalFavoritesFilterDialog({
    required this.initReadFilterSelect,
    required this.updateConfig,
  });

  final String initReadFilterSelect;
  final ValueChanged<String> updateConfig;

  @override
  State<_LocalFavoritesFilterDialog> createState() =>
      _LocalFavoritesFilterDialogState();
}

const readFilterList = favoriteReadFilters;

class _LocalFavoritesFilterDialogState
    extends SettingsSaveState<_LocalFavoritesFilterDialog> {
  List<String> optionTypes = ['Filter'];
  late var readFilter = widget.initReadFilterSelect;
  @override
  Widget build(BuildContext context) {
    Widget tabBar = Material(
      borderRadius: BorderRadius.circular(8),
      child: AppTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
      ),
    ).paddingTop(context.padding.top);
    return protectSettings(
      ContentDialog(
        content: DefaultTabController(
          length: optionTypes.length,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tabBar,
              TabViewBody(
                children: [
                  Column(
                    children: [
                      ListTile(
                        title: Text("Filter reading status".tl),
                        trailing: Select(
                          current: readFilter.tl,
                          values: readFilterList.map((e) => e.tl).toList(),
                          minWidth: 64,
                          onTap: (index) {
                            if (!mounted ||
                                !acceptsSettingsChanges ||
                                savingSettings ||
                                hasSettingsSaveError ||
                                index < 0 ||
                                index >= readFilterList.length) {
                              return;
                            }
                            setState(() {
                              readFilter = readFilterList[index];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          settingsSaveStatus,
          FilledButton(
            onPressed: savingSettings || hasSettingsSaveError
                ? null
                : () {
                    final value = readFilter;
                    saveSetting(
                      'local_favorites_read_filter',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_read_filter'] = value;
                      }),
                      onSaved: () {
                        widget.updateConfig(value);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) leaveSettings();
                        });
                      },
                    );
                  },
            child: Text("Confirm".tl),
          ),
        ],
      ),
    );
  }
}
