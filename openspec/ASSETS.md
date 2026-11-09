# Sprite asset manifest

The screensaver uses the original AfterDark "Flying Toasters" sprite assets
(c) Infinisy / Stardock. **These files are intentionally NOT committed to
this repo** (copyright) — see the `.gitignore` at the repo root. `build.sh`
copies the PNGs in from an installed original at build time. This manifest
documents every asset name so anyone can source them from their own copy
of the original screensaver.

## Sourcing
All assets live in the original bundle's `Contents/Resources/` directory,
named `character<N>_<frame>.png`. Copy them from:

```
~/Library/Screen Savers/Flying Toasters 1.2.saver/Contents/Resources/
```

(Or pass any directory containing the same `characterN_MN.png` files to
`./build.sh <dir>`.)

## Character frames (32 types, 347 frames)
| Character | Frames | Frame range | Class |
|-----------|--------|-------------|-------|
| character1 | 12 | 00–11 | normal |
| character2 | 3 | 00–02 | normal |
| character3 | 12 | 00–11 | normal |
| character4 | 12 | 00–11 | normal |
| character5 | 36 | 00–35 | spinner |
| character6 | 12 | 00–11 | normal |
| character7 | 12 | 00–11 | normal |
| character8 | 12 | 00–11 | normal |
| character9 | 1 | 00 | surprise |
| character10 | 3 | 00–02 | normal |
| character11 | 3 | 00–02 | normal |
| character12 | 1 | 00 | surprise |
| character13 | 1 | 00 | surprise |
| character14 | 1 | 00 | surprise |
| character15 | 35 | 00–34 | spinner |
| character16 | 1 | 00 | surprise |
| character17 | 7 | 00–06 | normal |
| character18 | 31 | 00–30 | spinner |
| character19 | 8 | 00–07 | normal |
| character20 | 3 | 00–02 | normal |
| character21 | 31 | 00–30 | spinner |
| character22 | 1 | 00 | surprise |
| character23 | 1 | 00 | surprise |
| character24 | 1 | 00 | surprise |
| character25 | 48 | 00–47 | spinner |
| character26 | 12 | 00–11 | normal |
| character27 | 12 | 00–11 | normal |
| character28 | 12 | 00–11 | normal |
| character29 | 1 | 00 | surprise |
| character30 | 19 | 00–18 | normal |
| character31 | 2 | 00–01 | normal |
| character32 | 1 | 00 | surprise |

Class is determined by frame count: `1` = surprise one-shot, `>= 20` =
spinner (its animation is the spin), otherwise = normal wingbeat loop.

## Full file list (350 PNGs)
Every file `build.sh` copies (`cp "$ASSET_SRC"/*.png`), one per line —
347 character frames, the `ZZ_` variant, and the two picker icons:

