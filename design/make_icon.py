"""CareerKit app icon generator ("Folded Ascent").

Draws everything at 4x (4096 px) and downsamples to 1024 for clean edges.
Outputs opaque RGB PNGs (no alpha, no rounded corners; iOS applies the mask):
  Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png         (light / default)
  Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png    (dark appearance)
  Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png  (tinted appearance, grayscale)
  design/icon/*.png copies for review.

Usage:  python design/make_icon.py
Requires: Pillow, numpy.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_SET = ROOT / "Sources" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
OUT_REVIEW = ROOT / "design" / "icon"

SIZE = 1024
S = 4  # supersampling factor
BIG = SIZE * S

# ---- geometry (1024 units) -------------------------------------------------
PAGE_X0, PAGE_X1 = 236, 788
PAGE_Y0, PAGE_Y1 = 168, 856
FOLD = 156                      # fold leg length, 45 degree cut
BAR = 64                        # stem / arm / leg thickness
OX = 24                         # optical shift of the K to the right
STEM_X0 = 336 + OX
STEM_X1 = STEM_X0 + BAR
K_TOP, K_BOT = 356, 756
JOIN_Y = 588                    # y where the arm's lower edge and the leg's upper edge meet the stem
ARM_C = 988 + OX                # x + y = ARM_C  is the arm's lower edge
DIAG = BAR * 2 ** 0.5           # horizontal width of a 45 degree bar of thickness BAR


def page_polygon():
    return [
        (PAGE_X0, PAGE_Y0),
        (PAGE_X1 - FOLD, PAGE_Y0),
        (PAGE_X1, PAGE_Y0 + FOLD),
        (PAGE_X1, PAGE_Y1),
        (PAGE_X0, PAGE_Y1),
    ]


def fold_polygon():
    return [
        (PAGE_X1 - FOLD, PAGE_Y0),
        (PAGE_X1 - FOLD, PAGE_Y0 + FOLD),
        (PAGE_X1, PAGE_Y0 + FOLD),
    ]


def arm_polygon():
    # lower edge: x + y = ARM_C ; upper edge: x + y = ARM_C - DIAG
    lo, up = ARM_C, ARM_C - DIAG
    return [
        (STEM_X1 - 4, up - (STEM_X1 - 4)),
        (up - K_TOP, K_TOP),
        (lo - K_TOP, K_TOP),
        (STEM_X1 - 4, lo - (STEM_X1 - 4)),
    ]


def leg_polygon():
    # upper edge starts at the stem at JOIN_Y, runs down-right at 45 degrees
    c_up = STEM_X1 - JOIN_Y          # x - y = c_up
    c_lo = c_up - DIAG
    return [
        (STEM_X1 - 4, (STEM_X1 - 4) - c_up),
        (c_up + K_BOT, K_BOT),
        (c_lo + K_BOT, K_BOT),
        (STEM_X1 - 4, (STEM_X1 - 4) - c_lo),
    ]


def stem_polygon():
    return [(STEM_X0, K_TOP), (STEM_X1, K_TOP), (STEM_X1, K_BOT), (STEM_X0, K_BOT)]


# ---- helpers ----------------------------------------------------------------
def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def scaled(poly):
    return [(x * S, y * S) for x, y in poly]


def radial_background(center_hex, edge_hex, cx=0.5, cy=0.42, reach=0.78):
    yy, xx = np.mgrid[0:BIG, 0:BIG].astype(np.float32)
    d = np.sqrt(((xx / BIG - cx) ** 2) + ((yy / BIG - cy) ** 2)) / reach
    d = np.clip(d, 0, 1)[..., None]
    d = d * d * (3 - 2 * d)  # smoothstep for a soft, even falloff
    c0 = np.array(hex_rgb(center_hex), np.float32)
    c1 = np.array(hex_rgb(edge_hex), np.float32)
    arr = c0 * (1 - d) + c1 * d
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def linear_fill(poly, c_a, c_b, p_a, p_b):
    """Fill polygon with a linear gradient c_a (at p_a) to c_b (at p_b), coordinates in 1024 units."""
    yy, xx = np.mgrid[0:BIG, 0:BIG].astype(np.float32)
    ax, ay = p_a[0] * S, p_a[1] * S
    bx, by = p_b[0] * S, p_b[1] * S
    vx, vy = bx - ax, by - ay
    t = ((xx - ax) * vx + (yy - ay) * vy) / (vx * vx + vy * vy)
    t = np.clip(t, 0, 1)[..., None]
    arr = np.array(hex_rgb(c_a), np.float32) * (1 - t) + np.array(hex_rgb(c_b), np.float32) * t
    layer = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    mask = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(mask).polygon(scaled(poly), fill=255)
    return layer, mask


def soft_shadow(poly, offset, blur, color_hex, opacity):
    mask = Image.new("L", (BIG, BIG), 0)
    moved = [(x + offset[0], y + offset[1]) for x, y in poly]
    ImageDraw.Draw(mask).polygon(scaled(moved), fill=int(255 * opacity))
    mask = mask.filter(ImageFilter.GaussianBlur(blur * S))
    layer = Image.new("RGB", (BIG, BIG), hex_rgb(color_hex))
    return layer, mask


def build(pal):
    img = radial_background(pal["bg_center"], pal["bg_edge"])

    # page drop shadow
    layer, mask = soft_shadow(page_polygon(), (0, 26), 30, pal["shadow"], pal["shadow_opacity"])
    img.paste(layer, (0, 0), mask)

    # page body with a faint top-to-bottom tonal shift
    layer, mask = linear_fill(page_polygon(), pal["page_top"], pal["page_bottom"],
                              (0, PAGE_Y0), (0, PAGE_Y1))
    img.paste(layer, (0, 0), mask)

    # shadow the fold throws on the page (clipped to the page)
    sh_layer, sh_mask = soft_shadow(fold_polygon(), (-9, 11), 11, pal["fold_shadow"], 0.55)
    page_mask = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(page_mask).polygon(scaled(page_polygon()), fill=255)
    clipped = Image.fromarray(np.minimum(np.array(sh_mask), np.array(page_mask)))
    img.paste(sh_layer, (0, 0), clipped)

    # the fold itself: back of the page, metallic
    layer, mask = linear_fill(fold_polygon(), pal["fold_a"], pal["fold_b"],
                              (PAGE_X1 - FOLD, PAGE_Y0), (PAGE_X1, PAGE_Y0 + FOLD))
    img.paste(layer, (0, 0), mask)

    draw = ImageDraw.Draw(img)
    # K: leg and stem in ink, ascending arm in champagne
    draw.polygon(scaled(leg_polygon()), fill=hex_rgb(pal["ink"]))
    layer, mask = linear_fill(arm_polygon(), pal["arm_a"], pal["arm_b"],
                              (STEM_X1, K_TOP + 200), (ARM_C - K_TOP, K_TOP))
    img.paste(layer, (0, 0), mask)
    draw.polygon(scaled(stem_polygon()), fill=hex_rgb(pal["ink"]))

    return img.resize((SIZE, SIZE), Image.LANCZOS)


LIGHT = dict(
    bg_center="#2A5E45", bg_edge="#14352A",
    shadow="#0A1F17", shadow_opacity=0.42,
    page_top="#FBF8F1", page_bottom="#F1ECDF",
    fold_shadow="#8E8570",
    fold_a="#D2B97F", fold_b="#A98C4E",
    ink="#1F4D3A",
    arm_a="#C9AD6C", arm_b="#B89B5E",
)

DARK = dict(
    bg_center="#12201A", bg_edge="#08100C",
    shadow="#000000", shadow_opacity=0.55,
    page_top="#EFEBDF", page_bottom="#E1DCCD",
    fold_shadow="#6F6859",
    fold_a="#D9C089", fold_b="#B08F50",
    ink="#1F4D3A",
    arm_a="#CDB27A", arm_b="#BC9F62",
)

TINTED = dict(
    bg_center="#1E1E1E", bg_edge="#0C0C0C",
    shadow="#000000", shadow_opacity=0.5,
    page_top="#F2F2F2", page_bottom="#E2E2E2",
    fold_shadow="#8A8A8A",
    fold_a="#A8A8A8", fold_b="#7C7C7C",
    ink="#2A2A2A",
    arm_a="#8F8F8F", arm_b="#7A7A7A",
)


def main():
    OUT_SET.mkdir(parents=True, exist_ok=True)
    OUT_REVIEW.mkdir(parents=True, exist_ok=True)
    jobs = [
        ("AppIcon-1024.png", LIGHT, False),
        ("AppIcon-1024-dark.png", DARK, False),
        ("AppIcon-1024-tinted.png", TINTED, True),
    ]
    for name, pal, gray in jobs:
        img = build(pal)
        if gray:
            img = img.convert("L").convert("RGB")
        assert img.mode == "RGB" and img.size == (SIZE, SIZE)
        img.save(OUT_SET / name, "PNG", optimize=True)
        img.save(OUT_REVIEW / name, "PNG", optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    main()
