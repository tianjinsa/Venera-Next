import 'dart:async';

import 'package:flutter/material.dart'
    as material
    show ElevationOverlay, Material, MaterialType, Theme;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/card.dart' as prism;
import 'package:prism_ui/common_button.dart' as prism;
import 'package:prism_ui/context.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/list_row.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/search_field.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/foundation/translations.dart';

import 'mobile_large_sheet.dart';
import 'mobile_ui.dart';

/// A stable value separate from its translated display label.
class MobileChoiceOption<T extends Object> {
  const MobileChoiceOption(
    this.value,
    this.label, {
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
}

/// A controlled selector. A short list morphs out of its value button; a
/// longer or explicitly searchable list opens a scrollable Prism sheet.
class MobileChoice<T extends Object> extends StatefulWidget {
  const MobileChoice({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.label,
    this.placeholder,
    this.searchable = false,
    this.setting = false,
    this.minWidth = 64,
  });

  static const menuLimit = 6;

  final List<MobileChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? placeholder;
  final bool searchable;

  /// Setting fields stay anchored to their value, irrespective of list size.
  /// Business pickers can still opt into the searchable sheet.
  final bool setting;
  final double minWidth;

  @override
  State<MobileChoice<T>> createState() => _MobileChoiceState<T>();
}

class _MobileChoiceState<T extends Object> extends State<MobileChoice<T>> {
  bool _sheetOpen = false;

  void _select(T choice, ValueChanged<T> changed) {
    if (!mounted ||
        widget.onChanged == null ||
        !NavigationAdmission.allows(context)) {
      return;
    }
    if (widget.options.any(
      (option) => option.enabled && option.value == choice,
    )) {
      changed(choice);
    }
  }

  Future<void> _showSheet() async {
    if (_sheetOpen || !NavigationAdmission.allows(context)) return;
    final changed = widget.onChanged;
    if (changed == null) return;
    final options = widget.options;
    final value = widget.value;
    final label = widget.label ?? 'Select'.tl;
    final searchable =
        widget.searchable || options.length >= prism.sheetSearchMinItemCount;
    _sheetOpen = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final selected = await showMobileLargeSheet<T>(
        context: context,
        builder: (_) => _ChoiceSheet<T>(
          label: label,
          options: options,
          value: value,
          searchable: searchable,
        ),
      );
      if (selected != null) _select(selected, changed);
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.options
        .where((option) => option.value == widget.value)
        .firstOrNull;
    final text = value?.label ?? widget.placeholder ?? 'Select'.tl;
    final changed = widget.onChanged;
    Widget target(VoidCallback? onPressed) => Semantics(
      label: widget.label,
      child: MobileChoiceButton(
        value: text,
        setting: widget.setting,
        minWidth: widget.minWidth,
        onPressed: onPressed,
      ),
    );

    if (changed == null || !widget.options.any((option) => option.enabled)) {
      return target(null);
    }
    if (!widget.setting &&
        (widget.searchable || widget.options.length > MobileChoice.menuLimit)) {
      return target(() => unawaited(_showSheet()));
    }
    return MobilePopupAnchor(
      targetBuilder: target,
      fallbackSourceColor: widget.setting ? _plainSettingSurface : null,
      placement: Directionality.of(context) == TextDirection.rtl
          ? prism.PopupPlacement.overAnchorStart
          : prism.PopupPlacement.overAnchorEnd,
      maxVisibleItems: widget.setting ? 7 : null,
      items: [
        for (final option in widget.options)
          prism.PopupMenuItem(
            label: option.label,
            subtitle: option.subtitle,
            checked: option.value == widget.value,
            // Keep the handler that offered this item, not a newer callback
            // that may belong to a different settings target.
            onPressed: option.enabled
                ? () => _select(option.value, changed)
                : null,
          ),
      ],
    );
  }

  /// Ungrouped settings forms put their transparent value on the page's
  /// Material, not the dark SettingRow surface. Take that actual page color
  /// (including elevation tint) only when there is no explicit source scope.
  static Color? _plainSettingSurface(BuildContext context) {
    Color? result;
    context.visitAncestorElements((element) {
      final surface = element.widget;
      if (surface is! material.Material ||
          surface.type == material.MaterialType.transparency) {
        return true;
      }
      final theme = material.Theme.of(element);
      final color =
          surface.color ??
          switch (surface.type) {
            material.MaterialType.canvas => theme.canvasColor,
            material.MaterialType.card => theme.cardColor,
            _ => null,
          };
      if (color == null || color.a == 0) return true;
      final painted = theme.useMaterial3
          ? material.ElevationOverlay.applySurfaceTint(
              color,
              surface.surfaceTintColor,
              surface.elevation,
            )
          : material.ElevationOverlay.applyOverlay(
              element,
              color,
              surface.elevation,
            );
      result = result == null ? painted : Color.alphaBlend(result!, painted);
      return result!.a < 1;
    });
    return result?.a == 1 ? result : null;
  }
}

/// Same trigger surface for specialized, application-owned picker content.
class MobileChoiceButton extends StatelessWidget {
  const MobileChoiceButton({
    super.key,
    required this.value,
    this.minWidth = 64,
    this.setting = false,
    this.onPressed,
  });

  final String value;
  final bool setting;
  final double minWidth;
  final VoidCallback? onPressed;

  Widget _valueText(
    BuildContext context, {
    required AlignmentDirectional alignment,
  }) {
    // The pinned Prism animates via AnimatedSize even at duration zero.
    // In Flutter 3.47 a changed label can then re-dirty itself during layout.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Align(
        alignment: alignment,
        widthFactor: 1,
        heightFactor: 1,
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return prism.PopupValueText(value, alignment: alignment);
  }

  @override
  Widget build(BuildContext context) {
    MobileChoiceTapLink.bind(context, onPressed);
    if (!setting) {
      return prism.OutlinedButton(
        key: ValueKey(onPressed != null),
        onPressed: onPressed,
        style: prism.ButtonStyle.from(
          minimumSize: Size(minWidth, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Flexible(
              child: _valueText(
                context,
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            const prism.GlyphIcon(prism.Glyphs.picker, size: 16),
          ],
        ),
      );
    }
    return prism.TextButton(
      key: ValueKey(onPressed != null),
      onPressed: onPressed,
      style: prism.ButtonStyle.from(
        foregroundColor: prism.Theme.of(context).colorScheme.onSurfaceVariant,
        textStyle: prism.BuildContextExtension(context).listTitleStyle,
        minimumSize: Size(minWidth, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: _valueText(
                context,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ),
          const prism.GlyphIcon(prism.Glyphs.picker),
        ],
      ),
    );
  }
}

/// A row press uses the very same anchor as its value. No extra navigator,
/// no hidden button and no mutation of the selected value on dismissal.
class MobileChoiceTapLink {
  VoidCallback? _open;
  void open() => _open?.call();

  Widget wrap(Widget child) => _ChoiceTapScope(link: this, child: child);

  static void bind(BuildContext context, VoidCallback? open) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ChoiceTapScope>();
    scope?.link._open = open;
  }
}

class _ChoiceTapScope extends InheritedWidget {
  const _ChoiceTapScope({required this.link, required super.child});
  final MobileChoiceTapLink link;
  @override
  bool updateShouldNotify(_ChoiceTapScope old) => link != old.link;
}

/// A choice stays at the reading end, even on small handsets. Both columns
/// may shrink, but neither is allowed to displace the other onto a new row.
/// Do not measure text speculatively: use the actual parent's width, direction
/// and text scaler. In particular, dialogs can still request intrinsics.
class MobileChoiceRow extends StatelessWidget {
  const MobileChoiceRow({
    super.key,
    required this.title,
    required this.choice,
    this.description,
  });

  final Widget title, choice;
  final Widget? description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: title),
          const SizedBox(width: 10),
          Flexible(child: choice),
        ],
      ),
      if (description != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: description!),
    ],
  );
}

