import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/list_row.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;
import 'package:prism_ui/surface.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;

import 'gesture.dart';
import 'mobile_ui.dart';

enum MobileContentStyle {
  summary(26),
  row(18),
  cover(14);

  const MobileContentStyle(this.radius);
  final double radius;
}

/// The matte content layer underneath floating liquid-glass controls.
///
/// Like FlClash's DashboardCard and profile rows, this is a raised, rounded
/// content surface, not another lens. Glass-on adds a static tonal treatment
/// and rim. There is deliberately no backdrop capture, filter or per-item
/// shader in a lazily built list. Callers retain their own gesture targets.
class MobileContentSurface extends StatelessWidget {
  const MobileContentSurface({
    super.key,
    this.style = MobileContentStyle.row,
    this.margin,
    this.fallbackDecoration,
    this.accent,
    this.selected = false,
    required this.child,
  });

  const MobileContentSurface.summary({
    super.key,
    this.fallbackDecoration,
    this.accent,
    required this.child,
  }) : style = MobileContentStyle.summary,
       margin = null,
       selected = false;

  final MobileContentStyle style;
  final EdgeInsetsGeometry? margin;
  final Decoration? fallbackDecoration;
  final Color? accent;
  final bool selected;
  final Widget child;

  static OutlinedBorder? inkShapeOf(
    BuildContext context,
    MobileContentStyle style,
  ) => MobileUi.enabledOf(context) ? prism.AppShape.all(style.radius) : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insets =
        margin ??
        (style == MobileContentStyle.summary
            ? const EdgeInsets.all(8)
            : EdgeInsets.zero);
    if (!MobileUi.enabledOf(context)) {
      // Keep the exact pre-existing summary and unwrapped desktop row.
      if (style != MobileContentStyle.summary && fallbackDecoration == null) {
        return child;
      }
      return Container(
        margin: insets,
        decoration:
            fallbackDecoration ??
            BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
        child: child,
      );
    }

    final glass = prism.LiquidGlassScope.of(context);
    final dark = scheme.brightness == Brightness.dark;
    final shape = prism.AppShape.all(style.radius);
    final prismColors = prism.Theme.of(context).colorScheme;
    final base = selected
        ? scheme.secondaryContainer
        : prism.SurfaceLevel.card.colorOf(prismColors);
    final tint = Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? 0.055 : 0.035),
      base,
    );
    return Padding(
      padding: insets,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: glass ? null : base,
          gradient: glass
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: dark ? 0.09 : 0.40),
                      base,
                    ),
                    tint.withValues(alpha: dark ? 0.94 : 0.92),
                  ],
                )
              : null,
          shape: shape,
          shadows: style == MobileContentStyle.summary
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: dark ? 0.14 : 0.07),
                    offset: const Offset(0, 2),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: shape.copyWith(
              side: BorderSide(
                color:
                    accent ??
                    (selected
                        ? scheme.primary.withValues(alpha: 0.6)
                        : glass && dark
                        ? Colors.white.withValues(alpha: 0.13)
                        : scheme.outlineVariant.withValues(alpha: 0.65)),
                width: selected ? 1 : 0.75,
              ),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            textStyle: DefaultTextStyle.of(context).style,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Prism supplies the row's title/leading/trailing layout. The same matte
/// surface as comic cards is used, without wrapping accessory actions in a
/// second outer gesture handler.
class MobileContentRow extends StatelessWidget {
  const MobileContentRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const style = MobileContentStyle.row;
    return MobileContentSurface(
      style: style,
      child: ClickInkWell(
        onTap: onTap,
        customBorder: MobileContentSurface.inkShapeOf(context, style),
        child: prism.ListRow(
          minHeight: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          horizontalTitleGap: 12,
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
        ),
      ),
    );
  }
}
