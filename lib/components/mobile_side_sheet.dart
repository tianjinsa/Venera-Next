import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:prism_ui/color.dart' as prism show ColorSchemeExtension;
import 'package:prism_ui/motion.dart' as prism show SpringCurve;
import 'package:prism_ui/sheet.dart' as prism show floatingSheetRadius;
import 'package:prism_ui/surface.dart'
    as prism
    show ElevatedSurfaceTheme, SurfaceLevel, SurfaceScope;
import 'package:prism_ui/theme_data.dart' as prism show Theme;
import 'package:venera_next/foundation/translations.dart';

/// Fixed layout metrics for controls that must remain inside the portion
/// exposed at the narrow detent. These never vary with drag progress.
class MobileSideSheetLayout extends InheritedWidget {
  const MobileSideSheetLayout({
    required this.controlsWidth,
    required this.bottomReserve,
    required super.child,
    super.key,
  });

  static MobileSideSheetLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileSideSheetLayout>();

  final double controlsWidth;

  // Reserve this much scroll extent so the last row can be pulled above the
  // area hidden by the top-aligned card's lower clip at the narrow detent.
  final double bottomReserve;

  /// Use physical right since that is the first part of this card to enter,
  /// without altering the inherited directionality of its labels or actions.
  Widget keepVisible(Widget child) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(width: controlsWidth, child: child),
  );

  @override
  bool updateShouldNotify(MobileSideSheetLayout oldWidget) =>
      controlsWidth != oldWidget.controlsWidth ||
      bottomReserve != oldWidget.bottomReserve;
}

/// A fixed-size floating card entering from the physical left. The clipped
/// viewport reveals its right edge and more of its height as the grip moves.
/// Leftward travel past the narrow detent dismisses the route.
class MobileSideSheetRoute<T> extends PopupRoute<T> {
  MobileSideSheetRoute({required BuildContext context, required this.builder})
    : _reducedMotion = MediaQuery.disableAnimationsOf(context),
      _barrierColor = prism.Theme.of(context).colorScheme.modalScrim,
      _barrierLabel = MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
      _textDirection = Directionality.of(context),
      _themes = InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      super(
        requestFocus: true,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      );

  final WidgetBuilder builder;
  final bool _reducedMotion;
  final Color _barrierColor;
  final String _barrierLabel;
  final TextDirection _textDirection;
  final CapturedThemes _themes;

