import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/shape.dart' as prism;
import 'package:prism_ui/text_field.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism show ColorScheme;
import 'package:venera_next/foundation/translations.dart';

import 'mobile_search_route.dart';
import 'mobile_ui.dart';

/// FlClash's search glyph, pill, clear and submit interaction. Use Prism's
/// underlying TextField rather than its SearchField wrapper: that wrapper's
/// hard 256-character formatter would truncate pasted source URLs and queries.
class MobileGlobalSearchBar extends StatelessWidget {
  const MobileGlobalSearchBar({
    super.key,
    required this.editing,
    required this.topPadding,
    required this.onSubmit,
    this.onSubmitFrom,
    this.onChanged,
    this.focusNode,
    this.action,
  });

  final TextEditingController editing;
  final double topPadding;
  final ValueChanged<String>? onSubmit;

  /// Use the visible caret, or the center of the field if it cannot be
  /// measured, when submission opens a separate full-page route.
  final void Function(String, BuildContext)? onSubmitFrom;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final border = prism.AppShape.input.copyWith(
      borderRadius: prism.AppRadius.full,
      borderSide: BorderSide.none,
    );
    final glass = prism.LiquidGlassScope.of(context);
    Widget field(ValueChanged<String>? submit) {
      final input = prism.TextField(
        controller: editing,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        onChanged: onChanged,
        onSubmitted: submit,
        decoration: prism.InputDecoration(
          hintText: 'Search'.tl,
          contentPadding: EdgeInsets.zero,
          border: border,
          focusedBorder: border,
          enabledBorder: border,
          prefixIcon: const prism.GlyphIcon(prism.Glyphs.search, size: 20),
          prefixIconConstraints: const BoxConstraints.tightFor(width: 40),
          suffixIconConstraints: const BoxConstraints(),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: editing,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 12)
                : MobileToolbarButton(
                    label: MaterialLocalizations.of(context).clearButtonTooltip,
                    icon: const prism.GlyphIcon(
                      prism.Glyphs.clearField,
                      size: 20,
                    ),
                    onPressed: () {
                      editing.clear();
                      onChanged?.call('');
                    },
                  ),
          ),
        ),
      );
      return glass
          ? prism.LiquidGlass(
              style: prism.LiquidGlassStyle.pill(prism.ColorScheme.of(context)),
              child: input,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: prism.AppRadius.full,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: input,
            );
    }

    final anchoredSubmit = onSubmitFrom;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, topPadding, 8, 0),
        child: SizedBox(
          height: 52,
          child: Row(
            spacing: 8,
            children: [
              MobileToolbarButton(
                label: 'Back'.tl,
                icon: const prism.GlyphIcon(prism.Glyphs.chevronBack),
                onPressed: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('mobile-global-search-field'),
                  height: 46,
                  child: anchoredSubmit == null
                      ? field(onSubmit)
                      : MobileSearchAnchor(
                          keyboardOrigin: (origin) =>
                              _visibleCaret(origin, editing.selection),
                          builder: (origin) =>
                              field((value) => anchoredSubmit(value, origin)),
                        ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

/// Read only the editor's geometry and selection endpoint, never its text.
/// A synchronous submit can run before a resized, collapsed or offscreen
/// editor has reliable bounds: let the route use the field's center then.
Offset? _visibleCaret(BuildContext field, TextSelection selection) {
  if (!selection.isValid) return null;
  RenderEditable? found;
  void visit(Element node) {
    if (found != null) return;
    if (node case StatefulElement(state: final EditableTextState editor)) {
      found = editor.renderEditable;
    } else {
      node.visitChildElements(visit);
    }
  }

  field.visitChildElements(visit);
  final editor = found;
  if (editor == null || !editor.attached || !editor.hasSize) return null;
  final caret = editor.getLocalRectForCaret(selection.extent).center;
  if (!caret.isFinite ||
      !(Offset.zero & editor.size).inflate(1).contains(caret)) {
    return null;
  }
  return editor.localToGlobal(caret);
}
