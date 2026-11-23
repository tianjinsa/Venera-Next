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
import 'package:prism_ui/scaffold.dart'
    as prism
    show AppBar, appBarLeadingWidth, isCompactBar;
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

  /// Direct commands in display order, paired into independent capsules.
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            const edge = 16.0;
            final spacing = back == null ? edge : 0.0;
            final leadingWidth = back == null
                ? 0.0
                : prism.appBarLeadingWidth(
                    context,
                    prism.isCompactBar(context, MobileUi.enabledOf(context)),
                  );
            // On narrow or inset-heavy screens, scroll the strip rather than
            // let a large contextual selection displace Back or clip actions.
            final actionWidth =
                (constraints.maxWidth -
                        MediaQuery.paddingOf(context).horizontal -
                        leadingWidth -
                        2 * spacing -
                        edge)
                    .clamp(0.0, double.infinity)
                    .toDouble();
            return prism.AppBar(
              title: title,
              titleSpacing: spacing,
              toolbarHeight: height,
              clipBehavior: Clip.none,
              leading: back == null
                  ? null
                  : Center(child: prism.BarItemPresence(child: back)),
              actions: [
                if (shortcuts.isNotEmpty || more != null) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: actionWidth),
                    child: MobileToolbarActions(
                      shortcuts: shortcuts,
                      more: more,
                      scrollable: true,
                    ),
                  ),
                  const SizedBox(width: edge),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ordered direct actions for one side of a toolbar. Each pair owns its
/// own Prism lens and press animation. An unpaired action and [more] each
/// stand alone; no action is dropped or converted to a menu item implicitly.
class MobileToolbarActions extends StatelessWidget {
  const MobileToolbarActions({
    super.key,
    required this.shortcuts,
    this.more,
    this.scrollable = false,
  });

  static const gap = 8.0;
  static const _groupSize = 2;

  final List<Widget> shortcuts;
  final Widget? more;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final direct = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        for (var i = 0; i < shortcuts.length; i += _groupSize)
          if (i + 1 == shortcuts.length)
            prism.BarItemPresence(child: shortcuts[i])
          else
            prism.BarItemPresence(
              child: IconButtonTheme(
                data: const IconButtonThemeData(
                  style: ButtonStyle(
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
                child: prism.TonalButtonGroup(
                  children: shortcuts.sublist(i, i + _groupSize),
                ),
              ),
            ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        if (shortcuts.isNotEmpty)
          if (scrollable)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: direct,
              ),
            )
          else
            direct,
        if (more != null) prism.BarItemPresence(child: more!),
      ],
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
  Widget build(BuildContext context) => prism.IconButton(
    // The pinned StyledButton notifies its own states during a disabled
    // flip. Remount only that small press surface, never its enclosing bar.
    key: ValueKey(onPressed != null),
    tooltip: label,
    icon: icon,
    onPressed: onPressed,
  );
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
  Widget build(BuildContext context) => MobilePopupAnchor(
    targetBuilder: (open) => MobileToolbarButton(
      label: label ?? 'More'.tl,
      icon: icon,
      onPressed: open,
    ),
    items: items,
  );
}

/// Keeps Prism's source snapshot, spring, nested levels and drag recognizers.
/// In the pinned Prism release, ordinary leaves wait for route.completed.
/// Its public keepsOpen callback instead fires on the committed row (including
/// keyboard activation), not on pointer down / hover. Start the same reverse
/// transition there, then run the action with the source route already current.
class MobilePopupAnchor extends StatelessWidget {
  const MobilePopupAnchor({
    super.key,
    required this.targetBuilder,
    required this.items,
    this.placement = prism.PopupPlacement.overAnchorEnd,
    this.maxVisibleItems,
  });

  final Widget Function(VoidCallback open) targetBuilder;
  final List<prism.PopupMenuItem> items;

  final prism.PopupPlacement placement;
  final int? maxVisibleItems;

  @override
  Widget build(BuildContext owner) => prism.PopupAnchor(
    placement: placement,
    targetBuilder: targetBuilder,
    popupBuilder: (_) => _CommittedPopup(
      owner: owner,
      items: items,
      maxVisibleItems: maxVisibleItems,
    ),
  );
}

class _CommittedPopup extends StatefulWidget {
  const _CommittedPopup({
    required this.owner,
    required this.items,
    this.maxVisibleItems,
  });

  final BuildContext owner;
  final int? maxVisibleItems;
  final List<prism.PopupMenuItem> items;

  @override
  State<_CommittedPopup> createState() => _CommittedPopupState();
}

class _CommittedPopupState extends State<_CommittedPopup> {
  bool _committed = false;
  late var _items = widget.items.map(_wrap).toList(growable: false);

  @override
  void didUpdateWidget(_CommittedPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.items, oldWidget.items)) {
      _items = widget.items.map(_wrap).toList(growable: false);
    }
  }

  prism.PopupMenuItem _wrap(prism.PopupMenuItem item) {
    final action = item.onPressed;
    final branch = item.subItems.isNotEmpty;
    if (!branch && (action == null || item.keepsOpen)) return item;
    return prism.PopupMenuItem(
      label: item.label,
      subtitle: item.subtitle,
      glyph: item.glyph,
      danger: item.danger,
      checked: item.checked,
      section: item.section,
      subItems: item.subItems.map(_wrap).toList(growable: false),
      keepsOpen: branch ? item.keepsOpen : true,
      onPressed: branch
          ? item.onPressed
          : () {
              final route = ModalRoute.of(context);
              if (_committed || route == null || !route.isCurrent) return;
              _committed = true;
              route.navigator!.pop();
              if (widget.owner.mounted) action!();
            },
    );
  }

  @override
  Widget build(BuildContext context) =>
      prism.PopupMenu(items: _items, maxVisibleItems: widget.maxVisibleItems);
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
