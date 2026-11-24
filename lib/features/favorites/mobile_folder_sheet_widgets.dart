import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
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
        // Reclaim the decoration's slot before squeezing a short title or
        // the real menu. Larger type is still allowed to wrap naturally.
        final compact =
            box.maxWidth < 176 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
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

  static const _margin = EdgeInsets.symmetric(horizontal: 3, vertical: 3);

  @override
  Widget build(BuildContext context) {
    final style = MobileContentStyle.row;
    final shape = MobileContentSurface.inkShapeOf(context, style);
    final scheme = Theme.of(context).colorScheme;
    final active = onPressed != null;
    final accent = !active
        ? scheme.onSurface.withValues(alpha: .38)
        : selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final count = this.count;
    final countLabel = count == null
        ? null
        : '@a comics'.tlParams({'a': count});
    final sideSheet = MobileSideSheetLayout.maybeOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final fixedWidth = math.max(
          0.0,
          (sideSheet?.maxContentWidth ?? box.maxWidth) - _margin.horizontal,
        );
        final collapsedWidth = math.max(
          0.0,
          (sideSheet?.minContentWidth ?? box.maxWidth) - _margin.horizontal,
        );
        final countRoom = count == null ? 0.0 : math.min(72.0, fixedWidth * .3);
        final leftWidth = math.min(collapsedWidth, fixedWidth - countRoom);
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

        // One rounded edge clips the matte fill/rim, its Material ink,
        // and all hit targets. Only the outer surface follows the drawer.
        // The contents keep the same constraints and physical-left origin.
        final surface = MobileContentSurface(
          style: style,
          selected: selected,
          margin: EdgeInsets.zero,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            fit: OverflowBoxFit.deferToChild,
            minWidth: fixedWidth,
            maxWidth: fixedWidth,
            child: Column(
              key: const ValueKey('mobile-folder-sheet-fixed-content'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  selected: selected,
                  enabled: active,
                  button: true,
                  label: countLabel == null ? label : '$label, $countLabel',
                  child: ClickInkWell(
                    key: const ValueKey('mobile-folder-sheet-select'),
                    onTap: onPressed,
                    customBorder: shape,
                    child: ExcludeSemantics(
                      child: Row(
                        // Only slot geometry is physical; text and icons keep
                        // the selected locale's directionality.
                        textDirection: TextDirection.ltr,
                        children: [
                          SizedBox(
                            width: leftWidth,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: nested ? 12 : 6,
                                right: 3,
                              ),
                              child: Row(
                                textDirection: TextDirection.ltr,
                                children: [
                                  SizedBox(
                                    width: 23,
                                    height: 27,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: 4,
                                          child: Icon(
                                            icon,
                                            key: const ValueKey(
                                              'mobile-folder-sheet-icon',
                                            ),
                                            size: 18,
                                            color: accent,
                                          ),
                                        ),
                                        if (selected)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: prism.GlyphIcon(
                                              prism.Glyphs.check,
                                              key: const ValueKey(
                                                'mobile-folder-sheet-selected',
                                              ),
                                              size: 11,
                                              color: accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: prism.ListRow(
                                      minHeight: 50,
                                      padding: EdgeInsets.zero,
                                      minVerticalPadding: 6,
                                      title: Text(
                                        label,
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
                                      subtitle: subtitle == null
                                          ? null
                                          : Text(
                                              subtitle!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (count != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  right: 9,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Tooltip(
                                    message:
                                        countHint ??
                                        'Comics directly in this folder'.tl,
                                    child: FittedBox(
                                      alignment: Alignment.centerRight,
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$count',
                                        key: const ValueKey(
                                          'mobile-folder-sheet-count',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: leftWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: action,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        return Padding(
          padding: _margin,
          child: ClipPath(
            key: const ValueKey('mobile-folder-sheet-row-clip'),
            clipper: shape == null ? null : ShapeBorderClipper(shape: shape),
            child: surface,
          ),
        );
      },
    );
  }
}
