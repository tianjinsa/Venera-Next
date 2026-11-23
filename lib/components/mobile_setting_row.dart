import 'package:flutter/material.dart';
import 'package:prism_ui/context.dart' as prism;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/inherited.dart' as prism;
import 'package:prism_ui/item_position.dart' as prism;
import 'package:prism_ui/list.dart' as prism;
import 'package:prism_ui/metrics.dart' as prism;
import 'package:prism_ui/typography.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:prism_ui/surface.dart' as prism;
import 'package:venera_next/components/mobile_content_surface.dart';
import 'package:venera_next/components/mobile_choice.dart';
import 'package:prism_ui/switch.dart' as prism show Switch;
import 'package:venera_next/components/mobile_ui.dart';

/// A settings cell, not a new persistence layer. Leave focus, validation,
/// long-running saves, and per-comic scope with the existing field owner.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding,
  });
  final Widget title;
  final Widget? leading, subtitle, trailing;
  final bool enabled;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!MobileUi.enabledOf(context)) {
      return ListTile(
        title: title,
        leading: leading,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        enabled: enabled,
        contentPadding: contentPadding,
      );
    }
    final position = prism.ItemPositionProvider.of(context)?.position;
    final row = prism.DecorationListItem(
      title: title,
      leading: leading,
      subtitle: subtitle,
      trailing: trailing,
      contentPadding: EdgeInsetsDirectional.only(
        start: prism.ListInsets.of(context).leading,
        end: trailing == null ? prism.ListInsets.of(context).leading : 8,
      ),
      onPressed: enabled ? onTap : null,
    );
    // Only this row's paint gets the content tone. The popup is pushed onto
    // the surrounding navigator; its floating material and accent stay intact.
    final theme = prism.Theme.of(context);
    final fill = MobileContentPalette.fill(context);
    final surface = prism.SurfaceScope(
      level: prism.SurfaceLevel.page,
      child: prism.Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            surfaceContainer: fill,
            surfaceBright: fill,
          ),
        ),
        child: row,
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: prism.ListInsets.of(context).margin,
        vertical: position == null ? 4 : 0,
      ),
      child: position == null
          ? prism.ItemPositionProvider(
              position: prism.ItemPosition.startAndEnd,
              child: surface,
            )
          : surface,
    );
  }
}

/// Shape and hairline come from the same Prism group positions FlClash uses.
/// Preserve each child's state, asynchronous save wrapper, and (for slivers)
/// the original scroll/visibility behavior. Desktop gets the original list.
List<Widget> settingGroup(
  BuildContext context,
  List<Widget> rows, {
  bool Function(Widget)? isVisible,
}) {
  if (!MobileUi.enabledOf(context)) return rows;
  bool visible(Widget row) => isVisible?.call(row) ?? true;
  final count = rows.where(visible).length;
  var index = 0;
  return [
    for (final row in rows)
      prism.ItemPositionProvider(
        // Keep the keyed field itself unique (including GlobalKeys); use a
        // distinct local key to move its wrapper along with it on reorder.
        key: row.key == null ? null : ValueKey<Key>(row.key!),
        position: visible(row)
            ? prism.ItemPosition.get(index++, count)
            : prism.ItemPosition.middle,
        child: row,
      ),
  ];
}

Widget settingSectionGap(BuildContext context) => SliverToBoxAdapter(
  child: MobileUi.enabledOf(context)
      ? const prism.ListSectionGap()
      : const SizedBox.shrink(),
);

class SettingChoiceRow extends StatelessWidget {
  const SettingChoiceRow({
    super.key,
    required this.title,
    required this.choice,
    this.subtitle,
    this.enabled = true,
  });
  final Widget title, choice;
  final Widget? subtitle;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final link = MobileChoiceTapLink();
    return link.wrap(
      SettingRow(
        title: title,
        subtitle: subtitle,
        trailing: choice,
        enabled: enabled,
        onTap: enabled ? link.open : null,
      ),
    );
  }
}

class SettingDisclosure extends StatelessWidget {
  const SettingDisclosure({super.key});
  @override
  Widget build(BuildContext context) => MobileUi.enabledOf(context)
      ? const prism.GlyphIcon(prism.Glyphs.chevronForward)
      : const Icon(Icons.arrow_right);
}

/// Prism ListHeader's no-actions layout without requiring its application-wide
/// MeasureScope (Venera's router and text scaling are application-owned).
class SettingSectionLabel extends StatelessWidget {
  const SettingSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final insets = prism.ListInsets.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: insets.margin) +
            prism.listHeaderPaddingOf(context),
        child: Text(
          text,
          style: prism.AppTextStyle.headline
              .of(context)
              .copyWith(
                color: prism.BuildContextExtension(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class SettingFootnote extends StatelessWidget {
  const SettingFootnote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: prism.ListInsets.of(context).margin,
    ),
    child: prism.ListFooter(text: text, last: true),
  );
}

/// The whole row toggles once; the real Prism switch still owns its drag.
/// TalkBack/VoiceOver get a single labeled switch rather than two actions.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
  });
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!MobileUi.enabledOf(context)) {
      return SwitchListTile(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        contentPadding: contentPadding,
      );
    }
    final update = onChanged;
    return MergeSemantics(
      child: SettingRow(
        title: title,
        subtitle: subtitle,
        enabled: update != null,
        onTap: update == null ? null : () => update(!value),
        trailing: prism.Switch(value: value, onChanged: update),
      ),
    );
  }
}

class SettingInlineSwitch extends StatelessWidget {
  const SettingInlineSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) => MobileUi.enabledOf(context)
      ? prism.Switch(value: value, onChanged: onChanged, semanticLabel: label)
      : Switch(value: value, onChanged: onChanged);
}
