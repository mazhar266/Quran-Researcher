#!/usr/bin/env python3
"""Build a single A6 tajweed-coloured mushaf PDF sized for 6" e-readers.

Layout is done by headless Chrome (HarfBuzz shaping, proper RTL, justification)
from HTML generated out of core.db, then PyMuPDF stamps the frame, running
heads, page numbers and the bookmark outline onto the result.

    python3 pdf/build_quran_pdf.py            # whole Quran
    python3 pdf/build_quran_pdf.py --surahs 1-3

Requires: google-chrome, pymupdf.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "assets" / "db" / "core.db"
OUT = ROOT / "pdf" / "quran-a6-tajweed.pdf"

F_QURAN = ROOT / "assets" / "fonts" / "UthmanicHafs_V22.ttf"
F_SURAH = ROOT / "data" / "fonts" / "surah-name-v4.ttf" / "surah-name-v4.ttf"
F_SURAH2 = ROOT / "data" / "fonts" / "surah-name-v2.ttf" / "surah-name-v2.ttf"
F_COMMON = ROOT / "data" / "fonts" / "quran-common.ttf" / "quran-common.ttf"

# --- page geometry, in millimetres -----------------------------------------
PAGE_W, PAGE_H = 105.0, 148.0          # A6
LINES = 6                              # body lines per page
MARGIN_X = 5.5                         # @page side margin
MARGIN_T, MARGIN_B = 12.0, 11.0        # room for the running head / folio
# A hair under an exact sixth of the text block, so six lines always fit a
# page and a seventh never does.
LINE_H = (PAGE_H - MARGIN_T - MARGIN_B) / LINES - 0.04
FONT_MM = 9.2                          # Quran text size

FRAME = 2.8                            # frame inset from the trimmed edge
HEAD_MM, FOLIO_MM = 5.6, 4.4           # running-head / folio glyph sizes

TEXT_W = PAGE_W - 2 * MARGIN_X         # width the flow is laid out into
FRAME_EM = 8.046875                    # advance of the surah cartouche glyph
HEAD_FS = TEXT_W / FRAME_EM            # cartouche sized to span the text block
NAME_FS = HEAD_FS * 0.94               # surah name, inside the cartouche panel

MM = 72.0 / 25.4                       # millimetre -> PDF point

# --- tajweed palette (mirrors lib/tajweed/tajweed.dart) --------------------
RULE_COLOR = {
    "ham_wasl": "#AAAAAA",
    "slnt": "#AAAAAA",
    "laam_shamsiyah": "#AAAAAA",
    "madda_normal": "#537FFF",
    "madda_permissible": "#4050FF",
    "madda_necessary": "#000EBC",
    "madda_obligatory_monfasel": "#2144C1",
    "madda_obligatory_mottasel": "#2144C1",
    "qalaqah": "#DD0008",
    "ghunnah": "#FF7E1E",
    "ikhafa": "#9400A8",
    "ikhafa_shafawi": "#D500B7",
    "idgham_ghunnah": "#169200",
    "idgham_wo_ghunnah": "#169200",
    "idgham_shafawi": "#58B800",
    "iqlab": "#26BFFD",
    "idgham_mutajanisayn": "#00897B",
    "idgham_mutaqaribayn": "#00695C",
}


def attaches_to_previous(c: int) -> bool:
    """True for marks that must never open a text run: cut from their base
    letter the shaper loses the positioning that draws them."""
    return (
        c == 0x0640                      # tatweel
        or 0x064B <= c <= 0x065F         # harakat, shadda, maddah
        or c == 0x0670                   # dagger alef
        or 0x06D6 <= c <= 0x06DC         # small high marks
        or 0x06DF <= c <= 0x06E8
        or 0x06EA <= c <= 0x06ED
        or 0x0610 <= c <= 0x061A
        or 0x08D3 <= c <= 0x08FF
    )


def snap(text: str, start: int, end: int) -> tuple[int, int]:
    """Widen [start, end) onto whole letter-plus-marks clusters."""
    while start > 0 and attaches_to_previous(ord(text[start])):
        start -= 1
    while end < len(text) and attaches_to_previous(ord(text[end])):
        end += 1
    return start, end


def ayah_html(text: str, spans: list) -> str:
    """One ayah as coloured HTML runs, each word boxed on its own.

    Every word is its own inline-block: left as plain inline text, Chrome
    justifies a sparse line by prising the letters of a word apart, which
    breaks the joins of the script. Boxed, a word is atomic and the slack
    can only go into the spaces between words.
    """
    n = len(text)
    snapped = [
        (*snap(text, max(0, min(a, n)), max(0, min(b, n))), rule)
        for a, b, rule in spans
    ]

    words, at = [], 0
    for word in text.split(" "):
        lo, hi = at, at + len(word)
        at = hi + 1
        cuts = {lo, hi}
        for a, b, _ in snapped:
            if a < hi and b > lo:
                cuts.update((max(a, lo), min(b, hi)))
        runs: list[tuple[str | None, str]] = []
        for a, b in zip(sorted(cuts), sorted(cuts)[1:]):
            rule = next((r for s, e, r in snapped if s <= a and b <= e), None)
            color = RULE_COLOR.get(rule) if rule else None
            if runs and runs[-1][0] == color:          # keep runs whole
                runs[-1] = (color, runs[-1][1] + text[a:b])
            else:
                runs.append((color, text[a:b]))
        words.append("<w>%s</w>" % "".join(
            f'<c style="color:{c}">{html.escape(t)}</c>' if c else html.escape(t)
            for c, t in runs))

    # The ayah number rides on the last word rather than floating free.
    if len(words) > 1 and text.split(" ")[-1][:1] in "٠١٢٣٤٥٦٧٨٩":
        words[-2:] = ["\u00a0".join(words[-2:])]
    return " ".join(words)


# --- data ------------------------------------------------------------------
def load(db: Path, wanted: range | None):
    """Surah metadata plus every ayah's tajweed text, spans and juz."""
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    surahs = {
        s: dict(name=na, arabic=ar, place=pl, count=n, bismillah=bool(b))
        for s, na, ar, pl, n, b in con.execute(
            "select id, name_simple, name_arabic, revelation_place,"
            " verses_count, bismillah_pre from surahs order by id"
        )
    }
    juz = {(s, a): j for s, a, j in con.execute("select surah, ayah, juz from ayahs")}
    ayahs = []
    for s, a, text, spans in con.execute(
        "select surah, ayah, text, spans from tajweed_ayah order by surah, ayah"
    ):
        if wanted and s not in wanted:
            continue
        ayahs.append((s, a, text, json.loads(spans), juz[(s, a)]))
    con.close()
    return surahs, ayahs


