#!/usr/bin/env python3
"""Phase 0 ETL: convert raw QUL/Arramooz data under data/ into versioned
SQLite modules under dist/ plus a manifest.json. (dist/, not build/, so
`flutter clean` never deletes ETL output.)

Outputs:
  core.db            metadata, scripts, wbw, translations, transliterations,
                     morphology, similarities, themes, topics, surah info, FTS
  scripts_extra.db   secondary word/ayah scripts (Warsh, Digital Khatt, V4, ...)
  tafsir_<slug>.db   one per tafsir book
  audio_<id>.db      one per reciter (URLs + word timing segments)
  dict_ar.db         Arramooz dictionary with normalized roots
  fontpack_v1.zip    604 QPC V1 page fonts
  fontpack_v2.zip    604 QPC V2 page fonts
  manifest.json      module registry (size, sha256, attribution)

Usage: python3 etl/build.py [--skip-fonts]
"""
import hashlib
import json
import re
import sqlite3
import sys
import zipfile
from pathlib import Path

import grammar

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
BUILD = ROOT / "dist"
SCHEMA_VERSION = 1


def load(relpath):
    """Load a QUL JSON file, transparently handling the dir-wrapped layout."""
    p = DATA / relpath
    if p.is_dir():
        inner = sorted(p.glob("*.json"))
        if len(inner) != 1:
            raise ValueError(f"{p}: expected exactly one inner json, got {inner}")
        p = inner[0]
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def loc_parts(location):
    s, a, w = location.split(":")
    return int(s), int(a), int(w)


def key_parts(verse_key):
    s, a = verse_key.split(":")
    return int(s), int(a)


# The QPC source mixes unquoted and quoted attributes (<rule class=x> and
# <rule class='x'>), and rules can nest — so tokenize instead of matching
# whole <rule>..</rule> pairs with one regex.
# [^>]* tolerates stray extra attributes (13:37 carries a leaked Bootstrap
# tooltip attribute in the source data).
TAG_RE = re.compile(r"<rule class=['\"]?([a-z_0-9]+)['\"]?[^>]*>|</rule>")


def parse_tajweed(marked):
    """Turn '<rule class=x>..</rule>' markup into (plain_text, spans).
    Spans are [start, end, rule] in code points of the plain text; nested
    rules emit inner spans first so renderers can give them precedence."""
    out, spans, stack, pos, last = [], [], [], 0, 0
    for m in TAG_RE.finditer(marked):
        head = marked[last : m.start()]
        out.append(head)
        pos += len(head)
        last = m.end()
        if m.group(1):  # opening tag
            stack.append((m.group(1), pos))
        elif stack:  # closing tag
            rule, start = stack.pop()
            spans.append([start, pos, rule])
        # else: stray </rule> with no opener — drop it
    out.append(marked[last:])
    pos += len(marked) - last
    for rule, start in stack:  # unclosed openers: close at end of text
        spans.append([start, pos, rule])
    return "".join(out), spans


ALEF_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ء": "ا",
                           "ؤ": "ا", "ئ": "ا", "ى": "ي", "ة": "ه"})


def norm_root(r):
    """Fold hamza/alef variants and strip spaces so QUL and Arramooz roots join."""
    return (r or "").replace(" ", "").replace("ـ", "").translate(ALEF_FOLD)


def fresh_db(name):
    path = BUILD / name
    path.unlink(missing_ok=True)
    con = sqlite3.connect(path)
    con.executescript(
        "PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF; PRAGMA page_size=4096;"
    )
    return con, path


def finish_db(con):
    con.commit()
    # Matches AppDatabase.schemaVersion so drift treats the file as
    # already-migrated and never writes to it.
    con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
    con.execute("PRAGMA optimize")
    con.execute("VACUUM")
    con.close()


