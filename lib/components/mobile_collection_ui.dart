import 'package:flutter/material.dart';
import 'package:prism_ui/card.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/menu.dart';
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
            child: prism.Card(
              onPressed: onOpen,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const prism.GlyphIcon(prism.Glyphs.chevronForward),
                ],
              ),
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
