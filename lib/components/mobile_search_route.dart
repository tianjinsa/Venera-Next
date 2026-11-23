import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:prism_ui/goo.dart' as prism show gooPairOutline;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/motion.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism show ColorScheme;
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/navigation_admission.dart';

/// Measure in this navigator's overlay, not window coordinates: detail can
/// also live in a root route above the main shell's nested navigator.
Future<T?> pushSearchFrom<T>(BuildContext origin, Widget Function() page) {
  if (!NavigationAdmission.allows(origin) ||
      ModalRoute.isCurrentOf(origin) == false) {
    return Future.value();
  }
  if (!AppPageRoute.mobileOf(origin)) return origin.to<T>(page);

  final navigator = Navigator.of(origin);
  final overlay = navigator.overlay?.context.findRenderObject();
  final source = origin.findRenderObject();
  if (overlay is! RenderBox || !overlay.hasSize || source is! RenderBox) {
    return origin.to<T>(page);
  }
  final viewport = Offset.zero & overlay.size;
  Rect? measure() {
    if (!source.attached || !source.hasSize || !overlay.attached) return null;
    final rect = MatrixUtils.transformRect(
      source.getTransformTo(overlay),
      Offset.zero & source.size,
    ).intersect(Offset.zero & overlay.size);
    return rect.isEmpty || !rect.isFinite ? null : rect;
  }

  final initial = measure();
  if (initial == null || viewport.isEmpty) return origin.to<T>(page);
  final reduce = MediaQuery.disableAnimationsOf(origin);
  final anchor = origin.findAncestorStateOfType<_MobileSearchAnchorState>();
  final route = AppPageRoute<T>.fromAnchor(
    builder: (_) => page(),
    reduceMotion: reduce,
    reveal: (_, animation, _, child) => _SearchReveal(
      animation: animation,
      initial: initial,
      viewport: viewport.size,
      measure: measure,
      child: child,
    ),
  );
  final result = navigator.push<T>(route);
  if (!reduce) anchor?._follow(route);
  return result;
}

