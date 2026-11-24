import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/slider.dart' as prism;
import 'package:venera_next/components/mobile_setting_row.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/foundation/translations.dart';

import 'brightness_policy.dart';

/// Presentation values live until their own save settles, independently of
/// the form that initiated them. The reader owns a shared instance for its
/// toolbar and settings sidebar; a later edit replaces only that field.
class ReaderBrightnessPreview extends ChangeNotifier {
  bool? _enabled;
  int? _brightness;
  bool? get enabled => _enabled;
  int? get brightness => _brightness;
  Object? _enabledToken, _brightnessToken;
  bool _disposed = false;

  VoidCallback previewEnabled(bool value) {
    final token = Object();
    if (_disposed) return () {};
    _enabledToken = token;
    _enabled = value;
    notifyListeners();
    return () {
      if (_disposed || !identical(_enabledToken, token)) return;
      _enabledToken = null;
      _enabled = null;
      notifyListeners();
    };
  }

  VoidCallback previewBrightness(int value) {
    final token = Object();
    if (_disposed) return () {};
    _brightnessToken = token;
    _brightness = normalizeReaderBrightness(value);
    notifyListeners();
    return () {
      if (_disposed || !identical(_brightnessToken, token)) return;
      _brightnessToken = null;
      _brightness = null;
      notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ReaderBrightnessOverlay extends StatelessWidget {
  const ReaderBrightnessOverlay({
    super.key,
    required this.enabled,
    required this.brightness,
  });

  final bool enabled;
  final Object? brightness;

  @override
  Widget build(BuildContext context) {
    final opacity = readerBrightnessOverlayOpacity(
      enabled: enabled,
      brightness: brightness,
    );
    if (opacity == 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: SizedBox.expand(
        child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
      ),
    );
  }
}

class ReaderBrightnessControl extends StatelessWidget {
  const ReaderBrightnessControl({
    super.key,
    required this.enabled,
    required this.brightness,
    required this.onEnabledChanged,
    required this.onBrightnessChanged,
    this.onBrightnessChangeEnd,
    this.previewBrightness,
    this.commitBrightness,
    this.compact = false,
    this.usePrism,
  });

  final bool enabled;
  final Object? brightness;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onBrightnessChanged;
  final ValueChanged<int>? onBrightnessChangeEnd;
  final VoidCallback Function(int)? previewBrightness;
  final Future<void> Function(int)? commitBrightness;
  final bool compact;
  final bool? usePrism;

  @override
  Widget build(BuildContext context) {
    final usePrism = this.usePrism ?? MobileUi.enabledOf(context);
    final normalizedBrightness = normalizeReaderBrightness(brightness);
    if (usePrism && MobileUi.enabledOf(context)) {
      final preview = previewBrightness;
      final commit = commitBrightness;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: settingGroup(context, [
          SettingSwitchRow(
            title: Text('Night dimming'.tl),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          if (enabled && preview != null && commit != null)
            ReaderPictureSlider(
              title: 'Reader brightness'.tl,
              min: readerBrightnessMin.toDouble(),
              max: readerBrightnessMax.toDouble(),
              divisions: (readerBrightnessMax - readerBrightnessMin) ~/ 5,
              value: normalizedBrightness.toDouble(),
              format: (value) => '${value.round()}%',
              preview: (value) => preview(value.round()),
              commit: (value) => commit(value.round()),
            )
          else if (enabled)
            SettingRow(
              title: Text('Reader brightness'.tl),
              trailing: Text('$normalizedBrightness%'),
              subtitle: prism.Slider(
                min: readerBrightnessMin.toDouble(),
                max: readerBrightnessMax.toDouble(),
                divisions: (readerBrightnessMax - readerBrightnessMin) ~/ 5,
                value: normalizedBrightness.toDouble(),
                onChanged: (value) => onBrightnessChanged(value.round()),
                onChangeEnd: (value) =>
                    onBrightnessChangeEnd?.call(value.round()),
              ),
            ),
        ]),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: compact ? EdgeInsets.zero : null,
          title: Text('Night dimming'.tl),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: enabled
              ? ListTile(
                  contentPadding: compact ? EdgeInsets.zero : null,
                  title: Text('Reader brightness'.tl),
                  trailing: Text('$normalizedBrightness%'),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.brightness_low, size: 20),
                      Expanded(
                        child: Slider(
                          min: readerBrightnessMin.toDouble(),
                          max: readerBrightnessMax.toDouble(),
                          divisions:
                              (readerBrightnessMax - readerBrightnessMin) ~/ 5,
                          value: normalizedBrightness.toDouble(),
                          onChanged: (value) {
                            onBrightnessChanged(value.round());
                          },
                          onChangeEnd: (value) {
                            onBrightnessChangeEnd?.call(value.round());
                          },
                        ),
                      ),
                      const Icon(Icons.brightness_high, size: 20),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A Prism slider whose samples only change the visual preview. The confirmed
/// edit keeps its preview until the owner finishes saving it.
class ReaderPictureSlider extends StatefulWidget {
  const ReaderPictureSlider({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.preview,
    required this.commit,
  });

  final String title;
  final double value, min, max;
  final int divisions;
  final String Function(double) format;
  final VoidCallback Function(double) preview;
  final Future<void> Function(double) commit;

  @override
  State<ReaderPictureSlider> createState() => _ReaderPictureSliderState();
}

class _ReaderPictureSliderState extends State<ReaderPictureSlider> {
  late final _value = ValueNotifier(widget.value);
  double? _draft;
  VoidCallback? _revert;
  int _edit = 0;
  int? _pointer;
  Offset _origin = Offset.zero;
  Axis? _direction;
  bool _finishingPointer = false;

  @override
  void didUpdateWidget(covariant ReaderPictureSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draft == null) _value.value = widget.value;
  }

  void _change(double value) {
    if (_direction == Axis.vertical || value == _value.value) return;
    _edit++;
    final previous = _revert;
    _draft = _value.value = value;
    _revert = widget.preview(value);
    previous?.call();
  }

  void _cancel() {
    _edit++;
    _draft = null;
    final release = _revert;
    _revert = null;
    release?.call();
    _value.value = widget.value;
  }

  Future<void> _save() async {
    final value = _draft;
    final release = _revert;
    if (value == null || release == null) return;
    final edit = _edit;
    // The accepted edit, not the live widget, owns this preview. Closing the
    // sheet must not release it while its scoped write is still pending.
    _revert = null;
    try {
      await widget.commit(value);
    } finally {
      release();
      if (mounted && _edit == edit) {
        _draft = null;
        _value.value = widget.value;
      }
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _origin = event.position;
    _direction = null;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _direction != null) return;
    final offset = event.position - _origin;
    if (offset.dx.abs() <= kTouchSlop && offset.dy.abs() <= kTouchSlop) return;
    _direction = offset.dy.abs() > offset.dx.abs()
        ? Axis.vertical
        : Axis.horizontal;
    if (_direction == Axis.vertical && _revert != null) _cancel();
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _finishingPointer = true;
    // A real tap can emit its last sample during this same pointer dispatch.
    scheduleMicrotask(() {
      _finishingPointer = false;
      if (!mounted) return;
      if (_direction != Axis.vertical) unawaited(_save());
      _direction = null;
    });
  }

  void _pointerCancelled(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _direction = Axis.vertical; // Ignore Prism's cancel-time end notification.
    if (_revert != null) _cancel();
    scheduleMicrotask(() => _direction = null);
  }

  @override
  void dispose() {
    final release = _revert;
    if (release != null) scheduleMicrotask(release);
    _value.dispose();
    super.dispose();
  }

  Widget _readout(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    double width(double value) => TextPainter.computeMaxIntrinsicWidth(
      text: TextSpan(text: widget.format(value), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    // ListRow measures the trailing slot to lay out its slider below the
    // title. Keep the track from moving when 95% becomes 100% mid-gesture.
    return SizedBox(
      width: math.max(width(widget.min), width(widget.max)).ceilToDouble(),
      child: ValueListenableBuilder(
        valueListenable: _value,
        builder: (_, value, _) =>
            Text(widget.format(value), style: style, textAlign: TextAlign.end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingRow(
    title: Text(widget.title, softWrap: true, maxLines: 2),
    trailing: Builder(builder: _readout),
    subtitle: Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _pointerCancelled,
      child: ValueListenableBuilder(
        valueListenable: _value,
        builder: (_, value, _) => prism.Slider(
          value: value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          onChanged: _change,
          // Drag and tap cancellation also call Prism's onChangeEnd. Only
          // accept settled pointer input, and retain keyboard/semantics edits.
          onChangeEnd: (_) {
            if (_pointer == null && !_finishingPointer && _direction == null) {
              unawaited(_save());
            }
          },
        ),
      ),
    ),
  );
}

/// Compact settings panel; persistence and preference scope belong to its host.
class ReaderBrightnessPanel extends StatelessWidget {
  const ReaderBrightnessPanel({
    super.key,
    required this.enabled,
    required this.brightness,
    required this.onEnabledChanged,
    required this.onBrightnessChanged,
    this.onBrightnessChangeEnd,
    this.previewBrightness,
    this.commitBrightness,
    this.status,
    this.additionalSettings,
    this.usePrism,
  });
  final bool enabled;
  final Object? brightness;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onBrightnessChanged;
  final ValueChanged<int>? onBrightnessChangeEnd;
  final VoidCallback Function(int)? previewBrightness;
  final Future<void> Function(int)? commitBrightness;
  final Widget? status;
  final Widget? additionalSettings;
  final bool? usePrism;
  @override
  Widget build(BuildContext context) {
    final usePrism = this.usePrism ?? MobileUi.enabledOf(context);
    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReaderBrightnessControl(
          compact: true,
          usePrism: usePrism,
          enabled: enabled,
          brightness: brightness,
          onEnabledChanged: onEnabledChanged,
          onBrightnessChanged: onBrightnessChanged,
          onBrightnessChangeEnd: onBrightnessChangeEnd,
          previewBrightness: previewBrightness,
          commitBrightness: commitBrightness,
        ),
        ?additionalSettings,
        ?status,
      ],
    );
    if (usePrism) {
      // Consume the sheet's scroll controller. Dragging a long form hands
      // off to the same gesture owner, not a fixed-height nested card.
      return ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Adjust picture'.tl,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          controls,
        ],
      );
    }
    final panelWidth =
        (MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).left -
                MediaQuery.paddingOf(context).right -
                32)
            .clamp(0.0, 360.0);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: panelWidth,
        maxHeight:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    160)
                .clamp(100.0, double.infinity),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          width: panelWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: controls,
          ),
        ),
      ),
    );
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
