import 'package:flutter/material.dart';
import 'package:prism_ui/card.dart' as prism show Card;
import 'package:prism_ui/list_row.dart' as prism show ListRow;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: prism.Card(
        inert: enabled && onTap == null,
        onPressed: enabled ? onTap : null,
        child: prism.ListRow(
          title: title,
          leading: leading,
          subtitle: subtitle,
          trailing: trailing,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
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
