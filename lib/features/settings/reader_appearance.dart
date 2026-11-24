import 'mobile_setting_row.dart';

import 'package:flutter/material.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/reader_appearance.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/translations.dart';

import 'setting_components.dart';
import 'setting_field.dart';

/// Shared placement for the full settings page and the reader's picture menu.
class ReaderAppearanceSettings extends StatelessWidget {
  const ReaderAppearanceSettings({
    super.key,
    this.comicId,
    this.sourceKey,
    this.useDeviceSettings = false,
    this.activeScope = false,
    this.compact = false,
    this.preview,
    this.onChanged,
  });
  final String? comicId, sourceKey;
  final bool useDeviceSettings, activeScope, compact;
  final ReaderColorPreview? preview;
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
    final draft = preview;
    Widget slider(
      String title,
      NumericPreference preference,
      ReaderColorAdjustment adjustment,
    ) {
      if (draft != null) {
        return _PictureColorSetting(
          key: ValueKey((comicId, sourceKey, adjustment, draft)),
          title: title,
          preference: preference,
          adjustment: adjustment,
          preview: draft,
          comicId: comicId,
          sourceKey: sourceKey,
          onChanged: () => onChanged?.call(preference.key),
        );
      }
      return SliderSetting.reader(
        title: title,
        preference: preference,
        valueFormatter: (value) => '${(value * 100).round()}%',
        comicId: id,
        comicSource: source,
        useDeviceSettings: device,
        onChanged: () => onChanged?.call(preference.key),
      );
    }

    return ListTileTheme.merge(
      dense: compact ? true : null,
      contentPadding: compact ? EdgeInsets.zero : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: settingGroup(context, [
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
          slider(
            'Line enhancement strength'.tl,
            ReaderPreferences.readerLineEnhancementStrength,
            ReaderColorAdjustment.lineStrength,
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
          slider(
            'Night mode intensity'.tl,
            ReaderPreferences.readerNightModeIntensity,
            ReaderColorAdjustment.nightIntensity,
          ),
        ]),
      ),
    );
  }
}

class _PictureColorSetting extends StatefulWidget {
  const _PictureColorSetting({
    super.key,
    required this.title,
    required this.preference,
    required this.adjustment,
    required this.preview,
    required this.comicId,
    required this.sourceKey,
    required this.onChanged,
  });

  final String title;
  final NumericPreference preference;
  final ReaderColorAdjustment adjustment;
  final ReaderColorPreview preview;
  final String? comicId, sourceKey;
  final VoidCallback onChanged;

  @override
  State<_PictureColorSetting> createState() => _PictureColorSettingState();
}

class _PictureColorSettingState
    extends SettingsSaveState<_PictureColorSetting> {
  final _fields = SettingFieldStore(
    readSettings: () => appdata.settings,
    updateSettings: (change) => appdata.updateSettings(change),
  );

  SettingField<num> get _field => SettingField(
    key: widget.preference.key,
    preference: widget.preference,
    comicId: widget.comicId,
    sourceKey: widget.sourceKey,
    scope: ReaderPreferenceScope.active,
  );

  late double _value = _fields.read(_field)!.toDouble();

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_read);
  }

  void _read() {
    final value = _fields.read(_field)!.toDouble();
    if (_value != value) setState(() => _value = value);
  }

  Future<void> _commit(double value) async {
    final target = _field;
    await saveSetting(
      (target.comicId, target.sourceKey, target.key, target.scope),
      () => _fields.save(target, value),
      onSaved: widget.onChanged,
      isCurrent: () => mounted && target.matches(_field),
    );
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_read);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => protectSettings(
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReaderPictureSlider(
          title: widget.title,
          min: widget.preference.min,
          max: widget.preference.max,
          divisions:
              ((widget.preference.max - widget.preference.min) /
                      widget.preference.step)
                  .round(),
          value: _value,
          format: (value) => '${(100 * value).round()}%',
          preview: (value) => acceptsSettingsChanges
              ? widget.preview.show(widget.adjustment, value)
              : () {},
          commit: _commit,
        ),
        if (hasSettingsSaveError)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: settingsSaveStatus,
          ),
      ],
    ),
  );
}
