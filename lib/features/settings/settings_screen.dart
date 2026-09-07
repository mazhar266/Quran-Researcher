import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../data/prefs.dart';
import '../../data/repo.dart';
import '../../l10n/l10n.dart';
import '../../tajweed/tajweed.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final resources = ref.watch(translationResourcesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTooltip)),
      body: ListView(
        children: [
          // With a single script there is nothing to choose between.
          if (readerScripts.length > 1) ...[
            _SectionHeader(context.l10n.sectionScript),
            RadioGroup<String>(
              groupValue: settings.scriptSlug,
              onChanged: (v) =>
                  notifier.update((s) => s.copyWith(scriptSlug: v)),
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
          ],
          _SectionHeader(context.l10n.sectionFontSize),
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
          _SectionHeader(context.l10n.sectionTajweed),
          SwitchListTile(
            title: Text(context.l10n.tajweedColors),
            subtitle: Text(context.l10n.tajweedColorsSub),
            value: settings.tajweedColors,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(tajweedColors: v)),
          ),
          ListTile(
            enabled: settings.tajweedColors,
            title: Text(context.l10n.tajweedLegend),
            subtitle: Text(settings.tajweedDisabledRules.isEmpty
                ? context.l10n.tajweedAllShown(tajweedRules.length)
                : context.l10n
                    .tajweedHidden(settings.tajweedDisabledRules.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTajweedLegend(context),
          ),
          _SectionHeader(context.l10n.sectionDisplay),
          SwitchListTile(
            title: Text(context.l10n.wordByWord),
            subtitle: Text(context.l10n.wordByWordSub),
            value: settings.wordByWord,
            onChanged: (v) => notifier.update((s) => s.copyWith(wordByWord: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.transliteration),
            value: settings.transliteration,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(transliteration: v)),
          ),
          _SectionHeader(context.l10n.sectionTranslations),
          for (final r in resources)
            CheckboxListTile(
              title: Text(r.name),
              subtitle: Text(r.lang == 'en'
                  ? context.l10n.langEnglish
                  : context.l10n.langBangla),
              value: settings.translationSlugs.contains(r.slug),
              onChanged: (checked) => notifier.update((s) {
                final slugs = [...s.translationSlugs];
                checked! ? slugs.add(r.slug) : slugs.remove(r.slug);
                return s.copyWith(translationSlugs: slugs);
              }),
            ),
          _SectionHeader(context.l10n.sectionTheme),
          RadioGroup<ReadingTheme>(
            groupValue: settings.theme,
            onChanged: (v) => notifier.update((s) => s.copyWith(theme: v)),
            child: Column(
              children: [
                for (final t in ReadingTheme.values)
                  RadioListTile<ReadingTheme>(
                    value: t,
                    title: Text(switch (t) {
                      ReadingTheme.light => context.l10n.themeLight,
                      ReadingTheme.dark => context.l10n.themeDark,
                      ReadingTheme.sepia => context.l10n.themeSepia,
                      ReadingTheme.oled => context.l10n.themeOled,
                    }),
                  ),
              ],
            ),
          ),
          _SectionHeader(context.l10n.sectionLanguage),
          RadioGroup<String>(
            groupValue: settings.appLanguage,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(appLanguage: v)),
            child: Column(
              children: [
                RadioListTile<String>(
                    value: 'system', title: Text(context.l10n.langSystem)),
                RadioListTile<String>(
                    value: 'en', title: Text(context.l10n.langEnglish)),
                RadioListTile<String>(
                    value: 'bn', title: Text(context.l10n.langBangla)),
              ],
            ),
          ),
          _SectionHeader(context.l10n.sectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.aboutTitle),
            subtitle: Text(context.l10n.aboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

void _showTajweedLegend(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Consumer(
        builder: (context, ref, _) {
          final disabled = ref.watch(
              settingsProvider.select((s) => s.tajweedDisabledRules.toSet()));
          final notifier = ref.read(settingsProvider.notifier);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Tajweed rules',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final rule in tajweedRules)
                SwitchListTile(
                  secondary: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: rule.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: rule.arabic,
                      style: const TextStyle(
                          fontFamily: 'UthmanicHafs', fontSize: 17),
                    ),
                    TextSpan(text: '  ${rule.label}'),
                  ])),
                  subtitle: rule.harakat == null
                      ? null
                      : Text('${rule.harakat} ḥarakāt'),
                  value: !disabled.contains(rule.slug),
                  onChanged: (on) => notifier.update((s) {
                    final set = s.tajweedDisabledRules.toSet();
                    on ? set.remove(rule.slug) : set.add(rule.slug);
                    return s.copyWith(tajweedDisabledRules: set.toList());
                  }),
                ),
            ],
          );
        },
      ),
    ),
  );
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
