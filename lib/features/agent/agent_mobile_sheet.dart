import 'package:flutter/widgets.dart';
import 'package:venera_next/components/mobile_large_sheet.dart';

Future<T?> showAgentMobileSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showMobileLargeSheet<T>(context: context, builder: builder);
