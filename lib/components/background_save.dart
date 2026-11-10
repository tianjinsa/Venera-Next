import 'dart:async';

import 'package:flutter/material.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/translations.dart';

/// The root overlay owns the indicator, so it survives the saving route.
/// Accepted work is still retained by the application's storage/exit owners.
class BackgroundSave {
  static final _hosts = Expando<_BackgroundSaveHost>();

  static void run(BuildContext context, Future<void> Function() save) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final host = _hosts[overlay] ??= _BackgroundSaveHost(overlay);
    host.run(save);
  }
}

class _BackgroundSaveHost {
  _BackgroundSaveHost(this.overlay);
  final OverlayState overlay;
  OverlayEntry? _entry;
  int _pending = 0;
  final _failures = <Object, String>{};
  bool _reviewing = false;

  void run(Future<void> Function() save) {
    _pending++;
    _refresh();
    unawaited(() async {
      try {
        await save();
      } catch (error, stack) {
        Log.error('Background save', error, stack);
        _failures[Object()] = '$error\n\n$stack';
      } finally {
        _pending--;
        _refresh();
      }
    }());
  }

  void _refresh() {
    if (!overlay.mounted) return;
    if (_pending == 0 && _failures.isEmpty) {
      _entry?.remove();
      _entry?.dispose();
      _entry = null;
    } else if (_entry == null) {
      _entry = OverlayEntry(
        builder: (context) => Positioned(
          right: MediaQuery.paddingOf(context).right + 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: _SaveIndicator(
            failed: _failures.isNotEmpty,
            onReview: () => _review(context),
          ),
        ),
      );
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  Future<void> _review(BuildContext context) async {
    if (_reviewing || _failures.isEmpty) return;
    _reviewing = true;
    final failures = Map.of(_failures);
    try {
      final acknowledged = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Background save failed'.tl),
          scrollable: true,
          content: SelectableText(failures.values.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Close'.tl),
            ),
          ],
        ),
      );
      if (acknowledged == true) {
        // Do not dismiss failures that arrived while these details were open.
        for (final key in failures.keys) {
          _failures.remove(key);
        }
      }
    } finally {
      _reviewing = false;
      _refresh();
    }
  }
}

class _SaveIndicator extends StatefulWidget {
  const _SaveIndicator({required this.failed, required this.onReview});
  final bool failed;
  final VoidCallback onReview;

  @override
  State<_SaveIndicator> createState() => _SaveIndicatorState();
}

class _SaveIndicatorState extends State<_SaveIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.35,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(_SaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animate();
  }

  void _animate() {
    if (widget.failed || MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const CircleBorder(),
    child: Tooltip(
      message: widget.failed ? 'Background save failed'.tl : 'Saving...'.tl,
      child: Semantics(
        liveRegion: widget.failed,
        label: widget.failed ? 'Background save failed'.tl : 'Saving...'.tl,
        child: IconButton(
          key: const ValueKey('background-save-status'),
          onPressed: widget.failed ? widget.onReview : null,
          icon: widget.failed
              ? Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                )
              : FadeTransition(
                  opacity: _pulse,
                  child: Icon(
                    Icons.save_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}
