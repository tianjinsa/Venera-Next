import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'dart:async';
import 'package:venera_next/foundation/log.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/foundation/translations.dart';

import 'package:venera_next/components/loading.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.manager});
  final HistoryManager? manager;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final _manager = widget.manager ?? HistoryScope.read(context);
  late final _pager = HistoryPager(manager: _manager);
  final _scrollController = ScrollController();
  final _gridKey = GlobalKey<SliverGridComicsState>();

  String? _dragDate() {
    final comic = _gridKey.currentState?.firstVisibleComic;
    return comic is History ? comic.lastReadTime.split(' ').first : null;
  }

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onPageChanged);
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_reloadHistory());
    _manager.addListener(onUpdate);
    ComicSourceManager().addListener(onUpdate);
  }

  @override
  void dispose() {
    _manager.removeListener(onUpdate);
    ComicSourceManager().removeListener(onUpdate);
    _searchTimer?.cancel();
    _reloadTimer?.cancel();
    _cancelRefresh?.call();
    _pager.dispose();
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void onUpdate() {
    // Cover refreshes can notify once per visible comic. Read one snapshot
    // for the burst instead of reloading the database for every notification.
    _reloadTimer ??= Timer(const Duration(milliseconds: 100), () {
      _reloadTimer = null;
      _searchTimer?.cancel();
      unawaited(_reloadHistory());
    });
  }

  void _onPageChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
  }

  void _maybeLoadMore() {
    if (!mounted ||
        !_scrollController.hasClients ||
        (_searchTimer?.isActive ?? false) ||
        _pager.query != query) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter < position.viewportDimension * 2) {
      unawaited(_pager.loadMore());
    }
  }

  Future<bool> _reloadHistory({bool keepLoaded = true}) async {
    final loaded = await _pager.reload(query: query, keepLoaded: keepLoaded);
    if (!mounted || !loaded) return false;
    if (multiSelectMode && selectedComics.isNotEmpty) {
      final revision = _pager.revision;
      final selectionRequest = _selectionRequest;
      try {
        final remaining = await _manager.getMatchingIds(query: query);
        if (!mounted ||
            revision != _pager.revision ||
            selectionRequest != _selectionRequest ||
            !multiSelectMode) {
          return false;
        }
        setState(() {
          selectedComics.retainAll(remaining);
          if (selectedComics.isEmpty) multiSelectMode = false;
        });
      } catch (_) {
        // A later refresh can reconcile selection; the loaded page is usable.
      }
    }
    return true;
  }

  List<History> get comics => _pager.items;
  var controller = FlyoutController();
  final searchController = TextEditingController();
  Timer? _searchTimer;
  Timer? _reloadTimer;
  bool searchMode = false;
  String query = '';

  Future<bool> _applyQuery() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    return _reloadHistory(keepLoaded: false);
  }

  void _search(String value) {
    _searchTimer?.cancel();
    setState(() {
      query = value;
      selectedComics.clear();
      _selectionRequest++;
      _selectingAll = false;
      multiSelectMode = false;
    });
    if (query.trim().isEmpty) {
      unawaited(_applyQuery());
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      _searchTimer = null;
      unawaited(_applyQuery());
    });
  }

  void _closeSearch() {
    _searchTimer?.cancel();
    searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      searchMode = false;
    });
    _search('');
  }

  Future<void> _enterMultiSelect() async {
    final request = ++_selectionRequest;
    _searchTimer?.cancel();
    FocusScope.of(context).unfocus();
    final requestedQuery = query;
    if (_pager.query != query || _pager.isReloading || _pager.error != null) {
      if (!await _applyQuery()) return;
    }
    if (mounted && request == _selectionRequest && query == requestedQuery) {
      setState(() => multiSelectMode = true);
    }
  }

  void _exitMultiSelect() {
    setState(() {
      multiSelectMode = false;
      selectedComics.clear();
      _selectionRequest++;
      _selectingAll = false;
    });
  }

  bool multiSelectMode = false;
  Set<ComicID> selectedComics = {};
  bool _selectingAll = false;
  int _selectionRequest = 0;

  ComicID _identity(History comic) => ComicID(comic.type, comic.id);

  Future<void> _selectAcrossQuery({bool invert = false}) async {
    if (_selectingAll) return;
    final request = ++_selectionRequest;
    final revision = _pager.revision;
    setState(() => _selectingAll = true);
    try {
      final identities = await _manager.getMatchingIds(query: query);
      if (!mounted ||
          request != _selectionRequest ||
          revision != _pager.revision ||
          !multiSelectMode) {
        return;
      }
      setState(() {
        selectedComics = invert
            ? identities.difference(selectedComics)
            : identities;
      });
    } catch (_) {
      if (mounted && request == _selectionRequest) {
        context.showMessage(message: 'Failed to load history'.tl);
      }
    } finally {
      if (mounted && request == _selectionRequest) {
        setState(() => _selectingAll = false);
      }
    }
  }

  Future<void> selectAll() => _selectAcrossQuery();

  void deSelect() {
    setState(() {
      selectedComics.clear();
      _selectionRequest++;
      _selectingAll = false;
    });
  }

  Future<void> invertSelection() => _selectAcrossQuery(invert: true);

  void _removeHistory(History comic) {
    _manager.remove(comic.id, comic.type);
  }

  final _refreshing = <(String, int)>{};
  bool _refreshingAll = false;
  VoidCallback? _cancelRefresh;

  void _refreshHistory(History comic) async {
    final identity = (comic.id, comic.type.value);
    if (_refreshingAll || !_refreshing.add(identity)) return;
    try {
      final result = await _manager.refreshHistoryInfo(comic);
      if (mounted) {
        context.showMessage(
          message: result ? 'Refresh Success'.tl : 'Refresh Failed'.tl,
        );
      }
    } catch (error, stack) {
      Log.error('Refresh history', error, stack);
      if (mounted) context.showMessage(message: error.toString());
    } finally {
      _refreshing.remove(identity);
    }
  }

  void _refreshAllHistories() async {
    if (_refreshingAll || _refreshing.isNotEmpty) return;
    _refreshingAll = true;
    var cancelled = false;
    StreamIterator<RefreshProgress>? iterator;
    void cancel() {
      cancelled = true;
      unawaited(iterator?.cancel() ?? Future<void>.value());
    }

    _cancelRefresh = cancel;
    final loading = showLoadingDialog(
      context,
      withProgress: true,
      cancelButtonText: 'Cancel'.tl,
      onCancel: cancel,
      message: 'Refreshing Histories'.tl,
    );
    try {
      iterator = StreamIterator(_manager.refreshAllHistoriesStream());
      var success = 0;
      var failed = 0;
      var skipped = 0;
      while (await iterator.moveNext()) {
        if (cancelled || !mounted) return;
        final progress = iterator.current;
        if (progress.total > 0) {
          loading.setProgress(progress.current / progress.total);
        }
        success = progress.success;
        failed = progress.failed;
        skipped = progress.skipped;
      }
      if (mounted && !cancelled) {
        context.showMessage(
          message:
              'Refresh Completed: Success @success, Failed @failed, Skipped @skipped'
                  .tlParams({
                    'success': success,
                    'failed': failed,
                    'skipped': skipped,
                  }),
        );
      }
    } catch (error, stack) {
      Log.error('Refresh histories', error, stack);
      if (mounted && !cancelled) context.showMessage(message: error.toString());
    } finally {
      try {
        await iterator?.cancel();
      } finally {
        loading.close();
        _cancelRefresh = null;
        _refreshingAll = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> selectActions = [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: "Select All".tl,
        onPressed: _selectingAll ? null : selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.deselect),
        tooltip: "Deselect".tl,
        onPressed: deSelect,
      ),
      IconButton(
        icon: const Icon(Icons.flip),
        tooltip: "Invert Selection".tl,
        onPressed: _selectingAll ? null : invertSelection,
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        tooltip: "Delete".tl,
        onPressed: selectedComics.isEmpty || _selectingAll
            ? null
            : () {
                final comicsToDelete = selectedComics.toList();
                _exitMultiSelect();

                _manager.batchDeleteHistories(comicsToDelete);
              },
      ),
    ];

    List<Widget> normalActions = [
      IconButton(
        icon: const Icon(Icons.query_stats),
        tooltip: 'Reading statistics'.tl,
        onPressed: () => context.to(() => ReadingStatsPage(manager: _manager)),
      ),
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search'.tl,
        onPressed: () => setState(() => searchMode = true),
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh All Histories'.tl,
        onPressed: _refreshAllHistories,
      ),
      IconButton(
        icon: const Icon(Icons.checklist),
        tooltip: multiSelectMode ? "Exit Multi-Select".tl : "Multi-Select".tl,
        onPressed: _enterMultiSelect,
      ),
      Tooltip(
        message: 'Clear History'.tl,
        child: Flyout(
          controller: controller,
          flyoutBuilder: (context) {
            return FlyoutContent(
              title: 'Clear History'.tl,
              content: Text('Are you sure you want to clear your history?'.tl),
              actions: [
                Button.outlined(
                  onPressed: () {
                    _manager.clearUnfavoritedHistory(
                      manager: FavoritesScope.read(context),
                    );
                    context.pop();
                  },
                  child: Text('Clear Unfavorited'.tl),
                ),
                const SizedBox(width: 4),
                Button.filled(
                  color: context.colorScheme.error,
                  onPressed: () {
                    _manager.clearHistory();
                    context.pop();
                  },
                  child: Text('Clear'.tl),
                ),
              ],
            );
          },
          child: IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              controller.show();
            },
          ),
        ),
      ),
    ];

    final searchActions = [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear'.tl,
          onPressed: () {
            searchController.clear();
            _search('');
          },
        ),
      IconButton(
        icon: const Icon(Icons.checklist),
        tooltip: 'Multi-Select'.tl,
        onPressed: _enterMultiSelect,
      ),
    ];

    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (multiSelectMode) {
          _exitMultiSelect();
        } else if (searchMode) {
          _closeSearch();
        }
      },
      child: Scaffold(
        body: AppScrollBar(
          controller: _scrollController,
          topPadding: MediaQuery.paddingOf(context).top + 52,
          dragLabelBuilder: _dragDate,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _maybeLoadMore(),
              );
              return false;
            },
            child: SmoothCustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppbar(
                  leading: Tooltip(
                    message: multiSelectMode || searchMode
                        ? "Cancel".tl
                        : "Back".tl,
                    child: IconButton(
                      onPressed: () {
                        if (multiSelectMode) {
                          _exitMultiSelect();
                        } else if (searchMode) {
                          _closeSearch();
                        } else {
                          context.pop();
                        }
                      },
                      icon: multiSelectMode || searchMode
                          ? const Icon(Icons.close)
                          : const Icon(Icons.arrow_back),
                    ),
                  ),
                  title: multiSelectMode
                      ? Text(selectedComics.length.toString())
                      : searchMode
                      ? TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search'.tl,
                            border: InputBorder.none,
                          ),
                          onChanged: _search,
                        )
                      : Text('History'.tl),
                  actions: multiSelectMode
                      ? selectActions
                      : searchMode
                      ? searchActions
                      : normalActions,
                ),
                SliverGridComics(
                  key: _gridKey,
                  comics: comics,
                  filterBlockedComics: false,
                  selections: {
                    for (final comic in comics)
                      if (selectedComics.contains(_identity(comic)))
                        comic: true,
                  },
                  onLongPressed: null,
                  onTap: multiSelectMode
                      ? (c, heroID) {
                          setState(() {
                            _selectionRequest++;
                            _selectingAll = false;
                            final identity = _identity(c as History);
                            if (selectedComics.contains(identity)) {
                              selectedComics.remove(identity);
                            } else {
                              selectedComics.add(identity);
                            }
                            if (selectedComics.isEmpty) {
                              multiSelectMode = false;
                            }
                          });
                        }
                      : null,
                  badgeBuilder: (c) {
                    return ComicSource.find(c.sourceKey)?.name;
                  },
                  menuBuilder: (c) {
                    return [
                      MenuEntry(
                        icon: Icons.refresh,
                        text: 'Refresh Info'.tl,
                        onClick: () {
                          _refreshHistory(c as History);
                        },
                      ),
                      MenuEntry(
                        icon: Icons.remove,
                        text: 'Remove'.tl,
                        color: context.colorScheme.error,
                        onClick: () {
                          _removeHistory(c as History);
                        },
                      ),
                    ];
                  },
                ),
                if (_pager.error != null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => unawaited(_pager.retry()),
                        icon: const Icon(Icons.refresh),
                        label: Text('Retry'.tl),
                      ),
                    ),
                  )
                else if (_pager.loading)
                  const SliverListLoadingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String getDescription(History h) {
    var res = "";
    if (h.ep >= 1) {
      res += "Chapter @ep".tlParams({"ep": h.ep});
    }
    if (h.page >= 1) {
      if (h.ep >= 1) {
        res += " - ";
      }
      res += "Page @page".tlParams({"page": h.page});
    }
    return res;
  }
}
