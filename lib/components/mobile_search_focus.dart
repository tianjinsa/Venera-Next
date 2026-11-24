import 'package:flutter/widgets.dart';
import 'package:venera_next/foundation/navigation_admission.dart';

/// A nested tab route can remain current in its own navigator while a root
/// dialog is covering it. Never hand the keyboard to such an editor.
bool searchInputOwnerIsCurrent(BuildContext owner) {
  if (!NavigationAdmission.allows(owner) ||
      !TickerMode.valuesOf(owner).enabled) {
    return false;
  }
  final visited = <ModalRoute<dynamic>>{};
  BuildContext scope = owner;
  while (true) {
    final route = ModalRoute.of(scope);
    if (route == null || !visited.add(route)) return true;
    final navigator = route.navigator;
    if (navigator == null ||
        !route.isCurrent ||
        route.offstage ||
        route.animation?.isCompleted == false ||
        navigator.userGestureInProgress) {
      return false;
    }
    scope = navigator.context;
  }
}

/// Navigation or a local expansion can report completion before its final
/// frame has enabled the field's input. Wait for that frame, then check the
/// original editor and owner again. Nothing retries or opens the IME directly.
void focusSearchInputAfterPaint(
  BuildContext owner,
  FocusNode editor, {
  required bool Function() isStillRequested,
}) {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) {
    if (!owner.mounted || !isStillRequested()) return;
    final attached = editor.context;
    if (attached == null ||
        !attached.mounted ||
        !editor.canRequestFocus ||
        editor.hasFocus ||
        MediaQuery.accessibleNavigationOf(owner) ||
        !identical(ModalRoute.of(owner), ModalRoute.of(attached)) ||
        !searchInputOwnerIsCurrent(owner)) {
      return;
    }
    editor.requestFocus();
  });
  binding.ensureVisualUpdate();
}

/// A one-shot request for the global search entry, not a permanent autofocus.
/// A covered, reversed or retired route cannot revive the request on return.
class SearchFocusOnArrival extends StatefulWidget {
  const SearchFocusOnArrival({
    super.key,
    required this.editor,
    required this.enabled,
    required this.child,
  });

  final FocusNode editor;
  final bool enabled;
  final Widget child;

  @override
  State<SearchFocusOnArrival> createState() => _SearchFocusOnArrivalState();
}

class _SearchFocusOnArrivalState extends State<SearchFocusOnArrival> {
  ModalRoute<dynamic>? _route;
  bool _consumed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consumed) return;
    final route = ModalRoute.of(context);
    if (_route != route) {
      _route?.animation?.removeStatusListener(_onStatus);
      _route = route;
      _route?.animation?.addStatusListener(_onStatus);
    }
    if (route?.offstage == true) return;
    if (route?.isCurrent == false || !TickerMode.valuesOf(context).enabled) {
      _consume();
      return;
    }
    _onStatus(route?.animation?.status ?? AnimationStatus.completed);
  }

  void _consume() {
    _consumed = true;
    _route?.animation?.removeStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    // Flutter temporarily reports the animation as complete while the route
    // is offstage for Hero layout. That is not a rendered, settled arrival.
    if (_consumed || _route?.offstage == true) return;
    if (status == AnimationStatus.reverse) {
      _consume();
      return;
    }
    if (status != AnimationStatus.completed) return;
    _consume();
    if (!widget.enabled) return;
    final owner = _route;
    final editor = widget.editor;
    focusSearchInputAfterPaint(
      context,
      editor,
      isStillRequested: () =>
          widget.enabled &&
          identical(widget.editor, editor) &&
          identical(ModalRoute.of(context), owner),
    );
  }

  @override
  void dispose() {
    _consume();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
