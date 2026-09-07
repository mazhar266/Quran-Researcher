# Quran Researcher — Development Plan

A cross-platform Flutter Quran application (Web, Android, iOS, Windows, macOS, Linux) built on the QUL (Quranic Universal Library) dataset and the Arramooz Arabic dictionary.

> Prepared August 2026 from a full inspection of the local dataset (~695 MB, 1,300+ files).
> Data sources: [Quranic Universal Library](https://qul.tarteel.ai) (attribution required in-app) and [Arramooz](https://github.com/linuxscout/arramooz) (GPL).

---

## 1. Repository layout

```
quran research/
├── data/                  # raw source data — NOT bundled as Flutter assets
│   ├── arramooz/          # git submodule: Arabic morphological dictionary
│   ├── audio/             # reciter timing files (MP3s stream from CDN)
│   ├── ayah_theme/        # thematic ayah-range labels
│   ├── dictionary/        # Arramooz exported to JSON (nouns, verbs)
│   ├── fonts/             # KFGQPC + qira'at + 2×604 per-page mushaf fonts
│   ├── info/              # surah introductions, topic ontology
│   ├── metadata/          # surah/ayah/juz/hizb/rub/ruku/manzil/sajda
│   ├── morphology/        # root/lemma/stem at word & ayah level
│   ├── mushaf/            # 21 script variants of the Quran text
│   ├── similarities/      # matching ayahs, Mutashabihat phrases
│   ├── tafsir/            # 10 tafsir books (5 EN, 5 BN)
│   ├── translation/       # EN + BN translations, word-by-word
│   └── transliteration/   # simple, tajweed, syllable-level
├── docs/                  # this document
└── (Flutter app "Quran Researcher" at root — Dart package quran_app,
     app id fi.mazhar.quran.researcher on every platform)
```

**Data quirk:** most `*.json` / `*.db` entries under `data/` are actually *directories*
containing the real JSON file (unzipped archives). The ETL must flatten these.

---

## 2. Data inventory

All Quran data is keyed by `surah:ayah` (6,236 ayahs) or `surah:ayah:word`
(83,668 words), which makes joining the datasets trivial.

| Domain | Size | Contents | Notes |
|---|---|---|---|
| `mushaf/` | 114 MB | 21 script variants: Uthmani (full + simple), Imlaei, IndoPak, Nastaleeq, Digital Khatt, QPC Hafs (plain / tajweed-annotated / word-by-word), QPC V1 & V4 glyph codes, Warsh, word-image URLs | Ayah- and word-level files; tajweed text uses inline `<rule class=…>` tags; V1 glyphs map to the 604 page fonts and carry `page_number` |
| `fonts/` | 365 MB | KFGQPC Hafs V22, five qira'at faces (Warsh, Qaloun, Douri, Sousi, Shu'ba), Nastaleeq, Digital Khatt IndoPak, 3 surah-name fonts, two full sets of 604 per-page fonts (QPC V1 = 161 MB, V2 = 200 MB) | Page fonts enable pixel-accurate Madani mushaf pages; far too big to bundle — must be downloadable packs |
| `translation/` | 24 MB | EN: Sahih International (simple + footnotes), word-by-word (plain + colored). BN: 5 full translations + word-by-word | Uniform `{"1:1": {"t": …}}` shape |
| `tafsir/` | 84 MB | EN: Ibn Kathir, Ma'arif-ul-Quran, Jalalayn, Tazkirul Quran, Abridged Explanation. BN: Ibn Kaseer, Abu Bakr Zakaria, Ahsanul Bayaan, Fathul Majid, Mokhtasar | HTML bodies per ayah; the two Ibn Kathirs alone are 39 MB — download on demand |
| `audio/` | 4 MB | Two reciters (Al-Afasy, Al-Husary), ayah-by-ayah MP3 URLs with **word-level timing segments** `[word, start_ms, end_ms]` | Audio streams from `audio-cdn.tarteel.ai`; segments enable karaoke-style word highlighting |
| `morphology/` | 20 MB | Root / lemma / stem at word and ayah level; 1,642 trilateral roots, 50,298 word–root links | Powers root search and the morphology explorer |
| `metadata/` | 2 MB | Ayah, surah names (with revelation order/place), juz, hizb, rub, ruku, manzil, sajda mappings | The navigation backbone |
| `similarities/` | 0.5 MB | Matching-ayah pairs with score/coverage/word-ranges; Mutashabihat-ul-Quran phrase index | Unique research feature — few apps have this |
| `info/` + `ayah_theme/` | 2.5 MB | Long-form surah introductions (EN), a 1.1 MB hierarchical topic ontology, thematic ayah-range labels | Topic ontology cross-links via `<topic data-id>` tags |
| `transliteration/` | 3 MB | Simple, tajweed-colored, and two syllable-level transliterations | Syllable form suits learners following audio |
| `arramooz/` | 85 MB | Arramooz Alwaseet morphological dictionary (git submodule): 26 MB SQLite with 30,213 nouns (root, wazn/pattern, gender, plurals, ~19k Arabic definitions) and 10,637 verbs; 5,251 noun + 3,451 verb roots; source CSVs | GPL-licensed; definitions Arabic-only; root orthography (e.g. `ءخذ`) needs normalization to match QUL roots |
| `dictionary/` | 31 MB | Arramooz exported to JSON: `arramooz-nouns.json` (30,213 rows), `arramooz-verbs.json` (10,637 rows) | Full-fidelity dump of the SQLite tables |