/// A regular Flutter [FormField] contract on a Prism trigger. Presentation
/// never writes settings: callers still own changing, saving and validation.
class MobileChoiceFormField<T extends Object> extends FormField<T> {
  MobileChoiceFormField({
    super.key,
    required List<MobileChoiceOption<T>> options,
    required String label,
    super.initialValue,
    ValueChanged<T>? onChanged,
    String? placeholder,
    bool searchable = false,
    bool enabled = true,
    FormFieldValidator<T>? validator,
    super.onSaved,
    super.onReset,
    super.autovalidateMode,
  }) : super(
         enabled: enabled && onChanged != null,
         validator: enabled && onChanged != null ? validator : null,
         builder: (field) {
           final choice = MobileChoice<T>(
             options: options,
             setting: !searchable,
             value: field.value,
             label: label.isEmpty ? null : label,
             placeholder: placeholder,
             searchable: searchable,
             onChanged: !enabled || onChanged == null
                 ? null
                 : (value) {
                     field.didChange(value);
                     onChanged(value);
                   },
           );
           final link = MobileChoiceTapLink();
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             mainAxisSize: MainAxisSize.min,
             children: [
               if (label.isEmpty)
                 choice
               else
                 link.wrap(
                   GestureDetector(
                     behavior: HitTestBehavior.opaque,
                     excludeFromSemantics: true,
                     onTap: field.widget.enabled ? link.open : null,
                     child: MobileChoiceRow(
                       title: ExcludeSemantics(
                         child: Text(
                           label,
                           style: prism.BuildContextExtension(field.context)
                               .listTitleStyle,
                         ),
                       ),
                       choice: choice,
                     ),
                   ),
                 ),
               if (field.errorText case final error?)
                 Padding(
                   padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 0),
                   child: Semantics(
                     liveRegion: true,
                     child: Text(
                       error,
                       style: TextStyle(
                         color: prism.Theme.of(field.context).colorScheme.error,
                       ),
                     ),
                   ),
                 ),
             ],
           );
         },
       );

  @override
  FormFieldState<T> createState() => _MobileChoiceFormFieldState<T>();
}

