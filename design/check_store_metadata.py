"""Checks docs/store/metadata.md and docs/store/metadata-localized.md against App Store limits.

Usage: python design/check_store_metadata.py
English file: reads the first fenced block under each "## <Field>" heading.
Localized file: reads the first fenced block under each "## <locale> > <Field>" heading,
for the locales in LOCALES. Apple counts characters (not bytes) in every localized field.
Exit code 1 when a limit is broken or a rule fails.
"""
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "docs" / "store"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

LIMITS = {  # heading: (limit, unit)
    "App Name": (30, "chars"),
    "Subtitle": (30, "chars"),
    "Keywords": (100, "bytes"),
    "Promotional Text": (170, "chars"),
    "Description": (4000, "chars"),
    "What's New": (4000, "chars"),
}

LOCALES = ["es-ES", "fr-FR", "de-DE", "zh-Hans"]
CJK_LOCALES = {"zh-Hans"}
LOCALIZED_LIMITS = {  # field: character limit
    "App Name": 30,
    "Subtitle": 30,
    "Keywords": 100,
    "Promotional Text": 170,
    "Description": 4000,
}
CAPTION_LINES = 6
CAPTION_MAX_WORDS = 5
CAPTION_MAX_CJK_CHARS = 12

# Third-party trademarks that must stay out of the name, subtitle and keywords.
TRADEMARKS = ["word", "google", "linkedin", "canva", "indeed", "microsoft", "docs", "office",
              "pages", "adobe", "acrobat", "zety", "novoresume", "infojobs", "stepstone", "xing",
              "monster"]
# Price words: not allowed in the name, subtitle or screenshot captions (guideline 2.3.7).
PRICE_WORDS = ["free", "gratis", "gratuit", "gratuite", "kostenlos", "umsonst", "免费"]
# Unverifiable ranking claims: not allowed in the name, subtitle, promo text or captions.
CLAIM_WORDS = ["best", "#1", "no.1", "top", "mejor", "número 1", "meilleur", "meilleure", "beste",
               "bester", "nummer 1", "最好", "最佳", "第一", "排名第一"]

ok = True


def fail(msg):
    global ok
    ok = False
    print("FAIL", msg)


def first_fence(section, label):
    f = re.search(r"```\n(.*?)\n```", section, re.S)
    if not f:
        raise SystemExit(f"missing fenced block under: {label}")
    return f.group(1)