### Gaps found during investigation

- **No line-layout data.** Per-page fonts and `page_number` exist, but the
  word→line mapping needed for true 15-line mushaf pages is missing. Download
  QUL's mushaf-layout databases (free) or ship page mode with justified
  per-page flow instead.
- **Audio & word images are CDN URLs**, not files — the app needs streaming +
  an offline cache, and the Tarteel CDN becomes a runtime dependency.
- **Only 2 reciters and 2 translation languages** are present; the schema
  treats both as open-ended lists so more QUL resources can be dropped in later.
- **Attribution required.** QUL resources carry per-resource attribution and
  licensing terms — record them in the pipeline and show them in-app.

---

## 3. Product shape

The dataset is unusually deep on the *research* side (morphology, similarities,
themes, topics, tajweed markup, a full Arabic dictionary). The natural product
is a **reader-first Quran app with a research layer most apps lack**, bilingual
English/Bengali from day one:

- **Read** — any of 21 scripts, translation mode and (later) authentic mushaf
  page mode, word-by-word interlinear EN/BN, tajweed coloring, transliteration.
- **Listen** — ayah audio with word-level highlight following the recitation,
  repeat/range drills for memorization.
- **Understand** — 10 tafsirs, surah introductions, ayah themes, topic
  ontology browser.
- **Research** — root/lemma/stem explorer with corpus-wide occurrences,
  Arramooz dictionary lookups, similar-ayah navigation, mutashabihat
  (similar-phrase) study for hifz review.

---

## 4. Architecture

### 4.1 Data pipeline (build-time, not in-app)

A one-off Dart (or Python) ETL turns the raw JSON into versioned SQLite
databases. Raw JSON is the wrong runtime format — a 15 MB tafsir file cannot
be parsed on app start, and web especially needs indexed access.

```
data/ (raw)  ──►  etl/build.py  ──►  dist/core.db      66 MB: 8 ayah scripts, wbw,
                                                       metadata, all translations &
                                                       transliterations, tajweed spans,
                                                       morphology, similarities,
                                                       themes, topics, FTS5
                                     scripts_extra.db  33 MB: Warsh, Digital Khatt,
                                                       V4 glyphs, word images, …
                                     tafsir_<slug>.db  ×10, 1.8–28 MB each
                                     audio_<id>.db     ×2: URLs + word segments
                                     dict_ar.db        12 MB Arramooz + root_norm
                                     fontpack_v1.zip   69 MB / v2.zip 136 MB
                                     manifest.json     sizes, sha256, attribution
```

Output goes to `dist/` (not `build/`, which `flutter clean` deletes).
Rebuild any time with `python3 etl/build.py` (`--skip-fonts` for a fast run).
core.db came out at 66 MB rather than the estimated 25 MB because it carries
all 11 translation/transliteration resources and both tajweed levels; a
slimmed web variant can be split out later if first-load size demands it.

Every module gets a manifest entry (id, version, size, license/attribution,
checksum) so the app can list, download, verify, and update content
independently of app releases.

ETL responsibilities:

