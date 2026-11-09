# OpenToasters

A from-scratch macOS screensaver rebuilt from the classic AfterDark
"Flying Toasters" (Infinisy, 2012). Uses the original sprite assets
from the installed `Flying Toasters 1.2.saver` (personal use).

## Why it was rebuilt

* The 2012 original had a large memory leak — it kept allocating
  per-frame objects, so its footprint grew without bound over time.
* This version:
  - **Zero per-frame allocations.** Fixed-size C struct pools
    (`Toaster` array of 96, `drawOrder` index array). The frame loop
    is pure math + `CGContextDrawImage`.
  - **Sprites decoded exactly once per session** (`kCGImageSourceShouldCacheImmediately`)
    and **released when the saver stops**, so memory returns to
    baseline between runs instead of growing.
  - Measured (1280x800, 8 active toasters, 12 s continuous):
    12 MB after load, 14 MB after 12 s — flat, ~10 MB total overhead
    (the decoded sprite bitmaps themselves).

* More randomization than the original:
  - **Unified right-to-left flight stream** — every toaster flies right
    → left, as if the whole flock is crossing the sky together, with a
    per-toaster angle spread (±~20°) and their nose pointed along their
    path. Sprites face left natively, so nothing is mirrored.
  - **Low-opacity celestial background** — a procedural starfield
    (~1 per 9000 pt², some slowly twinkling, warm/cool tint variation)
    plus 2–6 large, very faint, soft-edged celestial bodies that drift
    slowly right → left and wrap around. Pure Core Graphics (stars are
    per-frame ellipse fills, bodies are prebuilt radial gradients) —
    negligible cost and zero extra memory.
  - **Density** — default 16 toasters (slider 1–48) scaled *linearly*
    by screen area, so 4K displays get proportionally more (16 at
    1080p → ~64 at 4K). Pool raised to 96; still zero per-frame
    allocations.
  - **Depth / parallax layers** — each toaster gets a random depth
    `z` in [0.35, 1.0]; far toasters are smaller *and* slower, drawn
    behind near ones.
  - **Global wind drift** — a slowly varying (sinusoidal) wind vector
    bends every path, so nothing flies in a perfectly straight line.
  - **Per-toaster variation** (re-rolled on every respawn):
    direction (mostly right-to-left, some diagonal, occasional
    full-360 dart), speed (x0.6–1.4), size (x0.75–1.3), vertical wobble
    (amplitude/frequency/phase), frame animation rate, initial tilt.
  - **Character classes** — 32 sprite types, 347 frames:
    - 12-frame types: normal flight loop (most common)
    - 31–48-frame types: spinners (their animation IS the spin)
    - 1-frame types: "surprise" one-shot characters (rarer)
  - **Gentle wingbeats** — the 12-frame flight loops run at ~0.5–0.75
    beats/s (down from up to 1.3) so the flapping reads as soft against
    the vertical bob (amplitude bumped to 9–28 pt to match).
  - **Special maneuvers** (config, on by default): spin tumbles for
    non-spinner characters, wind.

## Configuration (Settings button in the screensaver picker)

* Toasters: 1–48 (default 16; scaled linearly by screen area so big
  displays get proportionally more)
* Speed: 0.25–3.0x
* Size: 0.5–2.0x
* Special maneuvers: on/off
* Characters: 32 toggle buttons (sprite thumbnails) — pick which types
  fly. Settings persist in the saver's own `NSUserDefaults` domain
  (`com.opentoasters.saver`).

## Layout

```
opentoasters/
  Sources/OpenToastersView.m   the screensaver (Objective-C + AppKit)
  Sources/preview.m            offscreen test harness
  build.sh                     compiles the .saver bundle + harness
  .github/workflows/build.yml  CI: assetless build + artifact upload
  OpenToasters.saver           (build output)
  preview                      (build output, test harness)
  opentoaster_frames/          (snapshot output from test runs)
```

## Build

```sh
./build.sh                      # uses ~/Library/Screen Savers/Flying Toasters 1.2.saver/Contents/Resources
./build.sh /path/to/assets      # or point at a different asset directory
./build.sh --no-assets          # assetless bundle — what the CI workflow builds
                                # (copyrighted sprites never enter CI)
```

A GitHub Actions workflow (`.github/workflows/build.yml`) runs the assetless
build on a macOS runner, verifies the bundle metadata + signature, runs the
preview harness as a smoke test, and uploads the `.saver` as a build
artifact.

Requires Xcode command line tools (clang). Output is a bundle in this
directory, ad-hoc codesigned.

## Installing the sprite assets

`build.sh` copies the PNGs in from your installed original at build time (see
Build). If you instead have an assetless bundle — e.g., the CI artifact, or a
`./build.sh --no-assets` build — install the sprites by hand before installing
the saver:

1. Copy the 350 PNGs from your own copy of the original into the bundle:

   ```sh
   cp -R ~/Library/Screen\ Savers/Flying\ Toasters\ 1.2.saver/Contents/Resources/*.png \
       "OpenToasters.saver/Contents/Resources/"
   ```

   The engine loads every `character<N>_<frame>.png` it finds in
   `Contents/Resources` (32 types, 347 frames; the disabled
   `ZZ_character14_00.png` variant is ignored, same as the original).
   `openspec/ASSETS.md` is the full name manifest if you're sourcing the
   files from elsewhere. Only the PNGs are needed — this rebuild has no
   audio or plist dependencies.

2. Strip Finder metadata (`cp` brings it along and `codesign` rejects it),
   then re-sign — any file added to a signed bundle invalidates its signature:

   ```sh
   xattr -cr "OpenToasters.saver"
   find "OpenToasters.saver" -name .DS_Store -delete
   codesign --force --sign - "OpenToasters.saver"
   codesign -v "OpenToasters.saver"
   ```

3. Then install as usual (next section).

## Install

```sh
cp -R "OpenToasters.saver" ~/Library/Screen\ Savers/
```

Then pick "OpenToasters" in System Settings → Screen Saver. (The
original 1.2 bundle is left untouched.)

## Test

```sh
./preview "OpenToasters.saver" 8 30 1280 800
# -> runs 8s of real-time animation, writes PNG snapshots to
#    opentoaster_frames/, prints character/frame counts and
#    phys_footprint before/during/after.
```

## Notes

* Sprite/audio assets from the original AfterDark saver are **not committed**
  (copyright) — `.gitignore` blocks them and `openspec/ASSETS.md` is the
  full name manifest (350 PNGs + audio/plist) for sourcing from your own
  copy of `Flying Toasters 1.2.saver`.
* `ZZ_character14_00.png` in the original assets is a disabled variant
  (prefix sorts it out of the normal scan) — intentionally ignored,
  same as the original's behavior. `thumbnail.png`/`thumbnail@2x.png`
  are the picker icons and are included in the bundle.
* The engine normally drives `animateOneFrame` itself; a 2.5 s
  watchdog starts a 60 Hz fallback timer if it doesn't, so the saver
  animates regardless of engine version.
* Target: macOS 11+, arm64 (builds fine on Intel too — the compiler
  flags are arch-agnostic).
