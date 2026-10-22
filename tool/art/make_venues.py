#!/usr/bin/env python3
"""Render venue backgrounds in code: shaft walls (one per storey band) and lobby floor materials.

No Gemini: the game needs these to sit behind the cabin and under the lanes without competing, so they are drawn to
the game's own constraints (lib/ui/painters/shaft_painter.dart, lobby_painter.dart, lib/ui/widgets/lift_shaft.dart).

Sunrise Towers (society) for now:
  society_wall_<band>.webp   732 x 524 px = the 366 x 262 unit shaft panel at 2x. Bands follow the building: ground
                             (levels 1-4), low (5-8), mid (9-12), high (13-16), top (17-20). Detail lives in the two
                             side bands, because the cabin (196 units) and the NEXT strip cover the middle; the wall
                             stays near the facade colour so brass chips and the cabin read on top.
  society_floor_<material>.webp  408 px square, tileable (4 x 4 tiles of 34 units at 3x): tile, marble, wood. Kept light
                             with low contrast: the lane text ("+3 waiting") is dark ink on top, so 95% of pixels must
                             clear 4.3:1 against it (the same as the game's own grid lines) and the thin grout 3:1.

    python3 tool/art/make_venues.py                # writes art/processed/
    python3 tool/art/make_venues.py --preview      # also art/review/venue_society_<band>.png mock-ups
Deterministic; needs only Pillow and numpy.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PW, PH = 732, 524  # shaft panel at 2x (366 x 262 units)
CAB_X0, CAB_W = 70 * 2, 196 * 2  # cabin column in the panel (pad 10 + NEXT 44 + gaps 8 + 8)
BANDS = ["ground", "low", "mid", "high", "top"]
FLOORS = ["tile", "marble", "wood"]
FACADE = np.array([42, 39, 86], np.float32)  # LL.facade
LANE_INK = (0x6B, 0x5C, 0x44)
LIGHT = np.array([-0.45, -0.6, 0.66])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def fft_noise(shape, sigma, seed, aniso=(1.0, 1.0)):
    """Periodic (tileable) smooth noise in [0,1]; sigma in px, aniso scales (y, x)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal(shape))
    fy = np.fft.fftfreq(shape[0])[:, None]
    fx = np.fft.fftfreq(shape[1])[None, :]
    k = 2 * np.pi ** 2 * sigma ** 2
    f *= np.exp(-k * ((fy * aniso[0]) ** 2 + (fx * aniso[1]) ** 2))
    n = np.fft.ifft2(f).real
    n = (n - n.mean()) / (n.std() * 4 + 1e-9) + 0.5
    return np.clip(n, 0, 1).astype(np.float32)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def grid(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return yy, xx


def box_height(h, w, x0, y0, x1, y1, edge, amp):
    yy, xx = grid(h, w)
    d = np.minimum(np.minimum(xx - x0, x1 - xx), np.minimum(yy - y0, y1 - yy))
    return amp * smooth(d / edge) * (d > 0)


def shade(albedo, height, gloss=0.0, shin=20.0, relief=2.0, ambient=0.55):
    gy, gx = np.gradient(height)
    n = np.stack([-gx * relief, -gy * relief, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    diffuse = np.clip((n * LIGHT).sum(-1), 0, 1)
    half = LIGHT + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    spec = np.clip((n * half).sum(-1), 0, 1) ** shin * gloss
    flat = LIGHT[2]
    return albedo * (ambient + (1 - ambient) * diffuse / flat)[..., None] + 255.0 * spec[..., None] * 0.5


def to_img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def luminance(rgb):
    c = np.asarray(rgb, np.float32) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


# ---------------------------------------------------------------- walls

def wall(band: str) -> Image.Image:
    seed = BANDS.index(band) + 31
    h, w = PH, PW
    yy, xx = grid(h, w)
    plaster = fft_noise((h, w), 2.2, seed) - 0.5
    cloud = fft_noise((h, w), 60, seed + 1) - 0.5
    top = FACADE * 1.18
    bottom = FACADE * 0.78
    t = (yy / h)[..., None]
    albedo = top * (1 - t) + bottom * t
    albedo = albedo * (1 + 0.05 * plaster[..., None] + 0.08 * cloud[..., None])
    height = plaster * 0.6
    emit = np.zeros((h, w, 3), np.float32)
    gloss = 0.0

    left_band = (xx < CAB_X0 - 8) & True
    right_band = xx > CAB_X0 + CAB_W + 8

    def window(x0, y0, x1, y1, sky_top, sky_bottom, lit=0.0, arch=False):
        nonlocal albedo, height, emit
        m = ((xx > x0) & (xx < x1) & (yy > y0) & (yy < y1)).astype(np.float32)
        if arch:
            cx, r = (x0 + x1) / 2, (x1 - x0) / 2
            top_cut = (yy < y0 + r) & ((xx - cx) ** 2 + (yy - (y0 + r)) ** 2 > r * r)
            m = np.where(top_cut, 0, m)
        k = np.clip((yy - y0) / max(1, (y1 - y0)), 0, 1)[..., None]
        sky = np.array(sky_top, np.float32) * (1 - k) + np.array(sky_bottom, np.float32) * k
        mm = m[..., None]
        emit = emit * (1 - mm) + sky * mm * (0.55 + lit)
        albedo = albedo * (1 - mm)
        # reveal: a recessed frame
        height = height - 5.0 * smooth(np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))) / 255.0)
        return m

    def stars(m, n, seed2):
        nonlocal emit
        rng = np.random.default_rng(seed2)
        ys, xs = np.nonzero(m > 0)
        if not len(ys):
            return
        for i in rng.choice(len(ys), size=min(n, len(ys)), replace=False):
            emit[ys[i], xs[i]] += 120

    def skyline(m, y_base, seed2):
        """Dark stepped silhouettes with a few warm lit windows, clipped to the window mask m."""
        nonlocal emit
        rng = np.random.default_rng(seed2)
        ys, xs = np.nonzero(m > 0)
        x0, x1 = xs.min(), xs.max()
        x = x0
        while x < x1:
            bw = int(rng.integers(10, 22))
            bh = int(rng.integers(14, 46))
            sel = (xx >= x) & (xx < x + bw) & (yy > y_base - bh) & (yy < y_base + 60) & (m > 0)
            emit = np.where(sel[..., None], np.array([18, 16, 40], np.float32), emit)
            for _ in range(int(rng.integers(0, 3))):
                wx, wy = int(rng.integers(x + 2, x + bw - 2)), int(rng.integers(y_base - bh + 4, y_base - 3))
                emit[wy:wy + 2, wx:wx + 2] = np.where((m[wy:wy + 2, wx:wx + 2] > 0)[..., None], (255, 210, 120), emit[wy:wy + 2, wx:wx + 2])
            x += bw + int(rng.integers(0, 4))

    BRASS = np.array([200, 150, 60], np.float32)

    def trim(x0, y0, x1, y1, thick=3):
        nonlocal albedo, height, gloss
        ring = ((xx > x0 - thick) & (xx < x1 + thick) & (yy > y0 - thick) & (yy < y1 + thick)) & ~((xx > x0) & (xx < x1) & (yy > y0) & (yy < y1))
        albedo = np.where(ring[..., None], BRASS * 0.8, albedo)
        height = np.where(ring, 2.0, height)

    sides = [(14, 50), (CAB_X0 + CAB_W + 14, PW - 14)]  # x ranges of the two visible bands

    # pilasters between floors, brass skirting, in every band
    for x in (6, CAB_X0 - 14, CAB_X0 + CAB_W + 6, PW - 22):
        height += box_height(h, w, x, 0, x + 14, h, 5, 5.0)
    skirt = (yy > h - 34) & (yy < h - 26)
    albedo = np.where(skirt[..., None], BRASS * 0.7, albedo)
    height = np.where(skirt, 1.5, height)

    if band == "ground":
        # wainscot panelling on the lower half, a warm wall lamp each side, a blank noticeboard
        for (a, b) in sides:
            for px in range(a, b - 20, 46):
                height += box_height(h, w, px, int(h * 0.55), min(px + 38, b), h - 44, 6, -4.0)
        rail = (yy > h * 0.52) & (yy < h * 0.52 + 6)
        albedo = np.where(rail[..., None], BRASS * 0.7, albedo)
        for cx in (34, PW - 40):
            r = np.hypot(xx - cx, yy - h * 0.26)
            emit += np.stack([255 * np.exp(-(r / 26) ** 2), 205 * np.exp(-(r / 26) ** 2), 120 * np.exp(-(r / 26) ** 2)], -1) * 0.35
            albedo = np.where((r < 7)[..., None], np.array([255, 224, 150], np.float32), albedo)
        board = box_height(h, w, CAB_X0 + CAB_W + 34, int(h * 0.12), CAB_X0 + CAB_W + 84, int(h * 0.38), 4, 3.0)
        height += board
        albedo = np.where((board > 1.0)[..., None], np.array([150, 112, 70], np.float32), albedo)
    else:
        cfg = {
            "low": dict(rows=2, ww=34, wh=62, sky=((70, 60, 120), (130, 86, 130)), lit=0.15),
            "mid": dict(rows=2, ww=38, wh=78, sky=((54, 52, 112), (160, 96, 120)), lit=0.25),
            "high": dict(rows=2, ww=40, wh=96, sky=((38, 40, 104), (196, 112, 112)), lit=0.3),
            "top": dict(rows=1, ww=54, wh=170, sky=((16, 18, 60), (60, 44, 110)), lit=0.35),
        }[band]
        masks = []
        for si, (a, b) in enumerate(sides[1:]):  # the NEXT strip hides the left band, so windows go on the right only
            cols = max(1, (b - a) // (cfg["ww"] + 14))
            span = cfg["ww"] * cols + 14 * (cols - 1)
            ox = a + ((b - a) - span) // 2
            for r in range(cfg["rows"]):
                gap = (h - 60 - cfg["rows"] * cfg["wh"]) // (cfg["rows"] + 1)
                y0 = 30 + gap + r * (cfg["wh"] + gap)
                for c in range(cols):
                    x0 = ox + c * (cfg["ww"] + 14)
                    m = window(x0, y0, x0 + cfg["ww"], y0 + cfg["wh"], cfg["sky"][0], cfg["sky"][1], cfg["lit"], arch=(band == "top"))
                    trim(x0, y0, x0 + cfg["ww"], y0 + cfg["wh"])
                    masks.append((m, y0 + cfg["wh"]))
        for i, (m, yb) in enumerate(masks):
            if band in ("high", "top"):
                skyline(m, yb - 4, seed + 100 + i)
            if band == "top":
                stars(m, 60, seed + 200 + i)
        if band in ("mid", "high"):
            # warm light spill on the wall from one lit window
            m, _ = masks[0]
            spill = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26))) / 255.0
            emit += np.stack([255 * spill, 190 * spill, 110 * spill], -1) * 0.10

    out = shade(albedo, height, gloss) + emit
    # rails/vignette: darker toward the bottom so the panel sits on the lobby, as the painter does
    out *= (1 - 0.18 * smooth((yy - h * 0.7) / (h * 0.3)))[..., None]
    return to_img(out)