# ---------------------------------------------------------------- core.db
AYAH_SCRIPTS_CORE = {  # slug -> source path
    "uthmani": "mushaf/uthmani.json",
    "uthmani-simple": "mushaf/uthmani-simple.json",
    "imlaei": "mushaf/imlaei-script-ayah-by-ayah.json",
    "imlaei-simple": "mushaf/imlaei-simple.json",
    "qpc-hafs": "mushaf/qpc-hafs.json",
    "indopak-nastaleeq": "mushaf/indopak-nastaleeq.json",
    "digital-khatt-indopak": "mushaf/digital-khatt-indopak-ayah-by-ayah-script.json",
    "qpc-v1-glyph": "mushaf/qpc-v1-ayah-by-ayah-glyphs.json",
}
AYAH_SCRIPTS_EXTRA = {
    "warsh": "mushaf/qpc-warsh-script-ayah.json",
}
WORD_SCRIPTS_EXTRA = {
    "digital-khatt-v2": "mushaf/digital-khatt-v2.json",
    "digital-khatt-indopak": "mushaf/digital-khatt-indopak.json",
    "qpc-nastaleeq": "mushaf/qpc-nastaleeq.json",
    "qpc-v4-glyph": "mushaf/qpc-v4.json",
    "imlaei": "mushaf/imlaei.json",
    "warsh": "mushaf/qpc-warsh-script-wbw.json",
    "word-image-url": "mushaf/black-images-word-by-word.json",
    "colored-en-wbw": "translation/en/colored-english-wbw-translation.json",
}
TRANSLATIONS = [
    # (slug, lang, name, path, has_footnotes)
    ("en-sahih-international", "en", "Sahih International",
     "translation/en/en-sahih-international-simple.json", False),
    ("en-sahih-international-fn", "en", "Sahih International (with footnotes)",
     "translation/en/en-sahih-international-with-footnote-tags.json", True),
    ("bn-sheikh-mujibur-rahman", "bn", "Sheikh Mujibur Rahman",
     "translation/bn/bn-sheikh-mujibur-rahman-simple.json", False),
    ("bn-taisirul-quran", "bn", "Taisirul Quran",
     "translation/bn/bn-taisirul-quran-simple.json", False),
    ("bn-abu-bakr-zakaria", "bn", "Dr. Abu Bakr Muhammad Zakaria",
     "translation/bn/dr-abu-bakr-muhammad-zakaria-simple.json", False),
    ("bn-fathul-majid", "bn", "Fathul Majid",
     "translation/bn/fathul-majid-bn-simple.json", False),
    ("bn-rawai-al-bayan", "bn", "Rawai al-Bayan",
     "translation/bn/bn-rawai-al-bayan-simple.db", False),
]
TRANSLITERATIONS = [
    ("translit-simple", "transliteration/transliteration-simple.json"),
    ("translit-tajweed", "transliteration/english-transliteration-tajweed.json"),
    ("translit-syllables", "transliteration/syllables-transliteration.json"),
    ("translit-syllables-2", "transliteration/syllables-transliteration-2.json"),
]

