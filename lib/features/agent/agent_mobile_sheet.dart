import 'package:flutter/material.dart';
import 'package:prism_ui/sheet.dart' as prism show SheetProps, showSheet;
import 'package:prism_ui/sheet_header.dart' as prism show SheetDragHandle;

/// The single scroll view in each panel inherits Prism's primary controller.
/// A drag scrolls the list, then hands off at its top to Prism's sheet.
Future<T?> showAgentMobileSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double detent = .9,
}) => prism.showSheet<T>(
  context: context,
  props: prism.SheetProps(detents: [detent]),
  builder: (context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Center(child: prism.SheetDragHandle()),
          ),
          Expanded(child: Builder(builder: builder)),
        ],
      ),
    ),
  ),
);
