import 'package:flutter/material.dart';
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
  return navigator.push<T>(
    AppPageRoute<T>.fromAnchor(
      builder: (_) => page(),
      reduceMotion: reduce,
      reveal: (_, animation, _, child) => _SearchReveal(
        animation: animation,
        initial: initial,
        viewport: viewport.size,
        measure: measure,
        child: child,
      ),
    ),
  );
}

/// FlClash scaffold_search.dart's measured trigger, spring and staggered
/// content, extended to a *route* here rather than its inline search bar.
/// Prism OpenContainer.zoom also grows a tile, but installs a full-page drag
/// dismiss; Venera must keep normal Android back and iOS edge-only back.
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
  // The full-page adaptation is critically damped so its boundaries never
  // overshoot and clip beyond the display. Styling uses Prism's real glass.
  static final _growth = prism.SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 190, ratio: 1),
    seconds: .45,
  );
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
          final growth = _growth.transform(t).clamp(0.0, 1.0);
          final bounds = Rect.lerp(start, viewport, growth)!;
          final radius = BorderRadius.circular(
            start.shortestSide * .5 * (1 - growth),
          );
          final opacity = const Interval(
            .16,
            .75,
            curve: Curves.easeOut,
          ).transform(t);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Only a moving surface samples the backdrop. It is removed as
              // soon as the real page is opaque; no standing full-screen blur.
              if (opacity < 1)
                Positioned.fromRect(
                  rect: bounds,
                  child: glass
                      ? prism.LiquidGlass(
                          borderRadius: radius,
                          style: prism.LiquidGlassStyle.regular(
                            prism.ColorScheme.of(context),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh,
                            borderRadius: radius,
                          ),
                        ),
                ),
              // Stable keyed subtree, always laid out as a full page. We clip
              // its paint, never squeeze lists/fields into the button's size.
              ClipRRect(
                key: const ValueKey('search-route-reveal'),
                clipBehavior: t == 1 ? Clip.none : Clip.antiAlias,
                clipper: _RevealClip(radius.toRRect(bounds)),
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

class _RevealClip extends CustomClipper<RRect> {
  const _RevealClip(this.bounds);
  final RRect bounds;

  @override
  RRect getClip(Size size) => bounds;

  @override
  bool shouldReclip(_RevealClip oldClipper) => oldClipper.bounds != bounds;
}