  static const _initialWidth = .4;
  static const _rail = 22.0;
  static const _initialHeight = .86;
  static const _offscreenGap = 28.0;
  static const _fling = 700.0;
  static final _settle = prism.SpringCurve(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 340, ratio: 1),
    seconds: .30,
  );

  late final AnimationController _extent;
  bool _dragging = false;
  late double _dragOrigin;
  double _dragTravel = 0;

  @override
  void install() {
    super.install();
    _extent = AnimationController(vsync: navigator!);
  }

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration =>
      _reducedMotion ? Duration.zero : const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration =>
      _reducedMotion ? Duration.zero : const Duration(milliseconds: 260);

  @override
  Color get barrierColor => _barrierColor;
  @override
  String get barrierLabel => _barrierLabel;
  @override
  bool get barrierDismissible => true;

  void _settleExtent(double target) {
    if (!isCurrent) return;
    if (_reducedMotion) {
      _extent.value = target;
      return;
    }
    _extent.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: _settle,
    );
  }

  void _toggleExtent() => _settleExtent(_extent.value < .5 ? 1 : 0);

  void _startDrag() {
    _dragging = isCurrent && controller?.isCompleted == true;
    if (!_dragging) return;
    _extent.stop();
    _dragOrigin = _extent.value;
    _dragTravel = 0;
  }

  void _drag(double delta, double minWidth, double viewportWidth) {
    if (!_dragging || !isCurrent) return;
    final range = viewportWidth - minWidth;
    if (range <= 0) return;
    // Keep the edge under the finger, even when reversing direction or
    // crossing from resizing into the existing offscreen dismissal.
    final atStart = _dragOrigin * range;
    _dragTravel = (_dragTravel + delta).clamp(
      -atStart - minWidth - _offscreenGap,
      range - atStart,
    );
    final pixels = atStart + _dragTravel;
    _extent.value = (pixels / range).clamp(0.0, 1.0);
    // The route's quadratic travel is unchanged. Only overdrag at the
    // narrow detent moves the route/scrim and enables swipe dismissal.
    final travel = (-pixels / (minWidth + _offscreenGap)).clamp(0.0, 1.0);
    final routeProgress = 1 - math.sqrt(travel);
    if (controller!.value != routeProgress) {
      controller!.value = routeProgress;
    }
  }

  void _finishDrag({double speed = 0, bool cancelled = false}) {
    if (!_dragging) return;
    _dragging = false;
    if (!isCurrent) return;
    final slidingOffscreen = controller!.value < 1;
    if (!cancelled &&
        slidingOffscreen &&
        (controller!.value < .5 || speed < -_fling)) {
      navigator!.pop();
      return;
    }
    if (slidingOffscreen) controller!.forward();
    _settleExtent(
      cancelled
          ? (_dragOrigin >= .5 ? 1 : 0)
          : speed.abs() > _fling
          ? (speed > 0 ? 1 : 0)
          : (_extent.value >= .5 ? 1 : 0),
    );
  }

  Widget _grip(
    Color color,
    double progress,
    double minWidth,
    double maxWidth,
  ) => Align(
    alignment: Alignment.centerRight,
    child: Semantics(
      label: 'Folder panel width'.tl,
      value: '${(100 * lerpDouble(_initialWidth, 1, progress)!).round()}%',
      increasedValue: '100%',
      decreasedValue: '40%',
      onIncrease: progress < 1 ? () => _settleExtent(1) : null,
      onDecrease: progress > 0 ? () => _settleExtent(0) : null,
      child: Listener(
        // Flutter ends an accepted drag even on PointerCancel. Restore the
        // starting detent before its end callback sees the event.
        onPointerCancel: (_) => _finishDrag(cancelled: true),
        child: GestureDetector(
          key: const ValueKey('mobile-side-sheet-handle'),
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _toggleExtent,
          onHorizontalDragStart: (_) => _startDrag(),
          onHorizontalDragUpdate: (details) =>
              _drag(details.delta.dx, minWidth, maxWidth),
          onHorizontalDragEnd: (details) =>
              _finishDrag(speed: details.primaryVelocity ?? 0),
          onHorizontalDragCancel: () => _finishDrag(cancelled: true),
          child: SizedBox(
            width: _rail,
            height: 112,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const SizedBox(width: 4, height: 34),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _themes.wrap(
    Directionality(
      textDirection: _textDirection,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colors = prism.Theme.of(context).colorScheme;
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final minWidth = width * _initialWidth;
              final minHeight = height * _initialHeight;
              final shape = RoundedSuperellipseBorder(
                borderRadius: prism.floatingSheetRadius(
                  MediaQuery.displayCornerRadiiOf(context),
                  1,
                ),
              );
              final clipper = ShapeBorderClipper(shape: shape);
              return AnimatedBuilder(
                animation: Listenable.merge([animation, _extent]),
                child: MobileSideSheetLayout(
                  controlsWidth: math.max(0, minWidth - _rail),
                  bottomReserve: height - minHeight,
                  child: Material(
                    key: const ValueKey('mobile-side-sheet-surface'),
                    color: prism.SurfaceLevel.page.colorOf(colors),
                    elevation: 12,
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: prism.ElevatedSurfaceTheme(
                      child: prism.SurfaceScope(
                        level: prism.SurfaceLevel.page,
                        child: Padding(
                          padding: const EdgeInsets.only(right: _rail),
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ),
                ),
                builder: (context, card) {
                  final progress = _extent.value;
                  final exposure = lerpDouble(minWidth, width, progress)!;
                  final shownHeight = lerpDouble(minHeight, height, progress)!;
                  // The scrim's original quadratic entrance/exit stays on
                  // the route. Only the viewport changes its dimensions.
                  final untravelled = 1 - animation.value;
                  final shownWidth = math.max(
                    0.0,
                    exposure -
                        untravelled * untravelled * (exposure + _offscreenGap),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        top: (height - shownHeight) / 2,
                        width: shownWidth,
                        height: shownHeight,
                        // The explicit path clips paint, pointer hits and the
                        // semantics of the hidden portions of the card.
                        child: ClipPath(
                          key: const ValueKey('mobile-side-sheet-viewport'),
                          clipper: clipper,
                          child: Semantics(
                            scopesRoute: true,
                            explicitChildNodes: true,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                OverflowBox(
                                  alignment: Alignment.topRight,
                                  minWidth: width,
                                  maxWidth: width,
                                  minHeight: height,
                                  maxHeight: height,
                                  child: card,
                                ),
                                _grip(
                                  colors.onSurfaceVariant,
                                  progress,
                                  minWidth,
                                  width,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}
