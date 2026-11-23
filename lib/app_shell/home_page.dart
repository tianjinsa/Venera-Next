import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/features/history/history_scope.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/components/mobile_scroll_top.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/history/history.dart';
import 'package:venera_next/features/favorites/favorites.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/follow_updates/follow_updates.dart';
import 'package:venera_next/features/image_favorites/image_favorites.dart';
import 'package:venera_next/features/search/search.dart';
import 'package:venera_next/features/sync/sync.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _mobileScroll = ScrollController();

  @override
  void dispose() {
    _mobileScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MobileUi.enabledOf(context);
    final scrollView = SmoothCustomScrollView(
      controller: mobile ? _mobileScroll : null,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const SearchEntry(),
        const SyncStatusSummary(),
        HistorySummary(
          manager: HistoryScope.read(context),
          favoriteChanges: FavoritesScope.read(context),
        ),
        const ReadLaterSummary(),
        const LocalComicsSummary(),
        const FollowUpdatesWidget(),
        ComicSourceSummary(manager: ComicSourceManager.current),
        const ImageFavoritesSummary(),
        if (!mobile)
          SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    if (mobile) {
      return MobileScrollTopOverlay(
        controller: _mobileScroll,
        child: scrollView,
      );
    }
    return context.width > changePoint
        ? scrollView.paddingHorizontal(8)
        : scrollView;
  }
}
