import 'package:flutter/material.dart';
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;

/// Reader's existing command and accessible label, shared by its two
/// presentations. The shell keeps caching these widgets independently of page
/// position and stops their tickers when the controls are hidden.
class ReaderChromeAction extends StatelessWidget {
  const ReaderChromeAction({
    super.key,
    required this.usePrism,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.tonal = false,
    this.constraints,
  });

  final bool usePrism, selected, tonal;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    if (usePrism) {
      return prism.IconButton(
        tooltip: label,
        icon: icon,
        isSelected: selected,
        onPressed: onPressed,
        style: selected || constraints != null
            ? prism.ButtonStyle.from(
                foregroundColor: selected
                    ? prism.Theme.of(context).colorScheme.primary
                    : null,
                minimumSize: constraints == null
                    ? null
                    : Size(constraints!.minWidth, constraints!.minHeight),
              )
            : null,
      );
    }
    return tonal
        ? IconButton.filledTonal(
            tooltip: label,
            icon: icon,
            onPressed: onPressed,
          )
        : IconButton(
            tooltip: label,
            color: selected ? Theme.of(context).colorScheme.primary : null,
            constraints: constraints,
            icon: icon,
            onPressed: onPressed,
          );
  }
}