def bismillah_html(ayahs) -> str:
    """Al-Fatihah 1:1 without its ayah number — the basmala every surah but
    at-Tawbah opens with, coloured like the rest of the text."""
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    text, spans = con.execute(
        "select text, spans from tajweed_ayah where surah=1 and ayah=1"
    ).fetchone()
    con.close()
    text = re.sub(r"\s*[٠-٩]+$", "", text)
    return ayah_html(text, [s for s in json.loads(spans) if s[1] <= len(text)])


# --- HTML ------------------------------------------------------------------
def document(surahs, ayahs) -> str:
    """The whole body as one continuous flow; Chrome does the pagination."""
    parts, current, body = [], None, []

    def flush():
        if body:
            parts.append(f'<p>{" ".join(body)}</p>')
            body.clear()

    basmala = bismillah_html(ayahs)
    for s, a, text, spans, _ in ayahs:
        if s != current:
            flush()
            current = s
            parts.append(
                f'<h2><span class="frame"></span>'
                f'<span class="nm">{chr(0xE000 + s)}</span></h2>'
            )
            if surahs[s]["bismillah"]:
                parts.append(f'<p class="bsm">{basmala}</p>')
        body.append(ayah_html(text, spans))
    flush()

    def url(p: Path) -> str:
        return p.resolve().as_uri()

    return f"""<!doctype html><meta charset="utf-8"><title>Quran</title><style>
@font-face {{ font-family: Quran;  src: url("{url(F_QURAN)}"); }}
@font-face {{ font-family: SurahNm; src: url("{url(F_SURAH2)}"); }}
@font-face {{ font-family: Common;  src: url("{url(F_COMMON)}"); }}
@page {{
  size: {PAGE_W}mm {PAGE_H}mm;
  margin: {MARGIN_T}mm {MARGIN_X}mm {MARGIN_B}mm;
}}
html, body {{ margin: 0; padding: 0; }}
body {{
  font-family: Quran, serif;
  font-size: {FONT_MM}mm;
  line-height: {LINE_H}mm;
  direction: rtl;
  text-align: justify;
  text-align-last: center;
  -webkit-font-feature-settings: "liga", "calt", "rlig";
  font-variant-ligatures: common-ligatures contextual;
}}
c {{ font-style: normal; }}
w {{ display: inline-block; }}
p {{ margin: 0; orphans: 1; widows: 1; }}
p.bsm {{ text-align: center; text-align-last: center; }}

/* A surah head occupies exactly one body line of the 6-line grid. */
h2 {{
  margin: 0;
  height: {LINE_H}mm;
  line-height: {LINE_H}mm;
  position: relative;
  text-align: center;
  break-after: avoid;
  break-inside: avoid;
}}
h2 .frame {{
  font-family: Common;
  font-size: {HEAD_FS:.3f}mm;
  color: #6b5a3e;
  line-height: 1;
}}
h2 .nm {{
  font-family: SurahNm;
  font-size: {NAME_FS:.3f}mm;
  position: absolute;
  left: 0; right: 0;
  top: 50%;
  transform: translateY(-58%);
  line-height: 1;
}}
</style>
{"".join(parts)}
"""


