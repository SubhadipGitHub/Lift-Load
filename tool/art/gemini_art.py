#!/usr/bin/env python3
"""Generate and process the Lift Load art pack with Gemini image models.

    python3 tool/art/gemini_art.py prompts > art/prompts.md   # paste into the Gemini app by hand
    GEMINI_API_KEY=... python3 tool/art/gemini_art.py generate [--model M] [--only id,id] [--force]
    python3 tool/art/gemini_art.py process                     # art/raw -> art/processed (transparent, sized)
    python3 tool/art/gemini_art.py sheet                       # art/processed/_cast_lineup.png for review

Everything reads tool/art/art_pack.json (style bible + one prompt per asset). Raw output goes to art/raw/<id>.png,
game-ready files to art/processed/<id>.webp; both are git-ignored until an integration PR moves chosen files into
assets/. See docs/art/gemini-art-pack.md for the workflow and the review checklist.

Needs Python 3.10+, Pillow and numpy. `generate` needs a Gemini API key (Google AI Studio) in GEMINI_API_KEY and
network access to generativelanguage.googleapis.com; it is meant to run on your own machine.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "tool" / "art" / "art_pack.json"
RAW = ROOT / "art" / "raw"
OUT = ROOT / "art" / "processed"

# gemini-3-pro-image-preview gives the best final quality; gemini-3.1-flash-image is cheaper for drafts. Model ids
# change: check Google AI Studio and pass --model if this one is retired.
DEFAULT_MODEL = "gemini-3-pro-image-preview"
API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# Processed sizes. Residents: 6 px per design unit (3x device pixels at the largest 2x layout scale), so the
# tallest figure (104) lands at 624 px. Props share the resident scale. Scenes: fixed frames.
RESIDENT_PX_PER_UNIT = 6
PROP_HEIGHT_PX = 300
SCENE_SIZE = {"9:16": (1080, 1920), "16:9": (1920, 1080), "4:5": (864, 1080), "1:1": (1024, 1024)}

REFERENCE_NOTE = ("Use the attached reference image only for rendering style, lighting, materials and level of "
                  "detail; do not copy its character, pose or outfit.")


def load_pack() -> dict:
    return json.loads(PACK.read_text(encoding="utf-8"))


def full_prompt(pack: dict, a: dict) -> str:
    if a["kind"] == "resident_blink":
        return a["prompt"]
    style = pack["style"]["resident" if a["kind"] == "resident" else a["kind"]]
    parts = [a["prompt"], style]
    if a.get("reference"):
        parts.append(REFERENCE_NOTE)
    return "\n\n".join(parts)


def ordered(pack: dict) -> list[dict]:
    """Assets in an order where every reference and edit source comes first."""
    by_id = {a["id"]: a for a in pack["assets"]}
    done: list[dict] = []
    seen: set[str] = set()

    def visit(a: dict) -> None:
        if a["id"] in seen:
            return
        for dep in (a.get("reference"), a.get("edit_of")):
            if dep:
                visit(by_id[dep])
        seen.add(a["id"])
        done.append(a)

    for a in pack["assets"]:
        visit(a)
    return done


# ── prompts ──────────────────────────────────────────────────────────────────

def cmd_prompts(pack: dict, _: argparse.Namespace) -> None:
    print("# Lift Load art pack: prompts for the Gemini app\n")
    print("Work top to bottom. Attach the named image where a step says so. Save each result as "
          "`art/raw/<id>.png`, then run `python3 tool/art/gemini_art.py process`.\n")
    for a in ordered(pack):
        print(f"## {a['id']} ({a['name']})\n")
        if a.get("aspect"):
            print(f"Aspect ratio: {a['aspect']}")
        if a.get("edit_of"):
            print(f"Attach: `art/raw/{a['edit_of']}.png` (this is an edit of it)")
        elif a.get("reference"):
            print(f"Attach as style reference: `art/raw/{a['reference']}.png`")
        if a.get("weight_read"):
            print(f"Review for: {a['weight_read']}")
        print("\n```text\n" + full_prompt(pack, a) + "\n```\n")


# ── generate ─────────────────────────────────────────────────────────────────

def _image_part(path: Path) -> dict:
    return {"inline_data": {"mime_type": "image/png", "data": base64.b64encode(path.read_bytes()).decode()}}


def _call(model: str, key: str, parts: list[dict], aspect: str | None) -> bytes:
    config: dict = {"responseModalities": ["IMAGE"]}
    if aspect:
        config["imageConfig"] = {"aspectRatio": aspect}
    body = json.dumps({"contents": [{"role": "user", "parts": parts}], "generationConfig": config}).encode()
    req = urllib.request.Request(API.format(model=model), data=body, method="POST",
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
            break
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:400]
            if e.code in (429, 500, 503) and attempt < 3:
                time.sleep(2 ** (attempt + 2))
                continue
            raise SystemExit(f"Gemini API error {e.code}: {detail}")
    for cand in data.get("candidates", []):
        for p in cand.get("content", {}).get("parts", []):
            blob = p.get("inlineData") or p.get("inline_data")
            if blob and blob.get("data"):
                return base64.b64decode(blob["data"])
    reason = data.get("promptFeedback") or [c.get("finishReason") for c in data.get("candidates", [])]
    raise RuntimeError(f"no image in the response ({reason})")


def cmd_generate(pack: dict, args: argparse.Namespace) -> None:
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise SystemExit("Set GEMINI_API_KEY (a Google AI Studio key) first.")
    RAW.mkdir(parents=True, exist_ok=True)
    only = set(args.only.split(",")) if args.only else None
    for a in ordered(pack):
        if only and a["id"] not in only:
            continue
        dest = RAW / f"{a['id']}.png"
        if dest.exists() and not args.force:
            print(f"skip   {a['id']} (exists; --force to redo)")
            continue
        parts: list[dict] = [{"text": full_prompt(pack, a)}]
        src = a.get("edit_of") or a.get("reference")
        if src:
            ref = RAW / f"{src}.png"
            if not ref.exists():
                print(f"wait   {a['id']}: needs art/raw/{src}.png first")
                continue
            parts.append(_image_part(ref))
        try:
            png = _call(args.model, key, parts, a.get("aspect"))
        except RuntimeError as e:
            print(f"FAILED {a['id']}: {e}")
            continue
        dest.write_bytes(png)
        print(f"wrote  art/raw/{dest.name}")


# ── process ──────────────────────────────────────────────────────────────────

def _key_out(img):
    """Pure-green background to alpha, with a soft edge and green spill removed."""
    import numpy as np
    from PIL import Image

    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # How much greener than the other channels a pixel is: about 0 on the character (an olive kurta scores
    # around 30), 255 on the pure-green backdrop.
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - 40.0) / 80.0, 0.0, 1.0)
    # Despill only the soft edge, where the backdrop bled in; solid greens on the character stay as drawn.
    edge = (alpha < 1.0) & (greenness > 0)
    g = np.where(edge, np.maximum(r, b), g)
    rgba = np.dstack([r, g, b, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _trim_box(img):
    return img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()


def cmd_process(pack: dict, _: argparse.Namespace) -> None:
    from PIL import Image

    OUT.mkdir(parents=True, exist_ok=True)
    for a in pack["assets"]:
        src = RAW / f"{a['id']}.png"
        if not src.exists():
            continue
        img = Image.open(src)
        if a["kind"] in ("resident", "resident_blink", "prop"):
            img = _key_out(img)
            box = _trim_box(img)
            if a.get("edit_of"):
                # A blink frame swaps in over its idle frame, so it takes the idle frame's canvas, crop and scale
                # exactly; anything else would make the figure jump when it blinks.
                base = RAW / f"{a['edit_of']}.png"
                if not base.exists():
                    print(f"skip   {a['id']}: needs art/raw/{a['edit_of']}.png")
                    continue
                idle = _key_out(Image.open(base))
                img = img.resize(idle.size, Image.LANCZOS)
                box = _trim_box(idle)
            if box:
                img = img.crop(box)
            h = a["design_height"] * RESIDENT_PX_PER_UNIT if a.get("design_height") else PROP_HEIGHT_PX
            w = max(1, round(img.width * h / img.height))
            img = img.resize((w, h), Image.LANCZOS)
        else:
            size = SCENE_SIZE.get(a.get("aspect", "1:1"), (1024, 1024))
            img = img.convert("RGB")
            # Cover-crop to the exact frame.
            scale = max(size[0] / img.width, size[1] / img.height)
            img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
            left, top = (img.width - size[0]) // 2, (img.height - size[1]) // 2
            img = img.crop((left, top, left + size[0], top + size[1]))
        dest = OUT / f"{a['id']}.webp"
        img.save(dest, "WEBP", quality=90, method=6)
        print(f"wrote  {dest.relative_to(ROOT)}  {img.width}x{img.height}  {dest.stat().st_size // 1024} KB")


# ── sheet ────────────────────────────────────────────────────────────────────

def cmd_sheet(pack: dict, _: argparse.Namespace) -> None:
    """Every processed resident at its in-game relative height, idle and blink, for the silhouette review."""
    from PIL import Image, ImageDraw

    people = [a for a in pack["assets"] if a["kind"] == "resident" and (OUT / f"{a['id']}.webp").exists()]
    if not people:
        raise SystemExit("Nothing processed yet: run generate (or save images by hand) and process first.")
    tiles = []
    for a in people:
        idle = Image.open(OUT / f"{a['id']}.webp")
        blink_path = OUT / f"{a['id']}_blink.webp"
        blink = Image.open(blink_path) if blink_path.exists() else None
        tiles.append((a, idle, blink))
    pad, label_h = 24, 40
    floor_y = max(t[1].height for t in tiles) + pad
    width = pad + sum(t[1].width + (t[2].width if t[2] else 0) + pad * 2 for t in tiles)
    sheet = Image.new("RGB", (width, floor_y + label_h + pad), (0x1C, 0x1A, 0x3F))
    draw = ImageDraw.Draw(sheet)
    x = pad
    for a, idle, blink in tiles:
        for im in (idle, blink):
            if im is None:
                continue
            sheet.paste(im, (x, floor_y - im.height), im)
            x += im.width + pad // 2
        draw.text((x - idle.width - pad // 2, floor_y + 8), a["name"], fill=(0xFF, 0xF4, 0xE2))
        x += pad
    draw.line([(0, floor_y), (width, floor_y)], fill=(0xF5, 0xB8, 0x3D), width=2)
    dest = OUT / "_cast_lineup.png"
    sheet.save(dest)
    print(f"wrote  {dest.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("prompts", help="print every prompt as Markdown for the Gemini app")
    g = sub.add_parser("generate", help="call the Gemini API for missing images")
    g.add_argument("--model", default=DEFAULT_MODEL)
    g.add_argument("--only", help="comma-separated asset ids")
    g.add_argument("--force", action="store_true", help="regenerate even if art/raw/<id>.png exists")
    sub.add_parser("process", help="art/raw -> art/processed: key out green, trim, size, WebP")
    sub.add_parser("sheet", help="cast line-up at in-game relative heights")
    args = ap.parse_args()
    pack = load_pack()
    {"prompts": cmd_prompts, "generate": cmd_generate, "process": cmd_process, "sheet": cmd_sheet}[args.cmd](pack, args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
