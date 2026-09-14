# A6 tajweed mushaf

`quran-a6-tajweed.pdf` — the whole Quran, Arabic only, on A6 pages at six lines
each, sized to read comfortably on a 6" e-reader.

    python3 pdf/build_quran_pdf.py            # ~1 min, 2560 pages, 25 MB
    python3 pdf/build_quran_pdf.py --surahs 1-3 -o /tmp/preview.pdf

Needs `google-chrome` (or `chromium`) on PATH and `pymupdf`.

## What is in it

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

## How it is built

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

## Two things worth knowing

**Words are boxed (`w { display: inline-block }`).** Left as plain inline text,
Chrome justifies a sparse line by prising the letters of a word apart —
`أَلۡقَى` came out as `أَلۡ  قَى` with the join broken. Boxing each word makes it
atomic, so slack can only go into the spaces between words. This is the one
non-obvious thing in the stylesheet; do not remove it.

**Colour on e-ink.** Most 6" readers are greyscale, where the palette collapses
to grey levels — `ham_wasl` grey and `madda_normal` blue end up close. The
colours are correct and print correctly; they only pay off on a colour panel.

## Tuning

Everything is constants at the top of `build_quran_pdf.py`. `LINES` and
`FONT_MM` are the two that matter: `LINE_H` follows from `LINES`, and dropping
`FONT_MM` to 8.6 buys roughly 10% fewer pages at the cost of smaller type.
