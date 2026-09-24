#!/usr/bin/env python3
"""Build the app's mushaf mode as an A6 PDF for 6" e-readers.

The text is the 604-page Madinah mushaf in the QPC V4 page fonts the app's
mushaf view uses — one glyph per word, tajweed colour baked into the font —
set line for line as printed. A 15-line page is too small to read on A6, so
each mushaf page is spread over two leaves (lines 1-8 and 9-15), which lets
the glyphs run as large as the page width allows.

Two editions: `plain` is that mushaf alone; `complete` (the default) adds a
cover, clickable surah and juz indexes, and the marginal notes of a printed
mushaf — juz, hizb and its quarters, sajdah, manzil — with rukuʿ signs in the
margin and over the ayah they close. The notes take a margin column, so the
complete edition's text runs about 6% smaller.

    python3 pdf/build_mushaf_pdf.py                     # complete edition
    python3 pdf/build_mushaf_pdf.py --edition plain
    python3 pdf/build_mushaf_pdf.py --pages 1-5 -o /tmp/preview.pdf

Requires: google-chrome, pymupdf.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import statistics
import struct
import tempfile
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, replace
from functools import lru_cache
from pathlib import Path

import pymupdf

import mushaf_front
from build_quran_pdf import DB, F_COMMON, F_QURAN, F_SURAH, F_SURAH2, MM, ROOT, chrome_pdf

PAGE_FONTS = ROOT / "data" / "fonts" / "ttf"                 # p1.ttf .. p604.ttf
WORDS = ROOT / "data" / "mushaf" / "qpc-v4.json" / "qpc-v4.json"
PAGES = 604
# Chrome chokes on all 604 colour page fonts in one document, so pages are
# laid out in chunks, in parallel, and the results stitched together.
CHUNK, WORKERS = 20, 4

# --- leaf geometry, in millimetres -----------------------------------------
PAGE_W, PAGE_H = 105.0, 148.0          # A6
TEXT_TOP, TEXT_BOTTOM = 12.5, 136.0
SLOTS = 8                              # line slots per leaf

# A full Madinah line is ~16.4 em wide and 17.0 em at the 99th percentile;
# that is what the text width has to hold. The handful of wider pages shrink
# a few percent rather than overflow.
LINE_EM = 17.0


@dataclass(frozen=True)
class Edition:
    name: str
    out: Path
    frame_left: float                  # outer rule, from each trimmed edge
    frame_right: float
    complete: bool                     # cover, indexes and marginal notes
    inset: float = 2.0                 # outer rule to text
    mono: bool = False                 # black text: one glyph a word, no layers

    @property
    def text_left(self) -> float:
        return self.frame_left + self.inset

    @property
    def text_w(self) -> float:
        return PAGE_W - self.frame_right - self.inset - self.text_left

    @property
    def font(self) -> float:
        return self.text_w / LINE_EM


EDITIONS = {
    "plain": Edition("plain", ROOT / "pdf" / "mushaf-a6-madinah.pdf", 2.5, 2.5, False),
    # The notes live in a column outside the frame on the left, as a printed
    # mushaf keeps them in its outer margin.
    "complete": Edition("complete", ROOT / "pdf" / "mushaf-a6-madinah-complete.pdf",
                        9.6, 1.6, True),
}
NOTE_W, NOTE_X = 7.2, 1.2              # margin column of the complete edition

# The app's light paper palette (lib/features/mushaf/paper.dart), on white:
# e-ink turns a tinted ground into grey that only costs contrast.
GILT, ACCENT = "#9A7B3F", "#146B4E"

SPACE_EM = 0.04                        # the page fonts' space advance


# --- page fonts -------------------------------------------------------------
# Chrome draws COLR colour glyphs into the PDF as vector forms at ~9 KB a word,
# which put the book over 300 MB. Instead each page font is rewritten without
# its colour tables and with every glyph reachable at U+E000 + glyph id; a word
# is then set as its colour layers stacked on one another, in ordinary colour,
# and Chrome embeds the outlines as compact TrueType.
PUA = 0xE000


def sfnt_tables(data: bytes) -> dict[str, tuple[int, int]]:
    """Table tag -> (offset, length)."""
    count = struct.unpack_from(">H", data, 4)[0]
    tables = {}
    for i in range(count):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        tables[tag.decode("latin-1")] = (offset, length)
    return tables


def build_sfnt(tables: dict[str, bytes]) -> bytes:
    def checksum(t: bytes) -> int:
        t += b"\0" * (-len(t) % 4)
        return sum(struct.unpack(f">{len(t) // 4}I", t)) & 0xFFFFFFFF

    tags = sorted(tables)
    n, pow2 = len(tags), 1 << (len(tags).bit_length() - 1)
    out = struct.pack(">IHHHH", 0x00010000, n, pow2 * 16,
                      pow2.bit_length() - 1, (n - pow2) * 16)
    offset, body = 12 + 16 * n, b""
    for tag in tags:
        t = tables[tag]
        out += struct.pack(">4sIII", tag.encode("latin-1"), checksum(t),
                           offset + len(body), len(t))
        body += t + b"\0" * (-len(t) % 4)
    return out + body


class PageFont:
    """One QPC V4 page font: advances, glyph ids and COLR colour layers."""

    def __init__(self, page: int) -> None:
        self.page = page
        self.data = (PAGE_FONTS / f"p{page}.ttf").read_bytes()
        self.font = pymupdf.Font(fontbuffer=self.data)
        self.tables = sfnt_tables(self.data)
        off, _ = self.tables["COLR"]
        _, bases, base_at, layer_at, _ = struct.unpack_from(">HHIIH", self.data, off)
        self.layers: dict[int, list[tuple[int, int]]] = {}
        for i in range(bases):
            gid, first, count = struct.unpack_from(">3H", self.data, off + base_at + 6 * i)
            self.layers[gid] = [struct.unpack_from(">2H", self.data, off + layer_at + 4 * j)
                                for j in range(first, first + count)]
        self.em = struct.unpack_from(">H", self.data, self.tables["head"][0] + 18)[0]
        metrics = struct.unpack_from(">H", self.data, self.tables["hhea"][0] + 34)[0]
        # hmtx is (advance, left side bearing) pairs; keep the advances.
        self.advances = struct.unpack_from(f">{2 * metrics}H", self.data,
                                           self.tables["hmtx"][0])[0::2]
        self.kern = self._pair_kerning()

    def _pair_kerning(self) -> dict[tuple[int, int], tuple[int, int]]:
        """(first, second) glyph id -> the XAdvance each gets, from GPOS.

        A waqf mark shares a word entry with the word it sits on and has no
        advance of its own; a single pair-kerning lookup places it. Set glyph
        by glyph, the shaper never sees the pair, so the offset is applied by
        hand. Every page font has exactly this one PairPos format 1 lookup.
        """
        base, _ = self.tables["GPOS"]
        u16 = lambda at: struct.unpack_from(">H", self.data, at)[0]
        lookups = base + u16(base + 8)
        kern = {}
        for li in range(u16(lookups)):
            lookup = lookups + u16(lookups + 2 + 2 * li)
            assert u16(lookup) == 2, "only pair adjustment is expected"
            for si in range(u16(lookup + 4)):
                sub = lookup + u16(lookup + 6 + 2 * si)
                fmt, cov, vf1, vf2, sets = struct.unpack_from(">5H", self.data, sub)
                assert fmt == 1 and not (vf1 | vf2) & ~0x0004, "only XAdvance pairs"
                size1, size2 = 2 * bin(vf1).count("1"), 2 * bin(vf2).count("1")
                firsts = self._coverage(sub + cov)
                for i in range(sets):
                    pairs = sub + u16(sub + 10 + 2 * i)
                    for r in range(u16(pairs)):
                        at = pairs + 2 + r * (2 + size1 + size2)
                        second = u16(at)
                        dx1 = struct.unpack_from(">h", self.data, at + 2)[0] if size1 else 0
                        dx2 = struct.unpack_from(">h", self.data, at + 2 + size1)[0] if size2 else 0
                        kern[(firsts[i], second)] = (dx1, dx2)
        return kern

    def _coverage(self, at: int) -> list[int]:
        fmt, count = struct.unpack_from(">2H", self.data, at)
        if fmt == 1:
            return list(struct.unpack_from(f">{count}H", self.data, at + 4))
        glyphs = []
        for r in range(count):
            start, end, _ = struct.unpack_from(">3H", self.data, at + 4 + 6 * r)
            glyphs.extend(range(start, end + 1))
        return glyphs

    def advance_of(self, gid: int) -> int:
        return self.advances[min(gid, len(self.advances) - 1)]

    def stacks(self, text: str, mono: bool = False) -> list[tuple[list[tuple[int, int]], float, float | None]]:
        """Per glyph of `text`: its (layer glyph id, palette index) layers,
        the kerning added to its advance, and — only when a layer's own
        advance disagrees with the glyph's — the width its stack must keep,
        all in em. COLR draws every layer at the base glyph's origin with the
        base glyph's advance; a few shared layers carry a longer one."""
        gids = [self.font.has_glyph(ord(ch)) for ch in text]
        extra = [0] * len(gids)
        for i, (a, b) in enumerate(zip(gids, gids[1:])):
            dx1, dx2 = self.kern.get((a, b), (0, 0))
            extra[i] += dx1
            extra[i + 1] += dx2
        out = []
        for g, dx in zip(gids, extra):
            layers = [(g, 0xFFFF)] if mono else self.layers.get(g, [(g, 0xFFFF)])
            odd = any(self.advance_of(lg) != self.advance_of(g) for lg, _ in layers)
            out.append((layers, dx / self.em, self.advance_of(g) / self.em if odd else None))
        return out

    def advance(self, text: str) -> float:
        return (sum(self.font.glyph_advance(ord(ch)) for ch in text)
                + sum(dx for _, dx, _ in self.stacks(text)))

    def palette(self) -> list[str]:
        off, _ = self.tables["CPAL"]
        _, entries, _, _, records = struct.unpack_from(">4HI", self.data, off)
        first = struct.unpack_from(">H", self.data, off + 12)[0]
        return ["#%02X%02X%02X" % struct.unpack_from(">3B", self.data, off + records + 4 * i)[::-1]
                for i in range(first, first + entries)]

    def layer_font(self) -> bytes:
        glyphs = struct.unpack_from(">H", self.data, self.tables["maxp"][0] + 4)[0]
        assert PUA + glyphs <= 0xF8FF
        # cmap: one format-4 segment mapping U+E000 + n to glyph n.
        sub = struct.pack(">7H", 4, 32, 0, 4, 4, 1, 0)
        sub += struct.pack(">2H2x2H2H2H", PUA + glyphs - 1, 0xFFFF, PUA, 0xFFFF,
                           -PUA & 0xFFFF, 1, 0, 0)
        tables = {tag: self.data[o:o + n] for tag, (o, n) in self.tables.items()
                  if tag not in ("COLR", "CPAL", "cmap")}
        tables["cmap"] = struct.pack(">HHHHI", 0, 1, 3, 1, 12) + sub
        return build_sfnt(tables)


