"""Style board for the v1.8 venue colour worlds (docs/PRD-v1.8-vibrant.md, A).

    python3 tool/art/make_venue_board.py      # writes docs/art/venue-worlds/palette-board.png

A palette mock, not a render: one simplified play screen per venue (sky, shaft wall with the cabin, lobby floor with
lane cards, the dark chrome kept as it is) so the palettes can be approved before any backdrop is generated. The
chrome colours are the game's (lib/ui/theme.dart); the venue colours are the proposal. Deterministic.
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art" / "venue-worlds" / "palette-board.png"
TITLE = ROOT / "assets" / "fonts" / "Baloo2-800.ttf"
BODY = ROOT / "assets" / "fonts" / "NunitoSans-700.ttf"

# The dark chrome stays (LL.night, LL.panel, LL.cream, LL.brass, LL.mint).
NIGHT, PANEL, CREAM, BRASS, MINT, INK = "#1C1A3F", "#25234E", "#FFF4E2", "#F5B83D", "#3DDC97", "#1E1B3A"

# name, levels, sky top, sky bottom, wall, wall trim, floor, accent, confetti
VENUES = [
    ("Sunrise Towers", "1-20", "#FFB38A", "#FFE2B8", "#FF7A59", "#FFC233", "#FBEBD3", "#FF7A59",
     ["#FF7A59", "#FFC233", "#FFE2B8", "#FFFFFF"]),
    ("Skyline Offices", "21-40", "#4C9DFF", "#BFE3FF", "#14B8A6", "#9FB4C2", "#E8F1F0", "#4C9DFF",
     ["#14B8A6", "#4C9DFF", "#BFE3FF", "#FFFFFF"]),
    ("Lakeside Hospital", "41-60", "#7FD8E8", "#E4F8F4", "#3DDC97", "#FFFFFF", "#EEF8F3", "#2BB5A0",
     ["#3DDC97", "#7FD8E8", "#FFFFFF", "#B6FFDC"]),
    ("Bazaar Mall", "61-80", "#7A3FD1", "#FF9CC6", "#FF5FA2", "#A066F5", "#F9ECEF", "#A066F5",
     ["#FF5FA2", "#A066F5", "#FFC233", "#FFFFFF"]),
    ("Starlight Hotel", "81-100", "#141C4A", "#3B2C6B", "#8E2A4A", "#F5B83D", "#F6EFE2", "#F5B83D",
     ["#F5B83D", "#8E2A4A", "#FFE58F", "#FFFFFF"]),
]

W, H, GAP = 300, 560, 24


def grad(d, box, top, bottom):
    x0, y0, x1, y1 = box
    t, b = [int(top[i:i + 2], 16) for i in (1, 3, 5)], [int(bottom[i:i + 2], 16) for i in (1, 3, 5)]
    for y in range(y0, y1):
        k = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1, y)], fill=tuple(round(t[i] + (b[i] - t[i]) * k) for i in range(3)))


def panel(name, levels, sky_t, sky_b, wall, trim, floor, accent, confetti, title, body, seed):
    img = Image.new("RGB", (W, H), NIGHT)
    d = ImageDraw.Draw(img)
    # HUD (dark chrome stays).
    d.rounded_rectangle([10, 10, W - 10, 44], radius=17, fill=PANEL)
    d.text((22, 15), f"Lv {levels.split('-')[0]}", font=body, fill=BRASS)
    d.ellipse([W - 40, 17, W - 20, 37], fill=BRASS)
    # Shaft panel: sky through the side windows, the venue wall, the cabin.
    sx0, sy0, sx1, sy1 = 10, 54, W - 10, 250
    grad(d, (sx0, sy0, sx1, sy1), sky_t, sky_b)
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=18, outline=NIGHT, width=3)
    for wx in (sx0 + 8, sx1 - 70):  # wall columns with a window each
        d.rectangle([wx, sy0 + 6, wx + 62, sy1 - 6], fill=wall)
        d.rounded_rectangle([wx + 12, sy0 + 26, wx + 50, sy0 + 110], radius=14, fill=sky_b, outline=trim, width=3)
    d.rounded_rectangle([W // 2 - 62, sy0 + 22, W // 2 + 62, sy1 - 14], radius=10, fill="#C99A4E", outline=BRASS, width=5)
    d.rectangle([W // 2 - 50, sy0 + 34, W // 2 + 50, sy1 - 26], fill="#E9CFA0")
    for i, x in enumerate((W // 2 - 30, W // 2, W // 2 + 30)):  # riders on two rows
        r = 9 if i != 1 else 8
        y = sy1 - 52 if i != 1 else sy1 - 66
        d.ellipse([x - r, y - 2 * r, x + r, y], fill=INK)
        d.rounded_rectangle([x - r, y, x + r, y + 28 - (4 if i == 1 else 0)], radius=6, fill=accent)
    # Bench (dark chrome).
    for i in range(4):
        x = 12 + i * 70
        d.rounded_rectangle([x, 262, x + 62, 300], radius=12, outline="#5A5592", width=2, fill="#141230")
    # Lobby floor in the venue tint, with lane cards and floor tags.
    fx0, fy0, fx1, fy1 = 10, 312, W - 10, 488
    d.rounded_rectangle([fx0, fy0, fx1, fy1], radius=18, fill=floor)
    rng = random.Random(seed)
    tags = ["#FF6B5B", "#FFC233", "#14B8A6", "#4C7DFF", "#A066F5", "#7BD148"]
    for i in range(4):
        x = fx0 + 10 + i * 69
        d.rounded_rectangle([x, fy0 + 12, x + 58, fy0 + 104], radius=12, fill="#FFFFFF", outline="#E3CFA8", width=2)
        d.rounded_rectangle([x + 14, fy0 + 4, x + 44, fy0 + 20], radius=8, fill=rng.choice(tags))
        d.ellipse([x + 22, fy0 + 30, x + 36, fy0 + 44], fill=INK)
        d.rounded_rectangle([x + 20, fy0 + 44, x + 38, fy0 + 92], radius=7, fill=rng.choice(tags))
        d.ellipse([x + 22, fy0 + 118, x + 36, fy0 + 132], fill="#7A6F8A")
        d.rounded_rectangle([x + 20, fy0 + 132, x + 38, fy0 + 168], radius=7, fill="#B9B4E0")
    # Dock and Send (dark chrome stays; Send is mint).
    for i in range(3):
        d.ellipse([14 + i * 52, 500, 58 + i * 52, 544], fill=CREAM, outline="#4A3A20", width=3)
    d.rounded_rectangle([W - 128, 504, W - 12, 542], radius=19, fill=MINT, outline="#07402A", width=3)
    d.text((W - 98, 506), "Send", font=title, fill="#0E2A1F")
    # Confetti in venue colours over the cabin (a perfect send).
    for _ in range(26):
        x, y = rng.randint(sx0 + 20, sx1 - 20), rng.randint(sy0 + 10, sy1 - 40)
        s = rng.randint(3, 6)
        d.rectangle([x, y, x + s, y + s * 2], fill=rng.choice(confetti))
    return img


def main():
    title = ImageFont.truetype(str(TITLE), 22)
    body = ImageFont.truetype(str(BODY), 15)
    head = ImageFont.truetype(str(TITLE), 34)
    board = Image.new("RGB", (GAP + len(VENUES) * (W + GAP), H + 180), "#0F0E24")
    d = ImageDraw.Draw(board)
    d.text((GAP, 14), "Venue colour worlds (PRD v1.8, proposal)", font=head, fill=CREAM)
    d.text((GAP, 60), "Palette mock, not a render. Venue colours on sky, walls, floor and confetti; the dark chrome "
                      "(HUD, bench, dock, Send) is unchanged.", font=body, fill="#B9B4E0")
    for i, v in enumerate(VENUES):
        x = GAP + i * (W + GAP)
        board.paste(panel(*v, title=title, body=body, seed=i), (x, 96))
        d.text((x, H + 104), v[0], font=title, fill=CREAM)
        d.text((x, H + 138), f"Levels {v[1]}", font=body, fill="#B9B4E0")
        for j, c in enumerate([v[4], v[5], v[6], v[7]]):
            d.rounded_rectangle([x + 180 + j * 30, H + 136, x + 204 + j * 30, H + 160], radius=7, fill=c,
                                outline="#000000")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    board.save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}  {board.width}x{board.height}")


if __name__ == "__main__":
    main()
