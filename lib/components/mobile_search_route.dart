import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:prism_ui/goo.dart' as prism show gooPairOutline;
import 'package:prism_ui/liquid_glass.dart' as prism show LiquidGlassScope;
import 'package:venera_next/foundation/app_page_route.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/navigation_admission.dart';

/// Measure in the owning Navigator's overlay. Detail and source results can
/// also be opened in a root route above the main shell's nested navigator.
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
  final press = anchor?._takePress();
  final point = press == null ? initial.center : overlay.globalToLocal(press);
  final relative = Offset(
    ((point.dx - initial.left) / initial.width).clamp(0.0, 1.0),
    ((point.dy - initial.top) / initial.height).clamp(0.0, 1.0),
  );
  final route = AppPageRoute<T>.fromAnchor(
    builder: (_) => page(),
    reduceMotion: reduce,
    reveal: (_, animation, _, child) => _SearchReveal(
      animation: animation,
      initial: initial,
      viewport: viewport.size,
      measure: measure,
      relative: relative,
      sourceRadius: anchor?.widget.radius,
      child: child,
    ),
  );
  final result = navigator.push<T>(route);
  if (!reduce) anchor?._follow(route);
  return result;
}

/// Wrap the actual card, chip or button. The optional pointer affects its
/// local deformation, not its origin rectangle or the semantic tap target.
/// Keyboard activation uses the same control, centered.
class MobileSearchAnchor extends StatefulWidget {
  const MobileSearchAnchor({super.key, required this.builder, this.radius});

  final WidgetBuilder builder;
  final double? radius;

  @override
  State<MobileSearchAnchor> createState() => _MobileSearchAnchorState();
}

class _MobileSearchAnchorState extends State<MobileSearchAnchor> {
  PageRoute<dynamic>? _route;
  Animation<double> _opacity = kAlwaysCompleteAnimation;
  Offset? _press;
  int? _pointer;

  Offset? _takePress() {
    final position = _press;
    _press = null;
    _pointer = null;
    return position;
  }

