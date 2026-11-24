import 'reader_appearance.dart';

import 'package:flutter/material.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/reader/reader_appearance.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';

import 'setting_field.dart';

class ReaderBrightnessSetting extends StatefulWidget {
  const ReaderBrightnessSetting({
    super.key,
    this.comicId,
    this.sourceKey,
    this.preview,
    this.colorPreview,
    this.panel = false,
    this.onChanged,
    this.usePrism,
  });
  final String? comicId, sourceKey;
  final ReaderBrightnessPreview? preview;
  final ReaderColorPreview? colorPreview;
  final bool panel;
  final bool? usePrism;
  final ValueChanged<String>? onChanged;

  @override
  State<ReaderBrightnessSetting> createState() =>
      _ReaderBrightnessSettingState();
}

class _ReaderBrightnessSettingState
    extends SettingsSaveState<ReaderBrightnessSetting> {
  final _fields = SettingFieldStore(
    readSettings: () => appdata.settings,
    updateSettings: (change) => appdata.updateSettings(change),
  );

  SettingField<T> _field<T extends Object>(Preference<T> preference) =>
      SettingField(
        key: preference.key,
        preference: preference,
        comicId: widget.comicId,
        sourceKey: widget.sourceKey,
        scope: ReaderPreferenceScope.active,
      );

  var _localPreview = ReaderBrightnessPreview();
  ReaderBrightnessPreview? _observedPreview;
  ReaderBrightnessPreview get _preview => widget.preview ?? _localPreview;
  bool? _presentedEnabled;
  bool _savedEnabled = false;
  bool _deferBrightness = false;

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _previewChanged() {
    // The slider owns its thumb and number. Only the switch can change the
    // sheet's rows; transient brightness belongs to the reader overlay.
    if (_deferBrightness &&
        _presentedEnabled == (_preview.enabled ?? _savedEnabled)) {
      return;
    }
    _refresh();
  }

  void _bindPreview() {
    if (identical(_observedPreview, _preview)) return;
    _observedPreview?.removeListener(_previewChanged);
    _observedPreview = _preview..addListener(_previewChanged);
  }

  @override
  void initState() {
    super.initState();
    _bindPreview();
    appdata.settings.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ReaderBrightnessSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comicId != widget.comicId ||
        oldWidget.sourceKey != widget.sourceKey) {
      _localPreview.dispose();
      _localPreview = ReaderBrightnessPreview();
    }
    _bindPreview();
  }

  Future<void> _save<T extends Object>(
    Preference<T> preference,
    T value, [
    VoidCallback? release,
  ]) async {
    final comic = widget.comicId, source = widget.sourceKey;
    final field = _field(preference);
    try {
      await saveSetting(
        (comic, source, preference.key),
        () => _fields.save(field, value),
        onSaved: () => widget.onChanged?.call(preference.key),
        isCurrent: () => comic == widget.comicId && source == widget.sourceKey,
      );
    } finally {
      release?.call();
    }
  }

  void _enabled(bool value) {
    if (!acceptsSettingsChanges) return;
    _save(
      ReaderPreferences.readerBrightnessEnabled,
      value,
      _preview.previewEnabled(value),
    );
  }

  void _brightness(int value) {
    if (!acceptsSettingsChanges) return;
    _save<num>(
      ReaderPreferences.readerBrightness,
      value,
      _preview.previewBrightness(value),
    );
  }

  VoidCallback _draftBrightness(int value) =>
      acceptsSettingsChanges ? _preview.previewBrightness(value) : () {};

  Future<void> _commitBrightness(int value) =>
      _save<num>(ReaderPreferences.readerBrightness, value);

  @override
  Widget build(BuildContext context) {
    _deferBrightness =
        widget.panel && widget.usePrism == true && MobileUi.enabledOf(context);
    _savedEnabled = _fields.read(
      _field(ReaderPreferences.readerBrightnessEnabled),
    )!;
    final enabled = _presentedEnabled = _preview.enabled ?? _savedEnabled;
    final brightness =
        (_deferBrightness ? null : _preview.brightness) ??
        _fields.read<num>(_field(ReaderPreferences.readerBrightness))!;
    return protectSettings(
      widget.panel
          ? ReaderBrightnessPanel(
              usePrism: widget.usePrism,
              enabled: enabled,
              brightness: brightness,
              onEnabledChanged: _enabled,
              onBrightnessChanged: _brightness,
              previewBrightness: _deferBrightness ? _draftBrightness : null,
              commitBrightness: _deferBrightness ? _commitBrightness : null,
              status: hasSettingsSaveError ? settingsSaveStatus : null,
              additionalSettings: ReaderAppearanceSettings(
                comicId: widget.comicId,
                sourceKey: widget.sourceKey,
                activeScope: true,
                compact: true,
                preview: _deferBrightness ? widget.colorPreview : null,
                onChanged: widget.onChanged,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReaderBrightnessControl(
                  enabled: enabled,
                  brightness: brightness,
                  onEnabledChanged: _enabled,
                  onBrightnessChanged: _brightness,
                ),
                if (hasSettingsSaveError) settingsSaveStatus,
              ],
            ),
    );
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    _observedPreview?.removeListener(_previewChanged);
    _localPreview.dispose();
    super.dispose();
  }
}
