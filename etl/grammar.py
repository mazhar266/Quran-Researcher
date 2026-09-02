#!/usr/bin/env python3
"""Sarf (صرف) layer: word-level grammar from the Quranic Arabic Corpus.

Source: data/grammar/quran-morphology.txt — an Arabic-script fork of Quranic
Arabic Corpus morphology v0.4 (Kais Dukes, GPL). See data/grammar/NOTICE.md.

QAC annotates *segments* (prefix / stem / suffix) keyed surah:ayah:word:segment,
and its word numbering matches QUL's except that QUL counts the ayah-number
glyph as a trailing word (and QAC joins a few tokens like بعدما that QUL
splits). Words are therefore aligned by comparing letter-only text, and grammar
is emitted only for verified matches — never guessed.

Beyond the corpus features this derives, per verb lemma:
  * bab (باب) — deterministic for forms II-X; for form I from the ʿayn vowels
    of the past and present, taken from the Quran's own vocalised forms and
    from Arramooz's `future_type`.
  * masdar (مصدر) — pattern-instantiated for forms II-X; looked up in Arramooz
    for form I, whose masdar is samāʿī (heard, not derivable).
"""
import collections
import json
import re
import unicodedata

FATHA, KASRA, DAMMA = "َ", "ِ", "ُ"

# --- form I babs, keyed by (past ʿayn vowel, present ʿayn vowel) -------------
BAB_I = {
    (FATHA, DAMMA): ("نَصَرَ يَنْصُرُ", "nasara"),
    (FATHA, KASRA): ("ضَرَبَ يَضْرِبُ", "daraba"),
    (FATHA, FATHA): ("فَتَحَ يَفْتَحُ", "fataha"),
    (KASRA, FATHA): ("سَمِعَ يَسْمَعُ", "samia"),
    (DAMMA, DAMMA): ("كَرُمَ يَكْرُمُ", "karuma"),
    (KASRA, KASRA): ("حَسِبَ يَحْسِبُ", "hasiba"),
}
# Arramooz spells the present vowel out in Arabic.
ARRAMOOZ_VOWEL = {"فتحة": FATHA, "كسرة": KASRA, "ضمة": DAMMA,
                  FATHA: FATHA, KASRA: KASRA, DAMMA: DAMMA}

# --- forms II-X: bab name and masdar pattern (F/A/L = the three radicals) ----
FORMS = {
    2:  ("تَفْعِيل", "بَاب التَّفْعِيل", "taf'il", "تَFْAِيL"),
    3:  ("مُفَاعَلَة", "بَاب المُفَاعَلَة", "mufa'ala", "مُFَاAَLَة"),
    4:  ("إِفْعَال", "بَاب الإِفْعَال", "if'al", "إِFْAَاL"),
    5:  ("تَفَعُّل", "بَاب التَّفَعُّل", "tafa''ul", "تَFَAُّL"),
    6:  ("تَفَاعُل", "بَاب التَّفَاعُل", "tafa'ul", "تَFَاAُL"),
    7:  ("اِنْفِعَال", "بَاب الاِنْفِعَال", "infi'al", "اِنْFِAَاL"),
    8:  ("اِفْتِعَال", "بَاب الاِفْتِعَال", "ifti'al", "اِFْتِAَاL"),
    9:  ("اِفْعِلَال", "بَاب الاِفْعِلَال", "if'ilal", "اِFْAِLَاL"),
    10: ("اِسْتِفْعَال", "بَاب الاِسْتِفْعَال", "istif'al", "اِسْتِFْAَاL"),
}

PGN = {  # person-gender-number -> (Arabic sigah, latin key)
    "1S": ("مُتَكَلِّم وَحْدَهُ", "1s"),
    "1P": ("مُتَكَلِّم مَعَ الغَيْر", "1p"),
    "2MS": ("وَاحِد مُذَكَّر حَاضِر", "2ms"), "2MD": ("تَثْنِيَة مُذَكَّر حَاضِر", "2md"),
    "2MP": ("جَمْع مُذَكَّر حَاضِر", "2mp"), "2FS": ("وَاحِدَة مُؤَنَّث حَاضِر", "2fs"),
    "2FD": ("تَثْنِيَة مُؤَنَّث حَاضِر", "2fd"), "2FP": ("جَمْع مُؤَنَّث حَاضِر", "2fp"),
    "2D": ("تَثْنِيَة حَاضِر", "2d"),
    "3MS": ("وَاحِد مُذَكَّر غَائِب", "3ms"), "3MD": ("تَثْنِيَة مُذَكَّر غَائِب", "3md"),
    "3MP": ("جَمْع مُذَكَّر غَائِب", "3mp"), "3FS": ("وَاحِدَة مُؤَنَّث غَائِب", "3fs"),
    "3FD": ("تَثْنِيَة مُؤَنَّث غَائِب", "3fd"), "3FP": ("جَمْع مُؤَنَّث غَائِب", "3fp"),
}


def _strip(s):
    return "".join(c for c in s if not unicodedata.combining(c) and c != "ـ")


_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ء": "ا",
                       "ؤ": "ا", "ئ": "ا", "ى": "ي", "ة": "ه"})