CORE_SCHEMA = """
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE surahs(
  id INTEGER PRIMARY KEY, name TEXT, name_simple TEXT, name_arabic TEXT,
  revelation_order INTEGER, revelation_place TEXT, verses_count INTEGER,
  bismillah_pre INTEGER);
CREATE TABLE ayahs(
  id INTEGER PRIMARY KEY, surah INTEGER, ayah INTEGER, verse_key TEXT UNIQUE,
  words_count INTEGER, page INTEGER, juz INTEGER, hizb INTEGER, rub INTEGER,
  ruku INTEGER, manzil INTEGER, sajda_type TEXT);
CREATE TABLE scripts(id INTEGER PRIMARY KEY, slug TEXT UNIQUE, level TEXT, in_module TEXT);
CREATE TABLE ayah_text(script_id INTEGER, surah INTEGER, ayah INTEGER, text TEXT,
  PRIMARY KEY(script_id, surah, ayah)) WITHOUT ROWID;
CREATE TABLE tajweed_ayah(surah INTEGER, ayah INTEGER, text TEXT, spans TEXT,
  PRIMARY KEY(surah, ayah)) WITHOUT ROWID;
CREATE TABLE words(
  surah INTEGER, ayah INTEGER, pos INTEGER, location TEXT,
  text_qpc_hafs TEXT, text_v1_glyph TEXT, text_indopak TEXT,
  tajweed_text TEXT, tajweed_spans TEXT, tr_en TEXT, tr_bn TEXT,
  PRIMARY KEY(surah, ayah, pos)) WITHOUT ROWID;
CREATE TABLE resources(id INTEGER PRIMARY KEY, slug TEXT UNIQUE, lang TEXT,
  name TEXT, kind TEXT);
CREATE TABLE translations(resource_id INTEGER, surah INTEGER, ayah INTEGER,
  text TEXT, footnotes TEXT, PRIMARY KEY(resource_id, surah, ayah)) WITHOUT ROWID;
CREATE TABLE roots(id INTEGER PRIMARY KEY, arabic TEXT, arabic_norm TEXT,
  latin TEXT, words_count INTEGER, uniq_words_count INTEGER);
CREATE TABLE lemmas(id INTEGER PRIMARY KEY, text TEXT, text_clean TEXT);
CREATE TABLE stems(id INTEGER PRIMARY KEY, text TEXT, text_clean TEXT);
CREATE TABLE word_roots(root_id INTEGER, location TEXT, surah INTEGER,
  ayah INTEGER, pos INTEGER, PRIMARY KEY(root_id, location)) WITHOUT ROWID;
CREATE TABLE word_lemmas(lemma_id INTEGER, location TEXT, surah INTEGER,
  ayah INTEGER, pos INTEGER, PRIMARY KEY(lemma_id, location)) WITHOUT ROWID;
CREATE TABLE word_stems(stem_id INTEGER, location TEXT, surah INTEGER,
  ayah INTEGER, pos INTEGER, PRIMARY KEY(stem_id, location)) WITHOUT ROWID;
CREATE TABLE ayah_morphology(surah INTEGER, ayah INTEGER, roots TEXT,
  lemmas TEXT, stems TEXT, PRIMARY KEY(surah, ayah)) WITHOUT ROWID;
CREATE TABLE similar_ayahs(surah INTEGER, ayah INTEGER, matched_key TEXT,
  matched_words_count INTEGER, coverage INTEGER, score INTEGER, ranges TEXT);
CREATE TABLE phrases(id INTEGER PRIMARY KEY, source_key TEXT, from_word INTEGER,
  to_word INTEGER, surahs_count INTEGER, ayahs_count INTEGER, occurrences INTEGER);
CREATE TABLE phrase_occurrences(phrase_id INTEGER, verse_key TEXT, surah INTEGER,
  ayah INTEGER, ranges TEXT, PRIMARY KEY(phrase_id, verse_key)) WITHOUT ROWID;
CREATE TABLE themes(surah INTEGER, ayah_from INTEGER, ayah_to INTEGER,
  theme TEXT, keywords TEXT);
CREATE TABLE topics(id INTEGER PRIMARY KEY, name TEXT, arabic_name TEXT,
  parent_id INTEGER, thematic_parent_id INTEGER, ontology_parent_id INTEGER,
  description TEXT, wiki_link TEXT, ayahs TEXT, related_topics TEXT);
CREATE TABLE surah_info(surah INTEGER PRIMARY KEY, name TEXT, text TEXT);
CREATE TABLE word_grammar(
  surah INTEGER, ayah INTEGER, pos INTEGER, pos_tag TEXT, verb_form INTEGER,
  aspect TEXT, voice TEXT, pgn TEXT, mood TEXT, gcase TEXT, definite INTEGER,
  special TEXT, root TEXT, lemma TEXT, prefixes TEXT, suffixes TEXT,
  PRIMARY KEY(surah, ayah, pos)) WITHOUT ROWID;
CREATE TABLE verb_lemmas(
  id INTEGER PRIMARY KEY, lemma TEXT, root TEXT, verb_form INTEGER,
  bab_ar TEXT, bab_key TEXT, masdar TEXT, masdar_source TEXT, source TEXT,
  occurrences INTEGER);
CREATE INDEX idx_verb_lemma ON verb_lemmas(lemma, root);
CREATE VIRTUAL TABLE fts_ayah USING fts5(
  verse_key UNINDEXED, ar_simple, tr_en, tr_bn, translit,
  tokenize='unicode61 remove_diacritics 2');
"""


def section_lookup(meta_file, number_field):
    """Expand a QUL section file (juz/hizb/...) verse_mapping into
    {(surah, ayah): section_number}."""
    lookup = {}
    for entry in load(meta_file).values():
        num = entry[number_field]
        for s, rng in entry["verse_mapping"].items():
            a, _, b = rng.partition("-")
            for ayah in range(int(a), int(b or a) + 1):
                lookup[(int(s), ayah)] = num
    return lookup



