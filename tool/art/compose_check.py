#!/usr/bin/env python3
"""Integration gate: stand approved residents and cargo on a processed scene at the game's real scale.

    python3 tool/art/compose_check.py cabin   # docs/art/approved/cabin_normal_interior.webp
    python3 tool/art/compose_check.py art/processed/cabin_old_interior.webp --out art/review/cabin_old.png

The game draws a cabin 196 x 214 design units, so the scene is cover-cropped to that aspect (top-anchored by
--top px) and sprites, made at 6 px per unit, are scaled to the scene width. Look for: scale against the walls, feet on
the floor, contrast of every cast colour against the back wall, bright verticals behind faces, a clean floor line.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

CABIN_UNITS = (196, 214)
PX_PER_UNIT = 6
# Contact shadow spec for integration: a soft dark ellipse under each figure, centred on the feet line.
SHADOW_W = 0.62      # of the sprite's width
SHADOW_H = 0.20      # of the shadow's own width
SHADOW_ALPHA = 105   # 0-255, warm near-black so it reads on steel and on terracotta
SHADOW_BLUR = 0.035  # of the shadow's width

SETS = [
    (["resident_kid", "resident_uncle", "resident_gym"], [0.29, 0.50, 0.72]),
    (["resident_wheelchair", "resident_aunty", "cargo_cylinder", "resident_student"], [0.23, 0.46, 0.60, 0.76]),
    (["resident_grandpa", "resident_guard", "resident_puffer", "cargo_suitcase"], [0.24, 0.45, 0.66, 0.80]),
]


def shadow(sprite_w):
    w = round(sprite_w * SHADOW_W)
    h = max(4, round(w * SHADOW_H))
    pad = round(w * SHADOW_BLUR * 3)
    layer = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((pad, pad, pad + w, pad + h), fill=(24, 14, 10, SHADOW_ALPHA))
    return layer.filter(ImageFilter.GaussianBlur(w * SHADOW_BLUR))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene", help="'cabin' or a path to a processed scene")
    ap.add_argument("--approved", default="docs/art/approved")
    ap.add_argument("--top", type=int, default=90, help="px cut from the top before the aspect crop")
    ap.add_argument("--feet", type=float, default=0.90, help="feet line as a fraction of the cropped height")
    ap.add_argument("--no-shadow", action="store_true", help="skip the contact shadows (to compare)")
    ap.add_argument("--out", default="art/review/compose.png")
    a = ap.parse_args()
    path = Path(a.approved) / "cabin_normal_interior.webp" if a.scene == "cabin" else Path(a.scene)
    scene = Image.open(path).convert("RGBA")
    w = scene.width
    h = round(w * CABIN_UNITS[1] / CABIN_UNITS[0])
    scene = scene.crop((0, a.top, w, min(a.top + h, scene.height)))
    k = w / (CABIN_UNITS[0] * PX_PER_UNIT)
    feet = int(scene.height * a.feet)
    sheets = []
    for names, xs in SETS:
        c = scene.copy()
        for n, x in zip(names, xs):
            s = Image.open(Path(a.approved) / f"{n}.webp").convert("RGBA")
            s = s.resize((round(s.width * k), round(s.height * k)), Image.LANCZOS)
            sh = shadow(s.width)
            if not a.no_shadow:
                c.alpha_composite(sh, (int(x * w - sh.width / 2), feet - sh.height // 2))
            c.alpha_composite(s, (int(x * w - s.width / 2), feet - s.height))
        sheets.append(c.convert("RGB"))
    out = Image.new("RGB", (w * len(sheets), scene.height))
    for i, s in enumerate(sheets):
        out.paste(s, (i * w, 0))
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