/// The source glyph fades into the moving surface instead of remaining visibly
/// duplicated at rest. Follow the actual route so an interrupted pop, a
/// cancelled edge gesture, or route removal restores the same live control.
class MobileSearchAnchor extends StatefulWidget {
  const MobileSearchAnchor({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<MobileSearchAnchor> createState() => _MobileSearchAnchorState();
}

class _MobileSearchAnchorState extends State<MobileSearchAnchor> {
  PageRoute<dynamic>? _route;
  Animation<double> _opacity = kAlwaysCompleteAnimation;

  void _follow(PageRoute<dynamic> route) {
    setState(() {
      _route = route;
      _opacity = route.animation!
          .drive(CurveTween(curve: const Interval(0, .14)))
          .drive(Tween<double>(begin: 1, end: 0));
    });
    route.completed.then((_) {
      if (mounted && identical(_route, route)) {
        setState(() {
          _route = null;
          _opacity = kAlwaysCompleteAnimation;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => AppPageRoute.mobileOf(context)
      ? FadeTransition(
          opacity: _opacity,
          child: Builder(builder: widget.builder),
        )
      : Builder(builder: widget.builder);
}

class _SearchReveal extends StatefulWidget {
  const _SearchReveal({
    required this.animation,
    required this.initial,
    required this.viewport,
    required this.measure,
    required this.child,
  });

  final Animation<double> animation;
  final Rect initial;
  final Size viewport;
  final Rect? Function() measure;
  final Widget child;

  @override
  State<_SearchReveal> createState() => _SearchRevealState();
}

class _SearchRevealState extends State<_SearchReveal> {
  Rect? _returnTo;

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.reverse) _returnTo = widget.measure();
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_status);
  }

  @override
  void didUpdateWidget(_SearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_status);
      widget.animation.addStatusListener(_status);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_status);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = prism.LiquidGlassScope.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: widget.animation,
        child: widget.child,
        builder: (context, child) {
          final size = constraints.biggest;
          final viewport = Offset.zero & size;
          final start =
              _returnTo ??
              Rect.fromLTRB(
                widget.initial.left * size.width / widget.viewport.width,
                widget.initial.top * size.height / widget.viewport.height,
                widget.initial.right * size.width / widget.viewport.width,
                widget.initial.bottom * size.height / widget.viewport.height,
              );
          final t = reduce ? 1.0 : widget.animation.value;
          final frame = SearchMorphFrame.at(start, viewport, t);
          final opacity = const Interval(
            .32,
            .86,
            curve: Curves.easeOut,
          ).transform(t);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (opacity < 1)
                SearchMorphSurface(
                  frame: frame,
                  glass: glass
                      ? prism.LiquidGlassStyle.regular(
                          prism.ColorScheme.of(context),
                        )
                      : null,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              // Stable keyed subtree, always laid out as a full page. We clip
              // its paint, never squeeze lists/fields into the button's size.
              ClipRSuperellipse(
                key: const ValueKey('search-route-reveal'),
                clipBehavior: t == 1 ? Clip.none : Clip.antiAlias,
                clipper: _RevealClip(frame.clip),
                child: IgnorePointer(
                  ignoring: t < 1,
                  child: ExcludeSemantics(
                    excluding: t < 1,
                    child: Opacity(opacity: opacity, child: child),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevealClip extends CustomClipper<RSuperellipse> {
  const _RevealClip(this.bounds);
  final RSuperellipse bounds;

  @override
  RSuperellipse getClip(Size size) => bounds;

  @override
  bool shouldReclip(_RevealClip oldClipper) => oldClipper.bounds != bounds;
}

/// Prism's More menu (popup.dart, _RenderPopupMorph) draws a departing
/// platter and a droplet as a single refracting body. A whole page would
/// engulf its button at once, so we let the platter clear the lip *before*
/// opening it to the viewport. No private Prism route or copied shader.
@immutable
class SearchMorphFrame {
  const SearchMorphFrame._(this.platter, this.radius, this.droplet, this.blend);

  final Rect platter;
  final double radius;
  final Rect? droplet;
  final double blend;

  static final _settle = prism.SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 275, ratio: 1),
    seconds: .38,
  );

  factory SearchMorphFrame.at(Rect source, Rect page, double t) {
    final lift = const Interval(0, .38, curve: Curves.easeInOut).transform(t);
    final open = _settle.transform(const Interval(.33, 1).transform(t));
    final short = source.shortestSide;
    final seed = Size(math.min(source.width, short * 1.35), short) * .62;
    final bud = Size(
      math.min(page.width * .8, math.max(80.0, source.width * .65)),
      math.min(page.height * .3, math.max(54.0, short * 1.28)),
    );
    final down = source.center.dy <= page.center.dy ? 1 : -1;
    final travel = short * .5 + bud.height * .5 + 28;
    final landing = Offset(
      (source.center.dx + (page.center.dx - source.center.dx) * .12).clamp(
        page.left + bud.width / 2,
        page.right - bud.width / 2,
      ),
      (source.center.dy + down * travel).clamp(
        page.top + bud.height / 2,
        page.bottom - bud.height / 2,
      ),
    );
    final bulge = Rect.fromCenter(
      center: Offset.lerp(source.center, landing, lift)!,
      width: lerpDouble(seed.width, bud.width, lift)!,
      height: lerpDouble(seed.height, bud.height, lift)!,
    );
    final platter = Rect.lerp(bulge, page, open)!;
    final radius = lerpDouble(
      bulge.shortestSide / 2,
      0,
      const Interval(.42, .99, curve: Curves.easeInOut).transform(t),
    )!;
    final release = const Interval(
      0,
      .53,
      curve: Curves.easeInOut,
    ).transform(t);
    final extent = source.size * (1 - release);
    final residual = t >= .53
        ? null
        : Rect.fromCenter(
            center: Offset.lerp(source.center, landing, lift * .12)!,
            width: extent.width,
            height: extent.height,
          );
    return SearchMorphFrame._(
      platter,
      radius,
      residual,
      math.min(28.0, short * .7) *
          const Interval(0, .12, curve: Curves.easeInOut).transform(t),
    );
  }

  RSuperellipse get clip =>
      RSuperellipse.fromRectAndRadius(platter, Radius.circular(radius));

  Path outline({bool coarse = false}) => droplet == null
      ? (Path()..addRSuperellipse(clip))
      : prism.gooPairOutline(platter, radius, droplet!, blend, coarse: coarse);
}

/// One surface for both lobes: two LiquidGlass widgets would produce two
/// rims and never refract through the neck. The page is a separate stable
/// child; neither layout nor input is transformed into the small droplet.
class SearchMorphSurface extends LeafRenderObjectWidget {
  const SearchMorphSurface({
    super.key,
    required this.frame,
    required this.glass,
    required this.color,
  });
  final SearchMorphFrame frame;
  final prism.LiquidGlassStyle? glass;
  final Color color;

  bool _coarseOf(BuildContext context) =>
      glass != null &&
      prism.LiquidGlassScope.qualityOf(context) ==
          prism.LiquidGlassQuality.standard;

  @override
  RenderBox createRenderObject(BuildContext context) =>
      _RenderSearchMorph(frame, glass, color, _coarseOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) {
    (renderObject as _RenderSearchMorph).update(
      frame,
      glass,
      color,
      _coarseOf(context),
    );
  }
}

class _RenderSearchMorph extends RenderBox {
  _RenderSearchMorph(this.frame, this.glass, this.color, this.coarse);
  SearchMorphFrame frame;
  prism.LiquidGlassStyle? glass;
  Color color;
  bool coarse;
  late final _pane = prism.LiquidGlassPane(markNeedsPaint);

  void update(
    SearchMorphFrame value,
    prism.LiquidGlassStyle? style,
    Color fill,
    bool coarseOutline,
  ) {
    if ((style == null) != (glass == null)) markNeedsCompositingBitsUpdate();
    frame = value;
    glass = style;
    color = fill;
    coarse = coarseOutline;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;
  @override
  bool get alwaysNeedsCompositing => glass != null;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final style = glass;
    if (style == null) {
      _pane.clear();
      context.canvas.drawPath(
        frame.outline().shift(offset),
        Paint()..color = color,
      );
      return;
    }

    final prism.LiquidGlassShape shape;
    final Rect bounds;
    if (frame.droplet case final drop?) {
      final outline = frame.outline(coarse: coarse);
      bounds = outline.getBounds();
      if (bounds.isEmpty) return;
      shape = prism.LiquidGlassGoo(
        outline.shift(-bounds.topLeft),
        [frame.platter.shift(-bounds.topLeft), drop.shift(-bounds.topLeft)],
        [frame.blend],
        firstRadius: math.max(.001, frame.radius),
      );
    } else {
      bounds = frame.platter;
      shape = prism.LiquidGlassCorners.circular(frame.radius);
    }
    _pane.paint(
      context,
      bounds.shift(offset),
      shape: shape,
      style: style,
      hold: offset & size,
    );
  }

  @override
  void dispose() {
    _pane.dispose();
    super.dispose();
  }
}
