#!/usr/bin/env python3
"""Colour-worlds readiness check for the approved backdrops (docs/colour-worlds-plan.md).

For every shaft wall: the brightness of the side walls (outside the doorway) under the shipped scrim, the NEXT label
and the six floor chips against them, then the same with a dark plate behind the NEXT column. For every lobby floor:
its venue's lane ink against the floor. Also writes a contact sheet of each wall with the shipped doorway rectangle
drawn on it, to check the doorway fit by eye.

    python3 tool/art/wall_contrast.py [out.png]

Colours mirror lib/ui/theme.dart (LL.shaftScrim, LL.cabinPlate, LL.lilac, FloorStyle, VenueStyle.laneInk).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

APPROVED = Path("docs/art/approved")
VENUES = ["society_v2", "office", "hospital", "mall", "hotel"]
BANDS = ["ground", "mid", "high"]
DOORWAY = (332 / 1200, 72 / 800, 868 / 1200, 744 / 800)  # ArtAssets.shaftDoorway
SCRIM, SCRIM_A = "#14132E", 0x66 / 255  # LL.shaftScrim
PLATE, PLATE_A = "#14132E", 0xC7 / 255  # LL.cabinPlate
LABEL = "#B9B4E0"  # LL.lilac, the NEXT label
FLOORS = {"coral": "#FF6B5B", "sun": "#FFC233", "teal": "#14B8A6", "blue": "#4C7DFF", "plum": "#A066F5",
          "leaf": "#7BD148"}
LANE_INK = {"society_v2": "#6B5C44", "office": "#4F5B6B", "hospital": "#3F6157", "mall": "#7A5566",
            "hotel": "#6E4E3A"}


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32)


def lum(c):
    c = np.asarray(c, np.float32) / 255
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def ratio(a, b):
    a, b = max(a, b), min(a, b)
    return (a + 0.05) / (b + 0.05)


def over(px, colour, alpha):
    return px * (1 - alpha) + rgb(colour) * alpha


def main():
    label = float(lum(rgb(LABEL)))
    print(f"{'wall':18s} {'median L':>8s}  label  worst chip | with NEXT plate: label  worst chip")
    tiles = []
    for v in VENUES:
        for b in BANDS:
            img = Image.open(APPROVED / f"bg_{v}_shaft_{b}.webp").convert("RGB")
            px = np.asarray(img, np.float32)
            w = px.shape[1]
            side = np.concatenate([px[:, :int(w * DOORWAY[0])], px[:, int(w * DOORWAY[2]):]], axis=1).reshape(-1, 3)
            rows = []
            for plated in (False, True):
                s = over(side, SCRIM, SCRIM_A)
                if plated:
                    s = over(s, PLATE, PLATE_A)
                L = lum(s)
                med, p95 = float(np.median(L)), float(np.percentile(L, 95))
                chip = min((ratio(float(lum(rgb(c))), med), n) for n, c in FLOORS.items())
                rows.append((med, ratio(label, p95), chip))
            (m0, l0, c0), (_, l1, c1) = rows
            print(f"{v + '/' + b:18s} {m0:8.3f}  {l0:4.1f}:1  {c0[1]:5s} {c0[0]:.1f}:1 |"
                  f"                  {l1:4.1f}:1  {c1[1]:5s} {c1[0]:.1f}:1")
            t = img.resize((300, 200))
            ImageDraw.Draw(t).rectangle([DOORWAY[0] * 300, DOORWAY[1] * 200, DOORWAY[2] * 300, DOORWAY[3] * 200],
                                        outline="lime", width=2)
            tiles.append(t)
    print()
    for v, ink in LANE_INK.items():
        L = lum(np.asarray(Image.open(APPROVED / f"bg_{v}_lobby.webp").convert("RGB"), np.float32))
        print(f"lobby {v:11s} lane ink {ink}: {ratio(float(lum(rgb(ink))), float(np.percentile(L, 5))):.1f}:1 "
              f"(need 4.3)")
    if len(sys.argv) > 1:
        sheet = Image.new("RGB", (3 * 310, len(VENUES) * 210), "black")
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % 3) * 310, (i // 3) * 210))
        sheet.save(sys.argv[1])
        print(f"\nwrote {sys.argv[1]}")


if __name__ == "__main__":
    main()
