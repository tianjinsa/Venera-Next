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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 155;
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(compact ? 6 : 14, 6, 2, 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                  'Folders'.tl,
                  style: compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleLarge,
                  maxLines: compact ? 2 : 1,
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
    },
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
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 155;
        final inset = compact ? 4.0 : 10.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
          child: prism.ListRow(
            minHeight: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            horizontalTitleGap: 6,
            leading: compact
                ? null
                : ExcludeSemantics(
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
      },
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
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 155;
        final start = narrow ? (nested ? 12.0 : 4.0) : (nested ? 24.0 : 10.0);
        final end = narrow ? 4.0 : 10.0;
        return MobileContentSurface(
          style: MobileContentStyle.row,
          selected: selected,
          margin: EdgeInsetsDirectional.fromSTEB(start, 3, end, 3),
          child: _buildCell(
            context,
            box.maxWidth - start - end,
            narrow: narrow,
          ),
        );
      },
    );
  }

  Widget _buildCell(
    BuildContext context,
    double width, {
    required bool narrow,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final large = MediaQuery.textScalerOf(context).scale(16) > 23;
    final stacked = large || width < (expanded == null ? 226 : 266);
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
            child: narrow
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '$count',
                      key: const ValueKey('mobile-folder-sheet-count'),
                      semanticsLabel: '@a comics'.tlParams({'a': count}),
                    ),
                  )
                : Text(
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
    return Flex(
      direction: narrow ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: narrow
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: narrow ? 0 : 1,
          fit: FlexFit.tight,
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
                      padding: EdgeInsets.symmetric(horizontal: narrow ? 6 : 9),
                      horizontalTitleGap: 6,
                      leading: width < 175
                          ? null
                          : ExcludeSemantics(
                              child: Icon(icon, size: 20, color: accent),
                            ),
                      title: Text(
                        label,
                        // Preserve full accessible names when the row wraps.
                        semanticsLabel: label,
                        maxLines: narrow ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: onPressed == null
                            ? TextStyle(color: accent)
                            : null,
                      ),
                      subtitle:
                          subtitle == null &&
                              (!stacked || count == null) &&
                              !(narrow && check != null)
                          ? null
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (subtitle case final text?)
                                  Text(
                                    text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (narrow &&
                                    (countText != null || check != null))
                                  Row(
                                    children: [
                                      if (countText != null)
                                        Flexible(child: countText),
                                      if (check != null) ...[
                                        if (countText != null)
                                          const SizedBox(width: 4),
                                        check,
                                      ],
                                    ],
                                  )
                                else if (stacked)
                                  ?countText,
                              ],
                            ),
                      trailing: stacked ? null : countText,
                    ),
                  ),
                  if (!narrow && check != null)
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
            child: narrow
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  )
                : action,
          ),
      ],
    );
  }
}