@lru_cache(maxsize=8)
def page_font(page: int) -> PageFont:
    return PageFont(page)


# --- the printed lines ------------------------------------------------------
class Mushaf:
    """Word glyphs, ayah line ranges and surah metadata from core.db."""

    def __init__(self) -> None:
        con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
        self.layout = {(s, a): (p, l0, l1) for s, a, p, l0, l1 in
                       con.execute("select * from mushaf_layout")}
        self.order = [(s, a) for s, a in
                      con.execute("select surah, ayah from ayahs order by id")]
        self.juz = {(s, a): j for s, a, j in
                    con.execute("select surah, ayah, juz from ayahs")}
        self.surahs = {s: dict(name=n, arabic=ar, bismillah=bool(b), place=pl, verses=v)
                       for s, n, ar, b, pl, v in
                       con.execute("select id, name_simple, name_arabic, bismillah_pre,"
                                   " revelation_place, verses_count from surahs")}
        self.division = {(s, a): dict(juz=j, hizb=h, rub=r, ruku=k, manzil=mz, sajdah=sj)
                         for s, a, j, h, r, k, mz, sj in
                         con.execute("select surah, ayah, juz, hizb, rub, ruku, manzil,"
                                     " sajda_type from ayahs")}
        con.close()
        self.words: dict[tuple[int, int], list[str]] = {}
        raw = json.loads(WORDS.read_text(encoding="utf-8"))
        for key in sorted(raw, key=lambda k: tuple(map(int, k.split(":")))):
            s, a, _ = map(int, key.split(":"))
            self.words.setdefault((s, a), []).append(raw[key]["text"])
        self.notes, self.ruku_ends = self._notes()

    def _notes(self) -> tuple[dict[tuple[int, int], list], set[tuple[int, int]]]:
        """Marginal notes keyed by (page, line), in reading order, and the
        ayahs that close a rukuʿ.

        A quarter, hizb, juz or manzil is noted on the line where its first
        ayah begins; a sajdah and a rukuʿ on the line where the ayah ends.
        Rukuʿ carry the South Asian numbering: the rukuʿ's place in its surah
        (above), its ayah count (beside) and its place in the juz (below).
        """
        notes: dict[tuple[int, int], list] = defaultdict(list)
        ruku_ends = set()
        in_surah: dict[int, int] = defaultdict(int)
        in_juz: dict[int, int] = defaultdict(int)
        ruku_start = 0
        for i, key in enumerate(self.order):
            d = self.division[key]
            page, first_line, last_line = self.layout[key]
            before = self.division[self.order[i - 1]] if i else None
            if before and d["rub"] != before["rub"]:
                if (d["rub"] - 1) % 8 == 0:
                    note = ("juz", d["juz"])
                elif (d["rub"] - 1) % 4 == 0:
                    note = ("hizb", d["hizb"])
                else:
                    note = ("quarter", (d["rub"] - 1) % 4, d["hizb"])
                notes[(page, first_line)].append(((i, 0), note))
            if before and d["manzil"] != before["manzil"]:
                notes[(page, first_line)].append(((i, 1), ("manzil", d["manzil"])))
            if d["sajdah"]:
                notes[(page, last_line)].append(((i, 2), ("sajdah",)))
            after = self.division[self.order[i + 1]] if i + 1 < len(self.order) else None
            if after is None or after["ruku"] != d["ruku"]:
                in_surah[key[0]] += 1
                in_juz[d["juz"]] += 1
                notes[(page, last_line)].append(
                    ((i, 3), ("ruku", in_surah[key[0]], i + 1 - ruku_start, in_juz[d["juz"]])))
                ruku_ends.add(key)
                ruku_start = i + 1
        return {k: [n for _, n in sorted(v)] for k, v in notes.items()}, ruku_ends

    def lines(self, page: int) -> dict[int, dict]:
        """Every line of a page, keyed 1-15: text, surah head or basmala.

        The data only says which lines each ayah spans, not where a line
        breaks inside an ayah. The calligrapher filled every line to the same
        width, so the breaks are recovered by choosing, within each ayah that
        crosses a line, the split that makes the page's lines most equal.
        """
        font = page_font(page)
        ayahs = [k for k in self.order if self.layout[k][0] == page]
        seq = []                                    # (em width, glyphs, ayah)
        for k in ayahs:
            for w in self.words[k]:
                seq.append((font.advance(w), w, k))
        first, last = {}, {}
        for j, (_, _, k) in enumerate(seq):
            first.setdefault(k, j)
            last[k] = j

        used = sorted({l for k in ayahs
                       for l in range(self.layout[k][1], self.layout[k][2] + 1)})
        choices = []                                # break before word j
        for a, b in zip(used, used[1:]):
            crossing = [k for k in ayahs
                        if self.layout[k][1] <= a and self.layout[k][2] >= b]
            if crossing:
                k = crossing[0]
                choices.append(range(first[k] + 1, last[k] + 1))
            else:
                ending = [k for k in ayahs if self.layout[k][2] == a]
                choices.append([last[ending[-1]] + 1])

        def width(i: int, j: int) -> float:
            return sum(x[0] for x in seq[i:j]) + SPACE_EM * max(0, j - i - 1)

        # Total width is fixed, so minimising the sum of squares equalises lines.
        best: dict[int, tuple[float, list[int]]] = {0: (0.0, [])}
        for options in choices:
            nxt: dict[int, tuple[float, list[int]]] = {}
            for j in options:
                for i, (cost, path) in best.items():
                    if i < j and cost + width(i, j) ** 2 < nxt.get(j, (float("inf"),))[0]:
                        nxt[j] = (cost + width(i, j) ** 2, path + [j])
            best = nxt
        _, path = min((cost + width(i, len(seq)) ** 2, path)
                      for i, (cost, path) in best.items())
        cuts = [0, *path, len(seq)]

        out = {}
        for line, i, j in zip(used, cuts, cuts[1:]):
            out[line] = dict(kind="text", words=[seq[x][1] for x in range(i, j)],
                             width=width(i, j), ayah=seq[i][2],
                             closes=[seq[x][2] if x == last[seq[x][2]] else None
                                     for x in range(i, j)])
        for k in ayahs:
            s, a = k
            if a != 1:
                continue
            line = self.layout[k][1]
            if s == 1:                              # al-Fatihah's basmala is 1:1
                out[line - 1] = dict(kind="head", surah=s, ayah=k)
            elif self.surahs[s]["bismillah"]:
                out[line - 2] = dict(kind="head", surah=s, ayah=k)
                out[line - 1] = dict(kind="bism", ayah=k)
            else:
                out[line - 1] = dict(kind="head", surah=s, ayah=k)
        return dict(sorted(out.items()))


