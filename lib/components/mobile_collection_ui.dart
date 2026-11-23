import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/goo.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/motion.dart' as prism;
import 'package:prism_ui/navigation_dock.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/translations.dart';

/// An existing collection action, shown in a Prism shortcut slot on mobile
/// without changing the callback shared with the desktop toolbar.
Widget collectionShortcut(
  BuildContext context, {
  Key? key,
  required String label,
  required Widget icon,
  required VoidCallback? onPressed,
}) {
  if (MobileUi.enabledOf(context)) {
    return MobileToolbarButton(
      key: key,
      label: label,
      icon: icon,
      onPressed: onPressed,
    );
  }
  return IconButton(key: key, tooltip: label, icon: icon, onPressed: onPressed);
}

/// Converts existing folder/batch actions to leaves while keeping their
/// admission and confirmation logic in the page that owns the selection.
prism.PopupMenuItem collectionMenuAction(
  BuildContext context,
  MenuEntry entry,
) => prism.PopupMenuItem(
  label: entry.text,
  glyph: switch (entry.icon) {
    Icons.copy => prism.Glyphs.copy,
    Icons.select_all => prism.Glyphs.selectAll,
    Icons.check => prism.Glyphs.check,
    Icons.sort => prism.Glyphs.sort,
    _ => null,
  },
  danger:
      entry.color == Theme.of(context).colorScheme.error ||
      entry.icon == Icons.delete ||
      entry.icon == Icons.delete_outline,
  onPressed: entry.onClick,
);

/// One selectable item in a collection-options submenu. The persisted value,
/// not a hover or a gesture preview, is the source of the check mark.
prism.PopupMenuItem collectionOption<T>({
  required String label,
  required T value,
  required T current,
  required ValueChanged<T> onSelected,
}) => prism.PopupMenuItem(
  label: label,
  checked: current == value,
  onPressed: () {
    if (current != value) onSelected(value);
  },
);

/// Folder rows share spacing and press feedback whether the folder is local
/// or remote. The optional destructive action is a separate target.
class MobileCollectionFolder extends StatelessWidget {
  const MobileCollectionFolder({
    super.key,
    required this.label,
    required this.onOpen,
    this.onDelete,
  });

  final String label;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: MobileContentRow(
              leading: const Icon(Icons.folder_outlined, size: 20),
              title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const prism.GlyphIcon(prism.Glyphs.chevronForward),
              onTap: onOpen,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            MobileToolbarButton(
              label: 'Delete Folder'.tl,
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps a collection tile's footprint stable when entering/exiting batch
/// selection. Paints only a small indicator on a tile, never a glass layer.
class MobileCollectionTileFrame extends StatelessWidget {
  const MobileCollectionTileFrame({
    super.key,
    required this.selectionMode,
    required this.selected,
    required this.child,
  });

  final bool selectionMode;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        selected: selectionMode ? selected : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected && selectionMode ? colors.secondaryContainer : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (selectionMode)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected ? colors.primary : colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? colors.primary : colors.outline,
                          ),
                        ),
                        child: SizedBox.square(
                          dimension: 20,
                          child: selected
                              ? prism.GlyphIcon(
                                  prism.Glyphs.check,
                                  size: 14,
                                  color: colors.onPrimary,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The query, filter, batch-selection and route lifetime stay with the page.
class CollectionBarSearch {
  const CollectionBarSearch({
    required this.open,
    required this.controller,
    required this.onOpen,
    required this.onClose,
    required this.onChanged,
    this.more,
  });

  final bool open;
  final TextEditingController controller;
  final VoidCallback onOpen, onClose;
  final ValueChanged<String> onChanged;
  final Widget? more;
}

prism.PopupMenuItem collectionSelectionEntry(
  VoidCallback? onSelect, {
  String? label,
}) => prism.PopupMenuItem(
  label: label ?? 'Multi-Select'.tl,
  glyph: prism.Glyphs.selectAll,
  onPressed: onSelect,
);

/// Compact adaptation of FlClash's private scaffold _BarSearch: measure the
/// actual toolbar button, grow a Prism GooPane from it, and lay the real
/// SearchField out at its final width throughout. No route or list rebuilds
/// per animation tick. Reversal uses the same path, including mid-flight.
class MobileCollectionSearchToolbar extends StatefulWidget {
  const MobileCollectionSearchToolbar({
    super.key,
    required this.search,
    required this.toolbar,
  });
  final CollectionBarSearch search;
  final Widget Function(Widget searchButton) toolbar;

  @override
  State<MobileCollectionSearchToolbar> createState() =>
      _MobileCollectionSearchToolbarState();
}

class _MobileCollectionSearchToolbarState
    extends State<MobileCollectionSearchToolbar>
    with SingleTickerProviderStateMixin {
  final _origin = GlobalKey();
  final _stack = GlobalKey();
  final _focus = FocusNode();
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 280),
    value: widget.search.open ? 1 : 0,
  );
  static final _growth = prism.SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 390, ratio: .75),
    seconds: .45,
  );
  Rect? _from;