1. Flatten the directory-wrapped JSON files.
2. Normalize keys to `(surah, ayah, word)` integers.
3. Parse tajweed `<rule class=…>` markup into span ranges (never regex HTML at
   frame time).
4. Normalize Arramooz root spelling (hamza forms) to match QUL roots.
5. Build FTS5 indexes over translations, transliteration, and
   diacritic-stripped Arabic (the `*-simple` scripts provide this).
6. Validate counts in CI: 114 surahs, 6,236 ayahs, 83,668 words.
7. Record per-resource attribution/license into the manifest.

### 4.2 Schema sketch (core.db)

```
surahs(id, name, name_arabic, name_simple, revelation_place,
       revelation_order, verses_count, bismillah_pre)
ayahs(id, surah, ayah, verse_key, page_v1, juz, hizb, rub, ruku,
      manzil, sajda_type)
ayah_text(verse_key, script_id, text)          -- one row per script
words(location, verse_key, position, text_uthmani, text_v1_glyph,
      tajweed_html, tr_en, tr_bn, translit)
roots(id, arabic, latin, words_count)          + word_roots(root_id, location)
lemmas / stems                                 -- same shape
similar_ayahs(verse_key, matched_key, score, coverage, ranges_json)
phrases(id, source_key, from_w, to_w) + phrase_occurrences(phrase_id, …)
themes(surah, ayah_from, ayah_to, theme)
topics(id, name, arabic, parent_id, thematic_parent_id, description)
fts_search  -- FTS5 over translations + transliteration + normalized Arabic
```

dict_ar.db keeps Arramooz's `nouns` and `verbs` tables, with a `root_norm`
column added for joining against QUL roots.

### 4.3 Flutter stack

| Concern | Choice | Why |
|---|---|---|
| Database | `drift` (SQLite) | Typed queries, works on all six platforms — native FFI on mobile/desktop, `sqlite3.wasm` + OPFS/IndexedDB on web |
| State | `riverpod` | Testable, no BuildContext coupling, good for many small derived states (current ayah, playing word, selected script) |
| Navigation | `go_router` | Deep links (`/surah/2/ayah/255`) matter on web |
| Audio | `just_audio` + `audio_service` + `just_audio_media_kit` | One API across platforms; background playback + lock-screen controls on mobile; media_kit backend covers Windows/Linux |
| Downloads/cache | `dio` + `flutter_cache_manager` | Resumable module downloads, LRU audio cache |
| Fonts | Bundle UthmanicHafs V22 + one Bangla face; everything else via `FontLoader` at runtime | Keeps the base install small; page fonts load per page from the downloaded pack |

### 4.4 Rendering notes

- **Tajweed:** render pre-parsed span ranges as colored `TextSpan`s with a
  user-configurable rule→color map.
- **Word highlighting:** a ticker maps playback position → segment → word
  index → highlighted span. Word taps show the WBW gloss + morphology sheet.
- **Mushaf page mode:** each of the 604 pages uses its own font (`p{n}.ttf`)
  with the V1 glyph codes; lazily load the current ±2 pages' fonts and evict
  old ones.
- **Arabic search:** query the diacritic-stripped FTS column so users can
  search without harakat.

### 4.5 Platform specifics

- **Web:** drift/wasm with OPFS; lazy-load core.db in chunks on first visit
  and persist; verify Tarteel CDN CORS headers for audio early (fallback:
  proxy or download-only). Ship as an installable PWA.
- **Desktop:** keyboard navigation (arrows = ayah, PgUp/PgDn = page),
  two-pane layout (reader + tafsir/research side panel), `window_manager`
  for size persistence.
- **Mobile:** background audio, small base APK (~40 MB with core.db),
  everything heavy on demand.
- **Responsive rule:** one adaptive layout — bottom nav + single pane under
  600 dp, navigation rail + dual pane above.

---

## 5. Roadmap

### Phase 0 — Data pipeline & foundation ✅ DONE

`etl/build.py` produces all 17 modules into `dist/` with a manifest and a
self-validation report (18 checks: entity counts, section coverage, FTS spot
check, dictionary root join — 1,547 of 1,642 QUL roots have Arramooz entries).
Flutter app scaffolded for all six platforms as `quran_app`
(app id `fi.mazhar.quran.researcher`, display name "Quran Researcher") with flutter_riverpod,
go_router, drift (+sqlite3 libs), a light/dark/sepia theme system, and a
passing boot test. `data/` stays out of pubspec assets — it is ETL input only;
`dist/` is gitignored (regenerable).

