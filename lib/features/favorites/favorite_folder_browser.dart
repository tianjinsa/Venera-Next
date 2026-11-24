import 'package:flutter/material.dart';
import 'package:venera_next/components/mobile_dock_inset.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;
import 'package:prism_ui/text_field.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/components/tv_navigation.dart';
import 'package:venera_next/foundation/translations.dart';

import 'favorite_folder.dart';
import 'mobile_folder_sheet_widgets.dart';

/// Shared folder navigation for browsing, membership and destination picking.
/// Expansion is presentation-only; searching never changes stored hierarchy.
class FavoriteFolderBrowser extends StatefulWidget {
  const FavoriteFolderBrowser({
    super.key,
    required this.tree,
    required this.onSelected,
    this.selected = const {},
    this.disabled = const {},
    this.hidden = const {},
    this.enabled = true,
    this.checkboxes = false,
    this.countFor,
    this.trailingBuilder,
    this.headers = const [],
    this.footers = const [],
    this.trailingSlivers = const [],
    this.mobileSheetRows = false,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.primary = false,
  });

  final FavoriteFolderTree tree;
  final ValueChanged<String> onSelected;
  final Set<String> selected;
  final Set<String> disabled;
  final Set<String> hidden;
  final bool enabled;
  final bool checkboxes;
  final int Function(String)? countFor;
  final Widget Function(String)? trailingBuilder;
  final List<Widget> headers;
  final List<Widget> footers;
  final List<Widget> trailingSlivers;

  /// Only the physical-left favorites sheet uses these navigation cells.
  /// Membership/editing pickers retain their existing row and controls.
  final bool mobileSheetRows;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final bool primary;

  @override
  State<FavoriteFolderBrowser> createState() => _FavoriteFolderBrowserState();
}

class _FavoriteFolderBrowserState extends State<FavoriteFolderBrowser> {
  final _search = TextEditingController();
  final _expanded = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  void _revealSelection() {
    for (final name in widget.selected) {
      final parent = widget.tree.named(name)?.parentId;
      if (parent != null) _expanded.add(parent);
    }
  }

