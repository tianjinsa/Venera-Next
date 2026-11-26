import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:prism_ui/shape.dart' as prism show AppRadius;
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
    if (!source.attached ||
        !source.hasSize ||
        !overlay.attached ||
        !overlay.hasSize) {
      return null;
    }
    final rect = MatrixUtils.transformRect(
      source.getTransformTo(overlay),
      Offset.zero & source.size,
    );
    return rect.isFinite &&
            !rect.isEmpty &&
            rect.overlaps(Offset.zero & overlay.size)
        ? rect
        : null;
  }

  final initial = measure();
  if (initial == null || viewport.isEmpty) return origin.to<T>(page);
  final reduce = MediaQuery.disableAnimationsOf(origin);
  final anchor = origin.findAncestorStateOfType<_MobileSearchAnchorState>();
  final globalPoint = anchor?._takeOrigin(origin);
  final projected = globalPoint == null
      ? null
      : overlay.globalToLocal(globalPoint);
  final point = projected?.isFinite == true ? projected! : initial.center;
  final relative = Offset(
    ((point.dx - initial.left) / initial.width).clamp(0.0, 1.0),
    ((point.dy - initial.top) / initial.height).clamp(0.0, 1.0),
  );
  final route = AppPageRoute<T>.fromAnchor(
    builder: (_) => page(),
    reduceMotion: reduce,
    openingDuration: const Duration(milliseconds: 500),
    reveal: (_, animation, _, child) => _SearchReveal(
      animation: animation,
      initial: initial,
      viewport: viewport.size,
      measure: measure,
      relative: relative,
      cornerRadius: anchor?.widget.cornerRadius,
      sourceColor: anchor?.widget.sourceColor,
      child: child,
    ),
  );
  return navigator.push<T>(route);
}

/// Wrap only the actual card, chip or button, not its surrounding toolbar.
class MobileSearchAnchor extends StatefulWidget {
  const MobileSearchAnchor({
    super.key,
    required this.builder,
    this.keyboardOrigin,
    this.cornerRadius,
    this.sourceColor,
  });

  final WidgetBuilder builder;

  /// A Material control's radius. Prism pills use their full superellipse.
  final double? cornerRadius;
  final Color? sourceColor;

  /// Optional global caret position for an input that submits from the IME.
  /// A null result centers the reveal on that field, not on an earlier tap.
  final Offset? Function(BuildContext field)? keyboardOrigin;

  @override
  State<MobileSearchAnchor> createState() => _MobileSearchAnchorState();
}

class _MobileSearchAnchorState extends State<MobileSearchAnchor> {
  Offset? _press;
  int? _pointer;

  void _clearPress() {
    _press = null;
    _pointer = null;
  }

  Offset? _takeOrigin(BuildContext trigger) {
    final press = _press;
    _clearPress();
    final caret = widget.keyboardOrigin;
    return caret == null ? press : caret(trigger);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppPageRoute.mobileOf(context)) {
      return Builder(builder: widget.builder);
    }
    // Leave the original control painted while the new surface spreads.
    return Listener(
      onPointerDown: (event) {
        _pointer = event.pointer;
        _press = event.position;
      },
      onPointerMove: (event) {
        if (_pointer == event.pointer &&
            _press != null &&
            (event.position - _press!).distance > 20) {
          _clearPress();
        }
      },
      onPointerCancel: (event) {
        if (_pointer == event.pointer) _clearPress();
      },
      onPointerUp: (event) {
        // Keep the point through the current tap dispatch only.
        if (_pointer == event.pointer) {
          Future.microtask(() {
            if (_pointer == event.pointer) _clearPress();
          });
        }
      },
      child: Builder(builder: widget.builder),
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
    required this.cornerRadius,
    required this.sourceColor,
    required this.child,
  });

  final Animation<double> animation;
  final Rect initial;
  final Size viewport;
  final Rect? Function() measure;
  final Offset relative;
  final double? cornerRadius;
  final Color? sourceColor;
  final Widget child;

  @override
  State<_SearchReveal> createState() => _SearchRevealState();
}

