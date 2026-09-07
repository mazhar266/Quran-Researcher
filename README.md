<img src="icon.png" alt="Quran Researcher icon" width="96" align="right"/>

# Quran Researcher

A Quran reading and **research** app for every platform Flutter reaches — Android, iOS, Windows, macOS, Linux, and the web. Fully offline: the complete text in 21 scripts, translations, ten tafsir books, word-level morphology, a classical Arabic dictionary, and the research tools most Quran apps lack.

Bilingual by design: English and Bengali (বাংলা) — UI, translations, word-by-word glosses, and tafsir.

## Features

### Read
- **22 script variants** — Uthmani, QPC Hafs, IndoPak (Digital Khatt), Hafs Smart (15-line) and Warsh in the reader; Imlaei and more in the data
- **Tajweed colors** — all 18 QPC rule classes, with a legend and per-rule toggles
- **Mushaf page mode** — all 604 pages in the authentic KFGQPC V4 per-page fonts, set as a printed leaf (aged paper, gilt frame, ruled surah band, ornamented page number), swiped right-to-left like a physical mushaf, with the screen kept awake and a tap for full-screen
- **Word-by-word** interlinear English + Bangla glosses, transliteration, footnoted Sahih International
- **Warsh riwayah** as a script option (Arabic-only, with its own ayah numbering)
- **Mushaf divisions** — browse and jump by juz, hizb, rubʿ al-hizb (¼ ½ ¾ stops), rukuʿ, manzil, or the 15 sajdah ayahs; the reader marks each stop where it falls, as a printed mushaf does
- Navigation by surah, juz, or page · bookmarks · continue-where-you-left-off · light / dark / sepia / true-black (OLED) themes

### Listen
- Two reciters (Mishari Rashid al-Afasy, Mahmoud Khalil al-Husary), streamed and cached for offline replay
- **Word-level highlighting** that follows the recitation in real time
- Repeat one ayah or an A–B range — built for memorization
- Background playback with lock-screen controls on mobile

### Understand
- **Ten tafsir books** — Ibn Kathir, Ma'arif-ul-Quran, Al-Jalalayn, Tazkirul Quran, Mukhtasar (English); Ibn Kaseer, Abu Bakr Zakaria, Ahsanul Bayaan, Fathul Majid, Mokhtasar (বাংলা)
- Long-form surah introductions
- Full-text search across Arabic, English, Bangla, and transliteration

### Research
- **Tap any word** → its meaning, full **sarf** analysis (bab, sigah, masdar, i'rab), root, lemma, stem, and classical dictionary entry
- **Sarf (صرف)** — verb form I–X with its traditional **bab** (باب نصر / ضرب / فتح / سمع …), **sigah** (মাযী মা'রূফ · ওয়াহিদ মুযাক্কার গায়েব), **masdar**, voice, mood and case — in English and Bengali madrasa terminology
- **Root explorer** — 1,642 trilateral roots with every occurrence in the corpus (50,298 word–root links)
- **Arramooz dictionary** — 30,213 nouns and 10,637 verbs with wazn, plurals, and Arabic definitions
- **Similar-ayah navigation** with match ranges highlighted
- **Mutashabihat study mode** — repeated phrases across the mushaf, with a hide-and-recall mode for hifz review
- **Ayah themes** and a **2,512-topic ontology** with cross-linked descriptions

## Getting started

```bash
flutter pub get
flutter run          # pick your device: Linux, Chrome, Android, ...
```

Prebuilt databases ship in `assets/db/`, so a plain checkout builds and runs. First launch copies them to app storage (a few seconds, once).

**Linux audio** needs the system libmpv: `sudo apt install libmpv-dev` (the app runs fine without it — playback is disabled and tells you what to install).

### Rebuilding the data (optional)

The app's databases are produced from the raw datasets in `data/` by a single ETL script:

```bash
python3 etl/build.py            # full build into dist/ (+ --skip-fonts for a fast run)
cp dist/*.db assets/db/         # refresh the app's bundled databases
```

The ETL flattens QUL's archive layout, parses tajweed markup into span data, normalizes Arabic roots so QUL and Arramooz join, builds FTS5 indexes, packages the 604 page fonts, and self-validates (20 checks: entity counts, section coverage, markup leaks, dictionary joins).

## Architecture

| Layer | Choice |
|---|---|
| Data | Prebuilt SQLite modules (drift) — native FFI on mobile/desktop, WASM + OPFS on web; opened read-only with mmap tuning |
| State | riverpod |
| Navigation | go_router (deep-linkable: `/surah/2?ayah=255`, `/mushaf/302`) |
| Audio | just_audio + just_audio_background (mobile), media_kit/libmpv (desktop) |
| Localization | flutter gen-l10n — English + বাংলা |

```
etl/          Python ETL: raw data → versioned SQLite modules + manifest
data/         raw source datasets (QUL export, Arramooz submodule)
assets/db/    the modules the app ships (core, 10 tafsirs, audio, dictionary)
lib/
  data/       drift access layer, repositories, settings
  audio/      playback controller, word-timing sync
  tajweed/    rule palette + span builder
  features/   home · reader · mushaf · search · research · settings
docs/         development plan (phase-by-phase record)
```

## Testing

```bash
flutter test        # 79 tests, incl. end-to-end queries against the real DBs
```

The database tests read `dist/`, so run the ETL once first. A golden test pins Arabic text rendering (tajweed colors + highlight).

## Releases

Pushing a version tag builds and publishes all platforms via GitHub Actions:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Artifacts: Linux `.tar.gz`, Windows `.zip`, Android `.apk`, macOS `.dmg`, iOS `.ipa` (unsigned, for sideloading). Android is debug-signed unless `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEY_PROPERTIES` secrets are configured.

The macOS DMG contains `Quran Researcher.app` and an Applications shortcut. Drag the app to Applications after opening the DMG. If macOS blocks the app on first launch, run:

```bash
xattr -dr com.apple.quarantine "/Applications/Quran Researcher.app"
```

## Data sources & attribution

| Source | Content | License / terms |
|---|---|---|
| [Quranic Universal Library](https://qul.tarteel.ai) (Tarteel) | Quran text in all scripts, translations, tafsirs, morphology, audio timings, page fonts, metadata | Per-resource attribution required |
| [Arramooz Alwaseet](https://github.com/linuxscout/arramooz) (Taha Zerrouki) | Classical Arabic morphological dictionary | GPL |
| [Quranic Arabic Corpus](https://corpus.quran.com) (Kais Dukes) | Word-by-word grammar: part of speech, verb form, aspect, voice, person/gender/number, mood, case | GPL — **attribution and a link to corpus.quran.com are required in-app** |
| King Fahd Glorious Quran Printing Complex (via QUL) | KFGQPC fonts (Hafs, Warsh, page fonts) | Per KFGQPC terms |
| [audio-cdn.tarteel.ai](https://qul.tarteel.ai) | Recitation MP3 streams | Streamed at runtime |

Verify each resource's redistribution terms before publishing to app stores.
