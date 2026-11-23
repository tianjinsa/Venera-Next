import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:prism_ui/bar_item_presence.dart' as prism;
import 'package:prism_ui/button.dart' as prism;
import 'package:prism_ui/color.dart' as prism show ColorStyle;
import 'package:prism_ui/common_button.dart' as prism show IconButton;
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/l10n.dart' as prism;
import 'package:prism_ui/liquid_glass.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/scaffold.dart' as prism show AppBar;
import 'package:prism_ui/theme_data.dart' as prism;
import 'package:prism_ui/view_scope.dart' as prism;
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/translations.dart';

import 'tv_navigation.dart';

class MobileUi extends StatelessWidget {
  const MobileUi({super.key, required this.child});

  final Widget child;

  static bool enabledOf(BuildContext context) =>
      InheritedModel.inheritFrom<prism.ViewScope>(
        context,
        aspect: prism.ViewScopeAspect.isMobile,
      )?.isMobile ??
      false;

  @override
  Widget build(BuildContext context) {
    if (!(App.isAndroid || App.isIOS) || TvNavigation.enabledOf(context)) {
      return child;
    }
    return _MobileUiSettings(child: child);
  }
}

class _MobileUiSettings extends StatefulWidget {
  const _MobileUiSettings({required this.child});

  final Widget child;

  @override
  State<_MobileUiSettings> createState() => _MobileUiSettingsState();
}

class _MobileUiSettingsState extends State<_MobileUiSettings> {
  final _settings = appdata.settings;
  late var _glass = _readGlass();

  String _readGlass() =>
      GlobalPreferenceStore(_settings).read(AppearancePreferences.mobileGlass);

  @override
  void initState() {
    super.initState();
    _settings.addListener(_updateGlass);
  }

  void _updateGlass() {
    final glass = _readGlass();
    if (glass != _glass) setState(() => _glass = glass);
  }

  @override
  void dispose() {
    _settings.removeListener(_updateGlass);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MobileUiTheme(glass: _glass, child: widget.child);
}

/// Gives Prism controls the same color and brightness as the Material pages.
class MobileUiTheme extends StatelessWidget {
  const MobileUiTheme({super.key, required this.glass, required this.child});

  final String glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final compact = size.width <= changePoint;
    final enabled = compact && glass != 'off';
    return prism.ViewScope(
      size: size,
      isMobile: compact,
      child: prism.Theme(
        data: prism.ThemeData(
          colorScheme: prism.ColorScheme.fromSeed(
            seedColor: theme.colorScheme.primary,
            brightness: theme.brightness,
            style: prism.ColorStyle.soft,
          ),
          scaffoldBackgroundColor: theme.colorScheme.surface,
        ),
        child: prism.LiquidGlassScope(
          enabled: enabled,
          quality: glass == 'ultra'
              ? prism.LiquidGlassQuality.ultra
              : prism.LiquidGlassQuality.standard,
          child: prism.LiquidGlassHost(
            enabled: enabled,
            child: Overlay.wrap(child: child),
          ),
        ),
      ),
    );
  }
}