def _norm(s):
    return _strip(s).replace(" ", "").translate(_FOLD)


def parse_corpus(path):
    """-> {(surah, ayah, word): [ {text, pos, feats:{...}, raw}, ... ]}"""
    words = collections.defaultdict(list)
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4:
                continue
            loc = parts[0].split(":")
            if len(loc) != 4:
                continue
            s, a, w, _seg = (int(x) for x in loc)
            feats = parts[3].split("|")
            words[(s, a, w)].append({
                "text": parts[1],
                "pos": parts[2],
                "tags": [t for t in feats if ":" not in t],
                "kv": dict(t.split(":", 1) for t in feats if ":" in t),
            })
    return words


def align(qul_words, qac_words):
    """Map QUL word position -> QAC segment list, by letter-only text.

    Handles QUL's trailing ayah-number glyph and the few ayahs where QAC keeps
    a token (بعدما) that QUL splits. Unverifiable positions are dropped.
    """
    out = {}
    qi = 0
    for wi, (pos, qul_text) in enumerate(qul_words):
        if qi >= len(qac_words):
            break
        want = _strip(qul_text)
        if not want or not any(c.isalpha() for c in want):
            continue  # ayah-number glyph
        have = _strip("".join(seg["text"] for seg in qac_words[qi]))
        if _norm(have) == _norm(want):
            out[pos] = qac_words[qi]
            qi += 1
        elif _norm(have).startswith(_norm(want)) and wi + 1 < len(qul_words):
            # QAC merged this QUL word with the next: attach to both, advance
            # QAC once after the second QUL word consumes it.
            nxt = _norm(want) + _norm(qul_words[wi + 1][1])
            if _norm(have) == nxt:
                out[pos] = qac_words[qi]
                out[qul_words[wi + 1][0]] = qac_words[qi]
                qi += 1
        else:
            qi += 1  # desync: skip, emit nothing for this word
    return out


def ayn_vowel(surface, root):
    """Vowel carried by the 2nd radical of `surface`, or None."""
    letters, marks, buf = [], [], ""
    for c in surface:
        if unicodedata.combining(c):
            buf += c
        else:
            if letters:
                marks.append(buf)
            letters.append(c)
            buf = ""
    marks.append(buf)
    radicals = [c for c in _strip(root) if c.strip()]
    if len(radicals) < 3:
        return None
    idx, ri = [], 0
    for i, c in enumerate(letters):
        if ri < len(radicals) and c == radicals[ri]:
            idx.append(i)
            ri += 1
    if ri < 3:
        return None
    m = marks[idx[1]] if idx[1] < len(marks) else ""
    return next((v for v in (DAMMA, KASRA, FATHA) if v in m), None)


WEAK = set("اوىيءأإآؤئ")

_HAMZA_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
                             "ؤ": "ا", "ئ": "ا", "ى": "ي"})


def strict_key(s):
    """Verb key that keeps harakat (so آمَنَ form IV never collides with the
    form II أَمَّنَ) and folds only hamza carriers, whose spelling varies."""
    return (s or "").replace("ـ", "").replace("ٰ", "").translate(_HAMZA_FOLD).strip()


# Letter-skeleton prefix each form's masdar must show, used to reject a
# loose dictionary match that actually belongs to a different form.
FORM_PREFIX = {2: ("ت",), 3: ("م", "ف"), 4: ("ا",), 5: ("ت",), 6: ("ت",),
               7: ("ان",), 8: ("ا",), 9: ("ا",), 10: ("است",)}


def masdar_fits(masdar, vf):
    """Is this masdar's shape consistent with the verb's form?"""
    skel = _strip(masdar).replace("ٱ", "ا")
    if vf in FORM_PREFIX:
        return any(skel.startswith(p) for p in FORM_PREFIX[vf])
    # Form I: reject shapes that clearly belong to an augmented form.
    return not (skel.startswith("است") or skel.startswith("ان")
                or (skel.startswith("ت") and len(skel) >= 5)
                or (skel.startswith("ا") and len(skel) >= 5))


def is_sound(root):
    """A root with no hamza or weak letter — patterns instantiate safely."""
    radicals = [c for c in _strip(root) if c.strip()]
    return len(radicals) == 3 and not any(c in WEAK for c in radicals)


def instantiate(pattern, root):
    """Fill a masdar pattern's F/A/L placeholders with the root's radicals.

    Only valid for sound roots: weak/hamzated roots undergo changes the
    template cannot express (أقام -> إقامة, not إقوام), so callers must check
    is_sound() first rather than print a malformed word.
    """
    radicals = [c for c in _strip(root) if c.strip()]
    if len(radicals) < 3:
        return None
    return (pattern.replace("F", radicals[0])
                   .replace("A", radicals[1])
                   .replace("L", radicals[2]))


# A hollow verb (أجوف: middle radical و/ي) hides its ʿayn vowel inside a long
# vowel, so the classical signal is the vowel on the FIRST radical of the
# present tense: يَقُولُ -> ḍamma -> naṣara, يَبِيعُ -> kasra -> ḍaraba,
# يَخَافُ -> fatḥa -> samiʿa (from an original kasra past, خَوِفَ).
HOLLOW_BAB = {DAMMA: (FATHA, DAMMA), KASRA: (FATHA, KASRA), FATHA: (KASRA, FATHA)}