def add_grammar(con):
    """Sarf layer: align QAC morphology to QUL words, derive bab + masdar."""
    words = grammar.parse_corpus(DATA / "grammar/quran-morphology.txt")

    # Arramooz supplies form-I present vowels and samāʿī masdars.
    import sqlite3 as _sq
    ar = _sq.connect(DATA / "arramooz/data/arabicdictionary.sqlite")
    verbs = {}
    for voc, root, ft in ar.execute("SELECT vocalized, root, future_type FROM verbs"):
        verbs.setdefault(grammar._norm(root or ""), []).append((voc or "", ft or ""))
    masdars = {"strict": {}, "loose": {}}
    for voc, orig in ar.execute(
            "SELECT vocalized, original FROM nouns "
            "WHERE wordtype LIKE '%مصدر%' AND original != ''"):
        masdars["strict"].setdefault(grammar.strict_key(orig), []).append(voc)
        masdars["loose"].setdefault(grammar._norm(orig), []).append(voc)
    ar.close()

    # Word-level grammar, aligned per ayah and verified by text.
    by_ayah = {}
    for (s, a, w), segs in words.items():
        by_ayah.setdefault((s, a), {})[w] = segs
    matched = total = 0
    for (s, a), qac in sorted(by_ayah.items()):
        qul = [(p, t) for p, t in con.execute(
            "SELECT pos, text_qpc_hafs FROM words WHERE surah=?1 AND ayah=?2 "
            "ORDER BY pos", (s, a))]
        total += len([1 for _, t in qul if any(c.isalpha() for c in grammar._strip(t))])
        aligned = grammar.align(qul, [qac[i] for i in sorted(qac)])
        for pos, segs in aligned.items():
            stem = next((x for x in segs if "PREF" not in x["tags"]
                         and "SUFF" not in x["tags"]), segs[0])
            aspect, voice, pgn, mood = grammar.sigah(stem)
            special = next((t for t in stem["tags"]
                            if t in ("ACT_PCPL", "PASS_PCPL", "VN", "ADJ", "PN")), None)
            con.execute(
                "INSERT OR REPLACE INTO word_grammar VALUES"
                "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (s, a, pos, stem["pos"], int(stem["kv"].get("VF", 0)) or None,
                 aspect, voice, pgn, mood,
                 next((t for t in stem["tags"] if t in ("NOM", "ACC", "GEN")), None),
                 0 if "INDEF" in stem["tags"] else (1 if stem["pos"] == "N" else None),
                 special, stem["kv"].get("ROOT"), stem["kv"].get("LEM"),
                 json.dumps([x["text"] for x in segs if "PREF" in x["tags"]],
                            ensure_ascii=False) or None,
                 json.dumps([x["text"] for x in segs if "SUFF" in x["tags"]],
                            ensure_ascii=False) or None))
            matched += 1

    for i, row in enumerate(grammar.verb_lemmas(words, verbs, masdars), 1):
        con.execute("INSERT INTO verb_lemmas VALUES(?,?,?,?,?,?,?,?,?,?)",
                    (i, row["lemma"], row["root"], row["verb_form"], row["bab_ar"],
                     row["bab_key"], row["masdar"], row["masdar_source"],
                     row["source"], row["occurrences"]))
    print(f"    grammar: {matched}/{total} words aligned "
          f"({matched * 100 // max(total, 1)}%)")


