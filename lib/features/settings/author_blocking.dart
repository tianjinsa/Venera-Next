import 'package:flutter/material.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/translations.dart';

Future<void> showAuthorRuleEditor(BuildContext context, String author) {
  final work = context.getInheritedWidgetOfExactType<SettingsSaveScope>()?.work;
  return showDialog<void>(
    context: context,
    builder: (_) {
      final editor = _AuthorRuleEditor(author: author);
      return work == null
          ? editor
          : SettingsSaveScope(work: work, child: editor);
    },
  );
}

class _AuthorRuleEditor extends StatefulWidget {
  const _AuthorRuleEditor({required this.author});
  final String author;
  @override
  State<_AuthorRuleEditor> createState() => _AuthorRuleEditorState();
}

class _AuthorRuleEditorState extends SettingsSaveState<_AuthorRuleEditor> {
  late final _input = TextEditingController(text: widget.author.trim());
  String? _error;

  Future<void> _save({bool remove = false}) async {
    if (savingSettings || !acceptsSettingsChanges) return;
    final original = widget.author;
    final value = _input.text.trim();
    if (!remove && value.isEmpty) return;
    var changed = false;
    await saveSetting(
      original,
      () => appdata.updateSettings((draft) {
        final preferences = GlobalPreferenceStore(draft);
        final authors = preferences.read(KeywordPreferences.authors).toList();
        if (!authors.contains(original)) {
          changed = true;
          return;
        }
        if (!remove && value != original && authors.contains(value)) {
          throw StateError('Author already exists'.tl);
        }
        final index = authors.indexOf(original);
        authors.removeAt(index);
        if (!remove) authors.insert(index, value);
        preferences.write(KeywordPreferences.authors, authors);
      }),
      onSaved: () {
        if (changed) {
          setState(
            () => _error = 'The rule changed. Close and reopen the editor.'.tl,
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) leaveSettings();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => protectSettings(
    ContentDialog(
      title: 'Author blocking'.tl,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _input,
          enabled: !savingSettings,
          decoration: InputDecoration(
            labelText: 'Author'.tl,
            errorText: _error,
          ),
        ),
      ),
      actions: [
        settingsSaveStatus,
        TextButton(
          onPressed: savingSettings ? null : () => _save(remove: true),
          child: Text(
            'Delete'.tl,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        FilledButton(
          onPressed: savingSettings ? null : _save,
          child: Text('Save'.tl),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}

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
                onTap: () => showAuthorRuleEditor(context, author),
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
