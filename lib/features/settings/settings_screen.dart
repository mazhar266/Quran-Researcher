import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs.dart';
import '../../data/repo.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final resources = ref.watch(translationResourcesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Arabic script'),
          RadioGroup<String>(
            groupValue: settings.scriptSlug,
            onChanged: (v) => notifier.update((s) => s.copyWith(scriptSlug: v)),
            child: Column(
              children: [
                for (final script in readerScripts)
                  RadioListTile<String>(
                    value: script.slug,
                    title: Text(script.label),
                  ),
              ],
            ),
          ),
          const _SectionHeader('Arabic font size'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: settings.arabicFontSize,
              min: 20,
              max: 48,
              divisions: 14,
              label: settings.arabicFontSize.round().toString(),
              onChanged: (v) =>
                  notifier.update((s) => s.copyWith(arabicFontSize: v)),
            ),
          ),
          const _SectionHeader('Display'),
          SwitchListTile(
            title: const Text('Word-by-word glosses'),
            subtitle: const Text('Show each word with its English and Bangla meaning'),
            value: settings.wordByWord,
            onChanged: (v) => notifier.update((s) => s.copyWith(wordByWord: v)),
          ),
          SwitchListTile(
            title: const Text('Transliteration'),
            value: settings.transliteration,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(transliteration: v)),
          ),
          const _SectionHeader('Translations'),
          for (final r in resources)
            CheckboxListTile(
              title: Text(r.name),
              subtitle: Text(r.lang == 'en' ? 'English' : 'Bangla'),
              value: settings.translationSlugs.contains(r.slug),
              onChanged: (checked) => notifier.update((s) {
                final slugs = [...s.translationSlugs];
                checked! ? slugs.add(r.slug) : slugs.remove(r.slug);
                return s.copyWith(translationSlugs: slugs);
              }),
            ),
          const _SectionHeader('Theme'),
          RadioGroup<ReadingTheme>(
            groupValue: settings.theme,
            onChanged: (v) => notifier.update((s) => s.copyWith(theme: v)),
            child: Column(
              children: [
                for (final t in ReadingTheme.values)
                  RadioListTile<ReadingTheme>(
                    value: t,
                    title: Text(switch (t) {
                      ReadingTheme.light => 'Light',
                      ReadingTheme.dark => 'Dark',
                      ReadingTheme.sepia => 'Sepia (paper)',
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
