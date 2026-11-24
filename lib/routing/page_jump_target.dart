import 'package:flutter/widgets.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/discovery/discovery.dart';
import 'package:venera_next/features/search/search.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/log.dart';

extension PageJumpTargetNavigation on PageJumpTarget {
  void jump(BuildContext context, {BuildContext? searchOrigin}) {
    // The source owns the destination and its payload. A list of one author's
    // works can be a category with an opaque param, not a keyword search.
    final Widget Function() destination;
    switch (page) {
      case 'search':
        destination = () => SearchResultPage(
          text: attributes?['text'] ?? attributes?['keyword'] ?? '',
          sourceKey: sourceKey,
          options: List.from(attributes?['options'] ?? []),
        );
      case 'category':
        final key = ComicSource.find(sourceKey)!.categoryData!.key;
        destination = () => CategoryComicsPage(
          categoryKey: key,
          category:
              attributes?['category'] ??
              (throw ArgumentError('Category name is required')),
          options: List.from(attributes?['options'] ?? []),
          param: attributes?['param'],
        );
      default:
        Log.error('Page Jump', 'Unknown page: $page');
        return;
    }

    if (searchOrigin != null) {
      pushSearchFrom(searchOrigin, destination);
    } else {
      context.to(destination);
    }
  }
}
