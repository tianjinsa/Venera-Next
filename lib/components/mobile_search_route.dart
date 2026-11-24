import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    reveal: (_, animation, _, child) => _SearchReveal(
      animation: animation,
      initial: initial,
      viewport: viewport.size,
      measure: measure,
      relative: relative,
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
  });

  final WidgetBuilder builder;

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
    // Keep the original control in place and painted while the circle
    // passes over it. The rest of its label does not wink out on the first
    // frame of a point-sized reveal, or blink in at the end of reverse.
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
    required this.child,
  });

  final Animation<double> animation;
  final Rect initial;
  final Size viewport;
  final Rect? Function() measure;
  final Offset relative;
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
                    Offset(
                      start.left + start.width * widget.relative.dx,
                      start.top + start.height * widget.relative.dy,
                    ),
                    viewport,
                    t,
                  ),
                  sourceColor: sourceColor,
                  destinationColor: background,
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

/// A concentric liquid reveal. The touch/caret is the center for the entire
/// expansion; only the radius changes. Measuring the farthest corner, rather
/// than using the viewport's short side, prevents a corner flash at handoff.
@immutable
class SearchMorphFrame {
  const SearchMorphFrame._(
    this.center,
    this.radius,
    this.coveringRadius,
    this.growth,
  );

  static const growthEnd = .70;

  static double contentOpacity(double t) =>
      const Interval(growthEnd, 1, curve: Curves.easeInOut).transform(t);

  final Offset center;
  final double radius;
  final double coveringRadius;
  final double growth;

  factory SearchMorphFrame.at(Offset origin, Rect viewport, double t) {
    final center = Offset(
      origin.dx.clamp(viewport.left, viewport.right),
      origin.dy.clamp(viewport.top, viewport.bottom),
    );
    final dx = math.max(center.dx - viewport.left, viewport.right - center.dx);
    final dy = math.max(center.dy - viewport.top, viewport.bottom - center.dy);
    final coveringRadius = math.sqrt(dx * dx + dy * dy);
    final progress = (t / growthEnd).clamp(0.0, 1.0);
    final growth = const Cubic(.24, .12, .23, .98).transform(progress);
    return SearchMorphFrame._(
      center,
      coveringRadius * growth,
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
  });

  final SearchMorphFrame frame;
  final Color sourceColor;
  final Color destinationColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SearchSurfacePainter(
      frame,
      Color.lerp(sourceColor, destinationColor, frame.growth)!.withAlpha(255),
    ),
    size: Size.infinite,
  );
}

class _SearchSurfacePainter extends CustomPainter {
  const _SearchSurfacePainter(this.frame, this.fill);

  final SearchMorphFrame frame;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.radius <= 0) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size, doAntiAlias: false);
    canvas.drawCircle(frame.center, frame.radius, Paint()..color = fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SearchSurfacePainter oldDelegate) =>
      oldDelegate.frame.center != frame.center ||
      oldDelegate.frame.radius != frame.radius ||
      oldDelegate.fill != fill;
}