  @override
  void didUpdateWidget(FavoriteFolderBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected.containsAll(widget.selected) ||
        widget.selected.any(
          (name) =>
              oldWidget.tree.named(name)?.parentId !=
              widget.tree.named(name)?.parentId,
        )) {
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _updateQuery(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  Widget _buildMobileSheetSearch(BuildContext context) {
    final label = 'Search local folders'.tl;
    final border = prism.AppShape.input.copyWith(
      borderRadius: prism.AppRadius.full,
      borderSide: BorderSide.none,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 175;
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _search,
          builder: (context, value, _) => Semantics(
            label: label,
            child: prism.TextField(
              key: const ValueKey('favorite-folder-search'),
              controller: _search,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              inputFormatters: [LengthLimitingTextInputFormatter(256)],
              onChanged: _updateQuery,
              decoration: prism.InputDecoration(
                hintText: compact ? 'Search'.tl : label,
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: border,
                enabledBorder: border,
                contentPadding: EdgeInsetsDirectional.only(
                  start: compact ? 9 : 0,
                  end: value.text.isEmpty ? 8 : 0,
                ),
                prefixIcon: compact
                    ? null
                    : const prism.GlyphIcon(prism.Glyphs.search, size: 20),
                prefixIconConstraints: const BoxConstraints.tightFor(width: 36),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear'.tl,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: compact ? 32 : 44,
                          height: 44,
                        ),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: widget.enabled
                            ? () {
                                _search.clear();
                                _updateQuery('');
                              }
                            : null,
                      ),
                suffixIconConstraints: const BoxConstraints(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch(BuildContext context) {
    if (MobileUi.enabledOf(context)) {
      if (widget.mobileSheetRows) return _buildMobileSheetSearch(context);
      if (widget.enabled) {
        return prism.SearchField(
          key: const ValueKey('favorite-folder-search'),
          controller: _search,
          hintText: 'Search local folders'.tl,
          onChanged: _updateQuery,
        );
      }
    }
    final field = TextField(
      key: const ValueKey('favorite-folder-search'),
      controller: _search,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: 'Search local folders'.tl,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear'.tl,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
              ),
      ),
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
    );
    if (!TvNavigation.enabledOf(context)) return field;
    // EditableText ignores ordinary directional focus intents. Keep horizontal
    // keys for editing, but let a TV remote leave this single-line search.
    return DefaultTextEditingShortcuts(
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
            ignoreTextFields: false,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
            ignoreTextFields: false,
          ),
        },
        child: field,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <FavoriteFolder>[];
    final tree = widget.tree;
    for (final root in tree.roots) {
      final children = tree
          .childrenOf(root.id)
          .where((folder) => !widget.hidden.contains(folder.name))
          .toList();
      if (widget.hidden.contains(root.name) && children.isEmpty) continue;
      final matches = children
          .where(
            (child) => tree.label(child.name).toLowerCase().contains(_query),
          )
          .toList();
      if (_query.isNotEmpty &&
          !root.name.toLowerCase().contains(_query) &&
          matches.isEmpty) {
        continue;
      }
      rows.add(root);
      if (_query.isNotEmpty) {
        rows.addAll(matches);
      } else if (_expanded.contains(root.id)) {
        rows.addAll(children);
      }
    }
    final mobileRows = widget.mobileSheetRows && MobileUi.enabledOf(context);
    final rowIndexes = mobileRows
        ? {
            for (var i = 0; i < rows.length; i++)
              'favorite-folder-${rows[i].id}': i,
          }
        : null;
    final search = Padding(
      padding: mobileRows
          ? const EdgeInsets.symmetric(horizontal: 5, vertical: 8)
          : const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: _buildSearch(context),
    );
    return CustomScrollView(
      primary: widget.primary,
      shrinkWrap: widget.shrinkWrap,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverList.list(children: widget.headers),
              SliverToBoxAdapter(child: search),
              if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No folders found'.tl),
                  ),
                ),
              SliverList.builder(
                itemCount: rows.length,
                findChildIndexCallback: rowIndexes == null
                    ? null
                    : (key) => rowIndexes[(key as ValueKey<String>).value],
                itemBuilder: (context, index) {
                  final folder = rows[index];
                  final children = tree.childrenOf(folder.id);
                  final expanded =
                      _query.isNotEmpty || _expanded.contains(folder.id);
                  final enabled =
                      widget.enabled && !widget.disabled.contains(folder.name);
                  final child = folder.parentId != null;
                  final count = widget.countFor?.call(folder.name);
                  final detail = child && _query.isNotEmpty
                      ? tree.label(folder.name)
                      : children.isEmpty
                      ? null
                      : '@a subfolders'.tlParams({'a': children.length});
                  final key = ValueKey('favorite-folder-${folder.id}');
                  final selected = widget.selected.contains(folder.name);
                  void toggle() {
                    setState(() {
                      if (!_expanded.add(folder.id)) {
                        _expanded.remove(folder.id);
                      }
                    });
                  }

                  final canToggle = widget.enabled && _query.isEmpty;
                  if (mobileRows) {
                    return MobileFolderSheetRow(
                      key: key,
                      label: folder.name,
                      icon: expanded && children.isNotEmpty
                          ? Icons.folder_open
                          : Icons.folder_outlined,
                      subtitle: detail,
                      count: count,
                      selected: selected,
                      nested: child,
                      expanded: children.isEmpty ? null : expanded,
                      onToggle: children.isNotEmpty && canToggle
                          ? toggle
                          : null,
                      onPressed: enabled
                          ? () => widget.onSelected(folder.name)
                          : null,
                    );
                  }
                  final title = Text(folder.name, softWrap: true);
                  final subtitle = detail == null ? null : Text(detail);
                  final trailing =
                      widget.trailingBuilder?.call(folder.name) ??
                      (count == null
                          ? null
                          : Tooltip(
                              message: 'Comics directly in this folder'.tl,
                              child: Chip(
                                label: Text('$count'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ));
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final stackedCount =
                          count != null &&
                          widget.trailingBuilder == null &&
                          constraints.maxWidth < 320 &&
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final secondary = stackedCount
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ?subtitle,
                                Text('@a comics'.tlParams({'a': count})),
                              ],
                            )
                          : subtitle;
                      return Row(
                        key: key,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (child) const SizedBox(width: 24),
                          SizedBox(
                            width: 48,
                            child: children.isEmpty
                                ? const ExcludeSemantics(
                                    child: Icon(Icons.folder_outlined),
                                  )
                                : Semantics(
                                    label: folder.name,
                                    expanded: expanded,
                                    child: IconButton(
                                      tooltip:
                                          (expanded
                                                  ? 'Collapse folder'
                                                  : 'Expand folder')
                                              .tl,
                                      icon: Icon(
                                        expanded
                                            ? Icons.expand_more
                                            : Icons.chevron_right,
                                      ),
                                      onPressed: canToggle ? toggle : null,
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: widget.checkboxes
                                ? CheckboxListTile(
                                    title: title,
                                    subtitle: secondary,
                                    value: widget.selected.contains(
                                      folder.name,
                                    ),
                                    onChanged: enabled
                                        ? (_) => widget.onSelected(folder.name)
                                        : null,
                                  )
                                : ListTile(
                                    title: title,
                                    subtitle: secondary,
                                    trailing: stackedCount ? null : trailing,
                                    selected: widget.selected.contains(
                                      folder.name,
                                    ),
                                    enabled: enabled,
                                    onTap: enabled
                                        ? () => widget.onSelected(folder.name)
                                        : null,
                                    contentPadding: const EdgeInsets.only(
                                      left: 4,
                                      right: 12,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SliverList.list(children: widget.footers),
              ...widget.trailingSlivers,
              if (MobileDockInset.of(context) > 0)
                SliverToBoxAdapter(
                  child: SizedBox(height: MobileDockInset.of(context)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class FavoriteFolderSelect extends StatelessWidget {
  const FavoriteFolderSelect({
    super.key,
    required this.tree,
    required this.current,
    required this.onChanged,
    this.allowRoot = false,
    this.rootsOnly = false,
    this.disabled = const {},
    this.nullLabel,
    this.menuOwnerContext,
  });
  final FavoriteFolderTree tree;
  final String? current;
  final ValueChanged<String?>? onChanged;
  final bool allowRoot;
  final bool rootsOnly;
  final Set<String> disabled;
  final String? nullLabel;
  final BuildContext? menuOwnerContext;

  @override
  Widget build(BuildContext context) {
    final choices = rootsOnly ? FavoriteFolderTree(tree.roots) : tree;
    final names = [
      if (allowRoot) '',
      ...choices.flattened.map((folder) => folder.name),
    ];
    return Select(
      menuOwnerContext: menuOwnerContext,
      label: 'Local Favorites'.tl,
      current: current ?? (allowRoot ? '' : null),
      values: names,
      labels: {
        if (allowRoot) '': nullLabel ?? 'First-level folder'.tl,
        for (final name in names)
          if (name.isNotEmpty) name: choices.label(name),
      },
      minWidth: 112,
      onTap: onChanged == null
          ? null
          : (index) {
              final name = names[index];
              if (!disabled.contains(name)) {
                onChanged!(name.isEmpty ? null : name);
              }
            },
      menuBuilder: (context, select) => FavoriteFolderBrowser(
        primary: MobileUi.enabledOf(context),
        tree: choices,
        selected: {?current},
        disabled: disabled,
        onSelected: select,
        headers: [
          if (allowRoot)
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(nullLabel ?? 'First-level folder'.tl),
              selected: current == null,
              onTap: () => select(''),
            ),
        ],
      ),
    );
  }
}
