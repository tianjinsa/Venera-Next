import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism show TonalButtonTheme;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism show LiquidGlassScope;
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/translations.dart';

class MobileFolderSheetHeader extends StatelessWidget {
  const MobileFolderSheetHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            namesRoute: true,
            header: true,
            child: Text(
              'Folders'.tl,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        prism.TonalButtonTheme(
          glass: prism.LiquidGlassScope.of(context),
          child: MobileToolbarButton(
            key: const ValueKey('mobile-folder-sheet-close'),
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const prism.GlyphIcon(prism.Glyphs.close, size: 20),
            onPressed: onClose,
          ),
        ),
      ],
    ),
  );
}

class MobileFolderSheetSection extends StatelessWidget {
  const MobileFolderSheetSection({
    super.key,
    required this.label,
    required this.icon,
    required this.action,
  });

  final String label;
  final IconData icon;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 4),
      child: prism.ListRow(
        minHeight: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        horizontalTitleGap: 6,
        leading: ExcludeSemantics(
          child: Icon(
            icon,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Semantics(
          header: true,
          child: Text(
            label,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: prism.TonalButtonTheme(
          glass: prism.LiquidGlassScope.of(context),
          child: action,
        ),
      ),
    );
  }
}

/// A matte, lazy folder row. Selection and expansion deliberately use
/// separate sibling controls: activating one never triggers the other.
class MobileFolderSheetRow extends StatelessWidget {
  const MobileFolderSheetRow({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.count,
    this.countHint,
    this.selected = false,
    this.nested = false,
    this.expanded,
    this.onToggle,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final String? subtitle;
  final int? count;
  final String? countHint;
  final bool selected;
  final bool nested;

  /// Null for leaf rows. A true/false value with a null [onToggle] is a
  /// visible but disabled expansion control (for example, during search).
  final bool? expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MobileContentSurface(
      style: MobileContentStyle.row,
      selected: selected,
      margin: EdgeInsetsDirectional.fromSTEB(nested ? 24 : 10, 3, 10, 3),
      child: LayoutBuilder(
        builder: (context, box) {
          final large = MediaQuery.textScalerOf(context).scale(16) > 23;
          final stacked =
              large || box.maxWidth < (expanded == null ? 226 : 266);
          final count = this.count;
          final accent = onPressed == null
              ? scheme.onSurface.withValues(alpha: .38)
              : selected
              ? scheme.primary
              : scheme.onSurfaceVariant;
          final check = selected
              ? ExcludeSemantics(
                  child: prism.GlyphIcon(
                    prism.Glyphs.check,
                    key: const ValueKey('mobile-folder-sheet-selected'),
                    size: 16,
                    color: accent,
                  ),
                )
              : null;
          final countText = count == null
              ? null
              : Tooltip(
                  message: countHint ?? 'Comics directly in this folder'.tl,
                  child: Text(
                    '@a comics'.tlParams({'a': count}),
                    maxLines: stacked ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
          final action = expanded == null
              ? null
              : Semantics(
                  label: label,
                  expanded: expanded,
                  child: MobileToolbarButton(
                    key: const ValueKey('mobile-folder-sheet-expand'),
                    label: (expanded! ? 'Collapse folder' : 'Expand folder').tl,
                    icon: prism.GlyphIcon(
                      expanded!
                          ? prism.Glyphs.chevronDown
                          : prism.Glyphs.chevronForward,
                      size: 16,
                    ),
                    onPressed: onToggle,
                  ),
                );
          return Row(
            children: [
              Expanded(
                child: Semantics(
                  selected: selected,
                  enabled: onPressed != null,
                  button: true,
                  child: ClickInkWell(
                    key: const ValueKey('mobile-folder-sheet-select'),
                    onTap: onPressed,
                    customBorder: MobileContentSurface.inkShapeOf(
                      context,
                      MobileContentStyle.row,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: prism.ListRow(
                            minHeight: 50,
                            minVerticalPadding: 6,
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            horizontalTitleGap: 6,
                            leading: box.maxWidth < 175
                                ? null
                                : ExcludeSemantics(
                                    child: Icon(icon, size: 20, color: accent),
                                  ),
                            title: Text(
                              label,
                              // Preserve full accessible names when the row wraps.
                              semanticsLabel: label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: onPressed == null
                                  ? TextStyle(color: accent)
                                  : null,
                            ),
                            subtitle:
                                subtitle == null && (!stacked || count == null)
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (subtitle case final text?)
                                        Text(
                                          text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (stacked) ?countText,
                                    ],
                                  ),
                            trailing: stacked ? null : countText,
                          ),
                        ),
                        if (check != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: check,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (action != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: action,
                ),
            ],
          );
        },
      ),
    );
  }
}
