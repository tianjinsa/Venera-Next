import 'package:flutter/material.dart';
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/list_row.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;

import 'gesture.dart';
import 'mobile_ui.dart';

enum MobileContentStyle {
  summary(26),
  row(18),
  cover(14);

  const MobileContentStyle(this.radius);
  final double radius;
}

/// Values are relative to the *actual* page, not a second seed-generated
/// colour scheme. Multiplying the page colour toward black keeps every stop
/// below the page on a dark theme as well as on a light one. Pure black has
/// no darker colour: the (subtle) outline still separates neighbouring cards.
abstract final class MobileContentPalette {
  static Color fill(BuildContext context, {bool selected = false}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Color.alphaBlend(
      Colors.black.withValues(
        alpha: dark ? (selected ? .50 : .40) : (selected ? .095 : .060),
      ),
      theme.scaffoldBackgroundColor,
    );
  }

  static List<Color> glaze(BuildContext context, Color base) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    // Neither endpoint lightens beyond the page, including selected rows.
    return [
      Color.lerp(base, page, .18)!,
      Color.lerp(base, Colors.black, .016)!,
    ];
  }

  static Color _underAnchor(
    BuildContext surface,
    BuildContext anchor,
    EdgeInsetsGeometry insets,
    LinearGradient gradient,
    Color fallback,
  ) {
    final box = surface.findRenderObject();
    final target = anchor.findRenderObject();
    if (box is! RenderBox ||
        target is! RenderBox ||
        !box.attached ||
        !target.attached ||
        !box.hasSize ||
        !target.hasSize) {
      return fallback;
    }
    final direction = Directionality.of(surface);
    final rect = insets.resolve(direction).deflateRect(Offset.zero & box.size);
    if (rect.isEmpty) return fallback;
    final from = gradient.begin.resolve(direction).withinRect(rect);
    final to = gradient.end.resolve(direction).withinRect(rect);
    final axis = to - from;
    final local =
        target.localToGlobal(target.size.center(Offset.zero), ancestor: box) -
        from;
    // Same projection along the diagonal as the card's LinearGradient.
    final t = (axis.dx * local.dx + axis.dy * local.dy) / axis.distanceSquared;
    return Color.lerp(
      gradient.colors.first,
      gradient.colors.last,
      t.clamp(0, 1),
    )!;
  }
}

/// The matte content layer underneath floating liquid-glass controls.
///
/// Like FlClash's DashboardCard and profile rows, this is a separate, rounded
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
    final base = MobileContentPalette.fill(context, selected: selected);
    final gradient = glass
        ? LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: MobileContentPalette.glaze(context, base),
          )
        : null;
    return Padding(
      padding: insets,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: glass ? null : base,
          gradient: gradient,
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
                        ? scheme.outlineVariant.withValues(alpha: 0.40)
                        : scheme.outlineVariant.withValues(
                            alpha: dark ? 0.30 : 0.48,
                          )),
                width: selected ? 1 : 0.75,
              ),
            ),
          ),
          child: MobilePopupSourceSurface(
            colorAt: (anchor) => gradient == null
                ? base
                : MobileContentPalette._underAnchor(
                    context,
                    anchor,
                    insets,
                    gradient,
                    base,
                  ),
            child: Material(
              type: MaterialType.transparency,
              textStyle: DefaultTextStyle.of(context).style,
              child: child,
            ),
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
