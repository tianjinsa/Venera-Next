import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/loading.dart';
import 'package:venera_next/components/mobile_dock_inset.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/routing/page_jump_target.dart';
import 'package:venera_next/routing/settings.dart';
import 'package:venera_next/foundation/extensions.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'ranking_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<CategoriesPage> {
  var categories = <String>[];

  late TabController controller;

  void onSettingsChanged() {
    var categories = GlobalPreferenceStore(
      appdata.settings,
    ).read(DiscoveryPreferences.categoryPages);
    var allCategories = ComicSource.all()
        .map((e) => e.categoryData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();
    categories = categories
        .where((element) => allCategories.contains(element))
        .toList();
    if (!categories.isEqualTo(this.categories)) {
      setState(() {
        this.categories = categories;
      });
      controller = TabController(length: categories.length, vsync: this);
    }
  }

  @override
  void initState() {
    super.initState();
    var categories = GlobalPreferenceStore(
      appdata.settings,
    ).read(DiscoveryPreferences.categoryPages);
    var allCategories = ComicSource.all()
        .map((e) => e.categoryData?.key)
        .where((element) => element != null)
        .map((e) => e!)
        .toList();
    this.categories = categories
        .where((element) => allCategories.contains(element))
        .toList();
    appdata.settings.addListener(onSettingsChanged);
    controller = TabController(length: categories.length, vsync: this);
  }

  void addPage() {
    showPopUpWidget(appNavigation.rootContext, setCategoryPagesWidget());
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    appdata.settings.removeListener(onSettingsChanged);
  }

  Widget buildEmpty() {
    var msg = "No Category Pages".tl;
    msg += '\n';
    VoidCallback onTap;
    if (ComicSource.isEmpty) {
      msg += "Please add some sources".tl;
      onTap = () {
        context.to(() => ComicSourcePage());
      };
    } else {
      msg += "Please check your settings".tl;
      onTap = addPage;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: false,
      buttonText: "Manage".tl,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (categories.isEmpty) {
      return buildEmpty();
    }

    return Material(
      child: Column(
        children: [
          AppTabBar(
            controller: controller,
            key: PageStorageKey(categories.toString()),
            tabs: categories.map((e) {
              String title = e;
              try {
                title = getCategoryDataWithKey(e).title;
              } catch (e) {
                //
              }
              return Tab(text: title, key: Key(e));
            }).toList(),
            actionButton: TabActionButton(
              icon: const Icon(Icons.add),
              text: "Add".tl,
              onPressed: addPage,
            ),
          ).paddingTop(context.padding.top),
          Expanded(
            child: TabBarView(
              controller: controller,
              children: categories.map((e) => _CategoryPage(e)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _CategoryPage extends StatelessWidget {
  const _CategoryPage(this.category);

  final String category;

  CategoryData get data => getCategoryDataWithKey(category);

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    if (data.enableRankingPage || data.buttons.isNotEmpty) {
      children.add(buildTitle(data.title));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
          child: Wrap(
            children: [
              if (data.enableRankingPage)
                buildTag("Ranking".tl, (_) {
                  context.to(() => RankingPage(categoryKey: data.key));
                }),
              for (var buttonData in data.buttons)
                buildTag(buttonData.label.tl, (_) => buttonData.onTap()),
            ],
          ),
        ),
      );
    }

    for (var part in data.categories) {
      if (part.enableRandom) {
        children.add(
          StatefulBuilder(
            builder: (context, updater) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTitleWithRefresh(part.title, () => updater(() {})),
                  buildTags(part.categories),
                ],
              );
            },
          ),
        );
      } else {
        children.add(buildTitle(part.title));
        children.add(buildTags(part.categories));
      }
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MobileDockInset.of(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Text(
        title.tl,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget buildTitleWithRefresh(String title, void Function() onRefresh) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
      child: Row(
        children: [
          Text(
            title.tl,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget buildTags(List<CategoryItem> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: Wrap(
        children: List<Widget>.generate(
          categories.length,
          (index) => buildCategory(categories[index]),
        ),
      ),
    );
  }

  Widget buildCategory(CategoryItem item) => buildTag(
    item.label,
    (origin) {
      if (MobileUi.enabledOf(origin)) {
        item.target.jump(origin, searchOrigin: origin);
      } else {
        item.target.jump(appNavigation.mainNavigatorKey!.currentContext!);
      }
    },
    searchAnchor:
        item.target.page == 'search' || item.target.page == 'category',
  );

  Widget buildTag(
    String label,
    ValueChanged<BuildContext> onClick, {
    bool searchAnchor = false,
  }) {
    const border = BorderRadius.all(Radius.circular(8));
    Widget tag(BuildContext origin) => Material(
      borderRadius: border,
      color: origin.colorScheme.primaryContainer.toOpacity(.72),
      child: ClickInkWell(
        borderRadius: border,
        onTap: () => onClick(origin),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(label),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: searchAnchor
          ? MobileSearchAnchor(radius: 8, builder: tag)
          : Builder(builder: tag),
    );
  }

  bool get enableTranslation => appLocale.languageCode == 'zh';
}