def leaves(page: int, lines: dict[int, dict]) -> list[list[int]]:
    """Split a page's line numbers across leaves, never stranding a surah
    head (or its basmala) at the foot of the first leaf."""
    nums = list(lines)
    if len(nums) <= SLOTS:                          # the two opening pages
        return [nums]
    cut = SLOTS
    while cut > 1 and lines.get(cut, {}).get("kind") in ("head", "bism"):
        cut -= 1
    return [[n for n in nums if n <= cut], [n for n in nums if n > cut]]


# --- HTML -------------------------------------------------------------------
def arabic_digits(n: int) -> str:
    return str(n).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))


# --- marginal notes ------------------------------------------------------------
# Label type is sized so the widest label, «الحزب» at 1.95 em, clears the ornament.
NOTE_ROW = 3.1                          # mm per line of text inside a note
NOTE_GAP = 1.2


def _digits(n: int) -> str:
    return f'<span class="n">{arabic_digits(n)}</span>'


def _shape(kind: str, w: float, h: float) -> str:
    """The ornament behind a note, as SVG in millimetres."""
    if kind in ("juz", "hizb", "quarter"):
        # A lozenge-ended cartouche; the juz one filled and double-ruled.
        p, i = 1.6, 0.65
        outer = [(w / 2, 0), (w, p), (w, h - p), (w / 2, h), (0, h - p), (0, p)]
        inner = [(w / 2, i), (w - i, p + i / 2), (w - i, h - p - i / 2), (w / 2, h - i),
                 (i, h - p - i / 2), (i, p + i / 2)]
        pts = lambda ps: " ".join(f"{x:.2f},{y:.2f}" for x, y in ps)
        fill = "var(--tint)" if kind == "juz" else "#fff"
        body = (f'<polygon points="{pts(outer)}" fill="{fill}" stroke="var(--gilt)" stroke-width="0.3"/>'
                f'<polygon points="{pts(inner)}" fill="none" stroke="var(--gilt)" '
                f'stroke-width="{0.3 if kind == "juz" else 0.14}"/>')
    elif kind == "sajdah":                      # a mihrab arch
        body = (f'<path d="M0.15,{h} V2.9 Q0.15,0.9 {w / 2},0.15 Q{w - 0.15},0.9 {w - 0.15},2.9 V{h} Z" '
                f'fill="#fff" stroke="var(--gilt)" stroke-width="0.3"/>')
    elif kind == "manzil":
        body = (f'<rect x="0.15" y="0.15" width="{w - 0.3}" height="{h - 0.3}" rx="1.3" '
                f'fill="#fff" stroke="var(--gilt)" stroke-width="0.25"/>')
    else:
        return ""
    return (f'<svg class="shape" viewBox="0 0 {w} {h}" width="{w}mm" height="{h}mm">'
            f'{body}</svg>')