### Phase 1 — MVP reader ✅ DONE

Implemented: home with Surah / Juz / Bookmarks tabs and a "continue reading"
button; reader (`/surah/:id?ayah=n`, deep-linkable) with script picker
(Uthmani, QPC Hafs, IndoPak Nastaleeq — bundled fonts), any combination of the
7 EN/BN translations, word-by-word interlinear glosses, transliteration,
bismillah headers, sajdah markers; debounced FTS search across Arabic /
English / Bangla / transliteration; bookmarks and last-read (auto-saved on
scroll); settings for script, font size, translations, WBW, transliteration,
and light/dark/sepia theme, persisted via shared_preferences.

Data access: core.db ships as an asset (copied to app storage on native,
seeded into OPFS via drift WasmDatabase on web — `web/sqlite3.wasm` and
`web/drift_worker.js` are in place). No drift codegen: the schema is fixed by
the ETL, so a thin `QuranRepo` issues plain SQL through `customSelect`. The
ETL now stamps `PRAGMA user_version` so drift never writes to the file.

Verified: `flutter analyze` clean; 10 tests pass, including 9 end-to-end
repo tests against the real core.db (reader payload, script variants,
EN/BN/AR search, FTS injection safety); release builds succeed for web and
Linux. Linux note: this machine's gcc-14 lacks libstdc++-dev, so build with
`CXXFLAGS="--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13"` (or install
`libstdc++-14-dev`).

### Phase 2 — Audio & tafsir ✅ DONE

**Audio**: per-ayah playback of both reciters (Al-Afasy, Al-Husary) streamed
from the Tarteel CDN with `LockCachingAudioSource` keeping local copies for
offline replay (native). Player bar in the reader: reciter picker,
prev/play/next, repeat cycle off → this-ayah → range (A/B markers set from the
current ayah — the memorization loop). Word-level highlight follows the
recitation using the ETL's timing segments, in both continuous-text mode
(per-word TextSpans) and word-by-word mode (chip highlight); the playing ayah
is also tinted. Backends: just_audio + just_audio_background (Android/iOS
lock-screen controls; manifest service + FOREGROUND_SERVICE_MEDIA_PLAYBACK,
iOS UIBackgroundModes audio) and just_audio_media_kit with bundled libmpv on
Linux/Windows.

**Tafsir**: all 10 books readable from every ayah via a draggable bottom sheet
with a persisted book picker; HTML rendered with flutter_widget_from_html_core;
grouped entries follow their alias (e.g. 1:7 shows the 1:6–1:7 text with a
"covered together" note).

**Distribution note**: with no CDN yet, the 10 tafsir DBs (~122 MB) and 2
audio DBs ship as assets, lazily copied into app storage on first use — on web
Flutter fetches assets on demand, which is effectively download-on-demand.
Swapping the asset source for real CDN downloads is a Phase 5 change confined
to `openModuleDb`.

Verified: analyze clean; 15 tests pass (new: segments parsing + `wordAt`,
tafsir group aliasing, all 10 books returning text for 2:255, both reciters);
Linux debug and web release builds succeed.

### Phase 3 — Mushaf mode & tajweed ✅ DONE

**Tajweed**: settings toggle colors all 18 QPC rule classes in the
Uthmani/QPC-Hafs scripts using the standard palette, rendered from the ETL's
pre-parsed spans (no HTML parsing at frame time); a legend sheet lists every
rule with its color and a per-rule show/hide switch; coloring composes with
the audio word highlight (spans split at word boundaries).

**Mushaf page mode**: `/mushaf/:page` shows all 604 pages with the authentic
QPC V1 per-page fonts, swiped RTL like a physical mushaf, with surah headers,
bismillah, page/juz indicator, go-to-page, and an ayah list that jumps back to
the reader; the reader's book icon opens the current page. Fonts ship as the
69 MB zip asset: extracted to app storage once on native, decompressed
per-page in memory on web; current ±1 page fonts preload. Layout is justified
flow — line-accurate 15-line pages still await QUL's layout DBs.

