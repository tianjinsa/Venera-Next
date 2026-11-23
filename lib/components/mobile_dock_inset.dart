import 'package:flutter/widgets.dart';

/// Clearance for the last scroll item or a fixed bottom action on a root tab.
/// It is NOT padding on the page: its viewport should paint behind the dock.
/// Pushed routes, sheets, wide layouts and TV have no dock in their subtree.
class MobileDockInset extends InheritedWidget {
  const MobileDockInset({
    super.key,
    required this.clearance,
    required super.child,
  });

  final double clearance;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MobileDockInset>()
          ?.clearance ??
      0;

  @override
  bool updateShouldNotify(MobileDockInset oldWidget) =>
      oldWidget.clearance != clearance;
}