```
character1_00.png
character1_01.png
character1_02.png
character1_03.png
character1_04.png
character1_05.png
character1_06.png
character1_07.png
character1_08.png
character1_09.png
character1_10.png
character1_11.png
character2_00.png
character2_01.png
character2_02.png
character3_00.png
character3_01.png
character3_02.png
character3_03.png
character3_04.png
character3_05.png
character3_06.png
character3_07.png
character3_08.png
character3_09.png
character3_10.png
character3_11.png
character4_00.png
character4_01.png
character4_02.png
character4_03.png
character4_04.png
character4_05.png
character4_06.png
character4_07.png
character4_08.png
character4_09.png
character4_10.png
character4_11.png
character5_00.png
character5_01.png
character5_02.png
character5_03.png
character5_04.png
character5_05.png
character5_06.png
character5_07.png
character5_08.png
character5_09.png
character5_10.png
character5_11.png
character5_12.png
character5_13.png
character5_14.png
character5_15.png
character5_16.png
character5_17.png
character5_18.png
character5_19.png
character5_20.png
character5_21.png
character5_22.png
character5_23.png
character5_24.png
character5_25.png
character5_26.png
character5_27.png
character5_28.png
character5_29.png
character5_30.png
character5_31.png
character5_32.png
character5_33.png
character5_34.png
character5_35.png
character6_00.png
character6_01.png
character6_02.png
character6_03.png
character6_04.png
character6_05.png
character6_06.png
character6_07.png
character6_08.png
character6_09.png
character6_10.png
character6_11.png
character7_00.png
character7_01.png
character7_02.png
character7_03.png
character7_04.png
character7_05.png
character7_06.png
character7_07.png
character7_08.png
character7_09.png
character7_10.png
character7_11.png
character8_00.png
character8_01.png
character8_02.png
character8_03.png
character8_04.png
character8_05.png
character8_06.png
character8_07.png
character8_08.png
character8_09.png
character8_10.png
character8_11.png
character9_00.png
character10_00.png
character10_01.png
character10_02.png
character11_00.png
character11_01.png
character11_02.png
character12_00.png
character13_00.png
character14_00.png
character15_00.png
character15_01.png
character15_02.png
character15_03.png
character15_04.png
character15_05.png
character15_06.png
character15_07.png
character15_08.png
character15_09.png
character15_10.png
character15_11.png
character15_12.png
character15_13.png
character15_14.png
character15_15.png
character15_16.png
character15_17.png
character15_18.png
character15_19.png
character15_20.png
character15_21.png
character15_22.png
character15_23.png
character15_24.png
character15_25.png
character15_26.png
character15_27.png
character15_28.png
character15_29.png
character15_30.png
character15_31.png
character15_32.png
character15_33.png
character15_34.png
character16_00.png
character17_00.png
character17_01.png
character17_02.png
character17_03.png
character17_04.png
character17_05.png
character17_06.png
character18_00.png
character18_01.png
character18_02.png
character18_03.png
character18_04.png
character18_05.png
character18_06.png
character18_07.png
character18_08.png
character18_09.png
character18_10.png
character18_11.png
character18_12.png
character18_13.png
character18_14.png
character18_15.png
character18_16.png
character18_17.png
character18_18.png
character18_19.png
character18_20.png
character18_21.png
character18_22.png
character18_23.png
character18_24.png
character18_25.png
character18_26.png
character18_27.png
character18_28.png
character18_29.png
character18_30.png
character19_00.png
character19_01.png
character19_02.png
character19_03.png
character19_04.png
character19_05.png
character19_06.png
character19_07.png
character20_00.png
character20_01.png
character20_02.png
character21_00.png
character21_01.png
character21_02.png
character21_03.png
character21_04.png
character21_05.png
character21_06.png
character21_07.png
character21_08.png
character21_09.png
character21_10.png
character21_11.png
character21_12.png
character21_13.png
character21_14.png
character21_15.png
character21_16.png
character21_17.png
character21_18.png
character21_19.png
character21_20.png
character21_21.png
character21_22.png
character21_23.png
character21_24.png
character21_25.png
character21_26.png
character21_27.png
character21_28.png
character21_29.png
character21_30.png
character22_00.png
character23_00.png
character24_00.png
character25_00.png
character25_01.png
character25_02.png
character25_03.png
character25_04.png
character25_05.png
character25_06.png
character25_07.png
character25_08.png
character25_09.png
character25_10.png
character25_11.png
character25_12.png
character25_13.png
character25_14.png
character25_15.png
character25_16.png
character25_17.png
character25_18.png
character25_19.png
character25_20.png
character25_21.png
character25_22.png
character25_23.png
character25_24.png
character25_25.png
character25_26.png
character25_27.png
character25_28.png
character25_29.png
character25_30.png
character25_31.png
character25_32.png
character25_33.png
character25_34.png
character25_35.png
character25_36.png
character25_37.png
character25_38.png
character25_39.png
character25_40.png
character25_41.png
character25_42.png
character25_43.png
character25_44.png
character25_45.png
character25_46.png
character25_47.png
character26_00.png
character26_01.png
character26_02.png
character26_03.png
character26_04.png
character26_05.png
character26_06.png
character26_07.png
character26_08.png
character26_09.png
character26_10.png
character26_11.png
character27_00.png
character27_01.png
character27_02.png
character27_03.png
character27_04.png
character27_05.png
character27_06.png
character27_07.png
character27_08.png
character27_09.png
character27_10.png
character27_11.png
character28_00.png
character28_01.png
character28_02.png
character28_03.png
character28_04.png
character28_05.png
character28_06.png
character28_07.png
character28_08.png
character28_09.png
character28_10.png
character28_11.png
character29_00.png
character30_00.png
character30_01.png
character30_02.png
character30_03.png
character30_04.png
character30_05.png
character30_06.png
character30_07.png
character30_08.png
character30_09.png
character30_10.png
character30_11.png
character30_12.png
character30_13.png
character30_14.png
character30_15.png
character30_16.png
character30_17.png
character30_18.png
character31_00.png
character31_01.png
character32_00.png
ZZ_character14_00.png
thumbnail.png
thumbnail@2x.png
```

## Other files in the original Resources (not used by this build)
Documented for completeness — `build.sh` copies only the PNGs, so none of
these enter the repo:

| File | What it is |
|------|------------|
| `toaster.mp3` | toast-popping sound effect (original) |
| `flapping.mp3` | wing-flapping sound effect (original) |
| `music.mp3` | background music loop (original) |
| `song.mp3` | background song (original) |
| `baby.mp3` | extra sound (original) |
| `benelrote.mp3` | extra sound (original) |
| `charudashi.mp3` | extra sound (original) |
| `music.plist` | original's music player config |
| `characters.plist` | original's character metadata |
| `en.lproj/`, `ja.lproj/`, `Base.lproj/` | localized strings (original) |

## Notes
- `ZZ_character14_00.png` is a disabled variant; the `ZZ_` prefix sorts it
  out of the normal `characterN_MN` scan, so it is intentionally ignored
  at runtime (same behavior as the original) but still copied into the
  bundle by the `*.png` glob.
- `thumbnail.png` / `thumbnail@2x.png` are the screensaver-picker icons;
  they ship in the built bundle.