**Qira'at**: Warsh joins the script picker with its KFGQPC face. Because its
ayah numbering differs from Hafs (6,214 ayahs), Warsh mode is deliberately
Arabic-only — translations, word-by-word, and audio hide with an explanatory
banner rather than silently misaligning.

Verified: analyze clean; 22 tests pass (tajweed span builder incl. disabled
rules and word-boundary splits, corpus-wide rule-palette coverage on surah 2,
mushaf page queries, Warsh row counts, fontpack integrity); Linux debug and
web release builds succeed.

### Phase 4 — Research layer ✅ DONE

Home gains a Research tab. **Tap a word** (word-by-word mode) → morphology
sheet: root (with corpus count, linking to the root screen), lemma, stem, and
the **Arramooz dictionary** — verb forms as chips plus defined nouns with
wazn, word type, and Arabic definitions. **Root explorer** searches 1,642
roots by Arabic letters or latin key and lists every occurrence with its
word and gloss, jumping into the reader. **Ayah research** (flask button on
each ayah): similar ayahs with score/coverage and match-range highlighting;
mutashabihat phrases; covering themes. **Mutashabihat browser** ranks the
most-repeated phrases; the phrase screen has a **hifz study mode** that shows
only the shared phrase and asks you to recall the ayah before revealing.
**Themes** and the **topic ontology** (2,512 topics, `<topic>` cross-links
made tappable, ayah chips, subtopics) are searchable; **surah introductions**
open from the reader's info button. Fixed en route: `scripts_extra.db` and
`dict_ar.db` were missing from assets (Warsh would have failed at runtime).

Verified: analyze clean; 31 tests pass (morphology joins incl. root اله =
2,851 occurrences, dictionary join, similar-ayah ranges, phrase 50 = 71 hits
across 70 ayahs, themes, topics, surah info); Linux + web builds succeed.

### Phase 5 — Polish & release ✅ DONE

**Localization**: full gen-l10n setup with English and Bangla ARB files
(~70 strings) covering home, reader, player, search, settings, and the
research hub; an App Language setting (system/EN/BN) switches at runtime.
Research detail screens (roots/phrase/topic internals) remain English-first.

**Attribution**: Settings → About lists every data source with its terms —
QUL, Tarteel CDN recitations, KFGQPC fonts, Arramooz (GPL), and the
translation/tafsir authors — plus Flutter's license page and the app version.

**Accessibility & desktop**: every control carries a tooltip/semantic label;
mushaf pages turn with arrow keys and PgUp/PgDn on desktop and web.

**Quality**: a golden test locks Arabic rendering (real KFGQPC font, tajweed
colors, range highlight) — regenerate with `--update-goldens` after
intentional visual changes. 33 tests total.

**Packaging**: Android release signing reads `android/key.properties`
(template committed, secrets gitignored; debug-signs without it); Linux has
the CMake gcc-13 guard and a `.desktop` file; web builds as an installable
PWA with the app icons.

### Release guide

- **Android**: create a keystore (see `android/key.properties.example`), copy
  the example to `android/key.properties`, then
  `flutter build appbundle --release`.
- **Web/PWA**: `flutter build web --release` → deploy `build/web/` to any
  static host (ensure gzip/brotli — core.db compresses well); assets load on
  demand, so first paint doesn't wait for the databases.
- **Linux**: `flutter build linux --release`; install
  `linux/quran-researcher.desktop` + `icon.png` per its comments (deb/flatpak
  packaging remains future work).
- **Windows/macOS/iOS**: `flutter build windows|macos|ipa` on the respective
  OS — configuration (ids, icons, entitlements) is already in place.
- Bundle sizes: ~340 MB web / ~390 MB Linux, dominated by the offline
  databases and the mushaf fontpack. Moving modules to CDN download-on-demand
  (the `openModuleDb` seam) is the lever if smaller installs are wanted.

---

## 6. Risks & open questions

- **CDN dependency** — audio and word images live on Tarteel's CDN. Mitigate
  with aggressive caching and a "download surah/juz audio" feature; decide
  early whether to self-host mirrors.
- **Web payload** — core.db (~25 MB) is a heavy first load; mitigate with
  per-surah chunking or lazy attach, and measure on 3G early.
