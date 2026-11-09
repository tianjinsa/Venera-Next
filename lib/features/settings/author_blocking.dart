import 'package:flutter/material.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/translations.dart';

class AuthorBlockingSettings extends StatefulWidget {
  const AuthorBlockingSettings({super.key});
  @override
  State<AuthorBlockingSettings> createState() => _AuthorBlockingSettingsState();
}

class _AuthorBlockingSettingsState
    extends SettingsSaveState<AuthorBlockingSettings> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _edit(String author, {required bool remove}) {
    final value = author.trim();
    if (value.isEmpty || !acceptsSettingsChanges) return;
    saveSetting(
      value,
      () => appdata.updateSettings((draft) {
        final preferences = GlobalPreferenceStore(draft);
        final authors = preferences.read(KeywordPreferences.authors).toSet();
        if (remove) {
          authors.remove(value);
        } else {
          authors.add(value);
        }
        preferences.write(KeywordPreferences.authors, authors.toList());
      }),
      onSaved: () {
        if (!remove && mounted) _input.clear();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authors = GlobalPreferenceStore(
      appdata.settings,
    ).read(KeywordPreferences.authors);
    return protectSettings(
      PopUpWidgetScaffold(
        title: 'Author blocking'.tl,
        onBack: leaveSettings,
        tailing: [settingsSaveStatus],
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _input,
                enabled: acceptsSettingsChanges,
                decoration: InputDecoration(
                  labelText: 'Add author'.tl,
                  suffixIcon: IconButton(
                    tooltip: 'Add author'.tl,
                    icon: const Icon(Icons.add),
                    onPressed: () => _edit(_input.text, remove: false),
                  ),
                ),
                onSubmitted: (value) => _edit(value, remove: false),
              ),
            ),
            for (final author in authors)
              ListTile(
                title: Text(author),
                trailing: IconButton(
                  tooltip: 'Delete'.tl,
                  icon: const Icon(Icons.close),
                  onPressed: () => _edit(author, remove: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_changed);
    _input.dispose();
    super.dispose();
  }
}