  void _follow(PageRoute<dynamic> route) {
    setState(() {
      _route = route;
      _opacity = route.animation!
          .drive(CurveTween(curve: const Interval(0, .10)))
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
  Widget build(BuildContext context) {
    if (!AppPageRoute.mobileOf(context)) {
      return Builder(builder: widget.builder);
    }
    return FadeTransition(
      opacity: _opacity,
      child: Listener(
        onPointerDown: (event) {
          _pointer = event.pointer;
          _press = event.position;
        },
        onPointerMove: (event) {
          if (_pointer == event.pointer &&
              _press != null &&
              (event.position - _press!).distance > 20) {
            _takePress();
          }
        },
        onPointerCancel: (event) {
          if (_pointer == event.pointer) _takePress();
        },
        onPointerUp: (event) {
          // On release, allow synchronous onTap/onPressed in this dispatch.
          // Never reuse a previous press for a later keyboard submission.
          if (_pointer == event.pointer) {
            Future.microtask(() {
              if (_pointer == event.pointer) _takePress();
            });
          }
        },
        child: Builder(builder: widget.builder),
      ),
    );
  }
}

class _SearchReveal extends StatefulWidget {
  const _SearchReveal({
    required this.animation,
    required this.initial,
    required this.viewport,
    required this.measure,
    required this.relative,
    required this.sourceRadius,
    required this.child,
  });

  final Animation<double> animation;
  final Rect initial;
  final Size viewport;
  final Rect? Function() measure;
  final Offset relative;
  final double? sourceRadius;
  final Widget child;

  @override
  State<_SearchReveal> createState() => _SearchRevealState();
}

class _SearchRevealState extends State<_SearchReveal> {
  Rect? _returnTo;
  double _lastT = 0;

  void _track() {
    final next = widget.animation.value;
    if (next < 1 && _lastT == 1) _returnTo = widget.measure();
    if (next == 1) _returnTo = null;
    _lastT = next;
  }

  @override
  void initState() {
    super.initState();
    _track();
    widget.animation.addListener(_track);
  }

  @override
  void didUpdateWidget(_SearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_track);
      widget.animation.addListener(_track);
      _track();
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_track);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor.withAlpha(255);
    final sourceColor = colors.surfaceContainerHigh.withAlpha(255);
    final sheen = prism.LiquidGlassScope.of(context)
        ? colors.primary.withValues(alpha: .16)
        : null;
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
          final opacity = SearchMorphFrame.contentOpacity(t);
          return Stack(
            key: const ValueKey('search-route-reveal'),
            fit: StackFit.expand,
            children: [
              if (t < SearchMorphFrame.growthEnd)
                SearchMorphSurface(
                  frame: SearchMorphFrame.at(
                    start,
                    viewport,
                    t,
                    relative: widget.relative,
                    sourceRadius: widget.sourceRadius,
                  ),
                  sourceColor: sourceColor,
                  destinationColor: background,
                  sheen: sheen,
                )
              else
                ColoredBox(
                  key: const ValueKey('search-route-backing'),
                  color: background,
                ),
              // Layout the destination once at full size, but keep it invisible
              // and out of hit testing, focus and a11y until the real handoff.
              IgnorePointer(
                ignoring: t < 1,
                child: ExcludeSemantics(
                  excluding: t < 1,
                  child: ExcludeFocus(
                    excluding: t < 1,
                    child: Opacity(
                      key: const ValueKey('search-route-content'),
                      opacity: opacity,
                      child: child,
                    ),
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

/// One connected, dark/light theme-colored body, derived from the anchored
/// surface rather than animated from a second position. Its corner stretches
/// toward the contact side, borrowing Prism's real Goo silhouette. There is
/// no departing droplet or refracting backdrop behind the growing pane.
@immutable
class SearchMorphFrame {
  const SearchMorphFrame._(
    this.platter,
    this.radius,
    this.growth,
    this._shoulder,
    this._blend,
  );

  static const growthEnd = .70;

  static double contentOpacity(double t) =>
      const Interval(growthEnd, 1, curve: Curves.easeInOut).transform(t);

  final Rect platter;
  final double radius;
  final double growth;
  final Rect? _shoulder;
  final double _blend;

  factory SearchMorphFrame.at(
    Rect source,
    Rect page,
    double t, {
    Offset relative = const Offset(.5, .5),
    double? sourceRadius,
  }) {
    final progress = (t / growthEnd).clamp(0.0, 1.0);
    final growth = const Cubic(.26, .13, .23, .98).transform(progress);
    final platter = Rect.lerp(source, page, growth)!;
    final radius = lerpDouble(
      sourceRadius ?? source.shortestSide / 2,
      0,
      const Interval(.52, 1, curve: Curves.easeIn).transform(progress),
    )!;
    final pulse = math.sin(math.pi * progress);
    final reach = math.min(platter.shortestSide / 2, math.max(16.0, radius));
    // Keep the moving shoulder inside the silhouette's bounds and overlapping
    // its body. The corner nearest the press stretches while the opposite
    // corners retain their own shape; then the deformation settles flush.
    final shoulder = reach <= 1 || progress == 0 || progress == 1
        ? null
        : Rect.fromCircle(
            center: Offset(
              _cornerAxis(
                relative.dx,
                source.left - page.left,
                page.right - source.right,
                platter.left,
                platter.right,
                reach,
              ),
              _cornerAxis(
                relative.dy,
                source.top - page.top,
                page.bottom - source.bottom,
                platter.top,
                platter.bottom,
                reach,
              ),
            ),
            radius: reach * (.20 + .33 * pulse),
          );
    return SearchMorphFrame._(
      platter,
      radius,
      growth,
      shoulder,
      reach * .74 * pulse,
    );
  }

  static double _cornerAxis(
    double relative,
    double before,
    double after,
    double start,
    double end,
    double reach,
  ) {
    // If there is no pointer (keyboard or assistive activation), deform into
    // the more open side. Edge taps are instead biased toward that contact.
    final towardStart = relative == .5 ? before > after : relative < .5;
    return towardStart ? start + reach * .55 : end - reach * .55;
  }

  RSuperellipse get clip =>
      RSuperellipse.fromRectAndRadius(platter, Radius.circular(radius));

  Path outline() {
    final shoulder = _shoulder;
    if (shoulder == null) return Path()..addRSuperellipse(clip);
    return Path.combine(
      PathOperation.intersect,
      prism.gooPairOutline(platter, radius, shoulder, _blend, coarse: true),
      Path()..addRect(platter),
    );
  }
}

class SearchMorphSurface extends StatelessWidget {
  const SearchMorphSurface({
    super.key,
    required this.frame,
    required this.sourceColor,
    required this.destinationColor,
    this.sheen,
  });

  final SearchMorphFrame frame;
  final Color sourceColor;
  final Color destinationColor;
  final Color? sheen;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SearchSurfacePainter(
      frame,
      Color.lerp(sourceColor, destinationColor, frame.growth)!.withAlpha(255),
      sheen,
    ),
    size: Size.infinite,
  );
}

class _SearchSurfacePainter extends CustomPainter {
  const _SearchSurfacePainter(this.frame, this.fill, this.sheen);

  final SearchMorphFrame frame;
  final Color fill;
  final Color? sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final path = frame.outline();
    canvas.save();
    canvas.clipRect(frame.platter, doAntiAlias: false);
    canvas.drawPath(path, Paint()..color = fill);
    if (sheen case final color?) {
      final strength = 1 - frame.growth;
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: color.a * strength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SearchSurfacePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.fill != fill ||
      oldDelegate.sheen != sheen;
}