- **Line-accurate mushaf** — requires fetching QUL's layout databases; decide
  in Phase 3 whether authenticity justifies it.
- **Bengali shaping** — verify complex-script rendering on Linux/Windows early
  with a proper Bangla face (e.g. Noto Serif Bengali).
- **Licensing** — confirm redistribution terms for each translation/tafsir and
  the KFGQPC fonts before public release. Arramooz is GPL: shipping its data
  as a download module needs a compliance check (attribution + source
  availability at minimum).
- **Dictionary coverage** — ~36% of Arramooz nouns have no definition and all
  definitions are Arabic-only; the word-by-word EN/BN glosses remain the
  primary meaning source, with Arramooz as the advanced/Arabic layer.


---

## Phase 6 — Sarf (morphology) layer ✅ DONE

Word-by-word meaning previously stopped at root/lemma/stem. It now carries a
full traditional analysis, from the **Quranic Arabic Corpus** morphology
(Kais Dukes, GPL — vendored at `data/grammar/`, attribution required):

* **Word type** — ism / fi'l / harf, plus ism fā'il, ism maf'ūl, masdar, proper noun.
* **Bab (باب)** — deterministic for forms II–X (تفعيل، مفاعلة، إفعال …); for form I
  derived from the ʿayn vowels of the past and present, read from the Quran's own
  vocalised forms, from Arramooz's `future_type`, and — for hollow verbs, whose
  vowel hides inside a long vowel — from the classical rule on the present's first
  radical (يَقُولُ → naṣara, يَبِيعُ → ḍaraba, يَخَافُ → samiʿa).
  **93% of verb words** in the Quran resolve a bab; the rest show nothing rather
  than a guess.
* **Sigah (صيغة)** — tense (māḍī / muḍāriʿ / amr), voice (maʿrūf / majhūl) and
  person-gender-number, in Arabic with English and Bengali madrasa terminology.
* **Masdar (مصدر)** — Arramooz's explicit verb→masdar link first (so آمَنَ → إيمان
  and أَقامَ → إقامة, both irregular); template instantiation only for *sound* roots,
  where it is safe; otherwise omitted.
* **I'rab** — mood for verbs (marfū' / manṣūb / majzūm), case for nouns.

Alignment: QAC annotates segments and numbers words slightly differently from
QUL (which counts the ayah-number glyph, and splits بعدما). Words are matched by
letter-only text and **99%** align; unverified positions get no grammar at all.

Verified: 45 tests (8 new covering form/aspect/voice/pgn/mood, passive
detection, hollow-verb babs, and that no malformed template masdar reaches a
weak root), plus 5 new ETL validation checks.

**Outstanding:** the QAC licence requires the app to show its source and link to
corpus.quran.com — add this to the attribution screen before release.


---

## Fix — mushaf page fonts were paired with the wrong glyph codes

Phase 3 assumed `data/fonts/ttf` held the QPC **V1** page fonts and rendered the
`qpc-v1-glyph` codes (U+FB50…) with them. It doesn't: those fonts report
`QCF4001_COLOR` internally and their cmaps only cover **U+FC41…U+FC64** — the
QPC **V4** range. The dataset ships V2 (`QCF2001`) and V4 page fonts and **no V1
fonts at all**, so V1 codes fell through to a system fallback and the page
rendered as loose Arabic letters (ٱ ب ب پ …) instead of mushaf glyphs.

Fix: the ETL now builds `mushaf_page_text` from the **qpc-v4 word glyphs**
grouped per ayah and keyed by page, and packs the fonts as `fontpack_v4.zip`
(the V2 set keeps its own name). The app loads those fonts under the family
`QPC_V4_P<page>` and extracts them to `mushaf_fonts_v4/`, so any earlier wrong
extraction is not reused. Verified across pages 1, 2, 50, 302, 500 and 604:
every glyph the page needs is present in that page's font (0 missing).

Guarded by two ETL checks (6,236 page-text rows over 604 pages) and a test
asserting page glyphs stay inside the V4 range that the shipped fonts encode.


---

## Fix — mushaf text invisible in dark theme

The KFGQPC V4 page fonts are COLR/CPAL **colour** fonts: each glyph carries a
baked-in palette (black text, coloured ayah markers), so `TextStyle.color` is
ignored and the page stayed black-on-black in the dark theme.

