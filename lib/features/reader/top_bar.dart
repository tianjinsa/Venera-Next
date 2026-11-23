import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/effects.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.title,
    this.chapterTitle,
    required this.actions,
    this.leadingActions = const [],
    this.trailingAccessory,
    required this.onBack,
    this.usePrism = false,
    this.toolbarHeight = 56,
  });
  final String title;
  final String? chapterTitle;
  final List<Widget> actions;

  /// Compact controls that belong on the same edge as Back, e.g. diagnostics.
  final List<Widget> leadingActions;

  /// A separate compact control before the trailing shortcuts, if available.
  final Widget? trailingAccessory;
  final VoidCallback onBack;
  final bool usePrism;
  final double toolbarHeight;
  @override
  Widget build(BuildContext context) {
    final heading = chapterTitle == null
        ? Text(
            title,
            style: ts.s18,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: ts.s16,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                chapterTitle!,
                style: ts.s12,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
    if (usePrism) {
      // Prism AppBar fixes the leading slot to one button. Let the reader's
      // left cluster take its actual width and keep all hit surfaces local to
      // their capsules, rather than laying a backdrop over the artwork.
      return prism.TonalButtonTheme(
        glass: prism.LiquidGlassScope.of(context),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: toolbarHeight,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              child: Row(
                spacing: MobileToolbarActions.gap,
                children: [
                  MobileToolbarActions(
                    shortcuts: [
                      MobileToolbarButton(
                        label: 'Back'.tl,
                        icon: const prism.GlyphIcon(prism.Glyphs.chevronBack),
                        onPressed: onBack,
                      ),
                      ...leadingActions,
                    ],
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: IgnorePointer(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 3),
                              Shadow(color: Colors.black, blurRadius: 1),
                            ],
                          ),
                          child: heading,
                        ),
                      ),
                    ),
                  ),
                  if (trailingAccessory case final accessory?)
                    MobileToolbarActions(shortcuts: [accessory]),
                  if (actions.isNotEmpty)
                    MobileToolbarActions(shortcuts: actions),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.92),
          border: Border(
            bottom: BorderSide(color: Colors.grey.toOpacity(0.5), width: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: context.padding.left,
            right: context.padding.right,
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              BackButton(onPressed: onBack),
              const SizedBox(width: 8),
              Expanded(child: heading),
              const SizedBox(width: 8),
              ...actions,
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
