import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism show TonalButtonTheme;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism show LiquidGlassScope;
import 'package:prism_ui/list_row.dart' as prism show ListRow;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_side_sheet.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/translations.dart';

class MobileFolderSheetHeader extends StatelessWidget {
  const MobileFolderSheetHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
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
    return MobileSideSheetLayout.maybeOf(context)?.keepVisible(content) ??
        content;
  }
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
    final content = LayoutBuilder(
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
    return MobileSideSheetLayout.maybeOf(context)?.keepVisible(content) ??
        content;
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
    final active = onPressed != null;
    final accent = !active
        ? scheme.onSurface.withValues(alpha: .38)
        : selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final count = this.count;
    final sideSheet = MobileSideSheetLayout.maybeOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        // In the card's own coordinates this lane never changes width. The
        // narrow detent clips the start of the card, leaving this lane intact.
        final lane = sideSheet?.controlsWidth ?? box.maxWidth * .56;
        final titleWidth = lane.clamp(0.0, box.maxWidth);
        final toggle = expanded == null
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
        return MobileContentSurface(
          style: MobileContentStyle.row,
          selected: selected,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                selected: selected,
                enabled: active,
                button: true,
                child: ClickInkWell(
                  key: const ValueKey('mobile-folder-sheet-select'),
                  onTap: onPressed,
                  customBorder: MobileContentSurface.inkShapeOf(
                    context,
                    MobileContentStyle.row,
                  ),
                  child: Row(
                    // Force only the physical order of these slots. Text,
                    // icons and focus controls still inherit the locale.
                    textDirection: TextDirection.ltr,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              ExcludeSemantics(
                                child: Icon(icon, size: 18, color: accent),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  subtitle ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              if (count != null)
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Tooltip(
                                    message:
                                        countHint ??
                                        'Comics directly in this folder'.tl,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '$count',
                                        key: const ValueKey(
                                          'mobile-folder-sheet-count',
                                        ),
                                        semanticsLabel: '@a comics'.tlParams({
                                          'a': count,
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: (titleWidth - 3).clamp(
                          0.0,
                          math.max(0.0, box.maxWidth - 6),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: nested ? 9 : 2,
                            right: 2,
                          ),
                          child: prism.ListRow(
                            minHeight: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            minVerticalPadding: 6,
                            title: Text(
                              label,
                              semanticsLabel: label,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: !active
                                  ? TextStyle(color: accent)
                                  : selected
                                  ? TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                    )
                                  : null,
                            ),
                            subtitle: selected
                                ? ExcludeSemantics(
                                    child: prism.GlyphIcon(
                                      prism.Glyphs.check,
                                      key: const ValueKey(
                                        'mobile-folder-sheet-selected',
                                      ),
                                      size: 16,
                                      color: accent,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (toggle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Align(alignment: Alignment.centerRight, child: toggle),
                ),
            ],
          ),
        );
      },
    );
  }
}
