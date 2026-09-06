import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Attribution and licensing, as required by the data sources' terms.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// The app's release version. Kept in step with `version:` in pubspec.yaml,
  /// which test/version_test.dart asserts.
  static const version = '2.1.2';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sources = [
      (
        name: 'Quranic Universal Library (QUL) — qul.tarteel.ai',
        detail: 'Quran text (KFGQPC Uthmani, IndoPak, Warsh & other scripts), '
            'tajweed annotations, word-by-word data, translations, tafsir '
            'books, transliterations, morphology, similar-ayah and '
            'mutashabihat data, themes, topics, surah introductions, mushaf '
            'metadata, and recitation timing data. Individual resources '
            'carry their own attributions per QUL\'s terms.',
      ),
      (
        name: 'Recitations',
        detail: 'Mishari Rashid al-Afasy and Mahmoud Khalil al-Husary '
            '(murattal, Hafs), streamed from the Tarteel CDN '
            '(audio-cdn.tarteel.ai) via QUL.',
      ),
      (
        name: 'Fonts — King Fahd Glorious Quran Printing Complex (KFGQPC)',
        detail: 'UthmanicHafs V22, the 604 QPC V4 per-page mushaf fonts, '
            'KFGQPC Nastaleeq, and the Warsh face, obtained via QUL.',
      ),
      (
        name: 'Arramooz Alwaseet — Taha Zerrouki',
        detail: 'Open-source Arabic morphological dictionary '
            '(github.com/linuxscout/arramooz), GPL-licensed. Used for the '
            'root dictionary entries in the research layer.',
      ),
      (
        name: 'Quranic Arabic Corpus — Kais Dukes',
        detail: 'Word-by-word grammar (part of speech, verb form, aspect, '
            'voice, person/gender/number, mood and case) from the Quranic '
            'Arabic Corpus, corpus.quran.com — GNU General Public License. '
            'The sarf analysis, including the bab and sigah of every verb, '
            'is derived from this annotation.',
      ),
      (
        name: 'Translations & tafsir',
        detail: 'Sahih International (EN); Sheikh Mujibur Rahman, Taisirul '
            'Quran, Dr. Abu Bakr Muhammad Zakaria, Fathul Majid, Rawai '
            'al-Bayan (BN); tafsir books by their respective authors and '
            'publishers, via QUL.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon.png',
                    width: 56,
                    height: 56,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.menu_book, size: 56)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('v$version',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final s in sources) ...[
            Text(s.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Text(s.detail,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            ),
          ],
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Open-source licenses'),
            subtitle: const Text('Flutter and package licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Quran Researcher',
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}
