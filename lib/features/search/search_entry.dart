import 'package:flutter/material.dart';
import 'package:prism_ui/card.dart' as prism show Card;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:prism_ui/shape.dart' as prism show AppCorner;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'search_page.dart';

void openGlobalSearch(BuildContext origin) =>
    pushSearchFrom(origin, () => const SearchPage(focusOnArrival: true));

class SearchEntry extends StatelessWidget {
  const SearchEntry({super.key});

  @override
  Widget build(BuildContext context) {
    void openSearch() => context.to(() => const SearchPage());
    if (MobileUi.enabledOf(context)) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Builder(
            builder: (origin) => prism.Card(
              radius: prism.AppCorner.full,
              onPressed: () => openGlobalSearch(origin),
              child: prism.ListRow(
                leading: const prism.GlyphIcon(prism.Glyphs.search, size: 20),
                title: Text('Search'.tl),
                minHeight: 50,
              ),
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Container(
        height: App.isMobile ? 52 : 46,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
          child: ClickInkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: openSearch,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text('Search'.tl, style: ts.s16),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
