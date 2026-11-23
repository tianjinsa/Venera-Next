import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/color.dart' as prism show ColorSchemeExtension;
import 'package:prism_ui/sheet.dart' as prism show floatingSheetRadius;
import 'package:prism_ui/surface.dart'
    as prism
    show ElevatedSurfaceTheme, SurfaceLevel, SurfaceScope;
import 'package:prism_ui/theme_data.dart' as prism show Theme;

/// A compact modal platter at the physical left. Prism's desktop side sheet
/// is right-aligned with a 360dp minimum; reuse the bottom sheet's surface
/// and corner policy instead of mirroring its layout or text direction.
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
  bool _dragging = false;

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

  void _startDrag() {
    _dragging = isCurrent && controller?.isCompleted == true;
  }

  void _drag(double delta, double width) {
    if (!_dragging || !isCurrent) return;
    // buildTransitions eases travel quadratically when not under the finger.
    // Invert the same curve so the handle moves by the actual finger delta.
    final transform = controller!;
    final remaining = 1 - transform.value;
    final travel = (remaining * remaining - delta / width).clamp(0.0, 1.0);
    transform.value = 1 - math.sqrt(travel);
  }

  void _finishDrag({double speed = 0, bool cancelled = false}) {
    if (!_dragging) return;
    _dragging = false;
    if (!isCurrent) return;
    if (!cancelled && (controller!.value < .5 || speed < -700)) {
      navigator!.pop();
    } else {
      controller!.forward();
    }
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
        child: Builder(
          builder: (context) {
            final colors = prism.Theme.of(context).colorScheme;
            final radius = prism.floatingSheetRadius(
              MediaQuery.displayCornerRadiiOf(context),
              1,
            );
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: SafeArea(
                minimum: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(380.0, constraints.maxWidth * .84);
                    return Align(
                      alignment: Alignment.centerLeft,
                      // The scrim does not travel with the platter.
                      child: SlideTransition(
                        position: animation
                            .drive(CurveTween(curve: Curves.easeOutQuad))
                            .drive(
                              Tween(
                                begin: Offset(-1 - 28 / math.max(width, 1), 0),
                                end: Offset.zero,
                              ),
                            ),
                        child: SizedBox(
                          width: width,
                          height: constraints.maxHeight,
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
                                      Padding(
                                        padding: EdgeInsets.only(
                                          right: _reducedMotion ? 0 : 18,
                                        ),
                                        child: Builder(builder: builder),
                                      ),
                                      if (!_reducedMotion)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: GestureDetector(
                                            key: const ValueKey(
                                              'mobile-side-sheet-handle',
                                            ),
                                            excludeFromSemantics: true,
                                            behavior: HitTestBehavior.opaque,
                                            onHorizontalDragStart: (_) =>
                                                _startDrag(),
                                            onHorizontalDragUpdate: (details) =>
                                                _drag(
                                                  details.delta.dx,
                                                  width + 28,
                                                ),
                                            onHorizontalDragEnd: (details) =>
                                                _finishDrag(
                                                  speed:
                                                      details.primaryVelocity ??
                                                      0,
                                                ),
                                            onHorizontalDragCancel: () =>
                                                _finishDrag(cancelled: true),
                                            child: SizedBox(
                                              width: 18,
                                              height: 96,
                                              child: Center(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colors.onSurfaceVariant,
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
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