def section(text, heading):
    m = re.search(r"^## " + re.escape(heading) + r"\s*$(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not m:
        raise SystemExit(f"missing heading: {heading}")
    return first_fence(m.group(1), heading)


def copy_rules(label, value):
    if "—" in value or "–" in value:
        fail(f"{label}: contains a dash character that is banned")
    if re.search(r"[\U0001F300-\U0001FAFF☀-➿]", value):
        fail(f"{label}: contains an emoji")


def fold(word):
    """Lowercase, strip accents and a plural s, so 'Modèles' and 'modele' compare equal."""
    w = unicodedata.normalize("NFKD", word.lower())
    w = "".join(c for c in w if not unicodedata.combining(c))
    if len(w) > 3 and w.endswith("s"):
        w = w[:-1]
    return w


def latin_words(text):
    return [fold(w) for w in re.findall(r"[^\W\d_]+|\d+", text) if not re.match(r"[　-鿿]", w)]


def has_term(text, term):
    """Whole-word match for Latin terms, substring match for CJK terms."""
    low = text.lower()
    if re.search(r"[　-鿿]", term):
        return term in low
    return re.search(r"(?<![\w#])" + re.escape(term) + r"(?!\w)", low) is not None


# ---------------------------------------------------------------- English (metadata.md)
print("== en-US  docs/store/metadata.md")
TEXT = (STORE / "metadata.md").read_text(encoding="utf-8")
values = {}
for heading, (limit, unit) in LIMITS.items():
    value = section(TEXT, heading)
    values[heading] = value
    n = len(value.encode("utf-8")) if unit == "bytes" else len(value)
    status = "ok" if n <= limit else "OVER"
    if n > limit:
        ok = False
    print(f"{heading:18} {n:5} / {limit:<5} {unit:5} {status}")

kw = values["Keywords"]
if ", " in kw or " ," in kw:
    fail("Keywords: spaces around commas")
name_words = set(re.findall(r"[a-z0-9]+", (values["App Name"] + " " + values["Subtitle"]).lower()))
kw_words = re.findall(r"[a-z0-9]+", kw.lower())
repeated = sorted(set(kw_words) & name_words)
dupes = sorted({w for w in kw_words if kw_words.count(w) > 1})
print("Words repeated from name/subtitle:", repeated or "none")
print("Duplicate words inside keywords:", dupes or "none")
if repeated or dupes:
    ok = False
for heading, value in values.items():
    copy_rules(heading, value)

# ---------------------------------------------------------------- Localized (metadata-localized.md)
LOC_PATH = STORE / "metadata-localized.md"
LOC_TEXT = LOC_PATH.read_text(encoding="utf-8")
for loc in LOCALES:
    print(f"\n== {loc}  docs/store/metadata-localized.md")
    cjk = loc in CJK_LOCALES
    v = {}
    for field, limit in LOCALIZED_LIMITS.items():
        value = section(LOC_TEXT, f"{loc} > {field}")
        v[field] = value
        n = len(value)
        status = "ok" if n <= limit else "OVER"
        if n > limit:
            fail(f"{loc} {field}: {n} characters, limit {limit}")
        print(f"{field:18} {n:5} / {limit:<5} chars {status}")
        if not value.strip():
            fail(f"{loc} {field}: empty")
        copy_rules(f"{loc} {field}", value)
    for field in ("App Name", "Subtitle", "Keywords", "Promotional Text"):
        if "\n" in v[field]:
            fail(f"{loc} {field}: must be a single line")

    # name: keyword-first, brand last after a colon
    if not re.search(r"\S\s?[:：]\s?CareerKit$", v["App Name"]):
        fail(f"{loc} App Name: must end with ': CareerKit' (brand last, after a colon)")

    # keywords
    kw = v["Keywords"]
    terms = kw.split(",")
    if " " in kw:
        fail(f"{loc} Keywords: contains spaces (use commas only, no spaces)")
    if any(not t for t in terms):
        fail(f"{loc} Keywords: empty term (double or trailing comma)")
    name_sub = v["App Name"] + " " + v["Subtitle"]
    if cjk:
        repeated = sorted(t for t in terms if t and (t.lower() in name_sub.lower()
                          or (not re.search(r"[　-鿿]", t) and fold(t) in latin_words(name_sub))))
        dupes = sorted({t for t in terms if terms.count(t) > 1})
    else:
        ns_words = set(latin_words(name_sub))
        kw_words = latin_words(kw)
        repeated = sorted(set(kw_words) & ns_words)
        dupes = sorted({w for w in kw_words if kw_words.count(w) > 1})
    print("Words repeated from name/subtitle:", repeated or "none")
    print("Duplicate words inside keywords:", dupes or "none")
    if repeated:
        fail(f"{loc} Keywords: repeats words from the name or subtitle: {repeated}")
    if dupes:
        fail(f"{loc} Keywords: duplicate words: {dupes}")

    # captions
    caps = section(LOC_TEXT, f"{loc} > Screenshot Captions").split("\n")
    if len(caps) != CAPTION_LINES:
        fail(f"{loc} Screenshot Captions: {len(caps)} lines, expected {CAPTION_LINES}")
    for line in caps:
        copy_rules(f"{loc} caption", line)
        if cjk:
            n = len(line.replace(" ", ""))
            if n > CAPTION_MAX_CJK_CHARS:
                fail(f"{loc} caption over {CAPTION_MAX_CJK_CHARS} characters ({n}): {line}")
        else:
            n = len(line.split())
            if n > CAPTION_MAX_WORDS:
                fail(f"{loc} caption over {CAPTION_MAX_WORDS} words ({n}): {line}")
    print(f"Screenshot Captions {len(caps)} lines, longest "
          f"{max((len(c.replace(' ', '')) if cjk else len(c.split())) for c in caps)} "
          f"{'chars' if cjk else 'words'}")

    # Apple rules: trademarks, prices and ranking claims
    for field in ("App Name", "Subtitle", "Keywords"):
        for tm in TRADEMARKS:
            if has_term(v[field], tm):
                fail(f"{loc} {field}: third-party trademark '{tm}'")
    for label, value in [("App Name", v["App Name"]), ("Subtitle", v["Subtitle"]),
                         ("Screenshot Captions", "\n".join(caps))]:
        for w in PRICE_WORDS:
            if has_term(value, w):
                fail(f"{loc} {label}: price word '{w}'")
    for label, value in [("App Name", v["App Name"]), ("Subtitle", v["Subtitle"]),
                         ("Promotional Text", v["Promotional Text"]),
                         ("Screenshot Captions", "\n".join(caps))]:
        for w in CLAIM_WORDS:
            if has_term(value, w):
                fail(f"{loc} {label}: ranking claim '{w}'")

    # description must keep the support links
    for link in ("https://ecomswiftllc.github.io/careerkit/support/", "support@ecomswiftllc.com"):
        if link not in v["Description"]:
            fail(f"{loc} Description: missing support link {link}")

print("\nRESULT:", "all checks passed" if ok else "FAILED")
sys.exit(0 if ok else 1)
