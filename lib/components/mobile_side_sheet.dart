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

/// A floating modal at the physical left. The same horizontal grip changes
/// both dimensions without changing the route or sharing the list's scroll
/// controller. Leftward travel past the narrow detent dismisses the route.
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

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _themes.wrap(
    Directionality(
      textDirection: _textDirection,
      child: ClipRect(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            minimum: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final colors = prism.Theme.of(context).colorScheme;
                final minWidth = constraints.maxWidth * _initialWidth;
                final minHeight = constraints.maxHeight * _initialHeight;
                final radius = prism.floatingSheetRadius(
                  MediaQuery.displayCornerRadiiOf(context),
                  1,
                );
                return AnimatedBuilder(
                  animation: _extent,
                  child: Builder(builder: builder),
                  builder: (context, content) {
                    final progress = _extent.value;
                    final width = lerpDouble(
                      minWidth,
                      constraints.maxWidth,
                      progress,
                    )!;
                    final height = lerpDouble(
                      minHeight,
                      constraints.maxHeight,
                      progress,
                    )!;
                    return Align(
                      alignment: Alignment.centerLeft,
                      // Keep the original transition regardless of extent.
                      child: SlideTransition(
                        position: animation
                            .drive(CurveTween(curve: Curves.easeOutQuad))
                            .drive(
                              Tween(
                                begin: Offset(
                                  -1 - _offscreenGap / math.max(width, 1),
                                  0,
                                ),
                                end: Offset.zero,
                              ),
                            ),
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Semantics(
                            scopesRoute: true,
                            explicitChildNodes: true,
                            child: Material(
                              key: const ValueKey('mobile-side-sheet-surface'),
                              color: prism.SurfaceLevel.page.colorOf(colors),
                              elevation: 12,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: radius,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: prism.ElevatedSurfaceTheme(
                                child: prism.SurfaceScope(
                                  level: prism.SurfaceLevel.page,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Physical right for both directions.
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 22,
                                        ),
                                        child: content,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Semantics(
                                          label: 'Folder panel width'.tl,
                                          value:
                                              '${(100 * width / math.max(1, constraints.maxWidth)).round()}%',
                                          increasedValue: '100%',
                                          decreasedValue: '40%',
                                          onIncrease: progress < 1
                                              ? () => _settleExtent(1)
                                              : null,
                                          onDecrease: progress > 0
                                              ? () => _settleExtent(0)
                                              : null,
                                          child: Listener(
                                            // Flutter ends an accepted drag even
                                            // on PointerCancel; restore the start
                                            // detent before that callback runs.
                                            onPointerCancel: (_) =>
                                                _finishDrag(cancelled: true),
                                            child: GestureDetector(
                                              key: const ValueKey(
                                                'mobile-side-sheet-handle',
                                              ),
                                              excludeFromSemantics: true,
                                              behavior: HitTestBehavior.opaque,
                                              onTap: _toggleExtent,
                                              onHorizontalDragStart: (_) =>
                                                  _startDrag(),
                                              onHorizontalDragUpdate:
                                                  (details) => _drag(
                                                    details.delta.dx,
                                                    minWidth,
                                                    constraints.maxWidth,
                                                  ),
                                              onHorizontalDragEnd: (details) =>
                                                  _finishDrag(
                                                    speed:
                                                        details
                                                            .primaryVelocity ??
                                                        0,
                                                  ),
                                              onHorizontalDragCancel: () =>
                                                  _finishDrag(cancelled: true),
                                              child: SizedBox(
                                                width: 22,
                                                height: 112,
                                                child: Center(
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const SizedBox(
                                                      width: 4,
                                                      height: 34,
                                                    ),
                                                  ),
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
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
