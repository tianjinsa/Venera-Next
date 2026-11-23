import 'package:flutter/material.dart';
import 'package:prism_ui/popup.dart' as prism;

import 'mobile_ui.dart';

/// For a short, flat set of commands. Labels are not used as business keys.
class AdaptiveActionMenu<T extends Object> extends StatelessWidget {
  const AdaptiveActionMenu({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
    this.destructive = const <Never>{},
  });
  final String label;
  final Map<T, String> options;
  final Set<T> destructive;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    if (MobileUi.enabledOf(context)) {
      return MobileMenuButton(
        label: label,
        items: [
          for (final entry in options.entries)
            prism.PopupMenuItem(
              label: entry.value,
              danger: destructive.contains(entry.key),
              onPressed: () => onSelected(entry.key),
            ),
        ],
      );
    }
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