# --- Chrome ----------------------------------------------------------------
def chrome_pdf(html_text: str, out: Path) -> None:
    exe = next(
        (p for p in ("google-chrome", "chromium", "chromium-browser",
                     "google-chrome-stable") if shutil.which(p)), None
    )
    if not exe:
        sys.exit("google-chrome / chromium not found on PATH")
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "quran.html"
        src.write_text(html_text, encoding="utf-8")
        subprocess.run(
            [exe, "--headless", "--disable-gpu", "--no-sandbox",
             "--no-pdf-header-footer", "--run-all-compositor-stages-before-draw",
             "--virtual-time-budget=600000", f"--user-data-dir={tmp}/profile",
             f"--print-to-pdf={out}", src.as_uri()],
            check=True, capture_output=True,
        )


# --- where each ayah landed ------------------------------------------------
DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def page_ayahs(doc: pymupdf.Document, ayahs) -> list[tuple[int, int]]:
    """For every page, the [first, last] index into `ayahs` it shows.

    The only Arabic-Indic digits in the flow are the ayah numbers, so reading
    them off each page replays the ayah sequence and says exactly where every
    ayah ended up. Extraction hands back the digits of a number in visual
    order, so each run is re-read left to right from the glyph positions.
    """
    body = pymupdf.Rect(0, MARGIN_T * MM, PAGE_W * MM, (PAGE_H - MARGIN_B) * MM)
    out, ptr = [], 0
    for page in doc:
        found = []
        for block in page.get_text("rawdict", clip=body)["blocks"]:
            for line in block.get("lines", ()):
                for span in line.get("spans", ()):
                    run = []
                    for ch in span["chars"]:
                        if "٠" <= ch["c"] <= "٩":
                            run.append((ch["bbox"][0], ch["c"]))
                        elif run:
                            found.append((line["bbox"][1], run))
                            run = []
                    if run:
                        found.append((line["bbox"][1], run))
        found.sort(key=lambda f: (round(f[0], 1), -max(x for x, _ in f[1])))

        first = min(ptr, len(ayahs) - 1)
        for _, run in found:
            digits = "".join(c for _, c in run).translate(DIGITS)
            reading = {int(digits[::-1]), int(digits)}
            hit = next((i for i in range(ptr, min(ptr + 4, len(ayahs)))
                        if ayahs[i][1] in reading), None)
            if hit is not None:
                ptr = hit + 1
        out.append((first, max(first, ptr - 1)))
    return out


