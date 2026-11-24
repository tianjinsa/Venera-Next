import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/routing/page_jump_target.dart';

import 'search_shortcut.dart';
import 'search_shortcut_manager.dart';
import 'mobile_search_widgets.dart';

PageJumpTarget? resolveSearchShortcut(SearchShortcut shortcut) {
  return ComicSource.find(shortcut.sourceKey)?.handleClickTagEvent
      ?.call(shortcut.namespace, shortcut.value);
}

void openSearchShortcut(BuildContext context, SearchShortcut shortcut) {
  final target = resolveSearchShortcut(shortcut);
  if (target == null) {
    context.showMessage(message: 'Search shortcut unavailable'.tl);
    return;
  }
  target.jump(context, searchOrigin: context);
}

String _shortcutAction(SearchShortcut shortcut, bool saved) => saved
    ? (shortcut.isAuthor ? 'Unfavorite author'.tl : 'Remove tag shortcut'.tl)
    : (shortcut.isAuthor ? 'Favorite author'.tl : 'Save tag shortcut'.tl);

Future<void> _toggleShortcut(
  BuildContext context,
  SearchShortcut shortcut,
  bool saved,
) async {
  final manager = SearchShortcutManager.instance;
  try {
    await (saved ? manager.remove(shortcut) : manager.add(shortcut));
    if (context.mounted) {
      context.showMessage(
        message: saved
            ? 'Search shortcut removed'.tl
            : 'Search shortcut saved'.tl,
      );
    }
  } catch (error, stack) {
    Log.error('Search shortcut', error, stack);
    if (context.mounted) context.showMessage(message: error.toString());
  }
}

void _copyShortcut(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  context.showMessage(message: 'Copied'.tl);
}

void showSearchShortcutMenu({
  required MenuRouteController menus,
  bool Function()? isValid,
  required BuildContext context,
  required Offset location,
  required String copyText,
  SearchShortcut? shortcut,
}) {
  final manager = SearchShortcutManager.instance;
  final entries = <MenuEntry>[
    MenuEntry(
      icon: Icons.copy,
      text: 'Copy'.tl,
      onClick: () => _copyShortcut(context, copyText),
    ),
  ];
  if (shortcut != null) {
    final saved = manager.contains(shortcut);
    entries.add(
      MenuEntry(
        icon: saved ? Icons.bookmark_remove : Icons.bookmark_add,
        text: _shortcutAction(shortcut, saved),
        onClick: () => _toggleShortcut(context, shortcut, saved),
      ),
    );
  }
  menus.show(context, location, entries, isValid: isValid);
}

class SearchShortcutsSliver extends StatefulWidget {
  const SearchShortcutsSliver({super.key});

  @override
  State<SearchShortcutsSliver> createState() => _SearchShortcutsSliverState();
}

class _SearchShortcutsSliverState extends State<SearchShortcutsSliver> {
  final manager = SearchShortcutManager.instance;

  @override
  void initState() {
    super.initState();
    manager.addListener(_update);
  }

  @override
  void dispose() {
    manager.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = manager.all;
    if (shortcuts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final authors = shortcuts
        .where((shortcut) => shortcut.isAuthor)
        .toList(growable: false);
    final tags = shortcuts
        .where((shortcut) => !shortcut.isAuthor)
        .toList(growable: false);
    final mobile = MobileUi.enabledOf(context);
    final children = <Widget>[
      const SizedBox(height: 16),
      if (mobile)
        MobileSearchSectionHeader(
          'Search shortcuts'.tl,
          leading: const Icon(Icons.bookmarks_outlined, size: 20),
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bookmarks_outlined),
          title: Text('Search shortcuts'.tl),
        ),
      if (authors.isNotEmpty) ...[
        _buildSectionTitle('Favorite authors'.tl, mobile),
        for (final shortcut in authors) _buildItem(context, shortcut),
      ],
      if (tags.isNotEmpty) ...[
        _buildSectionTitle('Saved tag searches'.tl, mobile),
        for (final shortcut in tags) _buildItem(context, shortcut),
      ],
    ];
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => children[index],
        childCount: children.length,
      ),
    ).sliverPaddingHorizontal(16);
  }

  Widget _buildSectionTitle(String title, bool mobile) {
    if (mobile) return MobileSearchSectionHeader(title);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildItem(BuildContext context, SearchShortcut shortcut) {
    final source = ComicSource.find(shortcut.sourceKey);
    final sourceName = source?.name ?? shortcut.sourceKey;
    final subtitle = '$sourceName · ${shortcut.namespace}';

    if (MobileUi.enabledOf(context)) {
      return Padding(
        key: ValueKey(shortcut.identity),
        padding: const EdgeInsets.only(bottom: 6),
        child: MobileSearchMenuRow(
          title: shortcut.value,
          subtitle: subtitle,
          leading: Icon(
            shortcut.isAuthor ? Icons.person_outline : Icons.label_outline,
            size: 20,
          ),
          onSearch: (origin) => openSearchShortcut(origin, shortcut),
          items: [
            prism.PopupMenuItem(
              label: 'Copy'.tl,
              glyph: prism.Glyphs.copy,
              onPressed: () => _copyShortcut(context, shortcut.value),
            ),
            prism.PopupMenuItem(
              label: _shortcutAction(shortcut, true),
              danger: true,
              onPressed: () => _toggleShortcut(context, shortcut, true),
            ),
          ],
        ),
      );
    }

    return ContextMenuRegion(
      identity: shortcut.identity,
      builder: (itemContext, menus) {
        void showShortcutMenu([Offset? position]) {
          final renderBox = itemContext.findRenderObject() as RenderBox;
          final offset = renderBox.localToGlobal(Offset.zero);
          final location =
              position ??
              Offset(
                offset.dx + renderBox.size.width / 2 - 121,
                offset.dy + renderBox.size.height - 8,
              );
          showSearchShortcutMenu(
            menus: menus,
            context: itemContext,
            location: location,
            copyText: shortcut.value,
            shortcut: shortcut,
          );
        }

        return MobileSearchAnchor(
          builder: (origin) => ClickInkWell(
            onTap: () => openSearchShortcut(origin, shortcut),
            onLongPress: () => showShortcutMenu(),
            onSecondaryTapUp: (details) =>
                showShortcutMenu(details.globalPosition),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                shortcut.isAuthor ? Icons.person_outline : Icons.label_outline,
              ),
              title: Text(
                shortcut.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
