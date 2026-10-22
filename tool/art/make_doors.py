#!/usr/bin/env python3
"""Render the lift doors as two separate leaves per lift kind, so the game can slide them.

Gemini cannot give two independent leaves with a matching seam, and the doors are the one asset that must move, so
they are drawn here: a height map and an albedo per kind, lit from the upper left, with colours sampled from the
approved interior so each door matches its cabin. Deterministic (fixed seeds); needs only Pillow and numpy.

    python3 tool/art/make_doors.py                 # art/processed/cabin_<kind>_door_{left,right}.webp
    python3 tool/art/make_doors.py --preview       # also art/review/doors_<kind>.png (closed / half / open strip)

A leaf is half the cabin: the cabin is drawn 196 x 214 units, so a leaf is 98 x 214 units, 432 x 944 px at the scale
the interiors use. The left leaf's seam is its right edge; the right leaf is the mirror, so the pair always meets.
Closing motion spec is in docs/art/gemini-art-pack.md (Integration, "Doors").
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

W, H = 432, 944
KINDS = ["normal", "old", "service", "express"]
LIGHT = np.array([-0.45, -0.60, 0.66])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = (LIGHT + np.array([0, 0, 1.0]))
HALF = HALF / np.linalg.norm(HALF)


def noise(shape, cell, seed, octaves=3):
    """Smooth value noise in [0,1]; cell is (cell_h, cell_w) in px of the coarsest octave."""
    rng = np.random.default_rng(seed)
    out = np.zeros(shape)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        ch, cw = max(1, cell[0] // 2 ** o), max(1, cell[1] // 2 ** o)
        small = rng.random((max(2, shape[0] // ch + 2), max(2, shape[1] // cw + 2))).astype(np.float32)
        img = Image.fromarray((small * 255).astype(np.uint8)).resize(
            (small.shape[1] * cw, small.shape[0] * ch), Image.BICUBIC)
        out += amp * np.asarray(img, dtype=np.float32)[: shape[0], : shape[1]] / 255.0
        total += amp
        amp *= 0.5
    return out / total


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def bevel_rect(x0, y0, x1, y1, width, height):
    """Height of a raised (or, negative height, recessed) rectangle with a bevelled edge."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.minimum(np.minimum(xx - x0, x1 - xx), np.minimum(yy - y0, y1 - yy))
    return height * smooth(d / width) * (d > 0)


