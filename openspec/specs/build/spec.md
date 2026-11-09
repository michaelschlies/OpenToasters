# Build & install

## Overview
`build.sh` compiles the Objective-C source into a signed `.saver` bundle,
copies in the (copyrighted) sprite assets from an installed original, and
builds the offscreen `preview` test harness.

## Requirements
- R1. `build.sh` MUST compile `Sources/OpenToastersView.m` into a bundle
  (`-bundle -undefined dynamic_lookup`, arch-agnostic flags, min macOS 11.0).
- R2. Sprite assets MUST be copied from an installed original (default
  `~/Library/Screen Savers/Flying Toasters 1.2.saver/Contents/Resources`, or
  the path given as a positional argument) into the bundle's
  `Contents/Resources`.
- R3. The bundle MUST be ad-hoc codesigned (`codesign --force --sign -`).
- R4. `build.sh` MUST also build the `preview` offscreen harness from
  `Sources/preview.m`.
- R5. The copyrighted sprite assets MUST NOT be committed to the repo — see
  `openspec/ASSETS.md` for the manifest.
- R6. With `--no-assets`, `build.sh` MUST build a bundle without copying any
  sprites (no asset directory required) — used by the CI workflow
  (`.github/workflows/build.yml`), where the assets do not exist.