Flutter cannot select a CPAL palette, and shipping a second monochrome pack
would double the 69 MB asset. Instead `lib/mushaf/font_mono.dart` rewrites the
sfnt table directory at load time to drop COLR and CPAL, which makes the
renderer fall back to each glyph's plain `glyf` outline — and those *do* take
the requested colour. The mushaf loads the colour font on light and sepia
backgrounds and the stripped one under a dark theme, cached separately as
`QPC_V4_P<page>` and `QPC_V4_MONO_P<page>`.

Covered by four tests: the shipped font really is a colour font, stripping
removes only COLR/CPAL while keeping `glyf`/`loca`/`cmap`, the rewritten sfnt
stays structurally valid (version, searchRange/entrySelector, 4-byte-aligned
in-bounds tables), and a font with no colour tables is returned untouched.


---

## Addition — true-black (OLED) theme

A fourth reading theme paints pure #000000 surfaces: on an OLED panel those
pixels are switched off, so it saves power and removes the dark theme's grey
halo in a dark room. Material's elevation overlays are dropped (a "raised"
surface tinted grey would defeat the point) and hairline `outlineVariant`
borders separate surfaces instead; sheets, dialogs and cards sit on #0A0A0A so
they read as layers without glowing.

It reports `Brightness.dark`, so the mushaf's colour-table stripping applies
and page glyphs take the theme's text colour. The settings screen builds its
list from `ReadingTheme.values`, so the option appeared without touching that
code; only the localized label (EN + বাংলা) was added.

Covered by five tests: every theme resolves, OLED is true black where the
ordinary dark theme deliberately is not, it reports dark brightness (the mushaf
mono-font trigger), its text/accent/divider colours stay legible on black, and
light and sepia stay light so they keep the colour mushaf font.


---

## Change — application id is now `fi.mazhar.quran.researcher`

The id was `research.quran.mazhar.fi`, which reads the domain backwards.
Reverse-DNS puts the domain first: `mazhar.fi` -> `fi.mazhar`, then the product.
Updated in the Android namespace/applicationId (and the Kotlin package
directory), the iOS and macOS bundle identifiers, the Linux GTK application id,
and the just_audio notification channel id.

Consequence: the id keys per-user storage, so the app looks at a new directory
(`~/.local/share/fi.mazhar.quran.researcher` on Linux). Bundled databases and
the extracted mushaf fonts simply regenerate; `shared_preferences.json`
(bookmarks, last-read, settings) does not, so copy it across when changing the
id. On Android the new id installs as a separate app — uninstall the old one.


---

## Addition — mushaf divisions surfaced (juz, hizb, rubʿ, rukuʿ, manzil, sajdah)

Phase 0 stored juz, hizb, rubʿ, rukuʿ, manzil and sajdah on every ayah, but
only juz and the sajdah icon were ever shown — hizb, rubʿ, rukuʿ and manzil had
zero references in `lib/`. They are now used everywhere they belong:

* **Reader stop markers** — the division that opens at an ayah is marked above
  it, the way a printed mushaf marks its margin: juz and manzil emphasised,
  hizb, rukuʿ, and the ۞ rubʿ quarters (¼, ½ — the nisf — and ¾). Suppressed in
  Warsh, whose numbering the Hafs-keyed data does not match.
* **Divisions browser** — the home tab formerly listing only juz now switches
  between juz (30), hizb (60), rubʿ (240, labelled "¼ Hizb 3" as a mushaf does),
  rukuʿ (558), manzil (7) and the 15 sajdah ayahs, marked obligatory or
  recommended with their page number.
* **Mushaf header** — page, juz and hizb quarter, instead of the juz alone.

`sections_repo.dart` loads the ~694 boundary ayahs once and caches them, so
the marker lookup is a map read rather than a query per ayah.

Covered by six tests: the division counts (30/60/240/558/7), the classical
start ayahs (juz 2 at 2:142, the seven manzils at 1:1, 5:1, 10:1, 17:1, 26:1,
37:1, 50:1), four rubʿ to a hizb with the half-hizb quarter, boundary marking
(including an ayah that opens a rukuʿ only, and mid-division ayahs marking
nothing), the 15 sajdahs with 4 obligatory, and an ayah reporting every
division it sits inside.