  void _measure() {
    final source = _origin.currentContext?.findRenderObject();
    final stack = _stack.currentContext?.findRenderObject();
    if (source is RenderBox &&
        stack is RenderBox &&
        source.attached &&
        stack.attached &&
        source.hasSize &&
        stack.hasSize) {
      _from = source.localToGlobal(Offset.zero, ancestor: stack) & source.size;
    }
  }

  void _open() {
    _measure();
    widget.search.onOpen();
  }

  void _requestFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && widget.search.open) _focus.requestFocus();
  });

  @override
  void initState() {
    super.initState();
    if (widget.search.open) _requestFocus();
  }

  @override
  void didUpdateWidget(MobileCollectionSearchToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search.open == widget.search.open) return;
    _measure(); // Also refresh after rotation / a system back.
    if (widget.search.open) {
      _motion.forward();
      _requestFocus();
    } else {
      _focus.unfocus();
      _motion.reverse();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.search;
    final colors = prism.Theme.of(context).colorScheme;
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final height = prism.TonalButtonSize.bar.button;
    final toolbar = widget.toolbar(
      MobileToolbarButton(
        key: _origin,
        label: 'Search'.tl,
        icon: const prism.GlyphIcon(prism.Glyphs.search),
        onPressed: _open,
      ),
    );
    final field = prism.SearchField(
      controller: spec.controller,
      focusNode: _focus,
      hintText: 'Search'.tl,
      onChanged: spec.onChanged,
    );
    final flanks = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MobileToolbarButton(
          icon: const prism.GlyphIcon(prism.Glyphs.close),
          label: 'Cancel'.tl,
          onPressed: spec.onClose,
        ),
        if (spec.more != null) ...[const SizedBox(width: 8), spec.more!],
      ],
    );
    final glass = prism.LiquidGlassScope.of(context);
    return Material(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final count = spec.more == null ? 1 : 2;
          final reserved = (height + gap) * count;
          final left = padding.left + 16;
          final right = constraints.maxWidth - padding.right - 16;
          final y = (constraints.maxHeight + padding.top - height) / 2;
          final slot = Rect.fromLTWH(
            left + (rtl ? reserved : 0),
            y,
            math.max(0.0, right - left - reserved),
            height,
          );
          return AnimatedBuilder(
            animation: _motion,
            builder: (_, _) {
              final t = _motion.value;
              final visible = spec.open || t > 0;
              final begin =
                  _from ??
                  Rect.fromLTWH(rtl ? left : right - height, y, height, height);
              final rect = Rect.lerp(begin, slot, _growth.transform(t))!;
              final opacity = const Interval(.24, .78).transform(t);
              return Stack(
                key: _stack,
                fit: StackFit.expand,
                children: [
                  ExcludeFocus(
                    excluding: spec.open,
                    child: ExcludeSemantics(
                      excluding: spec.open,
                      child: IgnorePointer(
                        ignoring: spec.open,
                        child: Opacity(
                          opacity: 1 - const Interval(0, .54).transform(t),
                          child: toolbar,
                        ),
                      ),
                    ),
                  ),
                  if (visible)
                    ExcludeFocus(
                      excluding: !spec.open,
                      child: ExcludeSemantics(
                        excluding: !spec.open,
                        child: IgnorePointer(
                          ignoring: !spec.open,
                          child: prism.GooSurface(
                            glass: glass
                                ? prism.LiquidGlassStyle.regular(colors)
                                : null,
                            color: colors.surfaceContainerHigh,
                            child: prism.TonalButtonTheme(
                              glass: glass,
                              child: Stack(
                                children: [
                                  Positioned.fromRect(
                                    rect: rect,
                                    child: prism.ElasticPress(
                                      child: prism.GooPane(
                                        key: const ValueKey(
                                          'collection-search-pane',
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            height,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Opacity(
                                                opacity: opacity,
                                                child: OverflowBox(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  minWidth: slot.width,
                                                  maxWidth: slot.width,
                                                  child: field,
                                                ),
                                              ),
                                              if (opacity < 1)
                                                IgnorePointer(
                                                  child: Opacity(
                                                    opacity: 1 - opacity,
                                                    child: const Center(
                                                      child: prism.GlyphIcon(
                                                        prism.Glyphs.search,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  PositionedDirectional(
                                    end:
                                        (rtl ? padding.left : padding.right) +
                                        16,
                                    top: y,
                                    height: height,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: flanks,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
