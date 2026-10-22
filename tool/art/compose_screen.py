#!/usr/bin/env python3
"""Review a backdrop on the real play-screen layout: shaft panel (cabin, NEXT chips, gauge, Send) and lobby (four
lanes of residents at the +60% figure size), at 2x of the 390 x 844 design. Uses the approved art for everything else.

    python3 tool/art/compose_screen.py --shaft art/processed/bg_society_shaft_mid.webp --lobby art/processed/bg_society_lobby.webp

Check: the middle third behind the cabin is calm, the side bands do not fight the chips and gauge, the lobby stays light
behind the lane text, and the residents read on the floor. Writes art/review/screen.png.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

A = Path("docs/art/approved")
BOOST = 1.6


def cover(img, size):
    s = max(size[0] / img.width, size[1] / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x, y = (img.width - size[0]) // 2, (img.height - size[1]) // 2
    return img.crop((x, y, x + size[0], y + size[1]))


def sprite(name, box_dp):
    im = Image.open(A / f"{name}.webp").convert("RGBA")
    k = box_dp * 2 / 120 / 6  # box dp at 2x, 120 design units tall, sprites made at 6 px per unit
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shaft", default=str(A / "society_wall_mid.webp"))
    ap.add_argument("--lobby", default=str(A / "society_floor_tile.webp"))
    ap.add_argument("--out", default="art/review/screen.png")
    a = ap.parse_args()
    PW, PH, LH = 732, 524, 560
    panel = cover(Image.open(a.shaft).convert("RGB"), (PW, PH)).convert("RGBA")
    d = ImageDraw.Draw(panel)
    # NEXT chips (floor badges), gauge plate and Send, in the places the layout puts them
    for i, f in enumerate(["coral", "teal", "sun"]):
        ic = Image.open(A / f"icon_floor_{f}.webp").convert("RGBA").resize((84, 84), Image.LANCZOS)
        if i:
            ic.putalpha(ic.getchannel("A").point(lambda v: int(v * 0.65)))
        panel.alpha_composite(ic, (20, 60 + i * 96))
    d.rounded_rectangle((540, 28, 720, 150), 32, fill=(14, 12, 40, 235), outline=(5, 4, 26, 255), width=4)
    d.arc((560, 54, 700, 194), 180, 360, fill=(61, 220, 151, 255), width=22)
    d.rounded_rectangle((544, 312, 716, 452), 44, fill=(61, 220, 151, 255), outline=(7, 64, 42, 255), width=5)
    cab = Image.open(A / "cabin_normal_interior.webp").convert("RGBA")
    t = 196 / 214
    cw = round(cab.height * t)
    cab = cab.crop(((cab.width - cw) // 2, 0, (cab.width - cw) // 2 + cw, cab.height)) if cab.width / cab.height > t else cab.crop((0, 90, cab.width, 90 + round(cab.width / t)))
    cab = cab.resize((392, 428), Image.LANCZOS)
    panel.alpha_composite(cab, (140, 60))
    for name, x in (("resident_officeW", 0.36), ("resident_kid", 0.66)):
        s = sprite(name, 80 * BOOST)
        panel.alpha_composite(s, (140 + int(392 * x) - s.width // 2, 60 + 428 - 40 - s.height))
    lobby = cover(Image.open(a.lobby).convert("RGB"), (PW, LH)).convert("RGBA")
    for lane, names in enumerate([["resident_gym", "resident_kid"], ["resident_uncle", "resident_student"], ["resident_puffer"], ["resident_grandpa", "resident_officeW"]]):
        cx = 12 + lane * 180 + 90
        feet, front_h = LH - 60, None
        for r, n in enumerate(names):
            s = sprite(n, 54 * BOOST * (1 - 0.06 * r))
            front_h = front_h or s.height
            f = feet - int(front_h * 0.5) * r  # the next in line stands behind, their feet at the front one's waist
            lobby.alpha_composite(s, (cx - s.width // 2, f - s.height))
    sheet = Image.new("RGB", (PW, PH + LH), (20, 18, 52))
    sheet.paste(panel.convert("RGB"), (0, 0))
    sheet.paste(lobby.convert("RGB"), (0, PH))
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
