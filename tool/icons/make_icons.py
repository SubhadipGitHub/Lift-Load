"""Render the Lift Load web icons: a brass lift cabin on the night colour.

    python3 tool/icons/make_icons.py          # writes web/favicon.png and web/icons/*

Everything is drawn with PIL at 4x and downsampled, so the output is the same on
every machine. Colours come from lib/ui/theme.dart (LL.night, LL.brass, ...).
The maskable icons are full-bleed with the cabin inside the 80% safe circle;
the plain icons sit on a rounded square with transparent corners.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

NIGHT = (0x1C, 0x1A, 0x3F)
NIGHT_TOP = (0x2E, 0x2A, 0x5E)
BRASS = (0xF5, 0xB8, 0x3D)
BRASS_DARK = (0xB5, 0x7D, 0x12)
STEEL = (0xD9, 0xDD, 0xE3)
STEEL_FLOOR = (0x9A, 0xA1, 0xAB)
INK = (0x1E, 0x1B, 0x3A)
CREAM = (0xFF, 0xF4, 0xE2)
GREEN = (0x5C, 0xC9, 0x7B)

SS = 4  # supersampling factor


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background(size, rounded):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        gd.line([(0, y), (size, y)], fill=lerp(NIGHT_TOP, NIGHT, y / (size - 1)) + (255,))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    if rounded:
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=255)
    else:
        md.rectangle([0, 0, size, size], fill=255)
    img.paste(grad, (0, 0), mask)
    return img


def cabin(img, box):
    """Draw the cabin into box = (x0, y0, x1, y1) of the content area."""
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    u = w / 100  # design units

    # Cables up to the top edge.
    cx = x0 + w / 2
    for dx in (-9, 9):
        d.line([(cx + dx * u, y0 - 40 * u), (cx + dx * u, y0 + 14 * u)], fill=STEEL_FLOOR, width=round(3 * u))

    # Brass frame with a darker lip.
    top = y0 + 12 * u
    d.rounded_rectangle([x0, top, x1, y1], radius=round(10 * u), fill=BRASS_DARK)
    d.rounded_rectangle([x0 + 2 * u, top, x1 - 2 * u, y1 - 4 * u], radius=round(9 * u), fill=BRASS)

    # Floor display: a small ink panel with a green up arrow.
    px0, px1 = cx - 16 * u, cx + 16 * u
    py0, py1 = top + 5 * u, top + 19 * u
    d.rounded_rectangle([px0, py0, px1, py1], radius=round(3 * u), fill=INK)
    d.polygon([(cx, py0 + 3 * u), (cx - 6 * u, py1 - 3.5 * u), (cx + 6 * u, py1 - 3.5 * u)], fill=GREEN)

    # Steel doors with a centre seam.
    dx0, dx1 = x0 + 11 * u, x1 - 11 * u
    dy0, dy1 = top + 25 * u, y1 - 12 * u
    d.rectangle([dx0, dy0, dx1, dy1], fill=STEEL)
    d.rectangle([dx0, dy1 - 6 * u, dx1, dy1], fill=STEEL_FLOOR)
    d.line([(cx, dy0), (cx, dy1)], fill=INK, width=round(2.4 * u))
    # Door handles.
    for hx in (cx - 6 * u, cx + 6 * u):
        d.rounded_rectangle([hx - 1.4 * u, dy0 + 22 * u, hx + 1.4 * u, dy0 + 36 * u], radius=round(1.4 * u),
                            fill=STEEL_FLOOR)
    # Light strip above the doors.
    d.rounded_rectangle([dx0, top + 21 * u, dx1, top + 23.5 * u], radius=round(1.2 * u), fill=CREAM)


def render(size, maskable):
    big = size * SS
    img = background(big, rounded=not maskable)
    # Content box: inside the maskable safe circle (radius 40%), or a little
    # inset from the rounded square.
    span = 0.50 if maskable else 0.58
    w = big * span
    h = w * 1.12
    x0 = (big - w) / 2
    y0 = (big - h) / 2 + big * 0.04
    cabin(img, (x0, y0, x0 + w, y0 + h))
    return img.resize((size, size), Image.LANCZOS)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("web")
    (out / "icons").mkdir(parents=True, exist_ok=True)
    render(192, False).save(out / "icons" / "Icon-192.png")
    render(512, False).save(out / "icons" / "Icon-512.png")
    render(192, True).save(out / "icons" / "Icon-maskable-192.png")
    render(512, True).save(out / "icons" / "Icon-maskable-512.png")
    render(32, False).save(out / "favicon.png")


if __name__ == "__main__":
    main()