def build_core():
    con, path = fresh_db("core.db")
    con.executescript(CORE_SCHEMA)
    con.execute("INSERT INTO meta VALUES('schema_version', ?)", (str(SCHEMA_VERSION),))

    # surahs
    for s in load("metadata/quran-metadata-surah-name.json").values():
        con.execute("INSERT INTO surahs VALUES(?,?,?,?,?,?,?,?)",
                    (s["id"], s["name"], s["name_simple"], s["name_arabic"],
                     s["revelation_order"], s["revelation_place"],
                     s["verses_count"], int(s["bismillah_pre"])))

    # ayahs with section numbers, page, sajda
    juz = section_lookup("metadata/quran-metadata-juz.json", "juz_number")
    hizb = section_lookup("metadata/quran-metadata-hizb.json", "hizb_number")
    rub = section_lookup("metadata/quran-metadata-rub.json", "rub_number")
    ruku = section_lookup("metadata/quran-metadata-ruku.json", "ruku_number")
    manzil = section_lookup("metadata/quran-metadata-manzil.json", "manzil_number")
    sajda = {tuple(key_parts(s["verse_key"])): s["sajdah_type"]
             for s in load("metadata/quran-metadata-sajda.json").values()}
    pages = {tuple(key_parts(k)): v["page_number"]
             for k, v in load(AYAH_SCRIPTS_CORE["qpc-v1-glyph"]).items()}
    for a in load("metadata/quran-metadata-ayah.json").values():
        s, n = a["surah_number"], a["ayah_number"]
        con.execute("INSERT INTO ayahs VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                    (a["id"], s, n, a["verse_key"], a["words_count"],
                     pages.get((s, n)), juz.get((s, n)), hizb.get((s, n)),
                     rub.get((s, n)), ruku.get((s, n)), manzil.get((s, n)),
                     sajda.get((s, n))))

    # ayah-level scripts
    for sid, (slug, src) in enumerate(AYAH_SCRIPTS_CORE.items(), 1):
        con.execute("INSERT INTO scripts VALUES(?,?,?,?)", (sid, slug, "ayah", "core"))
        for k, v in load(src).items():
            s, a = key_parts(k)
            con.execute("INSERT INTO ayah_text VALUES(?,?,?,?)", (sid, s, a, v["text"]))

    # tajweed, ayah level (parsed)
    for v in load("mushaf/qpc-hafs-tajweed.db")["verses"]:
        text, spans = parse_tajweed(v["text"])
        con.execute("INSERT INTO tajweed_ayah VALUES(?,?,?,?)",
                    (v["surah"], v["ayah"], text, json.dumps(spans)))

    # words
    qpc = load("mushaf/qpc-hafs-word-by-word.json")
    v1 = load("mushaf/qpc-v1-glyph-codes-wbw.json")
    indo = load("mushaf/indopak.json")
    tajw = load("mushaf/qpc-hafs-tajweed.json")
    tr_en = load("translation/en/english-wbw-translation.json")
    tr_bn = load("translation/bn/bangali-word-by-word-translation.json")
    for k, w in qpc.items():
        s, a, p = loc_parts(k)
        tt, tsp = parse_tajweed(tajw[k]["text"]) if k in tajw else (None, None)
        con.execute("INSERT INTO words VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                    (s, a, p, k, w["text"],
                     v1.get(k, {}).get("text"), indo.get(k, {}).get("text"),
                     tt, json.dumps(tsp) if tsp else None,
                     tr_en.get(k), tr_bn.get(k)))

    # translations & transliterations
    rid = 0
    for slug, lang, name, src, has_fn in TRANSLATIONS:
        rid += 1
        con.execute("INSERT INTO resources VALUES(?,?,?,?,?)",
                    (rid, slug, lang, name, "translation"))
        d = load(src)
        if "translation" in d and isinstance(d["translation"], list):  # rawai layout
            for row in d["translation"]:
                con.execute("INSERT INTO translations VALUES(?,?,?,?,NULL)",
                            (rid, row["sura"], row["ayah"], row["text"]))
        else:
            for k, v in d.items():
                s, a = key_parts(k)
                fn = json.dumps(v["f"], ensure_ascii=False) if has_fn and v.get("f") else None
                con.execute("INSERT INTO translations VALUES(?,?,?,?,?)",
                            (rid, s, a, v["t"], fn))
    for slug, src in TRANSLITERATIONS:
        rid += 1
        con.execute("INSERT INTO resources VALUES(?,?,?,?,?)",
                    (rid, slug, "en", slug, "transliteration"))
        for k, v in load(src).items():
            s, a = key_parts(k)
            text = v["t"] if isinstance(v, dict) else v
            con.execute("INSERT INTO translations VALUES(?,?,?,?,NULL)", (rid, s, a, text))

    # morphology
    wr = load("morphology/word-root.db")
    for r in wr["roots"]:
        con.execute("INSERT INTO roots VALUES(?,?,?,?,?,?)",
                    (r["id"], r["arabic_trilateral"], norm_root(r["arabic_trilateral"]),
                     r["english_trilateral"], r["words_count"], r["uniq_words_count"]))
    for x in wr["root_words"]:
        s, a, p = loc_parts(x["word_location"])
        con.execute("INSERT OR IGNORE INTO word_roots VALUES(?,?,?,?,?)",
                    (x["root_id"], x["word_location"], s, a, p))
    wl = load("morphology/word-lemma.db")
    for r in wl["lemmas"]:
        con.execute("INSERT INTO lemmas VALUES(?,?,?)", (r["id"], r["text"], r["text_clean"]))
    for x in wl["lemma_words"]:
        s, a, p = loc_parts(x["word_location"])
        con.execute("INSERT OR IGNORE INTO word_lemmas VALUES(?,?,?,?,?)",
                    (x["lemma_id"], x["word_location"], s, a, p))
    ws = load("morphology/word-stem.db")
    for r in ws["stems"]:
        con.execute("INSERT INTO stems VALUES(?,?,?)", (r["id"], r["text"], r["text_clean"]))
    for x in ws["stem_words"]:
        s, a, p = loc_parts(x["word_location"])
        con.execute("INSERT OR IGNORE INTO word_stems VALUES(?,?,?,?,?)",
                    (x["stem_id"], x["word_location"], s, a, p))
    ar = {r["verse_key"]: r["text"] for r in load("morphology/ayah-root.db")["roots"]}
    al = {r["verse_key"]: r["text"] for r in load("morphology/ayah-lemma.db")["lemmas"]}
    ast = {r["verse_key"]: r["text"] for r in load("morphology/ayah-stem.db")["stems"]}
    for k in set(ar) | set(al) | set(ast):
        s, a = key_parts(k)
        con.execute("INSERT INTO ayah_morphology VALUES(?,?,?,?,?)",
                    (s, a, ar.get(k), al.get(k), ast.get(k)))

    # similarities
    for k, matches in load("similarities/matching-ayah.json").items():
        s, a = key_parts(k)
        for m in matches:
            con.execute("INSERT INTO similar_ayahs VALUES(?,?,?,?,?,?,?)",
                        (s, a, m["matched_ayah_key"], m["matched_words_count"],
                         m["coverage"], m["score"], json.dumps(m["match_words"])))
    con.execute("CREATE INDEX idx_similar ON similar_ayahs(surah, ayah)")
    phrases = load(Path("similarities/Mutashabihat ul Quran.json/phrases.json"))
    for pid, ph in phrases.items():
        con.execute("INSERT INTO phrases VALUES(?,?,?,?,?,?,?)",
                    (int(pid), ph["source"]["key"], ph["source"]["from"],
                     ph["source"]["to"], ph["surahs"], ph["ayahs"], ph["count"]))
        for vk, ranges in ph["ayah"].items():
            s, a = key_parts(vk)
            con.execute("INSERT OR REPLACE INTO phrase_occurrences VALUES(?,?,?,?,?)",
                        (int(pid), vk, s, a, json.dumps(ranges)))
    con.execute("CREATE INDEX idx_phrase_occ_verse ON phrase_occurrences(surah, ayah)")

    # themes / topics / surah info
    for t in load("ayah_theme/ayah-themes.db")["themes"]:
        con.execute("INSERT INTO themes VALUES(?,?,?,?,?)",
                    (t["surah_number"], t["ayah_from"], t["ayah_to"],
                     t["theme"], t.get("keywords")))
    for t in load("info/topics.db")["topics"]:
        con.execute("INSERT INTO topics VALUES(?,?,?,?,?,?,?,?,?,?)",
                    (t["topic_id"], t["name"], t.get("arabic_name"),
                     t.get("parent_id"), t.get("thematic_parent_id"),
                     t.get("ontology_parent_id"), t.get("description"),
                     t.get("wiki_link"),
                     json.dumps(t.get("ayahs"), ensure_ascii=False),
                     json.dumps(t.get("related_topics"), ensure_ascii=False)))
    for k, v in load("info/surah-info-en.json").items():
        con.execute("INSERT INTO surah_info VALUES(?,?,?)",
                    (v["surah_number"], v["surah_name"], v["text"]))

    add_grammar(con)

    # FTS over primary resources
    con.execute("""
      INSERT INTO fts_ayah(verse_key, ar_simple, tr_en, tr_bn, translit)
      SELECT a.verse_key,
        (SELECT text FROM ayah_text t JOIN scripts sc ON sc.id=t.script_id
          WHERE sc.slug='uthmani-simple' AND t.surah=a.surah AND t.ayah=a.ayah),
        (SELECT text FROM translations tr JOIN resources r ON r.id=tr.resource_id
          WHERE r.slug='en-sahih-international' AND tr.surah=a.surah AND tr.ayah=a.ayah),
        (SELECT text FROM translations tr JOIN resources r ON r.id=tr.resource_id
          WHERE r.slug='bn-abu-bakr-zakaria' AND tr.surah=a.surah AND tr.ayah=a.ayah),
        (SELECT text FROM translations tr JOIN resources r ON r.id=tr.resource_id
          WHERE r.slug='translit-simple' AND tr.surah=a.surah AND tr.ayah=a.ayah)
      FROM ayahs a""")

    finish_db(con)
    return path


