# Quran Companion — Development Plan

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
└── (Flutter app at root — created with:
     flutter create --project-name quran_app --org <your.org> . )
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
(org `com.example` — change before store release) with flutter_riverpod,
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

### Phase 2 — Audio & tafsir (~3 weeks)

Both reciters with streaming + offline caching, word-level highlight following
recitation, ayah/range repeat for memorization, background playback. Tafsir
module downloads with an in-reader tafsir panel (all 10 books).

### Phase 3 — Mushaf mode & tajweed (~3 weeks)

Tajweed-colored rendering with legend and per-rule toggles. Downloadable V1/V2
font packs for the authentic 604-page mushaf view (line-accurate if QUL layout
DBs are added; justified page flow otherwise). Qira'at scripts (Warsh etc.)
with their bundled faces as a script option.

### Phase 4 — Research layer (~4 weeks)

Root/lemma/stem explorer with corpus-wide occurrences; tap-a-word → morphology
sheet with an **Arramooz dictionary tab** (root → classical entries: wazn,
derived nouns/verbs, plurals, Arabic definitions); similar-ayah navigation
with match-range highlighting; mutashabihat study mode for hifz; themes
browser; topic ontology with cross-links; surah introductions.

### Phase 5 — Polish & release (~2–3 weeks)

Accessibility (screen readers, dynamic type), localized UI (EN/BN),
attribution screen per QUL/Arramooz licensing, performance passes (page-font
eviction, web first-load), store packaging + PWA deployment, golden tests for
Arabic rendering.

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
