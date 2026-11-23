import 'package:flutter/material.dart';
import 'package:prism_ui/card_surface.dart' as prism;
import 'package:prism_ui/press_surface.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;
import 'package:prism_ui/surface.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class ComicDetailActionButton extends StatelessWidget {
  const ComicDetailActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
    this.onLongPressed,
    this.activeIcon,
    this.isActive,
    this.isLoading,
    this.iconColor,
  });

  final Widget icon;

  final Widget? activeIcon;

  final bool? isActive;

  final String text;

  final void Function() onPressed;

  final bool? isLoading;

  final Color? iconColor;

  final void Function()? onLongPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !(isLoading ?? false);
    final content = IconTheme.merge(
      data: IconThemeData(size: 20, color: iconColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else
            (isActive ?? false) ? (activeIcon ?? icon) : icon,
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
    if (MobileUi.enabledOf(context)) {
      final colors = prism.Theme.of(context).colorScheme;
      final level = prism.SurfaceScope.of(context).next;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // Prism owns the short tap, focus and pressed tint. Only the
        // quick-favorite long press is supplied by the app. A horizontal
        // scroll continues to win over both recognizers.
        child: GestureDetector(
          onLongPress: enabled ? onLongPressed : null,
          child: prism.PressSurface(
            fill: level.colorOf(colors),
            shape: prism.AppShape.full,
            look: prism.PressLook.tint,
            minimum: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            selected: isActive ?? false,
            onPressed: enabled ? onPressed : null,
            child: content,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: ClickInkWell(
            onTap: enabled ? onPressed : null,
            onLongPress: enabled ? onLongPressed : null,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            borderRadius: BorderRadius.circular(18),
            // Keep the compact outline inside the full-height touch target.
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
              child: content.paddingHorizontal(16),
            ),
          ),
        ),
      ),
    );
  }
}
