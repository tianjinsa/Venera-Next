import 'package:flutter/material.dart';
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/translations.dart';

import 'chrome_action.dart';
import 'platform_effects_controller.dart';
import 'image_favorite_controller.dart';

/// Snapshot of the automatic-reading action, independent of its controller.
class ReaderAutomaticReadingAction {
  const ReaderAutomaticReadingAction({
    required this.tooltip,
    required this.active,
    required this.playing,
    required this.onPressed,
  });
  final String tooltip;
  final bool active;
  final bool playing;
  final VoidCallback onPressed;
}

/// Presentation only. Optional callbacks express host/platform capabilities.
List<Widget> buildReaderBottomActions(
  BuildContext context, {
  required ReaderImageFavoriteStatus imageFavoriteStatus,
  bool usePrism = false,
  required VoidCallback? onCollect,
  VoidCallback? onRetryImageStatus,
  bool imageCollecting = false,
  VoidCallback? onFullscreen,
  required ReaderOrientation orientation,
  VoidCallback? onRotate,
  required bool brightnessEnabled,
  required VoidCallback onBrightness,
  required ReaderAutomaticReadingAction automaticReading,
  VoidCallback? onChapters,
  required VoidCallback onSave,
  required VoidCallback onShare,
}) {
  Widget action({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
    bool selected = false,
    BoxConstraints? constraints,
  }) {
    if (usePrism) {
      return ReaderChromeAction(
        usePrism: true,
        label: label,
        icon: icon,
        onPressed: onPressed,
        selected: selected,
      );
    }
    return Tooltip(
      message: label,
      child: IconButton(
        constraints: constraints,
        color: selected ? Theme.of(context).colorScheme.primary : null,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }

  // The same command owns both its direct button and its overflow entry.
  // Do not infer command identity from a translated label or widget order.
  final overflow = <prism.PopupMenuItem>[];
  List<Widget> secondary({
    required String label,
    required Icon icon,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    if (!usePrism) {
      return [
        action(
          label: label,
          icon: icon,
          onPressed: onPressed,
          selected: selected,
        ),
      ];
    }
    overflow.add(
      prism.PopupMenuItem(
        label: label,
        onPressed: onPressed,
        checked: selected ? true : null,
      ),
    );
    return const [];
  }

  final buttons = [
    Semantics(
      toggled: switch (imageFavoriteStatus) {
        ReaderImageFavoriteStatus.collected => true,
        ReaderImageFavoriteStatus.uncollected => false,
        _ => null,
      },
      child: action(
        label: imageCollecting
            ? 'Saving image collection'.tl
            : switch (imageFavoriteStatus) {
                ReaderImageFavoriteStatus.loading =>
                  'Loading image collection'.tl,
                ReaderImageFavoriteStatus.failed =>
                  'Unable to load image collection. Retry'.tl,
                ReaderImageFavoriteStatus.collected => 'Uncollect the image'.tl,
                ReaderImageFavoriteStatus.selectImage =>
                  'Select an image to collect'.tl,
                _ => 'Collect the image'.tl,
              },
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: imageCollecting
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: MediaQuery.disableAnimationsOf(context) ? 0.5 : null,
                ),
              )
            : Icon(switch (imageFavoriteStatus) {
                ReaderImageFavoriteStatus.collected => Icons.favorite,
                ReaderImageFavoriteStatus.failed => Icons.error_outline,
                ReaderImageFavoriteStatus.selectImage =>
                  Icons.add_photo_alternate_outlined,
                _ => Icons.favorite_border,
              }),
        onPressed: imageCollecting
            ? null
            : imageFavoriteStatus == ReaderImageFavoriteStatus.failed
            ? onRetryImageStatus
            : imageFavoriteStatus == ReaderImageFavoriteStatus.collected ||
                  imageFavoriteStatus ==
                      ReaderImageFavoriteStatus.uncollected ||
                  imageFavoriteStatus == ReaderImageFavoriteStatus.selectImage
            ? onCollect
            : null,
      ),
    ),
    if (onFullscreen != null)
      ...secondary(
        label: "${"Full Screen".tl}(F12)",
        icon: const Icon(Icons.fullscreen),
        onPressed: onFullscreen,
      ),
    if (onRotate != null)
      ...secondary(
        label: "Screen Rotation".tl,
        icon: Icon(switch (orientation) {
          ReaderOrientation.system => Icons.screen_rotation,
          ReaderOrientation.portrait => Icons.screen_lock_portrait,
          ReaderOrientation.landscape => Icons.screen_lock_landscape,
        }),
        onPressed: onRotate,
      ),
    action(
      label: 'Adjust picture'.tl,
      icon: const Icon(Icons.tune),
      selected: brightnessEnabled,
      onPressed: onBrightness,
    ),
    ...secondary(
      label: automaticReading.tooltip,
      icon: Icon(
        automaticReading.playing
            ? Icons.pause_circle_outline
            : Icons.play_circle_outline,
      ),
      selected: automaticReading.active,
      onPressed: automaticReading.onPressed,
    ),
    if (onChapters != null)
      ...secondary(
        label: "Chapters".tl,
        icon: const Icon(Icons.library_books),
        onPressed: onChapters,
      ),
    ...secondary(
      label: "Save Image".tl,
      icon: const Icon(Icons.download),
      onPressed: onSave,
    ),
    ...secondary(
      label: App.isHarmonyOS
          ? 'System sharing is not available on HarmonyOS. Save the image to Files instead.'
                .tl
          : 'Share'.tl,
      icon: const Icon(Icons.share),
      onPressed: App.isHarmonyOS ? null : onShare,
    ),
  ];
  if (!usePrism) return buttons;
  return [
    prism.TonalButtonGroup(
      key: const ValueKey('reader-bottom-quick'),
      children: buttons,
    ),
    MobileMenuButton(
      key: const ValueKey('reader-bottom-more'),
      items: overflow,
    ),
  ];
}