def note_html(note: tuple) -> tuple[float, str]:
    """(height in mm, markup) for one marginal note, positioned later."""
    kind = note[0]
    if kind == "ruku":
        _, surah_no, count, juz_no = note
        inner = (f'<span class="rn">{arabic_digits(surah_no)}</span>'
                 f'<span class="rk"><span>ع</span><span class="rc">{arabic_digits(count)}</span></span>'
                 f'<span class="rn">{arabic_digits(juz_no)}</span>')
        return 11.4, f'<div class="note ruku">{inner}</div>'
    rows = {
        "juz": lambda: ["الجزء", _digits(note[1])],
        "hizb": lambda: ["الحزب", _digits(note[1])],
        "quarter": lambda: {1: ["ربع"], 2: ["نصف"], 3: ["ثلاثة", "أرباع"]}[note[1]]
                           + ["الحزب", _digits(note[2])],
        "manzil": lambda: ["منزل", _digits(note[1])],
        "sajdah": lambda: ['<span class="mark">۩</span>', "سجدة"],
    }[kind]()
    pad = {"juz": 3.6, "hizb": 3.4, "quarter": 3.4, "manzil": 1.8, "sajdah": 3.0}[kind]
    h = len(rows) * NOTE_ROW + pad
    body = "".join(f"<span>{r}</span>" for r in rows)
    return h, (f'<div class="note {kind}">{_shape(kind, NOTE_W, h)}'
               f'<div class="rows" style="padding-top:{pad * (0.62 if kind == "sajdah" else 0.5):.2f}mm">'
               f'{body}</div></div>')


