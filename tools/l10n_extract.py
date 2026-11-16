#!/usr/bin/env python3
"""Finds user-visible string literals in Sources/ and compares them with Sources/Resources/Localizable.xcstrings.

Usage:
  python tools/l10n_extract.py              report: counts, missing keys, per-language gaps
  python tools/l10n_extract.py --missing    print missing keys as a JSON list
  python tools/l10n_extract.py --add-missing  add missing keys (no translations yet) to the catalog
  python tools/l10n_extract.py --suspects   print string literals that look user-visible but are NOT localized
  python tools/l10n_extract.py --check      exit 1 when keys are missing or translations are incomplete (used by CI)
  python tools/l10n_extract.py --build      merge tools/l10n_parts/*.json into the catalog (adds every key found in code)

Part files (one per area, written by translators) look like:
  { "Export": {"es": "Exportar", "fr": "Exporter", "de": "Exportieren", "zh-Hans": "导出"},
    "%lld pages": {"en": {"one": "%lld page", "other": "%lld pages"},
                   "es": {"one": "%lld página", "other": "%lld páginas"}, "fr": {...}, "de": {...},
                   "zh-Hans": "%lld 页"} }
A value that is an object with one/other keys becomes a plural variation. The English key is the source text.
Add "_comment" as a sibling key to give translators context (it is stored as the catalog comment).

A literal counts as localized when it appears inside a SwiftUI initializer that takes a LocalizedStringKey
(Text, Button, Label, Toggle, Section, TextField, Picker, Menu, Link, navigationTitle, accessibilityLabel,
accessibilityHint, alert, confirmationDialog, ...) or inside String(localized:) / LocalizedStringKey(...).
Interpolations are normalised the way Xcode does it: backslash-paren expressions become %@ (or %lld for
obvious integers) and a literal percent sign becomes %%.
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources"
CATALOG = SRC / "Resources" / "Localizable.xcstrings"
LANGS = ["es", "fr", "de", "zh-Hans"]

LOC_CALLS = [
    r'Text', r'Button', r'Label', r'Toggle', r'Section', r'TextField', r'SecureField', r'Picker', r'Menu', r'Link',
    r'DisclosureGroup', r'NavigationLink', r'LabeledContent', r'ShareLink', r'Stepper', r'Slider',
    r'\.navigationTitle', r'\.accessibilityLabel', r'\.accessibilityHint', r'\.accessibilityValue',
    r'\.help', r'\.alert', r'\.confirmationDialog', r'\.navigationBarTitle',
    r'ContentUnavailableView', r'\.badge',
]
LIT = r'"((?:[^"\\]|\\.)*)"'
CALL_RE = re.compile(r'(?<![A-Za-z0-9_])(?:' + '|'.join(LOC_CALLS) + r')\s*\(\s*(?:title\s*:\s*|label\s*:\s*)?' + LIT
                     + r'|(?<![A-Za-z0-9_])(?:String\(\s*localized\s*:\s*|LocalizedStringKey\(\s*|LocalizedStringResource\(\s*)' + LIT)
WORDY = re.compile(r'[A-Za-z]{2,}')
BS = chr(92)  # backslash
INT_NAMES = re.compile(r'\b(count|index|number|total|n|i|pages?|years?|words?|days?|hours?|minutes?|seconds?|score|percent|completion)\b')


def normalise(s):
    s = s.replace('%', '%%')
    out = []
    i = 0
    while i < len(s):
        if s.startswith(BS + '(', i):
            depth, j = 1, i + 2
            while j < len(s) and depth:
                depth += (s[j] == '(') - (s[j] == ')')
                j += 1
            expr = s[i + 2:j - 1]
            is_int = bool(INT_NAMES.search(expr)) and 'name' not in expr.lower() and '.' not in expr.split('(')[0]
            out.append('%lld' if is_int else '%@')
            i = j
        else:
            out.append(s[i])
            i += 1
    t = ''.join(out)
    t = t.replace(BS + 'n', '\n').replace(BS + '"', '"')
    t = t.replace(BS + 'u{2019}', '’').replace(BS + 'u{2014}', '—').replace(BS + 'u{00A0}', ' ')
    return t.replace(BS + BS, BS)


def strip_comments(code):
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    return re.sub(r'(?m)(?<!:)//.*$', '', code)


def scan():
    found = {}
    suspects = {}
    for p in sorted(SRC.rglob('*.swift')):
        code = strip_comments(p.read_text(encoding='utf-8', errors='replace'))
        spans = []
        for m in CALL_RE.finditer(code):
            lit = m.group(1) if m.group(1) is not None else m.group(2)
            key = normalise(lit)
            if WORDY.search(re.sub(r'%(?:\d+\$)?(?:lld|ld|d|@|f|lf|s)', '', key)):
                found.setdefault(key, set()).add(str(p.relative_to(ROOT)))
            spans.append(m.span(1) if m.group(1) is not None else m.span(2))
        for m in re.finditer(LIT, code):
            if any(a <= m.start(1) <= b for a, b in spans):
                continue
            s = m.group(1)
            if len(s) < 4 or not re.search(r'[A-Za-z]{3,}', s):
                continue
            if ' ' not in s and not s[0].isupper():
                continue
            if ' ' not in s and re.search(r'[._/#:$-]', s):
                continue
            ls = code.rfind('\n', 0, m.start()) + 1
            le = code.find('\n', m.start())
            line = code[ls:le]
            if re.search(r'(accessibilityIdentifier|systemName|systemImage|Notification\.Name|UserDefaults|forKey|^\s*import\b|Logger|print\(|assert|fatalError|#if|rawValue|CodingKeys|identifier|Image\(|NSLocalizedString|UTType|ck\.|com\.)', line):
                continue
            suspects.setdefault(s, set()).add(str(p.relative_to(ROOT)))
    return found, suspects


def load_catalog():
    if CATALOG.exists():
        return json.loads(CATALOG.read_text(encoding='utf-8'))
    return {"sourceLanguage": "en", "strings": {}, "version": "1.0"}


def lang_missing(cat, key):
    locs = cat["strings"].get(key, {}).get("localizations", {})
    return [l for l in LANGS if not locs.get(l, {}).get("stringUnit", {}).get("value")]


def unit(value, state="translated"):
    return {"stringUnit": {"state": state, "value": value}}


def loc_entry(value):
    if isinstance(value, dict):
        return {"variations": {"plural": {cat: unit(txt) for cat, txt in value.items()}}}
    return unit(value)


def build(cat):
    parts_dir = ROOT / "tools" / "l10n_parts"
    n_parts = 0
    for pf in sorted(parts_dir.glob("*.json")):
        data = json.loads(pf.read_text(encoding="utf-8"))
        n_parts += 1
        for key, tr in data.items():
            if key.startswith("_"):
                continue
            entry = cat["strings"].setdefault(key, {})
            entry["extractionState"] = "manual"
            if "_comment" in tr:
                entry["comment"] = tr["_comment"]
            locs = entry.setdefault("localizations", {})
            for lang, value in tr.items():
                if lang == "_comment":
                    continue
                locs[lang] = loc_entry(value)
    found, _ = scan()
    for k in found:
        cat["strings"].setdefault(k, {"extractionState": "manual", "localizations": {}})
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2, sort_keys=True) + chr(10), encoding="utf-8")
    return n_parts


def lang_missing(cat, key):  # noqa: F811 - plural aware version replaces the simple one
    locs = cat["strings"].get(key, {}).get("localizations", {})
    out = []
    for l in LANGS:
        e = locs.get(l, {})
        has = bool(e.get("stringUnit", {}).get("value")) or bool(e.get("variations"))
        if not has:
            out.append(l)
    return out


def spec_ok(source, translated):
    pat = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|lf|s)")
    a = sorted(re.findall(pat, source))
    b = sorted(re.findall(pat, translated))
    return a == b


def main():
    args = set(sys.argv[1:])
    argv = sys.argv[1:]
    if "--keys-in" in argv:
        prefix = argv[argv.index("--keys-in") + 1].replace("/", chr(92))
        prefix2 = prefix.replace(chr(92), "/")
        found_k, _ = scan()
        for k in sorted(found_k):
            if any(f.startswith(prefix) or f.startswith(prefix2) for f in found_k[k]):
                print(json.dumps(k, ensure_ascii=False))
        return
    if "--lint" in args:
        bad = 0
        for pf in sorted((ROOT / "tools" / "l10n_parts").glob("*.json")):
            data = json.loads(pf.read_text(encoding="utf-8"))
            for key, tr in data.items():
                if key.startswith("_"):
                    continue
                for lang in LANGS:
                    if lang not in tr:
                        print("%s: %r has no %s" % (pf.name, key, lang)); bad += 1; continue
                    vals = tr[lang].values() if isinstance(tr[lang], dict) else [tr[lang]]
                    if isinstance(tr[lang], dict) and "other" not in tr[lang]:
                        print("%s: %r %s plural needs 'other'" % (pf.name, key, lang)); bad += 1
                    for v in vals:
                        if not v:
                            print("%s: %r %s is empty" % (pf.name, key, lang)); bad += 1
                        elif not isinstance(tr.get("en"), dict) and not spec_ok(key, v) and "%" in key:
                            print("%s: %r %s placeholders differ: %r" % (pf.name, key, lang, v)); bad += 1
        print("lint problems: %d" % bad)
        sys.exit(1 if bad else 0)
    if "--build" in args:
        cat = load_catalog()
        n = build(cat)
        print("merged %d part files; catalog now has %d keys" % (n, len(cat["strings"])))
        args = args - {"--build"}
    found, suspects = scan()
    cat = load_catalog()
    keys = set(cat["strings"].keys())
    missing = sorted(k for k in found if k not in keys)
    unused = sorted(k for k in keys if k not in found)
    untranslated = {k: lang_missing(cat, k) for k in keys if lang_missing(cat, k)}
    if '--missing' in args:
        print(json.dumps(missing, ensure_ascii=False, indent=1))
        return
    if '--suspects' in args:
        for s in sorted(suspects):
            print(repr(s) + '  <- ' + sorted(suspects[s])[0])
        return
    if '--add-missing' in args:
        for k in missing:
            cat["strings"][k] = {"extractionState": "manual", "localizations": {}}
        CATALOG.parent.mkdir(parents=True, exist_ok=True)
        CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding='utf-8')
        print('added %d keys' % len(missing))
        return
    print('localizable literals found in code : %d' % len(found))
    print('catalog keys                        : %d' % len(keys))
    print('missing from catalog                : %d' % len(missing))
    print('in catalog but not found in code    : %d  (dynamic keys are fine)' % len(unused))
    print('catalog keys missing a translation  : %d' % len(untranslated))
    print('suspect literals (not localized)    : %d' % len(suspects))
    for k in missing[:15]:
        print('  MISSING', repr(k))
    if '--check' in args and (missing or untranslated):
        sys.exit(1)


if __name__ == '__main__':
    main()
