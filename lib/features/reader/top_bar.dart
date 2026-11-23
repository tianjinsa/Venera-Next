import 'package:flutter/material.dart';
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/bar_item_presence.dart' as prism;
import 'package:prism_ui/scaffold.dart' as prism show AppBar;
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
    this.more,
    required this.onBack,
    this.usePrism = false,
    this.toolbarHeight = 56,
  });
  final String title;
  final String? chapterTitle;
  final List<Widget> actions;
  final Widget? more;
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
      assert(actions.length <= 2);
      // A normal toolbar has a page surface. The comic is the surface here:
      // only real button bounds intercept taps; the title remains readable
      // without putting a solid or blurred bar across the artwork.
      return prism.TonalButtonTheme(
        glass: prism.LiquidGlassScope.of(context),
        child: prism.AppBar(
          toolbarHeight: toolbarHeight,
          titleSpacing: 0,
          clipBehavior: Clip.none,
          leading: Center(
            child: prism.BarItemPresence(
              child: MobileToolbarButton(
                label: 'Back'.tl,
                icon: const prism.GlyphIcon(prism.Glyphs.chevronBack),
                onPressed: onBack,
              ),
            ),
          ),
          title: IgnorePointer(
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
          actions: [
            if (actions.isNotEmpty)
              prism.BarItemPresence(
                child: prism.TonalButtonGroup(children: actions),
              ),
            if (actions.isNotEmpty && more != null) const SizedBox(width: 8),
            if (more != null) prism.BarItemPresence(child: more!),
            const SizedBox(width: 8),
          ],
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