def margin_notes(m: Mushaf, page: int, nums: list[int], top: float, pitch: float) -> str:
    """Notes stacked beside their lines, nudged apart so none overlap and all
    stay within the text block."""
    groups = []                                      # [top, [(height, html)]]
    for slot, n in enumerate(nums):
        items = [note_html(note) for note in m.notes.get((page, n), [])]
        if items:
            total = sum(h for h, _ in items) + NOTE_GAP * (len(items) - 1)
            groups.append([top + (slot + 0.5) * pitch - total / 2, items, total])
    floor = TEXT_TOP
    for g in groups:
        g[0] = max(g[0], floor)
        floor = g[0] + g[2] + NOTE_GAP
    ceiling = TEXT_BOTTOM
    for g in reversed(groups):
        g[0] = min(g[0], ceiling - g[2])
        ceiling = g[0] - NOTE_GAP
    out = []
    for y, items, _ in groups:
        for h, markup in items:
            out.append(markup.replace('class="note', f'style="top:{y:.2f}mm;height:{h:.2f}mm" class="note', 1))
            y += h + NOTE_GAP
    return "".join(out)


# --- HTML -------------------------------------------------------------------
def arabic_digits(n: int) -> str:
    return str(n).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))


def leaf_html(m: Mushaf, page: int, lines: dict[int, dict], nums: list[int],
              ed: Edition) -> str:
    text = [l for l in lines.values() if l["kind"] == "text"]
    opening = page <= 2
    if opening:
        # Al-Fatihah and the start of al-Baqarah are set in a narrow column of
        # uneven lines: centre each at its natural spacing, and let the type
        # grow until the longest line meets the text block.
        natural_gap = 0.12
        longest = max(l["width"] + natural_gap * (len(l["words"]) - 1) for l in text)
        size, median = min(ed.font * 1.25, ed.text_w / longest), 0.0
    else:
        # Every other line is justified to the block, bar the few the
        # calligrapher left short (some surah endings), which are centred.
        median = statistics.median(l["width"] for l in text)
        full = [l for l in text if l["width"] >= 0.9 * median]
        size = min(ed.font, ed.text_w / max(l["width"] for l in full))
        natural_gap = statistics.median(
            (ed.text_w / size - l["width"]) / (len(l["words"]) - 1)
            for l in full if len(l["words"]) > 1)

    # Keeping a surah head off the foot of the first leaf can push nine lines
    # onto the second; only then does the leaf tighten its line pitch.
    pitch = (TEXT_BOTTOM - TEXT_TOP) / max(SLOTS, len(nums))
    top = TEXT_TOP + (SLOTS - len(nums)) * pitch / 2 if opening else TEXT_TOP
    font = page_font(page)

    # A stack is left-to-right inside so its layers sit on the base glyph's
    # origin; its kerning is room on its right, towards the glyph before it in
    # the word — where the shaper would put it.
    def stack(layers, dx, width):
        style = (f"margin-right:{dx:.4f}em;" if dx else "") + (
            f"grid-template-columns:{width:.4f}em" if width is not None else "")
        return (f'<s style="{style}">' if style else "<s>") + "".join(
            f'<i class="c{c}">{chr(PUA + g)}</i>' if c != 0xFFFF
            else f"<i>{chr(PUA + g)}</i>" for g, c in layers) + "</s>"

    rows = []
    for slot, n in enumerate(nums):
        line = lines[n]
        y = top + slot * pitch
        if line["kind"] == "head":
            rows.append(
                f'<div class="ln head" style="top:{y:.2f}mm">'
                f'<span class="cartouche"></span>'
                f'<span class="sname">{chr(0xE000 + line["surah"])}</span></div>')
        elif line["kind"] == "bism":
            rows.append(f'<div class="ln bism" style="top:{y:.2f}mm">﷽</div>')
        else:
            short = line["width"] < 0.9 * median or opening
            style = (f"justify-content:center;column-gap:{natural_gap:.3f}em"
                     if short else "justify-content:space-between")
            words = []
            for w, closes in zip(line["words"], line["closes"]):
                # The ayah marker that closes a rukuʿ carries a small ʿayn.
                mark = ed.complete and closes in m.ruku_ends
                words.append(("<b class=\"rk\">" if mark else "<b>")
                             + "".join(stack(*st) for st in font.stacks(w, ed.mono)) + "</b>")
            rows.append(
                f'<div class="ln txt" style="top:{y:.2f}mm;font-family:P{page};'
                f'font-size:{size:.3f}mm;{style}">{"".join(words)}</div>')

    head_ayah = next(lines[n]["ayah"] for n in nums)
    surah, juz = head_ayah[0], m.juz[head_ayah]
    notes = margin_notes(m, page, nums, top, pitch) if ed.complete else ""
    return (
        f'<section class="leaf" style="--pitch:{pitch:.3f}mm">'
        '<div class="frame"></div><div class="rule"></div>'
        f'<div class="heading"><span class="hs">{chr(0xE000 + surah)}</span>'
        f'<span class="hj">{chr(0xE000 + juz)}</span></div>'
        f'{"".join(rows)}{notes}'
        f'<div class="folio"><span>{arabic_digits(page)}</span></div>'
        '</section>'
    )


