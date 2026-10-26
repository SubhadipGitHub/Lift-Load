"""Google Play feature graphic (1024x500 PNG, no alpha) from the approved landscape cover art.

    python3 tool/art/make_feature_graphic.py     # writes docs/store/feature_graphic_1024x500.png

The cover is cropped to the Play aspect, the app icon and the title go in the calm left half. Deterministic. The
tagline is the one in web/manifest.json. No claims ("best", "free"), no real names (Play policy, CLAUDE.md).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
COVER = ROOT / "docs" / "art" / "approved" / "home_skyline_landscape.webp"
ICON = ROOT / "docs" / "art" / "approved" / "app_icon.webp"
OUT = ROOT / "docs" / "store" / "feature_graphic_1024x500.png"
TITLE_FONT = ROOT / "assets" / "fonts" / "Baloo2-800.ttf"
TAG_FONT = ROOT / "assets" / "fonts" / "NunitoSans-700.ttf"

W, H = 1024, 500
CROP_TOP = 110  # of 1080, in cover pixels: keeps the moon and the tower tops, trims the empty road
CREAM = (0xFF, 0xF4, 0xE2)
BRASS = (0xF5, 0xB8, 0x3D)


def main():
    cover = Image.open(COVER).convert("RGB")
    ch = round(cover.width * H / W)
    img = cover.crop((0, CROP_TOP, cover.width, CROP_TOP + ch)).resize((W, H), Image.LANCZOS).convert("RGBA")

    # A soft left-to-right night wash keeps the type readable without hiding the sky.
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    for x in range(W):
        t = max(0.0, 1.0 - x / (W * 0.55))
        wd.line([(x, 0), (x, H)], fill=(0x1C, 0x1A, 0x3F, round(150 * t * t)))
    img = Image.alpha_composite(img, wash)

    # Icon tile with a drop shadow.
    size, x0, y0 = 150, 64, 78
    tile = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=round(size * 4 * 0.22), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.paste((10, 8, 40, 150), (x0, y0 + 8), mask)
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(14)))
    img.paste(tile, (x0, y0), mask)

    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(str(TITLE_FONT), 90)
    tag = ImageFont.truetype(str(TAG_FONT), 30)
    d.text((x0 - 4, 262), "Lift Load", font=title, fill=CREAM, stroke_width=3, stroke_fill=(0x1C, 0x1A, 0x3F))
    d.text((x0, 372), "Guess who fits. Mind the cable.", font=tag, fill=BRASS, stroke_width=2,
           stroke_fill=(0x1C, 0x1A, 0x3F))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}  {W}x{H}  {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
