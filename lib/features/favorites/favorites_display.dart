import 'package:flutter/material.dart';
import 'package:prism_ui/icons/icons.dart' as prism;
import 'package:prism_ui/popup.dart' as prism;
import 'package:venera_next/components/mobile_collection_ui.dart';
import 'package:venera_next/components/mobile_ui.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/foundation/translations.dart';

const favoriteReadFilters = ['All', 'UnCompleted', 'Completed'];

class FavoriteDisplayButton extends StatefulWidget {
  const FavoriteDisplayButton({super.key})
    : mobileItems = null,
      readingFilter = null,
      onReadingFilterSaved = null,
      isCurrent = null;

  const FavoriteDisplayButton.mobileMore({
    super.key,
    this.mobileItems = const [],
    this.readingFilter,
    this.onReadingFilterSaved,
    this.isCurrent,
  });

  final List<prism.PopupMenuItem>? mobileItems;
  final String? readingFilter;
  final ValueChanged<String>? onReadingFilterSaved;
  final bool Function()? isCurrent;

  @override
  State<FavoriteDisplayButton> createState() => _FavoriteDisplayButtonState();
}

class _FavoriteDisplayButtonState
    extends SettingsSaveState<FavoriteDisplayButton>
    with ContextMenuOwner {
  bool get _gallery =>
      GlobalPreferenceStore(appdata.settings)
          .read(FavoritePreferences.displayMode) ==
      'gallery';
  int get _columns =>
      GlobalPreferenceStore(appdata.settings)
          .read(FavoritePreferences.galleryColumns);
  @override
  Object get contextMenuIdentity => (_gallery, _columns);
  int _menuGeneration = 0;
  @override
  void initState() {
    appdata.settings.addListener(_onSettingsChanged);
    super.initState();
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    contextMenus.revalidate();
    final gallery = _gallery;
    if (widget.mobileItems case final items?) {
      final route = ModalRoute.of(context);
      final target = widget.isCurrent;
      bool isCurrent() =>
          mounted &&
          (target?.call() ?? true) &&
          identical(ModalRoute.of(context), route) &&
          route?.isCurrent != false &&
          NavigationAdmission.allows(context);
      bool canSave() =>
          isCurrent() &&
          acceptsSettingsChanges &&
          !savingSettings &&
          !hasSettingsSaveError;
      void select<T>(Preference<T> preference, T value) {
        if (!canSave()) return;
        saveSetting(
          preference.key,
          () => appdata.updateSettings(
            (draft) => GlobalPreferenceStore(draft).write(preference, value),
          ),
        );
      }

      final filter = widget.readingFilter;
      final onFilterSaved = widget.onReadingFilterSaved;
      return protectSettings(
        savingSettings || hasSettingsSaveError
            ? MobileToolbarButton(
                icon: const Icon(Icons.refresh),
                label: (hasSettingsSaveError ? 'Retry' : 'Save').tl,
                onPressed: !savingSettings && hasSettingsSaveError
                    ? retrySettingsSave
                    : null,
              )
            : MobileMenuButton(
                key: ValueKey((gallery, _columns, filter)),
                items: [
                  prism.PopupMenuItem(
                    label: 'Favorite display mode'.tl,
                    subItems: [
                      for (final (value, label) in [
                        ('list', 'List'.tl),
                        ('gallery', 'Gallery'.tl),
                      ])
                        collectionOption(
                          label: label,
                          value: value,
                          current: gallery ? 'gallery' : 'list',
                          onSelected: (value) =>
                              select(FavoritePreferences.displayMode, value),
                        ),
                      if (gallery)
                        prism.PopupMenuItem(
                          label:
                              "${'Gallery'.tl} · ${_columns == FavoritePreferences.galleryColumns.defaultValue ? 'Auto'.tl : '@c columns'.tlParams({'c': _columns})}",
                          subItems: [
                            collectionOption(
                              label: 'Auto'.tl,
                              value: FavoritePreferences
                                  .galleryColumns
                                  .defaultValue,
                              current: _columns,
                              onSelected: (value) => select(
                                FavoritePreferences.galleryColumns,
                                value,
                              ),
                            ),
                            for (
                              var count =
                                  FavoritePreferences.galleryColumns.min;
                              count <= FavoritePreferences.galleryColumns.max;
                              count++
                            )
                              collectionOption(
                                label: '@c columns'.tlParams({'c': count}),
                                value: count,
                                current: _columns,
                                onSelected: (value) => select(
                                  FavoritePreferences.galleryColumns,
                                  value,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  if (filter != null && onFilterSaved != null)
                    prism.PopupMenuItem(
                      label: 'Filter reading status'.tl,
                      glyph: prism.Glyphs.sort,
                      subtitle: filter.tl,
                      subItems: [
                        for (final value in favoriteReadFilters)
                          collectionOption(
                            label: value.tl,
                            value: value,
                            current: filter,
                            onSelected: (value) {
                              if (!canSave()) return;
                              saveSetting(
                                'local_favorites_read_filter',
                                () => appdata.updateImplicit((draft) {
                                  draft['local_favorites_read_filter'] = value;
                                }),
                                onSaved: () {
                                  if (isCurrent()) onFilterSaved(value);
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ...items,
                ],
              ),
      );
    }
    return protectSettings(
      Button.icon(
        icon: Icon(
          hasSettingsSaveError
              ? Icons.refresh
              : gallery
              ? Icons.grid_view
              : Icons.view_list,
        ),
        isLoading: savingSettings,
        tooltip: (hasSettingsSaveError ? 'Retry' : 'Favorite display mode').tl,
        onPressed: () {
          if (hasSettingsSaveError) {
            retrySettingsSave();
          } else {
            _openMenu(gallery);
          }
        },
      ),
    );
  }

  void _openMenu(bool gallery) {
    if (!acceptsSettingsChanges || !NavigationAdmission.allows(context)) return;
    final route = ModalRoute.of(context);
    final generation = ++_menuGeneration;
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    void select<T>(Preference<T> preference, T value) {
      if (!mounted ||
          !acceptsSettingsChanges ||
          generation != _menuGeneration ||
          !identical(ModalRoute.of(context), route) ||
          route?.isCurrent != true ||
          !NavigationAdmission.allows(context)) {
        return;
      }
      saveSetting(
        preference.key,
        () => appdata.updateSettings(
          (draft) => GlobalPreferenceStore(draft).write(preference, value),
        ),
      );
    }

    contextMenus.show(context, offset, _buildEntries(gallery, select));
  }

  List<MenuEntry> _buildEntries(
    bool gallery,
    void Function<T>(Preference<T>, T) select,
  ) {
    final columns = _columns;
    return [
      MenuEntry(
        icon: gallery ? Icons.view_list : Icons.check,
        text: 'List'.tl,
        onClick: () => select(FavoritePreferences.displayMode, 'list'),
      ),
      MenuEntry(
        icon: gallery ? Icons.check : Icons.grid_view,
        text: 'Gallery'.tl,
        onClick: () => select(FavoritePreferences.displayMode, 'gallery'),
      ),
      if (gallery) ...[
        MenuEntry(
          icon: columns == FavoritePreferences.galleryColumns.defaultValue
              ? Icons.check
              : Icons.auto_awesome_mosaic_outlined,
          text: 'Auto'.tl,
          onClick: () => select(
            FavoritePreferences.galleryColumns,
            FavoritePreferences.galleryColumns.defaultValue,
          ),
        ),
        for (
          var count = FavoritePreferences.galleryColumns.min;
          count <= FavoritePreferences.galleryColumns.max;
          count++
        )
          MenuEntry(
            icon: columns == count ? Icons.check : Icons.grid_view_outlined,
            text: '@c columns'.tlParams({'c': count}),
            onClick: () => select(FavoritePreferences.galleryColumns, count),
          ),
      ],
    ];
  }
}