def leaf_css(ed: Edition) -> str:
    """The stylesheet every leaf shares — text leaves and front matter alike."""
    colours = "".join(f".c{i}{{color:{c}}}" for i, c in enumerate(page_font(1).palette()))
    head_fs = ed.text_w / 8.046875                 # cartouche spans the text block
    return f"""
@font-face {{ font-family: Common;  src: url("{F_COMMON.as_uri()}"); }}
@font-face {{ font-family: SurahNm; src: url("{F_SURAH2.as_uri()}"); }}
@font-face {{ font-family: SurahHd; src: url("{F_SURAH.as_uri()}"); }}
@font-face {{ font-family: Quran;   src: url("{F_QURAN.as_uri()}"); }}
@page {{ size: {PAGE_W}mm {PAGE_H}mm; margin: 0; }}
:root {{ --gilt: {GILT}; --accent: {ACCENT}; --tint: #F4EDDA; }}
html, body {{ margin: 0; padding: 0; background: #fff; }}
.leaf {{
  position: relative; width: {PAGE_W}mm; height: {PAGE_H}mm;
  overflow: hidden; break-after: page;
}}
.leaf:last-child {{ break-after: auto; }}

/* The app's double rule: a heavier gilt line with a hairline inside it. */
.frame {{
  position: absolute; top: 2.5mm; bottom: 2.5mm;
  left: {ed.frame_left}mm; right: {ed.frame_right}mm;
  border: 0.45mm solid {GILT}; border-radius: 0.8mm;
}}
.rule {{
  position: absolute; top: 3.4mm; bottom: 3.4mm;
  left: {ed.frame_left + 0.9}mm; right: {ed.frame_right + 0.9}mm;
  border: 0.15mm solid {GILT}8c;
}}

/* Surah name at the start of the line, juz at the end, in the app's accent. */
.heading {{
  position: absolute; left: {ed.text_left + 0.5}mm; width: {ed.text_w - 1}mm;
  top: 4.1mm; height: 6.5mm;
  display: flex; justify-content: space-between; align-items: center;
  direction: rtl; color: {ACCENT}; line-height: 1;
}}
.hs {{ font-family: SurahHd; font-size: 5.4mm; }}
.hj {{ font-family: Common; font-size: 4.3mm; }}

.ln {{
  position: absolute; left: {ed.text_left}mm; width: {ed.text_w}mm;
  height: var(--pitch); line-height: var(--pitch);
  direction: rtl; white-space: nowrap;
}}
.txt {{ display: flex; align-items: center; }}
.txt b {{ font-weight: normal; }}
.txt s {{ display: inline-grid; direction: ltr; text-decoration: none; }}
.txt i {{ grid-area: 1 / 1; font-style: normal; }}
{colours}
.txt b.rk {{ position: relative; }}
.txt b.rk::before {{
  content: "ع"; position: absolute; left: -1em; right: -1em; text-align: center;
  top: calc(50% - 2.05em); font-family: Quran; font-size: 0.62em; line-height: 1;
  color: {ACCENT};
}}

/* A surah head fills its line with the cartouche; the basmala is centred. */
.head {{ text-align: center; }}
.cartouche {{
  font-family: Common; font-size: {head_fs:.3f}mm;
  color: {GILT}; line-height: var(--pitch);
}}
.sname {{
  position: absolute; left: 0; right: 0; top: 0;
  font-family: SurahNm; font-size: {head_fs * 0.9:.3f}mm;
  color: {ACCENT}; line-height: var(--pitch);
}}
.bism {{
  text-align: center; font-family: Common;
  font-size: {ed.text_w * 0.5 / 6.412:.3f}mm;
}}

/* The page number in its ornament at the foot of the leaf. */
.folio {{
  position: absolute; left: {ed.text_left}mm; width: {ed.text_w}mm;
  top: {TEXT_BOTTOM + 1.6}mm; text-align: center; line-height: 1;
}}
.folio span, .n, .rn, .rc {{
  font-feature-settings: "calt" 0, "liga" 0, "rlig" 0, "ccmp" 0;
}}
.folio span {{
  display: inline-block; padding: 0.5mm 3.2mm 0.9mm;
  border: 0.2mm solid {GILT}b3; border-radius: 3mm;
  font-family: Quran; font-size: 3.6mm; color: {ACCENT};
}}

/* Marginal notes: juz, hizb and quarters, sajdah, manzil, rukuʿ. */
.note {{
  position: absolute; left: {NOTE_X}mm; width: {NOTE_W}mm;
  font-family: Quran; color: {ACCENT}; direction: rtl; text-align: center;
}}
.note .shape {{ position: absolute; inset: 0; overflow: visible; }}
.note .rows {{
  position: relative; display: flex; flex-direction: column; align-items: center;
  font-size: 2.9mm; line-height: {NOTE_ROW}mm;
}}
.note .rows .n {{ font-size: 4.4mm; }}
.note .mark {{ font-size: 3.6mm; }}
.note.ruku {{
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  line-height: 1;
}}
.ruku .rn {{ font-size: 4.3mm; line-height: 3.3mm; }}
.ruku .rk {{
  display: flex; direction: rtl; align-items: center; gap: 0.4mm;
  font-size: 5mm; line-height: 4.6mm;
}}
.ruku .rc {{ font-size: 4mm; }}
{mushaf_front.front_css() if ed.complete else ""}
"""


