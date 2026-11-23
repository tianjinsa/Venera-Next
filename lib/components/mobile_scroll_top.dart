import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:venera_next/foundation/translations.dart';

import 'mobile_dock_inset.dart';
import 'mobile_ui.dart';

/// A fixed action in a root tab, not extra padding on its scroll viewport.
/// [MobileDockInset] already includes the bottom system inset when visible.
class MobileScrollTopOverlay extends StatefulWidget {
  const MobileScrollTopOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.onRefresh,
  });

  final ScrollController controller;
  final Widget child;
  final VoidCallback? onRefresh;

  @override
  State<MobileScrollTopOverlay> createState() => _MobileScrollTopOverlayState();
}

class _MobileScrollTopOverlayState extends State<MobileScrollTopOverlay> {
  // A short scroll should not cover content with another control.
  static const _revealOffset = 240.0;
  final _showTop = ValueNotifier(false);
  var _syncScheduled = false;

  ScrollPosition? get _position {
    final controller = widget.controller;
    if (controller.positions.length != 1) return null;
    final position = controller.position;
    return position.hasPixels && position.hasContentDimensions
        ? position
        : null;
  }

  bool get _pastThreshold {
    final position = _position;
    return position != null &&
        position.pixels - position.minScrollExtent >= _revealOffset;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant MobileScrollTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _scheduleSync();
  }

  void _sync() => _showTop.value = _pastThreshold;

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  void _scrollToTop() {
    final position = _position;
    if (position == null) {
      _sync();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
    } else {
      position.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _showTop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MobileUi.enabledOf(context)) return widget.child;
    final padding = MediaQuery.paddingOf(context);
    final dock = MobileDockInset.of(context);
    final end = Directionality.of(context) == TextDirection.rtl
        ? padding.left
        : padding.right;
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 &&
                notification.metrics.axis == Axis.vertical) {
              _scheduleSync();
            }
            return false;
          },
          child: widget.child,
        ),
        PositionedDirectional(
          bottom: math.max(dock, padding.bottom + 16),
          end: end + 16,
          child: ValueListenableBuilder(
            valueListenable: _showTop,
            builder: (context, atDistance, _) {
              final action = atDistance ? _scrollToTop : widget.onRefresh;
              if (action == null) return const SizedBox.shrink();
              return prism.TonalButtonTheme(
                glass: prism.LiquidGlassScope.of(context),
                child: SizedBox.square(
                  dimension: 48,
                  child: MobileToolbarButton(
                    key: ValueKey(atDistance ? 'scroll-top' : 'scroll-refresh'),
                    label: atDistance ? 'Back to top'.tl : 'Refresh'.tl,
                    icon: Icon(
                      atDistance ? Icons.arrow_upward_rounded : Icons.refresh,
                    ),
                    onPressed: action,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