def first_radical_vowel(surface, root):
    """Vowel carried by the first radical of `surface`."""
    letters, marks, buf = [], [], ""
    for c in surface:
        if unicodedata.combining(c):
            buf += c
        else:
            if letters:
                marks.append(buf)
            letters.append(c)
            buf = ""
    marks.append(buf)
    radicals = [c for c in _strip(root) if c.strip()]
    if not radicals:
        return None
    for i, c in enumerate(letters):
        if c == radicals[0]:
            m = marks[i] if i < len(marks) else ""
            return next((v for v in (DAMMA, KASRA, FATHA) if v in m), None)
    return None


def is_hollow(root):
    radicals = [c for c in _strip(root) if c.strip()]
    return len(radicals) == 3 and radicals[1] in "وي"


def verb_lemmas(words, arramooz_verbs, arramooz_masdars):
    """arramooz_masdars maps a normalised *verb* to its attested masdar(s)."""
    """Derive bab + masdar for every verb lemma in the corpus."""
    perf, impf, forms, counts = (collections.defaultdict(list),
                                 collections.defaultdict(list), {},
                                 collections.Counter())
    for segs in words.values():
        for seg in segs:
            if seg["pos"] != "V":
                continue
            lem, root = seg["kv"].get("LEM"), seg["kv"].get("ROOT")
            vf = seg["kv"].get("VF")
            if not (lem and root and vf):
                continue
            key = (lem, root)
            forms[key] = int(vf)
            counts[key] += 1
            if "PASS" not in seg["tags"]:
                if "PERF" in seg["tags"]:
                    perf[key].append(seg["text"])
                elif "IMPF" in seg["tags"]:
                    impf[key].append(seg["text"])

    rows = []
    for (lem, root), vf in forms.items():
        bab_ar = bab_key = masdar = source = None
        masdar_source = None
        # 1. Exact (harakat-preserving) dictionary link for this very verb.
        attested = arramooz_masdars["strict"].get(strict_key(lem))
        if attested:
            masdar, masdar_source = " · ".join(attested[:3]), "dictionary"
        if vf in FORMS:
            _, bab_ar, bab_key, pattern = FORMS[vf]
            source = "form"
            # 2. Deterministic template — safe only for sound roots.
            if not masdar and is_sound(root):
                masdar, masdar_source = instantiate(pattern, root), "pattern"
        elif vf == 1:
            pv = next((v for s in perf[(lem, root)]
                       if (v := ayn_vowel(s, root))), None)
            iv = next((v for s in impf[(lem, root)]
                       if (v := ayn_vowel(s, root))), None)
            if is_hollow(root) and not (pv and iv):
                # Read the bab off the present tense's first radical instead.
                fv = next((v for s in impf[(lem, root)]
                           if (v := first_radical_vowel(s, root))), None)
                if fv is None:
                    fv = ARRAMOOZ_VOWEL.get(next(
                        (ft for voc, ft in arramooz_verbs.get(_norm(root), [])
                         if _norm(voc) == _norm(lem)), ""))
                if fv in HOLLOW_BAB:
                    pv, iv = HOLLOW_BAB[fv]
                    source = "hollow"
            if not (pv and iv):  # fall back to the dictionary
                for voc, ft in arramooz_verbs.get(_norm(root), []):
                    if _norm(voc) == _norm(lem):
                        pv = pv or ayn_vowel(voc, root)
                        iv = iv or ARRAMOOZ_VOWEL.get((ft or "").strip())
                        if pv and iv:
                            source = "dictionary"
                            break
            else:
                source = "quran"
            if pv and iv and (pv, iv) in BAB_I:
                bab_ar, bab_key = BAB_I[(pv, iv)]
                bab_ar = f"بَاب {bab_ar}"
            else:
                source = None
        # 3. Looser dictionary link, keeping only shapes that fit the form.
        if not masdar:
            loose = [m for m in arramooz_masdars["loose"].get(_norm(lem), [])
                     if masdar_fits(m, vf)]
            if loose:
                masdar, masdar_source = " · ".join(loose[:3]), "dictionary"
        rows.append({
            "lemma": lem, "root": root, "verb_form": vf,
            "bab_ar": bab_ar, "bab_key": bab_key, "masdar": masdar,
            "masdar_source": masdar_source, "source": source,
            "occurrences": counts[(lem, root)],
        })
    return rows


def sigah(seg):
    """Traditional sigah parts (aspect, voice, person-gender-number, mood)."""
    tags = seg["tags"]
    aspect = ("PERF" if "PERF" in tags else
              "IMPF" if "IMPF" in tags else
              "IMPV" if "IMPV" in tags else None)
    voice = "PASS" if "PASS" in tags else ("ACT" if aspect else None)
    pgn = next((t for t in tags if t in PGN), None)
    return aspect, voice, pgn, seg["kv"].get("MOOD")