def frame_mask(x0, y0, x1, y1, thick):
    """1 on a rectangular ring of the given thickness, soft at both edges."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.minimum(np.minimum(xx - x0, x1 - xx), np.minimum(yy - y0, y1 - yy))
    return smooth(d / 2.0) * (1 - smooth((d - thick) / 2.0))


def sample(kind, box, fallback):
    p = Path("docs/art/approved") / f"cabin_{kind}_interior.webp"
    if not p.exists():
        p = Path("art/processed") / f"cabin_{kind}_interior.webp"
    if not p.exists():
        return np.array(fallback, dtype=np.float32)
    im = Image.open(p).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = box
    return np.asarray(im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))).reshape(-1, 3).mean(0)


def mix(a, b, t):
    return a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None]


def render(kind: str) -> Image.Image:
    seed = KINDS.index(kind) + 7
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    streak = 0.5 + 0.35 * (noise((H, W), (H // 2, 4), seed, 2) - 0.5)  # soft vertical brushing
    cloud = noise((H, W), (160, 120), seed + 1, 3)
    height = np.zeros((H, W), np.float32)
    albedo = np.zeros((H, W, 3), np.float32)
    gloss = np.zeros((H, W), np.float32)  # specular strength
    shin = 24.0
    emit = np.zeros((H, W, 3), np.float32)

    if kind == "normal":
        steel = sample("normal", (0.40, 0.30, 0.60, 0.55), (150, 135, 118))
        brass = np.array([196, 142, 58], np.float32)
        refl = smooth(noise((H, W), (420, 260), seed + 9, 2) * 1.6 - 0.3)  # broad soft reflections
        albedo = mix(steel * 0.80, steel * 1.18, 0.25 * streak + 0.75 * refl)
        gloss += 0.45
        panel = bevel_rect(58, 70, W - 14, H - 150, 14, -7)
        height += panel + (streak - 0.5) * 0.8
        ring = frame_mask(58, 70, W - 14, H - 150, 12) + frame_mask(20, 24, W - 8, H - 28, 9)
        ring = np.clip(ring, 0, 1)
        albedo = albedo * (1 - ring[..., None]) + brass * ring[..., None] * (0.85 + 0.3 * streak[..., None])
        height += ring * 3.0
        gloss += ring * 0.9
        height += bevel_rect(34, H - 132, W - 12, H - 40, 9, -4)
        shin = 30.0
    elif kind == "old":
        dark, light = np.array([54, 26, 15], np.float32), np.array([118, 62, 34], np.float32)
        grain = noise((H, W), (H // 3, 2), seed, 3)
        wood = 0.7 * grain + 0.3 * noise((H, W), (H // 5, 7), seed + 2, 2)
        albedo = mix(dark, light, smooth(wood * 1.25 - 0.1))
        gloss += 0.18
        height += (grain - 0.5) * 1.4
        for (a, b, c, d) in ((54, 70, W - 14, 520), (54, 560, W - 14, H - 128)):
            height += bevel_rect(a, b, c, d, 22, -9)
            albedo *= (1 - 0.18 * (bevel_rect(a, b, c, d, 22, 1) > 0.05))[..., None]
        scuff = noise((H, W), (6, 40), seed + 5, 2)
        albedo = np.where((scuff > 0.9)[..., None], albedo * 1.2, albedo)
        rail = frame_mask(14, 22, W - 4, H - 28, 7)
        brass = np.array([128, 92, 40], np.float32)
        kick = (yy > H - 112) & (yy < H - 34) & (xx > 24)
        albedo = np.where(kick[..., None], brass * (0.85 + 0.3 * cloud[..., None]), albedo)
        gloss += kick * 0.5
        height = np.where(kick, 2.0, height) + rail * 1.5
        shin = 14.0
    elif kind == "service":
        steel = sample("service", (0.17, 0.35, 0.22, 0.60), (150, 140, 124))
        albedo = mix(steel * 0.78, steel * 1.1, cloud * 0.6 + streak * 0.4)
        gloss += 0.35
        dents = noise((H, W), (190, 150), seed + 3, 2)
        height += (dents - 0.5) * 10.0 + (streak - 0.5) * 0.6
        for y0 in (120, 440, 700):
            rib = bevel_rect(26, y0, W - 10, y0 + 120, 22, 6)
            height += rib
        bolt_y = list(range(70, H - 60, 108))
        for by in bolt_y:
            for bx in (44, W - 36):
                r = np.hypot(xx - bx, yy - by)
                height += 6.5 * smooth((9 - r) / 5.0)
                albedo = np.where((r < 9)[..., None], albedo * 1.15, albedo)
        # chipped paint-free edges: darker bottom wear
        albedo *= (1 - 0.25 * smooth((yy - (H - 160)) / 160))[..., None]
        shin = 22.0
    else:  # express
        chrome = np.array([196, 202, 210], np.float32)
        glass = sample("express", (0.42, 0.30, 0.58, 0.60), (232, 224, 208))
        albedo[:] = chrome * (0.85 + 0.25 * streak[..., None])
        gloss += 0.95
        shin = 60.0
        px0, py0, px1, py1 = 56, 60, W - 22, H - 90
        inner = bevel_rect(px0, py0, px1, py1, 10, -9) > 0.01
        albedo = np.where(inner[..., None], mix(glass * 0.92, glass * 1.06, smooth(yy / H))[:, :, :], albedo)
        height += bevel_rect(px0, py0, px1, py1, 10, -9)
        gloss = np.where(inner, 0.55, gloss)
        # diagonal soft reflection streaks on the glass
        diag = np.sin((xx + yy * 0.55) / 70.0)
        albedo = np.where(inner[..., None], albedo * (1 + 0.05 * diag[..., None]), albedo)
        led = np.exp(-((W - xx) / 7.0) ** 2) * (yy > 40) * (yy < H - 60)
        emit = np.stack([80 * led, 165 * led, 255 * led], -1)

    # lighting
    gy, gx = np.gradient(height)
    n = np.stack([-gx * 2.2, -gy * 2.2, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    diffuse = np.clip((n * LIGHT).sum(-1), 0, 1)
    spec = np.clip((n * HALF).sum(-1), 0, 1) ** shin * gloss
    falloff = 1.05 - 0.28 * (yy / H) - 0.10 * (xx / W)  # lit from the top
    out = albedo * (0.38 + 0.78 * diffuse * falloff)[..., None] + 255.0 * spec[..., None] * 0.65 + emit

    # seam edge (right edge of the left leaf): dark rubber gap, then a thin highlight
    seam = np.clip((xx - (W - 9)) / 9.0, 0, 1)
    out *= (1 - 0.7 * seam)[..., None]
    out += (np.exp(-((xx - (W - 12)) / 1.6) ** 2) * 40)[..., None]
    # ambient occlusion toward the outer edges and the floor line
    ao = 1 - 0.30 * smooth((24 - xx) / 24) - 0.22 * smooth((yy - (H - 40)) / 40) - 0.16 * smooth((26 - yy) / 26)
    out *= ao[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def preview(kind: str, left: Image.Image, right: Image.Image, out: Path):
    p = Path("docs/art/approved") / f"cabin_{kind}_interior.webp"
    if not p.exists():
        p = Path("art/processed") / f"cabin_{kind}_interior.webp"
    scene = Image.open(p).convert("RGB")
    target = 196 / 214
    if scene.width / scene.height > target:
        cw = round(scene.height * target)
        x0 = (scene.width - cw) // 2
        scene = scene.crop((x0, 0, x0 + cw, scene.height))
    else:
        h = round(scene.width / target)
        scene = scene.crop((0, 90, scene.width, min(90 + h, scene.height)))
    scene = scene.resize((2 * W, H), Image.LANCZOS)
    frames = []
    for t in (1.0, 0.66, 0.33, 0.0):  # 1 = closed, 0 = open
        f = scene.copy()
        f.paste(left, (-round((1 - t) * W), 0))
        f.paste(right, (W + round((1 - t) * W), 0))
        frames.append(f)
    sheet = Image.new("RGB", (len(frames) * W, H // 2))
    for i, f in enumerate(frames):
        sheet.paste(f.resize((W, H // 2)), (i * W, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--only", default=",".join(KINDS))
    ap.add_argument("--out", default="art/processed")
    a = ap.parse_args()
    for kind in a.only.split(","):
        left = render(kind)
        right = left.transpose(Image.FLIP_LEFT_RIGHT)
        Path(a.out).mkdir(parents=True, exist_ok=True)
        left.save(Path(a.out) / f"cabin_{kind}_door_left.webp", quality=90)
        right.save(Path(a.out) / f"cabin_{kind}_door_right.webp", quality=90)
        print("wrote", kind)
        if a.preview:
            preview(kind, left, right, Path("art/review") / f"doors_{kind}.png")


if __name__ == "__main__":
    main()