class _MobileChoiceFormFieldState<T extends Object> extends FormFieldState<T> {
  @override
  void didUpdateWidget(covariant MobileChoiceFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      // A caller can also update the choice (e.g. mode follows the keyword).
      // External synchronization is not user interaction or another write.
      setValue(widget.initialValue);
    }
  }
}

class _ChoiceSheet<T extends Object> extends StatefulWidget {
  const _ChoiceSheet({
    required this.label,
    required this.options,
    required this.value,
    required this.searchable,
  });

  final String label;
  final List<MobileChoiceOption<T>> options;
  final T? value;
  final bool searchable;

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T extends Object> extends State<_ChoiceSheet<T>> {
  String _query = '';
  bool _committed = false;

  void _close([T? value]) {
    if (_committed || ModalRoute.of(context)?.isCurrent != true) return;
    _committed = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final options = _query.isEmpty
        ? widget.options
        : widget.options
              .where(
                (option) =>
                    option.label.toLowerCase().contains(_query) ||
                    (option.subtitle?.toLowerCase().contains(_query) ?? false),
              )
              .toList(growable: false);
    return MobileChoiceSheetFrame(
      title: widget.label,
      onClose: _close,
      header: widget.searchable
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: prism.SearchField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            )
          : null,
      child: options.isEmpty
          ? Center(child: Text('No results'.tl))
          : ListView.builder(
              primary: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return Semantics(
                  enabled: option.enabled,
                  selected: widget.value == option.value,
                  child: prism.Card(
                    key: ValueKey(option.value),
                    onPressed: option.enabled
                        ? () => _close(option.value)
                        : null,
                    child: Opacity(
                      opacity: option.enabled ? 1 : 0.38,
                      child: prism.ListRow(
                        title: Text(option.label),
                        subtitle: option.subtitle == null
                            ? null
                            : Text(option.subtitle!),
                        trailing: widget.value == option.value
                            ? const prism.GlyphIcon(prism.Glyphs.check)
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Content frame for Prism picker sheets. Keeps the body on Prism's primary
/// scroll controller so a pull from the top continues into sheet dismissal.
class MobileChoiceSheetFrame extends StatelessWidget {
  const MobileChoiceSheetFrame({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.header,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              MobileToolbarButton(
                label: 'Close'.tl,
                icon: const prism.GlyphIcon(prism.Glyphs.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        ?header,
        Expanded(child: child),
      ],
    ),
  );
}