class _SearchRevealState extends State<_SearchReveal> {
  Rect? _returnTo;
  bool _fadeBack = false;
  double _lastT = 0;

  void _track() {
    final next = widget.animation.value;
    if (next < 1 && _lastT == 1) {
      _returnTo = widget.measure();
      _fadeBack = _returnTo == null;
    }
    if (next == 1) {
      _returnTo = null;
      _fadeBack = false;
    }
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
    final background = theme.scaffoldBackgroundColor.withAlpha(255);
    final sourceColor =
        (widget.sourceColor ?? theme.colorScheme.surfaceContainerHigh)
            .withAlpha(255);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: widget.animation,
        child: widget.child,
        builder: (context, child) {
          final t = reduce ? 1.0 : widget.animation.value;
          final opacity = _fadeBack
              ? Curves.easeInOut.transform(t)
              : SearchMorphFrame.contentOpacity(t);
          return Stack(
            key: const ValueKey('search-route-reveal'),
            fit: StackFit.expand,
            children: [
              if (!_fadeBack)
                if (t < SearchMorphFrame.growthEnd)
                  _surface(constraints.biggest, t, sourceColor, background)
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

  Widget _surface(Size size, double t, Color sourceColor, Color background) {
    final initial = widget.initial;
    final scaleX = size.width / widget.viewport.width;
    final scaleY = size.height / widget.viewport.height;
    final bounds =
        _returnTo ??
        Rect.fromLTRB(
          initial.left * scaleX,
          initial.top * scaleY,
          initial.right * scaleX,
          initial.bottom * scaleY,
        );
    return SearchMorphSurface(
      frame: SearchMorphFrame.at(
        anchor: bounds,
        origin: Offset(
          bounds.left + bounds.width * widget.relative.dx,
          bounds.top + bounds.height * widget.relative.dy,
        ),
        viewport: Offset.zero & size,
        t: t,
      ),
      cornerRadius: widget.cornerRadius,
      sourceColor: sourceColor,
      destinationColor: background,
    );
  }
}

/// The spreading control and the circle that eventually covers the viewport.
@immutable
class SearchMorphFrame {
  const SearchMorphFrame._(
    this.anchor,
    this.center,
    this.radius,
    this.coveringRadius,
    this.growth,
  );

  static const growthEnd = .70;

  // Start gently, accelerate across the viewport, then settle at full coverage.
  static const _radiusCurve = Cubic(.36, 0, .28, 1);

  static double contentOpacity(double t) =>
      const Interval(growthEnd, 1, curve: Curves.easeInOut).transform(t);

  final Rect anchor;
  final Offset center;
  final double radius;
  final double coveringRadius;
  final double growth;

  factory SearchMorphFrame.at({
    required Rect anchor,
    required Offset origin,
    required Rect viewport,
    required double t,
  }) {
    final center = Offset(
      origin.dx.clamp(viewport.left, viewport.right),
      origin.dy.clamp(viewport.top, viewport.bottom),
    );
    final dx = math.max(center.dx - viewport.left, viewport.right - center.dx);
    final dy = math.max(center.dy - viewport.top, viewport.bottom - center.dy);
    final coveringRadius = math.sqrt(dx * dx + dy * dy);
    final progress = (t / growthEnd).clamp(0.0, 1.0);
    final growth = _radiusCurve.transform(progress);
    return SearchMorphFrame._(
      anchor,
      center,
      lerpDouble(anchor.shortestSide / 2, coveringRadius, growth)!,
      coveringRadius,
      growth,
    );
  }
}

class SearchMorphSurface extends StatelessWidget {
  const SearchMorphSurface({
    super.key,
    required this.frame,
    required this.sourceColor,
    required this.destinationColor,
    this.cornerRadius,
  });

  final SearchMorphFrame frame;
  final Color sourceColor;
  final Color destinationColor;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SearchSurfacePainter(
      frame,
      Color.lerp(
        sourceColor,
        destinationColor,
        _smoothStep(0, .38, frame.growth),
      )!.withAlpha(255),
      cornerRadius,
    ),
    size: Size.infinite,
  );
}

double _smoothStep(double start, double end, double value) {
  final t = ((value - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class _SearchSurfacePainter extends CustomPainter {
  const _SearchSurfacePainter(this.frame, this.fill, this.cornerRadius);

  final SearchMorphFrame frame;
  final Color fill;
  final double? cornerRadius;

  static const _segments = 72;
  static final _directions = List.generate(_segments, (index) {
    final angle = 2 * math.pi * index / _segments;
    return Offset(math.cos(angle), math.sin(angle));
  }, growable: false);

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.growth == 0) return;
    final viewport = Offset.zero & size;
    final paint = Paint()..color = fill;
    final circleWeight = _smoothStep(.06, .78, frame.growth);
    canvas.save();
    canvas.clipRect(viewport, doAntiAlias: false);
    if (circleWeight == 1) {
      canvas.drawCircle(frame.center, frame.radius, paint);
    } else {
      _paintContour(canvas, viewport, paint, circleWeight);
    }
    canvas.restore();
  }

  void _paintContour(Canvas canvas, Rect viewport, Paint paint, double weight) {
    final outline = _outline(weight);
    final coverSource = _smoothStep(.01, .19, frame.growth);
    if (coverSource == 1) {
      canvas.drawPath(outline, paint);
      return;
    }

    // The opening in the painted surface lets the real control show through.
    // Fade it at the handoff without an offscreen layer or a source snapshot.
    final source = Path();
    if (cornerRadius case final radius?) {
      source.addRRect(RRect.fromRectXY(frame.anchor, radius, radius));
    } else {
      source.addRSuperellipse(
        prism.AppRadius.full.toRSuperellipse(frame.anchor),
      );
    }
    final outsideSource = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(viewport)
      ..addPath(source, Offset.zero);
    canvas.clipPath(outline);
    canvas.drawPath(outsideSource, paint);
    if (coverSource > 0) {
      canvas.drawPath(
        source,
        paint..color = fill.withValues(alpha: coverSource),
      );
    }
  }

  Path _outline(double weight) {
    final bounds = frame.anchor;
    final center = Offset.lerp(bounds.center, frame.center, weight)!;
    final halfShortSide = bounds.shortestSide / 2;
    final corner = math.min(cornerRadius ?? halfShortSide, halfShortSide);
    final core =
        Offset(bounds.width / 2 - corner, bounds.height / 2 - corner) *
        (1 + .08 * math.sin(math.pi * frame.growth));
    final pressedRadius = lerpDouble(
      corner,
      frame.coveringRadius,
      frame.growth * (.58 + .42 * weight),
    )!;
    // Blend the distance to each contour on the same ray as the control spreads.
    final points = [
      for (final ray in _directions)
        center +
            ray *
                lerpDouble(
                  _roundedRectRadius(core, pressedRadius, ray),
                  frame.radius,
                  weight,
                )!,
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < _segments; i++) {
      final previous = points[(i + _segments - 1) % _segments];
      final start = points[i];
      final end = points[(i + 1) % _segments];
      final next = points[(i + 2) % _segments];
      final lead = start + (end - previous) / 6;
      final tail = end - (next - start) / 6;
      path.cubicTo(lead.dx, lead.dy, tail.dx, tail.dy, end.dx, end.dy);
    }
    return path..close();
  }

  static double _roundedRectRadius(Offset core, double radius, Offset ray) {
    final x = ray.dx.abs();
    final y = ray.dy.abs();
    final halfWidth = core.dx + radius;
    final halfHeight = core.dy + radius;
    if (y * halfWidth <= x * core.dy) return halfWidth / x;
    if (x * halfHeight <= y * core.dx) return halfHeight / y;
    final projection = core.dx * x + core.dy * y;
    final distance = core.dx * y - core.dy * x;
    return projection +
        math.sqrt(math.max(0, radius * radius - distance * distance));
  }

  @override
  bool shouldRepaint(_SearchSurfacePainter oldDelegate) =>
      oldDelegate.frame.anchor != frame.anchor ||
      oldDelegate.frame.center != frame.center ||
      oldDelegate.frame.radius != frame.radius ||
      oldDelegate.frame.growth != frame.growth ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.fill != fill;
}
