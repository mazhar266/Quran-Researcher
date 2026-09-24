"""Front matter for the complete mushaf: the cover and the two indexes.

Everything here is drawn from scratch — SVG geometry for the ornament, and the
calligraphy that ships with the app (`quran-common.ttf`) for the title — so the
book carries no one else's cover art.
"""

from __future__ import annotations

import math

from build_quran_pdf import F_COMMON, F_QURAN

PAGE_W, PAGE_H = 105.0, 148.0

GREEN, GREEN_DEEP = "#0E3B2D", "#082A20"
GOLD, GOLD_PALE = "#CFA955", "#E9D39A"
# The medallion, and the title calligraphy sized to sit inside its inner ring.
TITLE_X, TITLE_Y, TITLE_SIZE = PAGE_W / 2, 70.0, 31.0


def arabic_digits(n: int) -> str:
    return str(n).translate(str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩"))


# --- geometry ----------------------------------------------------------------
def _pts(points) -> str:
    return " ".join(f"{x:.3f},{y:.3f}" for x, y in points)


def star(cx: float, cy: float, points: int, outer: float, inner: float,
         turn: float = 0.0) -> str:
    """A regular star polygon, as SVG points."""
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi * i / points + turn - math.pi / 2
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return _pts(out)


def khatam(cx: float, cy: float, r: float) -> str:
    """The eight-pointed star of two interlaced squares."""
    return "".join(
        f'<rect x="{cx - r:.3f}" y="{cy - r:.3f}" width="{2 * r:.3f}" height="{2 * r:.3f}" '
        f'transform="rotate({turn} {cx:.3f} {cy:.3f})"/>'
        for turn in (0, 45))


def petals(cx: float, cy: float, count: int, r0: float, r1: float, width: float) -> str:
    """A ring of pointed petals (vesica shapes) radiating from a centre."""
    out = []
    for i in range(count):
        a = 360 * i / count
        mid = (r0 + r1) / 2
        out.append(
            f'<path transform="rotate({a:.3f} {cx:.3f} {cy:.3f})" d="M {cx:.3f} {cy - r0:.3f} '
            f'Q {cx + width:.3f} {cy - mid:.3f} {cx:.3f} {cy - r1:.3f} '
            f'Q {cx - width:.3f} {cy - mid:.3f} {cx:.3f} {cy - r0:.3f} Z"/>')
    return "".join(out)


def pendant(cx: float, y: float, direction: int) -> str:
    """The finial that hangs off the top and bottom of a cover medallion."""
    d = direction
    return (
        f'<path d="M {cx - 4.2:.3f} {y:.3f} C {cx - 4.2:.3f} {y + d * 3.5:.3f} '
        f'{cx - 1.2:.3f} {y + d * 5:.3f} {cx:.3f} {y + d * 9.5:.3f} '
        f'C {cx + 1.2:.3f} {y + d * 5:.3f} {cx + 4.2:.3f} {y + d * 3.5:.3f} {cx + 4.2:.3f} {y:.3f}"/>'
        f'<circle cx="{cx:.3f}" cy="{y + d * 11.2:.3f}" r="0.9"/>'
        f'<circle cx="{cx:.3f}" cy="{y + d * 3.2:.3f}" r="1.1"/>')


def corner(x: float, y: float, sx: int, sy: int, r: float) -> str:
    """A quarter medallion tucked into a corner of the inner panel."""
    return (
        f'<path d="M {x + sx * r:.3f} {y:.3f} A {r:.3f} {r:.3f} 0 0 {1 if sx * sy > 0 else 0} '
        f'{x:.3f} {y + sy * r:.3f}"/>'
        f'<path d="M {x + sx * r * 0.72:.3f} {y:.3f} A {r * 0.72:.3f} {r * 0.72:.3f} 0 0 '
        f'{1 if sx * sy > 0 else 0} {x:.3f} {y + sy * r * 0.72:.3f}"/>'
        f'<polygon points="{star(x + sx * r * 0.36, y + sy * r * 0.36, 8, r * 0.26, r * 0.12)}"/>')


def band(x0: float, y0: float, x1: float, y1: float, step: float) -> str:
    """The border band: khatam stars strung along all four sides on a rope of
    lozenges, with a larger rosette in each corner."""
    out = []
    w, h = x1 - x0, y1 - y0
    mid = (y1 - y0) and None
    cy_top, cy_bot = y0, y1
    for side_y in (cy_top, cy_bot):
        n = int((w - step) // step)
        pad = (w - n * step) / 2
        for i in range(n + 1):
            cx = x0 + pad + i * step
            if abs(cx - x0) < step * 0.6 or abs(cx - x1) < step * 0.6:
                continue
            out.append(khatam(cx, side_y, 1.35))
            if i < n:
                out.append(f'<polygon points="{_pts([(cx + step / 2, side_y - 0.9), (cx + step / 2 + 1.1, side_y), (cx + step / 2, side_y + 0.9), (cx + step / 2 - 1.1, side_y)])}"/>')
    for side_x in (x0, x1):
        n = int((h - step) // step)
        pad = (h - n * step) / 2
        for i in range(n + 1):
            cy = y0 + pad + i * step
            if abs(cy - y0) < step * 0.6 or abs(cy - y1) < step * 0.6:
                continue
            out.append(khatam(side_x, cy, 1.35))
            if i < n:
                out.append(f'<polygon points="{_pts([(side_x - 0.9, cy + step / 2), (side_x, cy + step / 2 + 1.1), (side_x + 0.9, cy + step / 2), (side_x, cy + step / 2 - 1.1)])}"/>')
    for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        out.append(f'<circle cx="{cx}" cy="{cy}" r="2.9" class="fill-deep"/>')
        out.append(f'<polygon points="{star(cx, cy, 8, 2.6, 1.15)}"/>')
        out.append(f'<circle cx="{cx}" cy="{cy}" r="0.7" class="solid"/>')
    return "".join(out)


# --- the cover ------------------------------------------------------------------
def cover_html() -> str:
    cx, cy = TITLE_X, TITLE_Y
    # Flat colour only: no gradient, no transparency. A soft mask on the first
    # page is what stalls e-ink readers that rasterise page 1 on import.
    svg = f"""
<svg class="art" viewBox="0 0 {PAGE_W} {PAGE_H}" xmlns="http://www.w3.org/2000/svg">
  <rect width="{PAGE_W}" height="{PAGE_H}" fill="{GREEN_DEEP}"/>
  <rect x="6.6" y="6.6" width="{PAGE_W - 13.2}" height="{PAGE_H - 13.2}" fill="{GREEN}"/>
  <g fill="none" stroke="{GOLD}">
    <rect x="3.6" y="3.6" width="{PAGE_W - 7.2}" height="{PAGE_H - 7.2}" stroke-width="0.7"/>
    <rect x="4.7" y="4.7" width="{PAGE_W - 9.4}" height="{PAGE_H - 9.4}" stroke-width="0.22"/>
    <rect x="11.3" y="11.3" width="{PAGE_W - 22.6}" height="{PAGE_H - 22.6}" stroke-width="0.22"/>
    <rect x="12.4" y="12.4" width="{PAGE_W - 24.8}" height="{PAGE_H - 24.8}" stroke-width="0.7"/>
  </g>
  <g fill="none" stroke="{GOLD}" stroke-width="0.3">{band(8.0, 8.0, PAGE_W - 8.0, PAGE_H - 8.0, 7.0)}</g>
  <g fill="none" stroke="{GOLD}" stroke-width="0.3">
    {corner(12.4, 12.4, 1, 1, 13)}{corner(PAGE_W - 12.4, 12.4, -1, 1, 13)}
    {corner(12.4, PAGE_H - 12.4, 1, -1, 13)}{corner(PAGE_W - 12.4, PAGE_H - 12.4, -1, -1, 13)}
  </g>
  <g fill="none" stroke="{GOLD}" stroke-width="0.28">
    {pendant(cx, cy - 31.2, -1)}{pendant(cx, cy + 31.2, 1)}
    <polygon points="{star(cx, cy, 16, 31.2, 26.6)}" stroke-width="0.55"/>
    <polygon points="{star(cx, cy, 16, 29.6, 25.4, math.pi / 16)}"/>
    <g stroke-width="0.22">{petals(cx, cy, 32, 23.4, 26.4, 0.95)}</g>
    <circle cx="{cx}" cy="{cy}" r="23.2" stroke-width="0.55"/>
    <circle cx="{cx}" cy="{cy}" r="22.2"/>
  </g>
  <g fill="{GOLD}">
    {"".join(f'<circle cx="{cx + 27.9 * math.cos(math.pi * i / 8 - math.pi / 2):.3f}" cy="{cy + 27.9 * math.sin(math.pi * i / 8 - math.pi / 2):.3f}" r="0.42"/>' for i in range(16))}
  </g>
</svg>"""
    return f"""
<section class="leaf cover">
  {svg}
  <div class="cover-kicker">مُصۡحَفُ ٱلتَّجۡوِيدِ</div>
  <div class="cover-title">&#xE076;</div>
  <div class="cover-riwaya">بِرِوَايَةِ حَفۡصٍ عَنۡ عَاصِمٍ</div>
</section>"""


# --- the indexes ---------------------------------------------------------------
TABLE_L, TABLE_R = 6.0, 99.0            # table edges, mm from the left
HEAD_TOP, HEAD_H = 20.8, 6.4            # column headings
BODY_BOTTOM = 135.5


def _n(n: int) -> str:
    return f'<span class="n">{arabic_digits(n)}</span>'


def _table(title: str, columns: list[tuple[str, float]], rows: list[tuple[list[str], tuple]],
           per_leaf: int, leaf_no: int) -> tuple[list[str], list[tuple]]:
    """Index leaves: a cartouche title, column headings, then `per_leaf` rows a
    leaf. Returns the leaves and, per row, (leaf, top, bottom, target)."""
    leaves, links = [], []
    row_h = (BODY_BOTTOM - HEAD_TOP - HEAD_H) / per_leaf
    head = "".join(f'<span style="width:{w}mm">{h}</span>' for h, w in columns)
    for start in range(0, len(rows), per_leaf):
        body = []
        for i, (cells, target) in enumerate(rows[start:start + per_leaf]):
            top = HEAD_TOP + HEAD_H + i * row_h
            body.append(f'<div class="ix-row" style="top:{top:.2f}mm;height:{row_h:.2f}mm">'
                        + "".join(f'<span style="width:{w}mm">{c}</span>'
                                  for c, (_, w) in zip(cells, columns)) + "</div>")
            links.append((leaf_no + len(leaves), top, top + row_h, target))
        leaves.append(
            '<section class="leaf front">'
            '<div class="frame"></div><div class="rule"></div>'
            f'<div class="ix-title"><span class="ix-cartouche">\ue000</span>'
            f'<span class="ix-name">{title}</span></div>'
            f'<div class="ix-head" style="top:{HEAD_TOP}mm;height:{HEAD_H}mm">{head}</div>'
            f'{"".join(body)}</section>')
    return leaves, links


def front_matter(m) -> tuple[list[str], list[tuple], list[tuple[str, int]]]:
    """Cover, surah index and juz index: the leaves, the index rows to link,
    and (outline title, leaf count) for each section."""
    surah_rows = []
    for s, meta in m.surahs.items():
        place = "مكية" if meta["place"] == "makkah" else "مدنية"
        surah_rows.append(([
            _n(s),
            f'<span class="ix-sn">{chr(0xE000 + s)}</span>',
            f'<span class="place">{place}</span>',
            _n(meta["verses"]),
            _n(m.layout[(s, 1)][0]),
        ], ("surah", s)))

    juz_rows, seen = [], set()
    for key in m.order:
        j = m.division[key]["juz"]
        if j in seen:
            continue
        seen.add(j)
        juz_rows.append(([
            f'<span class="jname">{chr(0xE000 + j)}</span>',
            f'<span class="opener">{chr(0xE900 + j - 1)}</span>',
            f'<span class="where"><span class="ix-sn">{chr(0xE000 + key[0])}</span>{_n(key[1])}</span>',
            _n(m.layout[key][0]),
        ], ("juz", j)))

    surahs, surah_links = _table(
        "فهرس السور",
        [("رقمها", 10), ("السورة", 31), ("نزولها", 20), ("آياتها", 15), ("الصفحة", 17)],
        surah_rows, 19, leaf_no=1)
    juz, juz_links = _table(
        "فهرس الأجزاء",
        [("الجزء", 34), ("أوله", 27), ("موضعه", 19), ("الصفحة", 13)],
        juz_rows, 15, leaf_no=1 + len(surahs))
    sections = [cover_html(), *surahs, *juz]
    front = [("Cover · الغلاف", 1), ("Index of surahs · فهرس السور", len(surahs)),
             ("Index of juz · فهرس الأجزاء", len(juz))]
    return sections, surah_links + juz_links, front


def front_css() -> str:
    return f"""
@font-face {{ font-family: Common; src: url("{F_COMMON.as_uri()}"); }}
@font-face {{ font-family: Quran; src: url("{F_QURAN.as_uri()}"); }}
.cover {{ background: {GREEN_DEEP}; }}
.cover .art {{ position: absolute; inset: 0; width: {PAGE_W}mm; height: {PAGE_H}mm; }}
.cover .fill-deep {{ fill: {GREEN}; }}
.cover .solid {{ fill: {GOLD}; stroke: none; }}
/* The calligraphy's ink is off its advance box (measured: centred 0.686 em
   in and 0.487 em down at line-height 1), so it is placed by its ink centre. */
.cover-title {{
  position: absolute; white-space: nowrap;
  left: {TITLE_X - 0.686 * TITLE_SIZE:.2f}mm; top: {TITLE_Y - 0.487 * TITLE_SIZE:.2f}mm;
  font-family: Common; font-size: {TITLE_SIZE}mm; line-height: {TITLE_SIZE}mm;
  color: {GOLD_PALE};
}}
.cover-kicker, .cover-riwaya {{
  position: absolute; left: 0; right: 0; text-align: center;
  font-family: Quran; color: {GOLD}; direction: rtl; line-height: 1;
}}
.cover-kicker {{ top: 20.5mm; font-size: 5.6mm; }}
.cover-riwaya {{ top: 118mm; font-size: 4.6mm; }}

/* Index leaves: a symmetric frame, a cartouche title, a ruled table. */
.leaf.front .frame {{ left: 2.5mm; right: 2.5mm; }}
.leaf.front .rule {{ left: 3.4mm; right: 3.4mm; }}
.ix-title {{
  position: absolute; left: {TABLE_L}mm; width: {TABLE_R - TABLE_L}mm; top: 5.2mm;
  height: 14mm; line-height: 14mm; text-align: center;
}}
.ix-cartouche {{ font-family: Common; font-size: {(TABLE_R - TABLE_L) / 8.046875:.3f}mm; color: var(--gilt); }}
.ix-name {{
  position: absolute; left: 0; right: 0; top: 0; direction: rtl;
  font-family: Quran; font-size: 4.6mm; color: var(--accent);
}}
.ix-head, .ix-row {{
  position: absolute; left: {TABLE_L}mm; width: {TABLE_R - TABLE_L}mm;
  display: flex; direction: rtl; align-items: center;
}}
.ix-head {{
  background: var(--tint); border-top: 0.35mm solid var(--gilt); border-bottom: 0.35mm solid var(--gilt);
  font-family: Quran; font-size: 3.4mm; color: var(--accent); line-height: 1;
}}
.ix-row {{
  border-bottom: 0.15mm solid {GOLD}66;
  font-family: Quran; font-size: 3.3mm; color: #1A1A17; line-height: 1;
}}
.ix-row:nth-of-type(even) {{ background: #FBF7EC; }}
.ix-head span, .ix-row > span {{ display: flex; justify-content: center; align-items: center; }}
.ix-row .ix-sn {{ font-family: SurahHd; font-size: 4.9mm; color: var(--accent); }}
.ix-row .n {{ font-size: 5.4mm; }}
.ix-row .place {{ font-size: 3.4mm; }}
.ix-row .jname {{ font-family: Common; font-size: 4.3mm; color: var(--accent); }}
.ix-row .opener {{ font-family: Common; font-size: 4.5mm; }}
.ix-row .where {{ display: flex; align-items: center; gap: 1.2mm; }}
.ix-row .where .ix-sn {{ font-size: 4.3mm; }}
"""
