import 'mobile_setting_row.dart';

import 'dart:ui' show ImageFilter;

import 'package:venera_next/foundation/application_preferences.dart';
import 'package:flutter/material.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/settings/setting_components.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Appearance".tl)),
        ...settingGroup(context, [
          SelectSetting.preference(
            title: "Theme Mode".tl,
            preference: AppearancePreferences.themeMode,
            optionTranslation: {
              "system": "System".tl,
              "light": "Light".tl,
              "dark": "Dark".tl,
            },
            onChanged: () async {
              appNavigation.forceRebuild();
            },
          ).toSliver(),
          SelectSetting.preference(
            title: "Theme Color".tl,
            preference: AppearancePreferences.color,
            optionTranslation: {
              "system": "System".tl,
              "red": "Red".tl,
              "pink": "Pink".tl,
              "purple": "Purple".tl,
              "green": "Green".tl,
              "orange": "Orange".tl,
              "blue": "Blue".tl,
            },
            onChanged: () async {
              await App.init();
              appNavigation.forceRebuild();
            },
          ).toSliver(),
          if (MobileUi.enabledOf(context))
            SelectSetting.preference(
              title: 'Glass effect'.tl,
              preference: AppearancePreferences.mobileGlass,
              stacked: true,
              optionTranslation: {
                'off': 'Off'.tl,
                'standard': 'Standard glass'.tl,
                'ultra': 'Ultra glass'.tl,
              },
              selectorBuilder: (context, value, select) => _GlassSelector(
                value: value ?? AppearancePreferences.mobileGlass.defaultValue,
                select: select!,
              ),
            ).toSliver(),
        ]),
      ],
    );
  }
}

class _GlassSelector extends StatelessWidget {
  const _GlassSelector({required this.value, required this.select});

  final String value;
  final ValueChanged<String> select;

  @override
  Widget build(BuildContext context) {
    final fallback = value != 'off' && !ImageFilter.isShaderFilterSupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: prism.SegmentedControl(
            segments: [
              ('off', 'Off'.tl),
              ('standard', 'Standard glass'.tl),
              ('ultra', 'Ultra glass'.tl),
            ],
            value: value,
            onChanged: select,
          ),
        ),
        if (fallback) Text('Using frosted glass on this renderer.'.tl),
      ],
    );
  }
}
