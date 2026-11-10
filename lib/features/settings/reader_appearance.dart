import 'package:flutter/material.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/translations.dart';
import 'setting_components.dart';

/// Shared placement for the full settings page and the reader's picture menu.
class ReaderAppearanceSettings extends StatelessWidget {
  const ReaderAppearanceSettings({
    super.key,
    this.comicId,
    this.sourceKey,
    this.useDeviceSettings = false,
    this.activeScope = false,
    this.compact = false,
    this.onChanged,
  });
  final String? comicId, sourceKey;
  final bool useDeviceSettings, activeScope, compact;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final comic =
        !activeScope ||
        (comicId != null &&
            appdata.settings.isComicSpecificSettingsEnabled(
              comicId!,
              sourceKey,
            ));
    final device = activeScope
        ? !comic && appdata.settings.isDeviceSpecificSettingsEnabled()
        : useDeviceSettings;
    final id = comic ? comicId : null;
    final source = comic ? sourceKey : null;
    return ListTileTheme.merge(
      dense: compact ? true : null,
      contentPadding: compact ? EdgeInsets.zero : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchSetting.reader(
            title: 'Line enhancement'.tl,
            preference: ReaderPreferences.readerLineEnhancement,
            subtitle: compact
                ? null
                : 'Deepen faint lines and text. Reduce strength for color comics.'
                      .tl,
            comicId: id,
            comicSource: source,
            useDeviceSettings: device,
            onChanged: () => onChanged?.call('readerLineEnhancement'),
          ),
          SliderSetting.reader(
            title: 'Line enhancement strength'.tl,
            preference: ReaderPreferences.readerLineEnhancementStrength,
            valueFormatter: (value) => '${(value * 100).round()}%',
            comicId: id,
            comicSource: source,
            useDeviceSettings: device,
            onChanged: () => onChanged?.call('readerLineEnhancementStrength'),
          ),
          SelectSetting.reader(
            title: 'Night mode'.tl,
            preference: ReaderPreferences.readerNightMode,
            optionTranslation: {
              'none': 'Off'.tl,
              'warm': 'Warm'.tl,
              'dark': 'Dark'.tl,
              'red': 'Red'.tl,
            },
            comicId: id,
            comicSource: source,
            useDeviceSettings: device,
            onChanged: () => onChanged?.call('readerNightMode'),
          ),
          SliderSetting.reader(
            title: 'Night mode intensity'.tl,
            preference: ReaderPreferences.readerNightModeIntensity,
            valueFormatter: (value) => '${(value * 100).round()}%',
            comicId: id,
            comicSource: source,
            useDeviceSettings: device,
            onChanged: () => onChanged?.call('readerNightModeIntensity'),
          ),
        ],
      ),
    );
  }
}
