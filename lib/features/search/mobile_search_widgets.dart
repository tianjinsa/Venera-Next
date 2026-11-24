import 'package:flutter/material.dart';
import 'package:prism_ui/chip.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/list_row.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/surface.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:prism_ui/typography.dart' as prism;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_search_route.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/translations.dart';

/// The same section treatment for sources, suggestions, shortcuts and history.
class MobileSearchSectionHeader extends StatelessWidget {
  const MobileSearchSectionHeader(
    this.label, {
    super.key,
    this.leading,
    this.action,
  });

  final String label;
  final Widget? leading, action;

  @override
  Widget build(BuildContext context) => prism.ListRow(
    minHeight: 44,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    horizontalTitleGap: 8,
    leading: leading,
    title: Semantics(
      header: true,
      child: Text(
        label,
        style: prism.AppTextStyle.headline
            .of(context)
            .copyWith(
              color: prism.Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ),
    trailing: action,
  );
}

class MobileSearchRow extends StatelessWidget {
  const MobileSearchRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
  });

  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap, onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  Widget build(BuildContext context) => MobileContentSurface(
    child: ClickInkWell(
      customBorder: MobileContentSurface.inkShapeOf(
        context,
        MobileContentStyle.row,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTapUp,
      child: prism.ListRow(
        minHeight: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        horizontalTitleGap: 10,
        leading: leading,
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    ),
  );
}

class MobileSearchMenuRow extends StatelessWidget {
  const MobileSearchMenuRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onSearch,
    required this.items,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final ValueChanged<BuildContext> onSearch;
  final List<prism.PopupMenuItem> items;

  @override
  Widget build(BuildContext context) {
    VoidCallback? openMenu;
    return MobileSearchAnchor(
      builder: (origin) => MobileSearchRow(
        title: title,
        subtitle: subtitle,
        leading: leading,
        onTap: () => onSearch(origin),
        onLongPress: () => openMenu?.call(),
        onSecondaryTapUp: (_) => openMenu?.call(),
        // Prism claims presses anywhere in its PopupAnchor. Anchor only
        // the accessory so a tap on the rest of the row still searches.
        trailing: MobilePopupAnchor(
          items: items,
          targetBuilder: (open) {
            openMenu = open;
            return MobileToolbarButton(
              label: 'More'.tl,
              icon: const prism.GlyphIcon(prism.Glyphs.more, size: 20),
              onPressed: open,
            );
          },
        ),
      ),
    );
  }
}

class MobileSearchTagSuggestion extends StatelessWidget {
  const MobileSearchTagSuggestion({
    super.key,
    required this.tag,
    required this.namespace,
    this.translation,
    required this.onSelected,
  });

  final String tag, namespace;
  final String? translation;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => MobileSearchRow(
    title: tag,
    subtitle: [
      if (translation case final translated? when translated != tag) translated,
      namespace,
    ].join(' · '),
    leading: const Icon(Icons.label_outline, size: 20),
    trailing: const prism.GlyphIcon(prism.Glyphs.chevronForward, size: 16),
    onTap: onSelected,
  );
}

/// Source and multi-option tokens share Prism selection without making old
/// pills brighter than the rest of the search page content.
class MobileSearchChoiceChip extends StatelessWidget {
  const MobileSearchChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = prism.Theme.of(context);
    final fill = MobileContentPalette.fill(context);
    return Semantics(
      selected: selected,
      child: prism.SurfaceScope(
        level: prism.SurfaceLevel.page,
        child: prism.Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surfaceContainer: fill,
              surfaceBright: fill,
            ),
          ),
          child: prism.Chip(
            label: label,
            selected: selected,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