# ------------------------------------------------------- scripts_extra.db
def build_scripts_extra():
    con, path = fresh_db("scripts_extra.db")
    con.executescript("""
      CREATE TABLE scripts(id INTEGER PRIMARY KEY, slug TEXT, level TEXT);
      CREATE TABLE ayah_text(script_id INTEGER, surah INTEGER, ayah INTEGER,
        text TEXT, PRIMARY KEY(script_id, surah, ayah)) WITHOUT ROWID;
      CREATE TABLE word_text(script_id INTEGER, location TEXT, surah INTEGER,
        ayah INTEGER, pos INTEGER, text TEXT,
        PRIMARY KEY(script_id, location)) WITHOUT ROWID;
    """)
    sid = 0
    for slug, src in AYAH_SCRIPTS_EXTRA.items():
        sid += 1
        con.execute("INSERT INTO scripts VALUES(?,?, 'ayah')", (sid, slug))
        for k, v in load(src).items():
            s, a = key_parts(k)
            con.execute("INSERT INTO ayah_text VALUES(?,?,?,?)", (sid, s, a, v["text"]))
    for slug, src in WORD_SCRIPTS_EXTRA.items():
        sid += 1
        con.execute("INSERT INTO scripts VALUES(?,?, 'word')", (sid, slug))
        for k, v in load(src).items():
            s, a, p = loc_parts(k)
            text = v["text"] if isinstance(v, dict) else v
            con.execute("INSERT INTO word_text VALUES(?,?,?,?,?,?)",
                        (sid, k, s, a, p, text))
    finish_db(con)
    return path


# ------------------------------------------------------------- tafsir dbs
def build_tafsirs():
    paths = []
    for src in sorted((DATA / "tafsir").glob("*/*")):
        slug = src.name.replace(".json", "").replace(".db", "")
        lang = src.parent.name
        con, path = fresh_db(f"tafsir_{slug}.db")
        con.executescript("""
          CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
          CREATE TABLE tafsir(surah INTEGER, ayah INTEGER, group_key TEXT,
            text TEXT, PRIMARY KEY(surah, ayah)) WITHOUT ROWID;
        """)
        con.execute("INSERT INTO meta VALUES('slug',?)", (slug,))
        con.execute("INSERT INTO meta VALUES('lang',?)", (lang,))
        for k, v in load(Path("tafsir") / lang / src.name).items():
            s, a = key_parts(k)
            if isinstance(v, str):  # alias: this ayah is covered by group v
                con.execute("INSERT INTO tafsir VALUES(?,?,?,NULL)", (s, a, v))
            else:
                con.execute("INSERT INTO tafsir VALUES(?,?,?,?)", (s, a, k, v["text"]))
        finish_db(con)
        paths.append(path)
    return paths


