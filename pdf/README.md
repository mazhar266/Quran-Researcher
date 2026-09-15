# A6 Quran PDFs for 6" e-readers

Three books, all built from the app's own data and fonts:

- `quran-a6-tajweed.pdf` — continuous flow, six large lines a page (below)
- `mushaf-a6-madinah.pdf` — the app's mushaf mode: the printed Madinah pages, line for line ([further down](#mushaf-a6-madinahpdf))
- `mushaf-a6-madinah-complete.pdf` — the same mushaf with a cover, clickable indexes and marginal notes ([last](#mushaf-a6-madinah-completepdf))

## quran-a6-tajweed.pdf

`quran-a6-tajweed.pdf` — the whole Quran, Arabic only, on A6 pages at six lines
each, sized to read comfortably on a 6" e-reader.

    python3 pdf/build_quran_pdf.py            # ~1 min, 2560 pages, 25 MB
    python3 pdf/build_quran_pdf.py --surahs 1-3 -o /tmp/preview.pdf

Needs `google-chrome` (or `chromium`) on PATH and `pymupdf`.

### What is in it

| | |
|---|---|
| Page | A6, 105 × 148 mm, 6 lines of body text |
| Text | `tajweed_ayah` from `assets/db/core.db` — Uthmani Hafs, every waqf mark, sajdah (۩), rub el hizb (۞), small letters and hamzat al-wasl exactly as stored |
| Type | KFGQPC Uthmanic Hafs V22 at 9.2 mm, justified, ~20.8 mm leading |
| Colour | the full 18-rule tajweed palette, identical to `lib/tajweed/tajweed.dart` |
| Furniture | surah cartouche + name, basmala line, running head (surah right, juz left), Arabic-Indic folio, hairline frame |
| Navigation | PDF outline with all 114 surahs and all 30 juz |

Every one of the 6236 ayat is accounted for on a page, and the font covers all
82 distinct codepoints in the text, so nothing falls back to a substitute glyph.

### How it is built

1. **Layout — headless Chrome.** The ayat become one continuous justified RTL
   flow; Chrome shapes it with HarfBuzz and paginates it. `@page` margins leave
   a content box a hair over six line boxes tall, so every page takes exactly
   six lines and never a seventh.
2. **Locate — PyMuPDF.** The only Arabic-Indic digits in the flow are the ayah
   numbers, so reading them back off each page replays the ayah sequence and
   says where everything landed. (Extraction returns a number's digits in
   visual order, and the ayah ornament stacks the last two on the same x, so a
   run is read by reversing it.)
3. **Decorate — PyMuPDF.** Frame, running heads, folios and the outline are
   stamped on afterwards. The surah names and juz names are single private-use
   glyphs in `surah-name-v*.ttf` / `quran-common.ttf`, so they need no shaping.

### Two things worth knowing

**Words are boxed (`w { display: inline-block }`).** Left as plain inline text,
Chrome justifies a sparse line by prising the letters of a word apart —
`أَلۡقَى` came out as `أَلۡ  قَى` with the join broken. Boxing each word makes it
atomic, so slack can only go into the spaces between words. This is the one
non-obvious thing in the stylesheet; do not remove it.

**Colour on e-ink.** Most 6" readers are greyscale, where the palette collapses
to grey levels — `ham_wasl` grey and `madda_normal` blue end up close. The
colours are correct and print correctly; they only pay off on a colour panel.

### Tuning

Everything is constants at the top of `build_quran_pdf.py`. `LINES` and
`FONT_MM` are the two that matter: `LINE_H` follows from `LINES`, and dropping
`FONT_MM` to 8.6 buys roughly 10% fewer pages at the cost of smaller type.

## mushaf-a6-madinah.pdf

The 604-page Madinah mushaf exactly as the app's mushaf view draws it — the
QPC V4 page fonts, one calligraphic glyph per word with tajweed colour built
in — but set **line for line as printed**, which the app itself does not do.

    python3 pdf/build_mushaf_pdf.py --edition plain   # ~75 s, 1206 leaves, 62 MB
    python3 pdf/build_mushaf_pdf.py --edition plain --pages 1-5 -o /tmp/preview.pdf

Same requirements: Chrome and `pymupdf`.

### Reading size

A printed Madinah line is ~16.4 em wide, so on A6 the page *width* decides how
big the glyphs can be (≈5.7 mm), not the number of lines. Fifteen lines at that
size don't fit an A6 page, so every mushaf page is spread over **two leaves**:
lines 1–8 and 9–15, with generous leading. Surah heads never strand at the foot
of the first leaf; the few leaves that then carry nine lines tighten their
spacing to fit.

| | |
|---|---|
| Leaves | 1206 A6 leaves; pages 1–2 are one leaf each, then mushaf page *N* opens on leaf 2*N*−3 |
| Text | all 83,668 word glyphs of `data/mushaf/qpc-v4.json`, in order, on the printed lines |
| Furniture | the app's gilt double rule, surah + juz heading, page-number pill; Madinah cartouche and calligraphic basmala |
| Navigation | outline of 114 surahs and 30 juz with every page under its juz; page labels `12-1`, `12-2` |

### How it is built

1. **Recover the lines.** `mushaf_layout` only says which lines each ayah
   spans. The calligrapher filled every line to the same width, so within each
   ayah that crosses a line the break is chosen to make the page's lines most
   equal (a small DP over glyph advances). Median line-width spread comes out
   at 0.35%; the only real outliers are pages 1–2 and centred surah endings,
   which are set centred.
2. **Flatten the colour fonts.** Chrome writes COLR glyphs as vector forms at
   ~9 KB a word — the first build was 324 MB. Each page font is rewritten
   (plain `struct`, no extra dependency) without `COLR`/`CPAL` and with every
   glyph reachable at U+E000 + id; a word is then its colour layers stacked in
   ordinary CSS colour, and Chrome embeds compact TrueType instead.
3. **Replay what the shaper did.** Split into layers, the glyphs no longer
   shape as one run, so two things are applied by hand: the page fonts'
   single GPOS pair-kerning lookup, and the base glyph's advance for the 29
   words whose shared layers carry a longer one — otherwise their waqf marks
   drift out of place.
4. **Render in chunks.** All 604 colour fonts in one document outlast Chrome's
   time budget, so pages go through Chrome 20 at a time, four in parallel, and
   are stitched with PyMuPDF.

### Worth knowing

**62 MB** is about the floor for this book: the V4 outlines themselves weigh
~166 KB a page. It is well within what e-readers open, but over GitHub's 50 MB
warning if it is committed.

## mushaf-a6-madinah-complete.pdf

The same mushaf, finished as a book. Built by the same script, whose default
edition it is:

    python3 pdf/build_mushaf_pdf.py            # ~80 s, 1215 leaves, 63 MB

| | |
|---|---|
| Cover | original geometric design in `mushaf_front.py` — star border, sunburst medallion with pendants, the app's «القرآن الكريم» calligraphy — gold on deep green |
| Indexes | surahs (number, name, Makki/Madani, ayat, page) over 6 leaves; juz (name, opening words, surah:ayah, page) over 2. Every row is a link to where it begins |
| Margin | juz, hizb, ¼ ½ ¾ of the hizb, sajdah (15), manzil — beside the line where each begins, the sajdah beside its ayah's end |
| Rukuʿ | all 558, South Asian style: ع in the margin with the rukuʿ's number in the surah above, its ayat beside, its number in the juz below — and a small ع over the closing ayah's marker |
| Labels | `Cover`, `i`–`viii` for the indexes, then `12-1`, `12-2` as before |

Quarter stars (۞), the sajdah sign (۩) and its overline were already drawn by
the V4 glyphs in the right places; the notes add what a printed mushaf keeps in
its margin. Notes sharing a line stack, and the column is nudged so no two ever
overlap. The column costs the text ~6% of its width (glyphs ≈5.3 mm).
