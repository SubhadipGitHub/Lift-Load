# Art pack: polished 3D-animated look with Gemini

This replaces the flat parametric art with a stylized 3D animated-feature look: soft rounded shapes, subsurface
skin and cinematic lighting. It covers the cast, cargo props, the four lift kinds, the five venues, the home skyline,
the store key art and the app icon.

Prompts live in one place, `tool/art/art_pack.json`. That file holds the style bible and one prompt per asset.
`tool/art/gemini_art.py` runs them through the Gemini API, or prints them for the Gemini app, then turns the output
into game-ready files.

## Rules the art must keep

- **Weight stays hidden, and the build is the clue (rule 3).**
  - Each type has one fixed look, and its build is how players learn its weight. The per-type prompts take their
    build from `ResidentLook` in `lib/ui/painters/resident_painter.dart`: height order, shoulders, hips and belly.
  - The two liars must stay liars. The gym regular is lean and athletic, not a bodybuilder. The puffer teen is a
    slight kid inside a huge jacket.
  - Nothing may hint at a number: no straining, no sweat drops, no scale props.
- **No studio, film, brand or real place names**, in prompts or anywhere else (CLAUDE.md). The prompts describe the
  look instead of naming who made it famous. Gemini also tends to refuse or water down "in the style of" a named
  studio. The rider's jacket and helmet are plain, every cylinder and water can is unlabelled, and signboards are
  blank.
- **Ship after Gate A, not during it.** Gate A's heavy-types metric measures how well testers learn the current
  silhouettes, so swapping the art mid-test would void it. Generate and review now, and integrate after the Gate A
  decision. This matches `.claude/memory/decisions.md`: "An illustrator pass can still replace it after Gate A".

## Workflow

You need a Google AI Studio API key on your own machine; this cloud session cannot reach the API. Python 3.10+ with
Pillow and numpy is also required.

```bash
export GEMINI_API_KEY=...                                # from aistudio.google.com
python3 tool/art/gemini_art.py generate --only resident_kid,resident_kid_blink
python3 tool/art/gemini_art.py process && python3 tool/art/gemini_art.py sheet
```

1. **Lock the anchor first.** `resident_kid` is the style reference for every other character and prop. Regenerate
   it (`--force`) until you love it; everything downstream inherits its rendering.
2. **Generate the rest.** `python3 tool/art/gemini_art.py generate` fills in whatever is missing, in dependency
   order. Use `--only id,id --force` to redo single assets. The default model is `gemini-3-pro-image-preview` for
   final quality; `--model gemini-3.1-flash-image` is cheaper for drafts. Model ids change, so check AI Studio.
3. **Process.** `process` does three things:
   - It keys out the green backdrop (read from the image's own border, since Gemini's green is not #00FF00), drops a
     corner watermark, and trims each sprite.
   - It removes green spill: at the figure's rim, and the green bounce light that glossy greys pick up (the
     wheelchair's metal came back teal). Saturated colours such as skin or an olive kurta are never touched.
   - It sizes residents at 6 px per design unit, so the tallest lands at 624 px.
   - It cover-crops each scene to its frame and writes WebP to `art/processed/`.

   Blink frames reuse their idle frame's exact crop and scale, so the swap never jumps.
4. **Review.** Run `python3 tool/art/gemini_art.py review`. It prints, per resident, the face colour against the card's
   skin hex, torso and leg width, silhouette area, and green-pixel counts. It also reports the build order against the
   design's, and writes `art/review/zoom_cream.png` and `zoom_night.png` (2x, on the lobby and night colours). Then
   look at `art/processed/_cast_lineup.png` (`sheet`) against the checklist below, and regenerate what fails. The
   numbers catch what the eye misses at phone size; they do not replace the sheets. Two readings to know:
   - Lit skin renders lighter than the flat hex, so the face limit is 40 per channel (the approved cast sits within
     35). A pale face on a deep-brown card is far past it.
   - The approved cast scores a build-order rank correlation of 0.87 (area against `design_build`, liars left out).
     Below 0.8, something drifted.

   `review --dir docs/art/approved` runs the same check on the approved cast.

Without an API key you can do the same by hand. Run `python3 tool/art/gemini_art.py prompts > art/prompts.md` and
paste each prompt into the Gemini app or AI Studio, one new chat per image, attaching the reference image the step
names. App prompts state the aspect ratio in words, since the app has no setting for it. Save each result as
`art/raw/<id>.png`, then run `process` and `sheet`. If the app adds a small corner watermark, `process` drops it from
characters and props, because it removes every island under 5% of the largest. Crop scenes by hand if one shows.

**Cost.** Expect roughly a few dollars to about $15 per full pass of 53 images on the pro model, plus retries.
Check current pricing before a full run.

`art/` (raw images and working output) is git-ignored. The approved, processed cast is the one exception:
`docs/art/approved/` holds the 17 WebP sprites (14 residents, 3 cargo props, about 0.5 MB) so a new session or machine
can line new art up against them with `review --dir` and `sheet`. It sits under `docs/`, outside `pubspec.yaml`'s
assets, so none of it ships. Add each new approved sprite there when you approve it. The integration PR moves the
chosen files into `assets/`.

## Review checklist (per character, on the line-up)

- **Height order.** Height order and relative size match the game: the kid is clearly smallest, and the gym regular
  is tallest.
- **Build reads at a glance, at phone size.** Hold the line-up at arm's length and check:
  - The uncle and the aunty read heavy and round.
  - The guard reads stocky.
  - The office pair and the student read slim.
- **The liars hold.**
  - The gym regular looks lean and light, with broad shoulders and a narrow waist.
  - The puffer teen's legs and face are thin under a huge jacket.
- **Skin tone matches the design.** Each prompt carries the tone and hex taken from `ResidentLook`
  (`lib/ui/painters/resident_painter.dart`), because left unsaid Gemini defaults to pale. Check the face against the
  hex on the card; the gym regular is the deepest brown and the easiest to get wrong.
- **Every resident of a type looks the same.** No variation, or players cannot learn the cast.
- **Vehicles and cargo read instantly:**
  - the wheelchair, the pram and the bellhop's trolley;
  - the water can, the suitcase and the gas cylinder.
- **Nothing that leaks or brands:**
  - no text, numbers, logos or labels;
  - no green fringe after `process` (if there is, regenerate: the character touched the backdrop colour);
  - feet visible, nothing cropped.
- **The blink frame lines up.** Only the eyes change when you flip between idle and blink.

## Integration (after Gate A, needs PRD v1.5 sign-off)

This is a separate build, sketched here so the art is made to fit it:

- **Sprites behind the painter.** A sprite-backed `ResidentFigure` path keeps the parametric painter as the
  fallback. The asset list and `designWidth` stay the source of figure widths. Idle sway, walks and power-cut dimming
  already work on any child widget, and blink becomes an idle/blink frame swap.
- **Raster cabins.** Raster cabin interiors and doors (the doors slide as two halves of one image), venue lobby
  floors and shaft walls, and the home skyline, all drawn under the existing UI.
- **Size budget.** About 2 MB of WebP for the cast and props and 3–5 MB for scenes, within the 25 MB APK budget.
- **Proof.** Re-run the responsive sweep and the screenshot contact sheets.
- **Rollout.** Ship behind a flag first, compare against the parametric cast with a few Gate A testers, then switch.