# -------------------------------------------------------------- audio dbs
def build_audio():
    paths = []
    for src in sorted((DATA / "audio").glob("*")):
        rec_id = src.name.rsplit("-", 1)[-1].replace(".json", "")
        slug = src.name.replace(".json", "")
        con, path = fresh_db(f"audio_{rec_id}.db")
        con.executescript("""
          CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
          CREATE TABLE ayah_audio(surah INTEGER, ayah INTEGER, url TEXT,
            duration_ms INTEGER, segments TEXT,
            PRIMARY KEY(surah, ayah)) WITHOUT ROWID;
        """)
        con.execute("INSERT INTO meta VALUES('slug',?)", (slug,))
        for k, v in load(Path("audio") / src.name).items():
            con.execute("INSERT INTO ayah_audio VALUES(?,?,?,?,?)",
                        (v["surah_number"], v["ayah_number"], v["audio_url"],
                         v.get("duration"), json.dumps(v.get("segments"))))
        finish_db(con)
        paths.append(path)
    return paths


# ------------------------------------------------------------- dict_ar.db
def build_dict():
    src = DATA / "arramooz/data/arabicdictionary.sqlite"
    path = BUILD / "dict_ar.db"
    path.unlink(missing_ok=True)
    con = sqlite3.connect(path)
    con.execute("ATTACH ? AS src", (str(src),))
    con.execute("CREATE TABLE nouns AS SELECT *, '' AS root_norm FROM src.nouns")
    con.execute("CREATE TABLE verbs AS SELECT *, '' AS root_norm FROM src.verbs")
    con.execute("DETACH src")
    for table in ("nouns", "verbs"):
        for rowid, root in con.execute(f"SELECT rowid, root FROM {table}").fetchall():
            con.execute(f"UPDATE {table} SET root_norm=? WHERE rowid=?",
                        (norm_root(root), rowid))
        con.execute(f"CREATE INDEX idx_{table}_root ON {table}(root_norm)")
    finish_db(con)
    return path


# ------------------------------------------------------------- font packs
def build_fontpacks():
    packs = [("fontpack_v1.zip", DATA / "fonts/ttf"),
             ("fontpack_v2.zip", DATA / "fonts/QPC V2 Font.ttf")]
    paths = []
    for name, srcdir in packs:
        path = BUILD / name
        path.unlink(missing_ok=True)
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(srcdir.glob("*.ttf")):
                z.write(f, f.name)
        paths.append(path)
    return paths


# --------------------------------------------------------------- manifest
ATTRIBUTION = {
    "core": "Quranic Universal Library (qul.tarteel.ai); grammar from the "
            "Quranic Arabic Corpus (corpus.quran.com, Kais Dukes, GPL)",
    "scripts_extra": "Quranic Universal Library (qul.tarteel.ai)",
    "tafsir": "Quranic Universal Library (qul.tarteel.ai); see book for author",
    "audio": "Quranic Universal Library / audio-cdn.tarteel.ai",
    "dict_ar": "Arramooz Alwaseet, Taha Zerrouki (GPL) — github.com/linuxscout/arramooz",
    "fontpack": "King Fahd Glorious Quran Printing Complex via QUL",
}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_manifest(paths):
    modules = []
    for p in sorted(paths):
        kind = p.stem.split("_")[0] if p.stem != "core" else "core"
        modules.append({
            "id": p.stem, "file": p.name, "bytes": p.stat().st_size,
            "sha256": sha256(p), "schema_version": SCHEMA_VERSION,
            "attribution": ATTRIBUTION.get(kind, ATTRIBUTION.get(p.stem, "QUL")),
        })
    out = BUILD / "manifest.json"
    out.write_text(json.dumps({"version": 1, "modules": modules}, indent=1))
    return out