class MobileToolbar extends StatelessWidget {
  const MobileToolbar({
    super.key,
    required this.title,
    this.leading,
    this.shortcuts = const [],
    this.more,
    this.showBack = false,
    this.backgroundColor,
    this.height = 54,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> shortcuts;
  final Widget? more;
  final bool showBack;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final back =
        leading ??
        (showBack
            ? MobileToolbarButton(
                label: 'Back'.tl,
                icon: const prism.GlyphIcon(prism.Glyphs.chevronBack),
                onPressed: () => Navigator.maybePop(context),
              )
            : null);
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: prism.TonalButtonTheme(
        glass: prism.LiquidGlassScope.of(context),
        child: prism.AppBar(
          title: title,
          titleSpacing: back == null ? 16 : 0,
          toolbarHeight: height,
          clipBehavior: Clip.none,
          leading: back == null
              ? null
              : Center(child: prism.BarItemPresence(child: back)),
          actions: [
            if (shortcuts.isNotEmpty)
              prism.BarItemPresence(
                child: IconButtonTheme(
                  data: const IconButtonThemeData(
                    style: ButtonStyle(
                      overlayColor: WidgetStatePropertyAll(Colors.transparent),
                    ),
                  ),
                  child: prism.TonalButtonGroup(children: shortcuts),
                ),
              ),
            if (shortcuts.isNotEmpty && more != null) const SizedBox(width: 8),
            if (more != null) prism.BarItemPresence(child: more!),
            if (shortcuts.isNotEmpty || more != null) const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class MobileToolbarButton extends StatelessWidget {
  const MobileToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      prism.IconButton(tooltip: label, icon: icon, onPressed: onPressed);
}

class MobileMenuButton extends StatelessWidget {
  const MobileMenuButton({
    super.key,
    required this.items,
    this.label,
    this.icon = const prism.GlyphIcon(prism.Glyphs.more),
  });

  final List<prism.PopupMenuItem> items;
  final String? label;
  final Widget icon;

  @override
  Widget build(BuildContext context) => prism.PopupAnchor(
    targetBuilder: (open) => MobileToolbarButton(
      label: label ?? 'More'.tl,
      icon: icon,
      onPressed: open,
    ),
    popupBuilder: (_) => prism.PopupMenu(items: items),
  );
}

/// NavigationDock accepts glyphs. These match the five Venera destinations.
abstract final class MobileNavGlyphs {
  static const home = prism.Glyph([
    prism.GlyphPath(
      'M3.5 10.8 L12 3.5 20.5 10.8 V20.3 H15 V14 H9 V20.3 H3.5 Z',
    ),
  ]);
  static const favorites = prism.Glyph([
    prism.GlyphPath(
      'M12 20.3 L4.9 13.4 C-1 7.7 6.7 2 12 7.2 C17.3 2 25 7.7 19.1 13.4 Z',
    ),
  ]);
  static const agent = prism.Glyph([
    prism.GlyphPath(
      'M10 3 L12.2 9.8 19 12 12.2 14.2 10 21 7.8 14.2 1 12 7.8 9.8 Z',
    ),
    prism.GlyphPath(
      'M19 2 L20 5 23 6 20 7 19 10 18 7 15 6 18 5 Z',
      solid: true,
    ),
  ]);
  static const explore = prism.Glyph([
    prism.GlyphCircle(12, 12, 8.6, role: prism.GlyphRole.line),
    prism.GlyphPath('M16.3 7.7 L14 14 7.7 16.3 10 10 Z'),
  ]);
  static const categories = prism.Glyph([
    prism.GlyphBox(3.5, 3.5, 10.1, 10.1, 1.5),
    prism.GlyphBox(13.9, 3.5, 20.5, 10.1, 1.5),
    prism.GlyphBox(3.5, 13.9, 10.1, 20.5, 1.5),
    prism.GlyphBox(13.9, 13.9, 20.5, 20.5, 1.5),
  ]);
}

class MobileUiLocalizations extends prism.UiLocalizations {
  static const delegate = _MobileUiLocalizationsDelegate();

  @override
  String get back => 'Back'.tl;
  @override
  String get cancel => 'Cancel'.tl;
  @override
  String get clearSearch => 'Clear search'.tl;
  @override
  String get close => 'Close'.tl;
  @override
  String get copy => 'Copy'.tl;
  @override
  String get cut => 'Cut'.tl;
  @override
  String get dialog => 'Dialog'.tl;
  @override
  String get hidePassword => 'Hide password'.tl;
  @override
  String get more => 'More'.tl;
  @override
  String get noSearchResults => 'No results'.tl;
  @override
  String get paste => 'Paste'.tl;
  @override
  String get reset => 'Reset'.tl;
  @override
  String get select => 'Select'.tl;
  @override
  String get search => 'Search'.tl;
  @override
  String get selectAll => 'Select All'.tl;
  @override
  String get showLess => 'Show less'.tl;
  @override
  String get showMore => 'Show more'.tl;
  @override
  String get showPassword => 'Show password'.tl;
  @override
  String get sort => 'Sort'.tl;
  @override
  String get submit => 'Submit'.tl;
}

class _MobileUiLocalizationsDelegate
    extends LocalizationsDelegate<prism.UiLocalizations> {
  const _MobileUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<prism.UiLocalizations> load(Locale locale) =>
      SynchronousFuture(MobileUiLocalizations());

  @override
  bool shouldReload(_MobileUiLocalizationsDelegate old) => false;
}
