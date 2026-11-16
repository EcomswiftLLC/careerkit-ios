"""Builds the website image assets from the app icon geometry in design/make_icon.py.

Writes into website/careerkit/assets/:
  favicon.svg            forest square + page + K (vector)
  careerkit-mark.svg     page + K only, transparent (vector, for the header logo)
  favicon-32.png, apple-touch-icon.png (180), icon-512.png
  og-image.png           1200 x 630 social preview (icon + name, no invented claims)

Usage: python website/make_site_assets.py     (needs Pillow, numpy)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "design"))
import make_icon as mi  # noqa: E402

OUT = ROOT / "website" / "careerkit" / "assets"
OUT.mkdir(parents=True, exist_ok=True)


def pts(poly):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in poly)


def mark_svg(with_bg):
    bg = ""
    view = "0 0 1024 1024"
    if with_bg:
        bg = '<rect width="1024" height="1024" rx="229" fill="#1F4D3A"/>'
    body = f"""
  <polygon points="{pts(mi.page_polygon())}" fill="#FAF7F0"/>
  <polygon points="{pts(mi.fold_polygon())}" fill="#B89B5E"/>
  <polygon points="{pts(mi.leg_polygon())}" fill="#1F4D3A"/>
  <polygon points="{pts(mi.arm_polygon())}" fill="#B89B5E"/>
  <polygon points="{pts(mi.stem_polygon())}" fill="#1F4D3A"/>"""
    if not with_bg:
        # crop to the page so the logo sits tight in the header
        view = f"{mi.PAGE_X0 - 6} {mi.PAGE_Y0 - 6} {mi.PAGE_X1 - mi.PAGE_X0 + 12} {mi.PAGE_Y1 - mi.PAGE_Y0 + 12}"
    title = "CareerKit"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" role="img" aria-label="{title}">'
            f"<title>{title}</title>{bg}{body}\n</svg>\n")


def font(size):
    for p in ("C:/Windows/Fonts/georgia.ttf", "/Library/Fonts/Georgia.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def sans(size):
    for p in ("C:/Windows/Fonts/segoeui.ttf", "/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def rounded_icon(px):
    icon = Image.open(mi.OUT_SET / "AppIcon-1024.png").convert("RGB").resize((px, px), Image.LANCZOS)
    mask = Image.new("L", (px * 4, px * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, px * 4 - 1, px * 4 - 1], radius=int(px * 4 * 0.2237), fill=255)
    mask = mask.resize((px, px), Image.LANCZOS)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out


def main():
    (OUT / "favicon.svg").write_text(mark_svg(True), encoding="utf-8")
    (OUT / "careerkit-mark.svg").write_text(mark_svg(False), encoding="utf-8")

    icon = Image.open(mi.OUT_SET / "AppIcon-1024.png").convert("RGB")
    icon.resize((180, 180), Image.LANCZOS).save(OUT / "apple-touch-icon.png", optimize=True)
    rounded_icon(512).save(OUT / "icon-512.png", optimize=True)
    rounded_icon(32).save(OUT / "favicon-32.png", optimize=True)

    # social preview 1200 x 630
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), "#FAF7F0")
    d = ImageDraw.Draw(img)
    d.rectangle([0, H - 14, W, H], fill="#1F4D3A")
    d.rectangle([80, 92, 80 + 72, 96], fill="#B89B5E")
    d.text((80, 128), "Resume Builder:", font=font(76), fill="#1F2421")
    d.text((80, 218), "CareerKit", font=font(76), fill="#1F4D3A")
    d.text((80, 340), "Free resume and cover letter maker", font=sans(34), fill="#5B605C")
    d.text((80, 388), "for iPhone and iPad", font=sans(34), fill="#5B605C")
    d.text((80, 520), "30 templates   ATS guidance   Word + PDF", font=sans(28), fill="#1F2421")
    ic = rounded_icon(360)
    img.paste(ic, (W - 360 - 90, (H - 360) // 2 - 7), ic)
    img.save(OUT / "og-image.png", optimize=True)
    print("assets written to", OUT)


if __name__ == "__main__":
    main()
