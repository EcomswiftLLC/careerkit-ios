"""Checks docs/store/metadata.md against App Store limits.

Usage: python design/check_store_metadata.py
Reads the first fenced block under each "## <Field>" heading.
Exit code 1 when a limit is broken or a rule fails.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXT = (ROOT / "docs" / "store" / "metadata.md").read_text(encoding="utf-8")

LIMITS = {  # heading: (limit, unit)
    "App Name": (30, "chars"),
    "Subtitle": (30, "chars"),
    "Keywords": (100, "bytes"),
    "Promotional Text": (170, "chars"),
    "Description": (4000, "chars"),
    "What's New": (4000, "chars"),
}


def block(heading):
    m = re.search(r"^## " + re.escape(heading) + r"\s*$(.*?)(?=^## |\Z)", TEXT, re.S | re.M)
    if not m:
        raise SystemExit(f"missing heading: {heading}")
    f = re.search(r"```\n(.*?)\n```", m.group(1), re.S)
    if not f:
        raise SystemExit(f"missing fenced block under: {heading}")
    return f.group(1)


ok = True
values = {}
for heading, (limit, unit) in LIMITS.items():
    value = block(heading)
    values[heading] = value
    n = len(value.encode("utf-8")) if unit == "bytes" else len(value)
    status = "ok" if n <= limit else "OVER"
    if n > limit:
        ok = False
    print(f"{heading:18} {n:5} / {limit:<5} {unit:5} {status}")

# keyword rules
kw = values["Keywords"]
if ", " in kw or " ," in kw:
    print("Keywords: spaces around commas"); ok = False
name_words = set(re.findall(r"[a-z0-9]+", (values["App Name"] + " " + values["Subtitle"]).lower()))
kw_words = re.findall(r"[a-z0-9]+", kw.lower())
repeated = sorted(set(kw_words) & name_words)
dupes = sorted({w for w in kw_words if kw_words.count(w) > 1})
print("Words repeated from name/subtitle:", repeated or "none")
print("Duplicate words inside keywords:", dupes or "none")
if repeated or dupes:
    ok = False

# copy rules
for heading, value in values.items():
    if "—" in value or "–" in value:
        print(f"{heading}: contains a dash character that is banned"); ok = False
    if re.search(r"[\U0001F300-\U0001FAFF☀-➿]", value):
        print(f"{heading}: contains an emoji"); ok = False

sys.exit(0 if ok else 1)
