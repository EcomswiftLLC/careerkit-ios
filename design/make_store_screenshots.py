"""Adds the caption frame to raw simulator screenshots for the App Store.

Input : design/screens-raw/<set>/01.png ... 08.png   (raw captures, any size, portrait)
        <set> is one of: iphone-6.9, iphone-6.5, ipad-13
Output: design/screens-store/<set>/01.png ... 08.png at the exact App Store size.

Usage : python design/make_store_screenshots.py
Requires: Pillow. Fonts: Georgia if present, else DejaVu Serif, else Pillow's default.
No raw captures exist yet (the app has to be run on a Mac or simulator first), so this does nothing until they are added.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "design" / "screens-raw"
OUT = ROOT / "design" / "screens-store"

SETS = {
    "iphone-6.9": (1320, 2868),
    "iphone-6.5": (1284, 2778),
    "ipad-13": (2064, 2752),
}
CAPTIONS = [
    "Build a polished resume",
    "30 templates to choose from",
    "Change every detail",
    "Start from a blank page",
    "Cover letters that match",
    "Check your layout",
    "Keep one resume per job",
    "Share or save as PDF",
]
IVORY, INK, CHAMPAGNE = "#FAF7F0", "#1F2421", "#B89B5E"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/georgia.ttf",
    "/Library/Fonts/Georgia.ttf",
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
]


def load_font(size):
    for p in FONT_CANDIDATES:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def wrap(draw, text, font, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def compose(raw_path, caption, size):
    W, H = size
    canvas = Image.new("RGB", size, IVORY)
    d = ImageDraw.Draw(canvas)
    margin = int(W * 0.08)
    font = load_font(int(W * 0.075))
    lines = wrap(d, caption, font, W - 2 * margin)
    y = int(H * 0.055)
    for line in lines:
        d.text((margin, y), line, font=font, fill=INK)
        y += int(font.size * 1.18)
    y += int(W * 0.025)
    d.rectangle([margin, y, margin + int(W * 0.09), y + 4], fill=CHAMPAGNE)
    top = y + int(W * 0.06)

    raw = Image.open(raw_path).convert("RGB")
    target_w = int(W * 0.88)
    scale = target_w / raw.width
    raw = raw.resize((target_w, int(raw.height * scale)), Image.LANCZOS)
    radius = int(target_w * 0.055)
    mask = Image.new("L", raw.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, raw.width - 1, raw.height - 1], radius=radius, fill=255)
    x = (W - target_w) // 2

    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, top + 18, x + raw.width, top + 18 + raw.height], radius=radius, fill=70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(W * 0.018)))
    canvas.paste(Image.new("RGB", size, "#3A3427"), (0, 0), shadow)
    canvas.paste(raw, (x, top), mask)
    return canvas


def main():
    made = 0
    for set_name, size in SETS.items():
        src = RAW / set_name
        if not src.is_dir():
            continue
        (OUT / set_name).mkdir(parents=True, exist_ok=True)
        for i, caption in enumerate(CAPTIONS, start=1):
            f = src / f"{i:02d}.png"
            if not f.exists():
                print("missing", f)
                continue
            img = compose(f, caption, size)
            assert img.size == size
            img.save(OUT / set_name / f"{i:02d}.png", "PNG", optimize=True)
            made += 1
    print("wrote", made, "screenshots" if made else "screenshots (add raw captures to design/screens-raw first)")


if __name__ == "__main__":
    main()