def document(m: Mushaf, pages: range, fonts: Path, ed: Edition) -> tuple[str, list[tuple[int, dict, list[int]]]]:
    plan = []
    body = []
    for page in pages:
        lines = m.lines(page)
        for nums in leaves(page, lines):
            plan.append((page, lines, nums))
            body.append(leaf_html(m, page, lines, nums, ed))
    faces = "".join(
        f'@font-face{{font-family:P{p};src:url("{(fonts / f"p{p}.ttf").as_uri()}");'
        f'font-display:block}}' for p in pages)
    doc = (f'<!doctype html><meta charset="utf-8"><title>Mushaf</title>'
           f'<style>{faces}{leaf_css(ed)}</style>{"".join(body)}')
    return doc, plan


# --- outline and labels ------------------------------------------------------
def navigation(doc: pymupdf.Document, m: Mushaf, plan,
               front: list[tuple[str, int]]) -> tuple[dict, dict]:
    """Outline and page labels; returns the PDF page (1-based) each surah and
    juz opens on. `front` is the front matter: (outline title, leaves)."""
    offset = sum(n for _, n in front)
    surah_at, juz_at, page_at = {}, {}, {}
    for pdf_page, (page, lines, nums) in enumerate(plan, start=offset + 1):
        page_at.setdefault(page, pdf_page)
        for n in nums:
            line = lines[n]
            k = line["ayah"]
            if line["kind"] == "head":
                surah_at.setdefault(line["surah"], pdf_page)
            juz_at.setdefault(m.juz[k], (pdf_page, page))

    toc, at = [], 1
    for title, count in front:
        toc.append([1, title, at])
        at += count
    toc.append([1, "Surahs · السور", offset + 1])
    for s, meta in m.surahs.items():
        if s in surah_at:
            toc.append([2, f"{s}. {meta['name']} · {meta['arabic']}", surah_at[s]])
    toc.append([1, "Juz & pages · الأجزاء والصفحات", offset + 1])
    starts = sorted((page, j) for j, (_, page) in juz_at.items())
    for idx, (page, j) in enumerate(starts):
        toc.append([2, f"Juz {j}", juz_at[j][0]])
        end = starts[idx + 1][0] if idx + 1 < len(starts) else PAGES + 1
        for p in range(page, end):
            if p in page_at:
                toc.append([3, f"Page {p}", page_at[p]])
    doc.set_toc(toc)

    # Readers that honour page labels show "12-1", "12-2": mushaf page, leaf;
    # the cover is "Cover" and the indexes run i, ii, iii ...
    labels = []
    if front:
        labels.append(dict(startpage=0, prefix="Cover", style="", firstpagenum=1))
        if offset > 1:
            labels.append(dict(startpage=1, prefix="", style="r", firstpagenum=1))
    labels += [dict(startpage=pdf_page - 1, prefix=f"{page}-", style="D", firstpagenum=1)
               for page, pdf_page in page_at.items()]
    doc.set_page_labels(labels)
    return surah_at, {j: at for j, (at, _) in juz_at.items()}


