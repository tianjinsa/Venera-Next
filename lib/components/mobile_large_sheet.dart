import 'package:flutter/material.dart';
import 'package:prism_ui/color.dart' as prism show ColorSchemeExtension;
import 'package:prism_ui/l10n.dart' as prism show UiLocalizations;
import 'package:prism_ui/sheet_header.dart' as prism show SheetDragHandle;
import 'package:prism_ui/sheet_navigator.dart' as prism show sheetNavigatorOf;
import 'package:prism_ui/snap_sheet.dart' as prism show SnapSheetRoute;
import 'package:prism_ui/theme_data.dart' as prism show Theme;

/// A phone-only presentation. Prism owns both detents, the floating transform,
/// keyboard lift, drag/scroll handoff, barrier and dismissal spring. Unlike a
/// content-fit sheet, an empty or filtered list can still expand to full width.
prism.SnapSheetRoute<T> mobileLargeSheetRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  VoidCallback? onDispose,
}) => _MobileLargeSheetRoute<T>(
  sheetBarrierColor: prism.Theme.of(context).colorScheme.modalScrim,
  barrierLabel: prism.UiLocalizations.of(context).close,
  onDispose: onDispose,
  builder: (context, controller) => PrimaryScrollController(
    controller: controller!,
    automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
    child: Material(
      key: const ValueKey('mobile-large-sheet-surface'),
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(child: prism.SheetDragHandle()),
            ),
            Expanded(child: Builder(builder: builder)),
          ],
        ),
      ),
    ),
  ),
);

Future<T?> showMobileLargeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => prism
    .sheetNavigatorOf(context)
    .push<T>(mobileLargeSheetRoute<T>(context: context, builder: builder));

class _MobileLargeSheetRoute<T> extends prism.SnapSheetRoute<T> {
  _MobileLargeSheetRoute({
    required super.builder,
    required super.sheetBarrierColor,
    required super.barrierLabel,
    this.onDispose,
  }) : super(detents: const [.5, .9], fitsContent: false);

  final VoidCallback? onDispose;

  @override
  void dispose() {
    try {
      onDispose?.call();
    } finally {
      super.dispose();
    }
  }
}
