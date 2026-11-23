import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:venera_next/components/effects.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

import 'chrome_action.dart';
import 'information_text.dart';

/// Presentation for progress and actions. The content owner supplies commands.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.label,
    required this.actions,
    required this.page,
    required this.maxPage,
    required this.reversed,
    required this.isOpen,
    required this.onPageChanged,
    required this.onPrevious,
    required this.onNext,
    this.progressIdentity,
    this.usePrism = false,
    this.previousTooltip,
    this.nextTooltip,
  });
  static const height = 105.0;
  final String label;
  final List<Widget> actions;
  final int page;
  final int maxPage;
  final bool reversed;
  final bool isOpen;
  final bool usePrism;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Object? progressIdentity;
  final String? previousTooltip, nextTooltip;

  @override
  Widget build(BuildContext context) {
    Widget pageEdge(String title, IconData icon, VoidCallback callback) {
      final button = ReaderChromeAction(
        usePrism: usePrism,
        label: title,
        icon: Icon(icon),
        onPressed: callback,
        tonal: true,
      );
      return usePrism
          ? prism.TonalButtonTheme(
              glass: prism.LiquidGlassScope.of(context),
              child: prism.TonalButtonGroup(children: [button]),
            )
          : button;
    }

    final child = SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              pageEdge(
                previousTooltip ??
                    MaterialLocalizations.of(context).previousPageTooltip,
                Icons.first_page,
                onPrevious,
              ),
              Expanded(
                child: ReaderProgressSlider(
                  key: ValueKey((progressIdentity, isOpen)),
                  page: page,
                  maxPage: maxPage,
                  reversed: reversed,
                  enabled: isOpen,
                  onChanged: onPageChanged,
                ),
              ),
              pageEdge(
                nextTooltip ??
                    MaterialLocalizations.of(context).nextPageTooltip,
                Icons.last_page,
                onNext,
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (usePrism)
            Flexible(
              child: Align(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  scrollDirection: Axis.horizontal,
                  child: prism.TonalButtonTheme(
                    glass: prism.LiquidGlassScope.of(context),
                    child: prism.TonalButtonGroup(
                      key: const ValueKey('reader-bottom-action-group'),
                      children: actions,
                    ),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constrains) {
                final labelSize = TextPainter(
                  text: TextSpan(
                    text: label,
                    style: DefaultTextStyle.of(context).style,
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                // Keep the existing 24px badge and 48px actions. When scaled
                // text cannot fit, use the same actions-only layout as phones.
                final small =
                    labelSize.height > 20 ||
                    constrains.maxWidth <
                        actions.length * 56 + labelSize.width + 32;
                labelSize.dispose();
                return Row(
                  children: [
                    if (!small) ...[
                      Container(
                        height: 24,
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(label)),
                      ).paddingLeft(16),
                      const Spacer(),
                      for (var button in actions) button.paddingHorizontal(4),
                      const SizedBox(width: 4),
                    ] else
                      for (var button in actions)
                        Expanded(child: Center(child: button)),
                  ],
                );
              },
            ),
        ],
      ),
    );

    final padding = context.padding;
    final panel = Container(
      decoration: BoxDecoration(
        color: usePrism
            ? context.colorScheme.surface
            : context.colorScheme.surface.toOpacity(0.92),
        border: !usePrism && isOpen
            ? Border(
                top: BorderSide(color: Colors.grey.toOpacity(0.5), width: 0.5),
              )
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        padding.left,
        0,
        padding.right,
        padding.bottom,
      ),
      child: child,
    );
    // The compact bar uses Prism glass only on the controls, not a second
    // full-width backdrop blur over the reading canvas.
    return usePrism ? panel : BlurEffect(child: panel);
  }
}

class ReaderProgressSlider extends StatelessWidget {
  const ReaderProgressSlider({
    super.key,
    required this.page,
    required this.maxPage,
    required this.reversed,
    required this.onChanged,
    this.enabled = true,
  });
  final int page;
  final int maxPage;
  final bool reversed;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final count = maxPage < 1 ? 1 : maxPage;
    final displayPage = page.clamp(1, count);
    final interactive = enabled && count > 1;
    return MergeSemantics(
      child: Semantics(
        label: 'Page'.tl,
        child: Directionality(
          // Reading direction is independent of the interface language.
          textDirection: reversed ? TextDirection.rtl : TextDirection.ltr,
          child: CallbackShortcuts(
            bindings: interactive
                ? {
                    const SingleActivator(LogicalKeyboardKey.home): () =>
                        onChanged(1),
                    const SingleActivator(LogicalKeyboardKey.end): () =>
                        onChanged(count),
                  }
                : const {},
            child: SizedBox(
              height: 48,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 11,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 22,
                  ),
                ),
                child: Slider(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  value: displayPage.toDouble(),
                  min: 1,
                  max: count.toDouble(),
                  divisions: count > 1 ? count - 1 : null,
                  onChanged: interactive
                      ? (value) => onChanged(value.round())
                      : null,
                  semanticFormatterCallback: (value) => 'Page @page'.tlParams({
                    'page': '${value.round()} / $count',
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderPageInfo extends StatelessWidget {
  const ReaderPageInfo({
    super.key,
    required this.page,
    required this.maxPage,
    this.chapterTitle,
  });
  final int page, maxPage;
  final String? chapterTitle;
  @override
  Widget build(BuildContext context) {
    final chapter = chapterTitle;
    final pages = '$page/$maxPage';
    final shortTitle = chapter != null && chapter.characters.length > 8
        ? '${chapter.characters.take(8)}...'
        : chapter;
    return Semantics(
      label: chapter == null ? pages : '$chapter : $pages',
      excludeSemantics: true,
      child: Wrap(
        spacing: 4,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (shortTitle != null) ReaderInformationText(text: '$shortTitle :'),
          // A chapter title must never ellipsize the actual page numbers.
          ReaderInformationText(text: pages, maxLines: null),
        ],
      ),
    );
  }
}