# ---------------------------------------------------------------- floors

def floor(material: str) -> Image.Image:
    n = 408
    seed = FLOORS.index(material) + 51
    yy, xx = grid(n, n)
    fine = fft_noise((n, n), 1.6, seed) - 0.5
    cloud = fft_noise((n, n), 40, seed + 1) - 0.5
    height = np.zeros((n, n), np.float32)
    if material == "tile":
        tile = 102  # 34 units at 3x
        gx, gy = (xx % tile), (yy % tile)
        d = np.minimum(np.minimum(gx, tile - gx), np.minimum(gy, tile - gy))
        grout = 1 - smooth((d - 1.0) / 1.8)
        ti, tj = (xx // tile).astype(int), (yy // tile).astype(int)
        rng = np.random.default_rng(seed)
        var = rng.random((n // tile, n // tile)).astype(np.float32)
        v = var[tj, ti]
        base = np.array([247, 232, 202], np.float32)
        albedo = base * (0.995 + 0.02 * v[..., None] + 0.02 * fine[..., None] + 0.015 * cloud[..., None])
        albedo = albedo * (1 - grout[..., None]) + np.array([234, 213, 176], np.float32) * grout[..., None]
        height = -grout * 2.5 + (fine * 0.4) + smooth(d / 6) * 0.8
        gloss = 0.12
    elif material == "marble":
        slab = 204
        gx, gy = (xx % slab), (yy % slab)
        d = np.minimum(np.minimum(gx, slab - gx), np.minimum(gy, slab - gy))
        grout = 1 - smooth((d - 1.0) / 2.5)
        warp = fft_noise((n, n), 70, seed + 3) - 0.5
        vein = np.abs(fft_noise((n, n), 34, seed + 4, aniso=(1.0, 0.3)) - 0.5 + 0.5 * warp)
        vein = 1 - smooth(vein / 0.012)
        base = np.array([241, 235, 224], np.float32)
        albedo = base * (0.99 + 0.025 * cloud[..., None])
        albedo = albedo * (1 - 0.08 * vein[..., None]) + np.array([196, 180, 164], np.float32) * 0.08 * vein[..., None]
        albedo = albedo * (1 - grout[..., None]) + np.array([224, 214, 198], np.float32) * grout[..., None]
        height = -grout * 1.5
        gloss = 0.55
    else:  # wood
        plank = 51  # 17 units at 3x
        row = (yy // plank).astype(int)
        rng = np.random.default_rng(seed)
        off = rng.random(n // plank + 1).astype(np.float32) * 204
        shifted = (xx + off[row]) % 204
        d_row = np.minimum(yy % plank, plank - yy % plank)
        d_end = np.minimum(shifted, 204 - shifted)
        seam = 1 - smooth((np.minimum(d_row, d_end) - 0.8) / 1.5)
        tone = rng.random(n // plank + 1).astype(np.float32)[row]
        grain = fft_noise((n, n), 3.0, seed + 5, aniso=(1.6, 0.18))
        base_a, base_b = np.array([250, 236, 206], np.float32), np.array([244, 226, 190], np.float32)
        albedo = base_a * (1 - tone[..., None]) + base_b * tone[..., None]
        albedo = albedo * (0.975 + 0.04 * grain[..., None])
        albedo = albedo * (1 - seam[..., None]) + np.array([232, 208, 168], np.float32) * seam[..., None]
        height = -seam * 2.0 + (grain - 0.5) * 0.5
        gloss = 0.25
    out = shade(albedo, height, gloss, shin=28.0, relief=0.6, ambient=0.9)
    # shading flattens the average a touch; pull the mean back to the albedo's so floors stay light
    out *= albedo.mean() / max(out.mean(), 1)
    return to_img(out)


def contrast_vs_ink(img: Image.Image):
    lum = luminance(np.asarray(img))
    ink = float(luminance(np.array(LANE_INK)))
    return ((float(np.percentile(lum, 5)) + 0.05) / (ink + 0.05), (float(np.percentile(lum, 0.2)) + 0.05) / (ink + 0.05))


# ---------------------------------------------------------------- preview

def mock(band: str, mat: str, wall_img: Image.Image, floor_img: Image.Image, out: Path):
    """The play screen at 2x for the society: shaft panel with cabin and NEXT chips, lobby floor with residents."""
    cab = Image.open("docs/art/approved/cabin_normal_interior.webp").convert("RGBA")
    target = 196 / 214
    cw = round(cab.height * target)
    x0 = (cab.width - cw) // 2
    cab = cab.crop((x0, 0, x0 + cw, cab.height)).resize((CAB_W, round(CAB_W / target)), Image.LANCZOS)
    panel = wall_img.convert("RGBA")
    panel.alpha_composite(cab, (CAB_X0, 60))
    d = ImageDraw.Draw(panel)
    for i in range(3):
        d.rounded_rectangle((20, 40 + i * 86, 20 + 84, 40 + i * 86 + 78), 14, fill=(245, 184, 61, 255 if i == 0 else 150))
    lobby_h = 560
    lobby = Image.new("RGBA", (PW, lobby_h))
    for yy in range(0, lobby_h, floor_img.height):
        for xx in range(0, PW, floor_img.width):
            lobby.paste(floor_img, (xx, yy))
    k = 108 / 624
    for lane, (name, depth) in enumerate([("resident_kid", 3), ("resident_uncle", 3), ("resident_gym", 3), ("resident_aunty", 3)]):
        cx = 60 + lane * 190
        for r in range(depth):
            s = Image.open(f"docs/art/approved/{name}.webp").convert("RGBA")
            sc = k * (1 - 0.06 * r)
            s = s.resize((round(s.width * sc), round(s.height * sc)), Image.LANCZOS)
            lobby.alpha_composite(s, (cx - s.width // 2 + 30, 70 + r * 150 - s.height // 3))
    sheet = Image.new("RGB", (PW, PH + lobby_h), (24, 22, 60))
    sheet.paste(panel.convert("RGB"), (0, 0))
    sheet.paste(lobby.convert("RGB"), (0, PH))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--out", default="art/processed")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    floors = {}
    for m in FLOORS:
        img = floor(m)
        img.save(out / f"society_floor_{m}.webp", quality=92)
        floors[m] = img
        c5, c0 = contrast_vs_ink(img)
        print(f"floor {m}: lane ink contrast p5 {c5:.1f}:1 (need >= 4.3, the in-game grid lines), darkest 0.2% {c0:.1f}:1 (need >= 3)")
    for b in BANDS:
        w = wall(b)
        w.save(out / f"society_wall_{b}.webp", quality=92)
        print("wall", b)
        if a.preview:
            mock(b, "tile", w, floors["tile"], Path("art/review") / f"venue_society_{b}.png")
    if a.preview:
        mats = []
        for m in FLOORS:
            mock("ground", m, wall("ground"), floors[m], Path("art/review") / f"_floor_{m}.png")
            mats.append(Image.open(Path("art/review") / f"_floor_{m}.png").crop((0, PH, PW, PH + 560)))
            (Path("art/review") / f"_floor_{m}.png").unlink()
        sheet = Image.new("RGB", (PW * 3, 560))
        for i, im in enumerate(mats):
            sheet.paste(im, (i * PW, 0))
        sheet.save(Path("art/review") / "venue_society_floors.png")


if __name__ == "__main__":
    main()
