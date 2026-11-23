import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/dialog.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:venera_next/foundation/selection_operation.dart';
import 'package:venera_next/foundation/translations.dart';

import 'message.dart';
import 'mobile_choice.dart';
import 'mobile_ui.dart';
import 'select.dart';
import 'window_selection_task.dart';

Future<int?> showSelectDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  int? initialIndex,
}) async {
  final task = WindowSelectionTask(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  int? current = initialIndex;
  final disposed = Completer<int?>();
  final removalFailed = Completer<int?>();
  removalFailed.future.ignore();
  PopupRoute<void>? route;

  void finish() {
    if (!disposed.isCompleted) disposed.complete(null);
  }

  bool canAct() =>
      !disposed.isCompleted && task.canPresent && route?.isCurrent == true;

  try {
    return await task.run((operation) async {
      operation.checkActive();
      final PopupRoute<void> dialog;
      if (MobileUi.enabledOf(context)) {
        dialog = _OwnedSelectAlertRoute(
          barrierColor: prism.Theme.of(context).colorScheme.alertScrim,
          barrierLabel: 'Close'.tl,
          onDispose: finish,
          builder: (_) => StatefulBuilder(
            builder: (context, setState) => prism.AlertDialog(
              title: title,
              child: MobileChoice<int>(
                value: current,
                options: [
                  for (final (index, option) in options.indexed)
                    MobileChoiceOption(index, option),
                ],
                onChanged: (index) {
                  if (canAct()) setState(() => current = index);
                },
              ),
              actions: [
                prism.TextButton(
                  onPressed: () {
                    if (!canAct()) return;
                    current = null;
                    navigator.pop();
                  },
                  child: Text('Cancel'.tl),
                ),
                prism.TextButton(
                  onPressed: current == null
                      ? null
                      : () {
                          if (canAct()) navigator.pop();
                        },
                  child: Text('Confirm'.tl),
                ),
              ],
            ),
          ),
        );
      } else {
        dialog = ResourceDialogRoute<void>(
          context: context,
          themes: InheritedTheme.capture(from: context, to: navigator.context),
          barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
          onDispose: finish,
          builder: (_) => StatefulBuilder(
            builder: (context, setState) {
              return ContentDialog(
                title: title,
                content: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Select(
                        current: current == null ? "" : options[current!],
                        values: options,
                        minWidth: 156,
                        onTap: (i) {
                          if (!canAct()) return;
                          setState(() => current = i);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (!canAct()) return;
                      current = null;
                      navigator.pop();
                    },
                    child: Text('Cancel'.tl),
                  ),
                  FilledButton(
                    onPressed: current == null
                        ? null
                        : () {
                            if (canAct()) navigator.pop();
                          },
                    child: Text('Confirm'.tl),
                  ),
                ],
              );
            },
          ),
        );
      }
      route = dialog;
      final release = task.retainPresentation(() {
        try {
          current = null;
          if (navigator.mounted && dialog.isActive) {
            navigator.removeRoute(dialog);
          } else {
            finish();
          }
        } catch (error, stack) {
          if (!removalFailed.isCompleted) {
            removalFailed.completeError(error, stack);
          }
          rethrow;
        }
      }, isCurrent: () => dialog.isCurrent);
      // Ordinary back/barrier dismissal keeps the current choice. Disposal
      // without a pop and explicit host cancellation both return null.
      final closed = navigator.push(dialog).then<int?>((_) => current);
      final result = await Future.any<int?>([
        closed,
        disposed.future,
        removalFailed.future,
      ]);
      release();
      return result;
    });
  } on SelectionCancelled {
    return null;
  } finally {
    if (route?.navigator == null) finish();
  }
}

// Prism's public alert motion with the explicit route ownership required when
// a source's hosting page or window can disappear during selection.
class _OwnedSelectAlertRoute extends PopupRoute<void>
    with prism.AlertMotionRouteMixin<void>, prism.AlertHostRoute<void> {
  _OwnedSelectAlertRoute({
    required this.barrierColor,
    required this.barrierLabel,
    required this.onDispose,
    required this.builder,
  });

  @override
  final Color barrierColor;
  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => true;

  final VoidCallback onDispose;
  final WidgetBuilder builder;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: SafeArea(child: Builder(builder: builder)),
  );

  @override
  void dispose() {
    try {
      onDispose();
    } finally {
      super.dispose();
    }
  }
}