def write_volumes(doc: pymupdf.Document, m: Mushaf, plan, front_leaves: int,
                  out_dir: Path) -> list[tuple[Path, int, int]]:
    """One PDF a juz. A whole 1200-leaf book with 600 embedded fonts is more
    than some e-readers will open; a juz is ~40 leaves and a couple of MB."""
    out_dir.mkdir(parents=True, exist_ok=True)
    first: dict[int, int] = {}
    for i, (page, lines, nums) in enumerate(plan):
        for n in nums:
            first.setdefault(m.juz[lines[n]["ayah"]], front_leaves + i)
    order = sorted(first)
    written = []
    for k, j in enumerate(order):
        start = first[j]
        end = first[order[k + 1]] if k + 1 < len(order) else doc.page_count - 1
        vol = pymupdf.open()
        vol.insert_pdf(doc, from_page=start, to_page=end)
        toc, labels, seen = [[1, f"Juz {j}", 1]], [], set()
        for offset, (page, lines, nums) in enumerate(plan[start - front_leaves:
                                                          end - front_leaves + 1]):
            for n in nums:
                if lines[n]["kind"] == "head":
                    meta = m.surahs[lines[n]["surah"]]
                    toc.append([2, f"{lines[n]['surah']}. {meta['name']} · {meta['arabic']}",
                                offset + 1])
            if page not in seen:
                seen.add(page)
                labels.append(dict(startpage=offset, prefix=f"{page}-", style="D",
                                   firstpagenum=1))
        vol.set_toc(toc)
        vol.set_page_labels(labels)
        vol.set_metadata({"title": f"الجزء {j} — Juz {j} (A6 mushaf)",
                          "author": "King Fahd Glorious Quran Printing Complex (text & fonts)",
                          "creator": "pdf/build_mushaf_pdf.py"})
        path = out_dir / f"juz-{j:02d}.pdf"
        vol.save(path, garbage=1, deflate=True, use_objstms=1)
        written.append((path, vol.page_count, path.stat().st_size))
    return written


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--edition", choices=EDITIONS, default="complete")
    ap.add_argument("--mono", action="store_true",
                    help="black text instead of the tajweed colour layers: half the "
                         "drawing per page, for readers that render slowly")
    ap.add_argument("--split", choices=("juz",),
                    help="also write one PDF a juz into pdf/volumes/")
    ap.add_argument("--pages", help="mushaf page range such as 1-5, for previews")
    ap.add_argument("-o", "--out", type=Path)
    args = ap.parse_args()
    ed = EDITIONS[args.edition]
    if args.mono:
        ed = replace(ed, mono=True, out=ed.out.with_name(ed.out.stem + "-mono.pdf"))
    out_path = args.out or ed.out

    pages = range(1, PAGES + 1)
    if args.pages:
        lo, _, hi = args.pages.partition("-")
        pages = range(int(lo), int(hi or lo) + 1)

    m = Mushaf()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    doc = pymupdf.open()
    front, links, jobs = [], [], []
    with tempfile.TemporaryDirectory() as tmp:
        fonts = Path(tmp) / "fonts"
        fonts.mkdir()
        for page in pages:
            (fonts / f"p{page}.ttf").write_bytes(page_font(page).layer_font())

        if ed.complete:
            sections, links, front = mushaf_front.front_matter(m)
            front_doc = (f'<!doctype html><meta charset="utf-8"><title>Front</title>'
                         f'<style>{leaf_css(ed)}</style>{"".join(sections)}')
            jobs.append((front_doc, sum(n for _, n in front)))
        chunks = [pages[i:i + CHUNK] for i in range(0, len(pages), CHUNK)]
        parts = [document(m, chunk, fonts, ed) for chunk in chunks]
        plan = [leaf for _, leaves_ in parts for leaf in leaves_]
        jobs += [(html_text, len(leaves_)) for html_text, leaves_ in parts]
        print(f"{len(pages)} mushaf pages -> {len(plan)} leaves"
              f"{f' + {jobs[0][1]} front' if ed.complete else ''}, "
              f"laying out {len(jobs)} chunks with Chrome ...", flush=True)

        outs = [Path(tmp) / f"{i:03d}.pdf" for i in range(len(jobs))]
        with ThreadPoolExecutor(WORKERS) as pool:
            list(pool.map(lambda job: chrome_pdf(job[0][0], job[1]), zip(jobs, outs)))
        for (_, expected), out in zip(jobs, outs):
            if not out.exists():
                raise SystemExit(f"Chrome produced no PDF for {out.name}")
            with pymupdf.open(out) as part:
                if part.page_count != expected:
                    raise SystemExit(f"{out.name}: {part.page_count} pages, expected {expected}")
                doc.insert_pdf(part)

    surah_at, juz_at = navigation(doc, m, plan, front)
    # Every index row jumps to where its surah or juz begins.
    for leaf, y0, y1, (kind, n) in links:
        target = (surah_at if kind == "surah" else juz_at).get(n)
        if target:
            doc[leaf].insert_link({
                "kind": pymupdf.LINK_GOTO, "page": target - 1, "to": pymupdf.Point(0, 0),
                "from": pymupdf.Rect(mushaf_front.TABLE_L * MM, y0 * MM,
                                     mushaf_front.TABLE_R * MM, y1 * MM)})
    doc.set_metadata({
        "title": "المصحف الشريف — Madinah Mushaf (A6)",
        "author": "King Fahd Glorious Quran Printing Complex (text & fonts)",
        "subject": "QPC V4 tajweed page fonts, the printed 15-line pages over two A6 leaves"
                   + ("; cover, indexes and marginal notes" if ed.complete else ""),
        "creator": "pdf/build_mushaf_pdf.py",
    })
    doc.save(out_path, garbage=1, deflate=True, use_objstms=1)
    print(f"{doc.page_count} leaves -> {out_path} "
          f"({out_path.stat().st_size / 1e6:.1f} MB)")
    if args.split:
        vols = write_volumes(doc, m, plan, doc.page_count - len(plan),
                             out_path.parent / "volumes")
        print(f"{len(vols)} volumes -> {vols[0][0].parent}/ "
              f"({sum(v[2] for v in vols) / 1e6:.1f} MB total, "
              f"largest {max(v[2] for v in vols) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
