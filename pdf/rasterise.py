#!/usr/bin/env python3
"""Make an image-only copy of a PDF: one picture a page, no fonts at all.

A reader that stalls on a book with hundreds of embedded fonts has nothing
left to do here but blit a bitmap. The outline, page labels and links are
carried over, so navigation still works; the text is no longer selectable and
the file grows.

    python3 pdf/rasterise.py pdf/mushaf-a6-madinah-complete.pdf
    python3 pdf/rasterise.py in.pdf -o out.pdf --size 1800x2537 --colours 64
    python3 pdf/rasterise.py pdf/volumes/juz-01.pdf -o /tmp/juz-01-images.pdf

Requires: pymupdf, pillow.
"""

from __future__ import annotations

import argparse
import tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import pymupdf
from PIL import Image

SIZE = (1800, 2537)                    # pixels; A6 at ~435 dpi
COLOURS = 64

_open: dict[str, pymupdf.Document] = {}


def _source(path: str) -> pymupdf.Document:
    if path not in _open:                               # one handle a worker
        _open[path] = pymupdf.open(path)
    return _open[path]


def render(job: tuple[str, int, int, int, int, str]) -> str:
    """One page, rendered and written as a single-page PDF holding the image.

    A leaf uses a few dozen colours — ink, the tajweed palette, the gilt rules
    and their anti-aliasing — so an indexed PNG keeps the text crisp at about a
    third of what JPEG costs on this kind of page. Pillow writes that into the
    PDF as an Indexed/Flate image; PyMuPDF would expand it back to RGB.
    """
    path, index, width, height, colours, out = job
    page = _source(path)[index]
    pix = page.get_pixmap(alpha=False, matrix=pymupdf.Matrix(
        width / page.rect.width, height / page.rect.height))
    image = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    image.quantize(colors=colours, method=Image.MEDIANCUT).save(
        out, "PDF", resolution=width / (page.rect.width / 72))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path)
    ap.add_argument("-o", "--out", type=Path)
    ap.add_argument("--size", default="x".join(map(str, SIZE)),
                    help=f"pixels per page, default {SIZE[0]}x{SIZE[1]}")
    ap.add_argument("--colours", type=int, default=COLOURS)
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args()
    width, height = (int(v) for v in args.size.lower().split("x"))
    out_path = args.out or args.source.with_name(args.source.stem + "-images.pdf")

    src = pymupdf.open(args.source)
    print(f"{src.page_count} pages -> {width}x{height} px images ...", flush=True)
    with tempfile.TemporaryDirectory() as tmp:
        jobs = [(str(args.source), i, width, height, args.colours,
                 f"{tmp}/{i:05d}.pdf") for i in range(src.page_count)]
        with ProcessPoolExecutor(args.workers) as pool:
            for done, _ in enumerate(pool.map(render, jobs, chunksize=4), 1):
                if done % 200 == 0 or done == len(jobs):
                    print(f"  {done}/{len(jobs)}", flush=True)
        out = pymupdf.open()
        for _, _, _, _, _, page_pdf in jobs:
            with pymupdf.open(page_pdf) as one:
                out.insert_pdf(one)

    # Carry the navigation over; the pages keep their size, so link rectangles
    # land where they did.
    for index in range(src.page_count):
        for link in src[index].get_links():
            out[index].insert_link(link)
    out.set_toc(src.get_toc())
    try:
        labels = src.get_page_labels()
        if labels:
            out.set_page_labels(labels)
    except Exception:                                   # older PyMuPDF
        pass
    meta = {k: v for k, v in (src.metadata or {}).items()
            if k in ("title", "author", "subject")}
    out.set_metadata({**meta, "creator": "pdf/rasterise.py"})
    out.save(out_path, garbage=1, deflate=True, use_objstms=1)
    print(f"{out.page_count} pages -> {out_path} "
          f"({out_path.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