# ------------------------------------------------------------- validation
def validate():
    con = sqlite3.connect(BUILD / "core.db")
    q = lambda sql: con.execute(sql).fetchone()[0]
    checks = [
        ("surahs", q("SELECT count(*) FROM surahs"), 114),
        ("ayahs", q("SELECT count(*) FROM ayahs"), 6236),
        ("words", q("SELECT count(*) FROM words"), 83668),
        ("core ayah scripts", q("SELECT count(*) FROM scripts"), len(AYAH_SCRIPTS_CORE)),
        ("ayah_text rows", q("SELECT count(*) FROM ayah_text"),
         6236 * len(AYAH_SCRIPTS_CORE)),
        ("tajweed ayahs", q("SELECT count(*) FROM tajweed_ayah"), 6236),
        ("roots", q("SELECT count(*) FROM roots"), 1642),
        ("word_roots", q("SELECT count(*) FROM word_roots"), None),
        ("translations resources", q("SELECT count(*) FROM resources"),
         len(TRANSLATIONS) + len(TRANSLITERATIONS)),
        ("fts rows", q("SELECT count(*) FROM fts_ayah"), 6236),
        ("juz coverage", q("SELECT count(*) FROM ayahs WHERE juz IS NULL"), 0),
        ("page coverage", q("SELECT count(*) FROM ayahs WHERE page IS NULL"), 0),
        ("last page", q("SELECT max(page) FROM ayahs"), 604),
        ("sajda ayahs", q("SELECT count(*) FROM ayahs WHERE sajda_type IS NOT NULL"), 15),
        ("wbw en missing", q("SELECT count(*) FROM words WHERE tr_en IS NULL"), None),
        ("wbw bn missing", q("SELECT count(*) FROM words WHERE tr_bn IS NULL"), None),
        ("unparsed tajweed markup (ayah)",
         q("SELECT count(*) FROM tajweed_ayah WHERE text LIKE '%<rule%' "
           "OR text LIKE '%</rule%' OR text LIKE '%<%'"), 0),
        ("unparsed tajweed markup (word)",
         q("SELECT count(*) FROM words WHERE tajweed_text LIKE '%<%'"), 0),
        ("grammar: words annotated",
         q("SELECT count(*) FROM word_grammar"), None),
        ("grammar: verb lemmas", q("SELECT count(*) FROM verb_lemmas"), None),
        ("grammar: forms II-X all have a bab",
         q("SELECT count(*) FROM verb_lemmas WHERE verb_form BETWEEN 2 AND 10 "
           "AND bab_ar IS NULL"), 0),
        ("grammar: verb words showing a bab (%)",
         q("SELECT 100 * (SELECT count(*) FROM word_grammar g JOIN verb_lemmas v"
           "  ON v.lemma=g.lemma AND v.root=g.root"
           " WHERE g.pos_tag='V' AND v.bab_ar IS NOT NULL)"
           " / (SELECT count(*) FROM word_grammar WHERE pos_tag='V')"), None),
        ("grammar: no template masdar on hamzated roots",
         q("SELECT count(*) FROM verb_lemmas WHERE masdar_source='pattern' "
           "AND (masdar LIKE '%أ%' OR masdar LIKE '%ؤ%' OR masdar LIKE '%ئ%')"), 0),
    ]
    ok = True
    for name, got, want in checks:
        status = "OK " if want is None or got == want else "FAIL"
        if status == "FAIL":
            ok = False
        print(f"  [{status}] {name}: {got}" + (f" (expected {want})" if want else ""))
    # spot checks
    fts = con.execute(
        "SELECT verse_key FROM fts_ayah WHERE fts_ayah MATCH 'straight path' LIMIT 1"
    ).fetchone()
    print(f"  [{'OK ' if fts and fts[0]=='1:6' else 'FAIL'}] FTS 'straight path' -> {fts}")
    dcon = sqlite3.connect(BUILD / "dict_ar.db")
    dcon.execute("ATTACH ? AS core", (str(BUILD / "core.db"),))
    joined = dcon.execute("""
      SELECT count(DISTINCT r.id) FROM core.roots r
      JOIN nouns n ON n.root_norm = r.arabic_norm""").fetchone()[0]
    print(f"  [{'OK ' if joined > 500 else 'FAIL'}] QUL roots with dict entries: "
          f"{joined} / 1642")
    con.close(); dcon.close()
    return ok


def main():
    BUILD.mkdir(exist_ok=True)
    skip_fonts = "--skip-fonts" in sys.argv
    outputs = []
    print("core.db ..."); outputs.append(build_core())
    print("scripts_extra.db ..."); outputs.append(build_scripts_extra())
    print("tafsir ..."); outputs.extend(build_tafsirs())
    print("audio ..."); outputs.extend(build_audio())
    print("dict_ar.db ..."); outputs.append(build_dict())
    if not skip_fonts:
        print("font packs ..."); outputs.extend(build_fontpacks())
    manifest = write_manifest(outputs)
    print(f"\n{len(outputs)} modules -> {BUILD}")
    for p in outputs:
        print(f"  {p.name:45s} {p.stat().st_size/1e6:8.1f} MB")
    print("\nValidation:")
    ok = validate()
    print("\nManifest:", manifest)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