# --- frame, running heads, folios, outline ---------------------------------
def decorate(doc: pymupdf.Document, surahs, ayahs, index) -> None:
    ink = (0.42, 0.35, 0.24)                    # muted gold-brown furniture
    left, right = FRAME * MM, (PAGE_W - FRAME) * MM
    top, bottom = 11.0 * MM, 138.0 * MM

    for pno, page in enumerate(doc):
        page.insert_font(fontname="SN", fontfile=str(F_SURAH))
        page.insert_font(fontname="CM", fontfile=str(F_COMMON))
        page.insert_font(fontname="QR", fontfile=str(F_QURAN))

        page.draw_rect(pymupdf.Rect(left, top, right, bottom),
                       color=ink, width=0.7)
        page.draw_rect(pymupdf.Rect(left + 1.2, top + 1.2, right - 1.2,
                                    bottom - 1.2), color=ink, width=0.3)

        i0, i1 = index[pno]
        # The head names whatever surah and juz the page opens in.
        surah, juz = ayahs[i0][0], ayahs[i0][4]

        page.insert_text((right - _w(F_SURAH, chr(0xE000 + surah), HEAD_MM),
                          8.6 * MM),
                         chr(0xE000 + surah), fontname="SN",
                         fontsize=HEAD_MM * MM, color=ink)
        page.insert_text((left, 8.6 * MM), chr(0xE000 + juz), fontname="CM",
                         fontsize=HEAD_MM * 0.82 * MM, color=ink)

        folio = str(pno + 1).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))
        page.insert_text(((PAGE_W * MM - _w(F_QURAN, folio, FOLIO_MM)) / 2,
                          143.6 * MM),
                         folio, fontname="QR", fontsize=FOLIO_MM * MM, color=ink)


def _w(font: Path, text: str, size_mm: float) -> float:
    return _font(font).text_length(text, size_mm * MM)


_CACHE: dict[Path, pymupdf.Font] = {}


def _font(path: Path) -> pymupdf.Font:
    if path not in _CACHE:
        _CACHE[path] = pymupdf.Font(fontfile=str(path))
    return _CACHE[path]


def outline(doc: pymupdf.Document, surahs, ayahs, index) -> None:
    """Two top-level groups so any reader's TOC can reach a surah or a juz."""
    first_page = {}
    for pno, (i0, i1) in enumerate(index):
        for i in range(i0, i1 + 1):
            s, a, *_ , j = ayahs[i]
            first_page.setdefault(("s", s), pno + 1)
            first_page.setdefault(("j", j), pno + 1)

    toc = [[1, "Surahs · السور", 1]]
    for s, meta in surahs.items():
        if ("s", s) in first_page:
            toc.append([2, f"{s}. {meta['name']} · {meta['arabic']}",
                        first_page[("s", s)]])
    toc.append([1, "Juz · الأجزاء", 1])
    for j in range(1, 31):
        if ("j", j) in first_page:
            toc.append([2, f"Juz {j}", first_page[("j", j)]])
    doc.set_toc(toc)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--surahs", help="range such as 1-3, for quick previews")
    ap.add_argument("-o", "--out", type=Path, default=OUT)
    args = ap.parse_args()

    wanted = None
    if args.surahs:
        lo, _, hi = args.surahs.partition("-")
        wanted = range(int(lo), int(hi or lo) + 1)

    surahs, ayahs = load(DB, wanted)
    print(f"{len(ayahs)} ayat -> laying out with Chrome ...", flush=True)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    raw = args.out.with_suffix(".chrome.pdf")
    chrome_pdf(document(surahs, ayahs), raw)

    doc = pymupdf.open(raw)
    index = page_ayahs(doc, ayahs)
    decorate(doc, surahs, ayahs, index)
    outline(doc, surahs, ayahs, index)
    doc.set_metadata({
        "title": "القرآن الكريم — Tajweed Mushaf (A6)",
        "author": "King Fahd Glorious Quran Printing Complex (text & fonts)",
        "subject": "Uthmani Hafs text with tajweed colouring, 6 lines per page",
        "creator": "pdf/build_quran_pdf.py",
    })
    doc.save(args.out, garbage=1, deflate=True, use_objstms=1)
    raw.unlink()
    print(f"{doc.page_count} pages -> {args.out}")


if __name__ == "__main__":
    main()
