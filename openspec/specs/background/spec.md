# Celestial background

## Overview
A low-opacity procedural night sky sits behind the flock: a field of tiny
stars (some twinkling) plus a few large, very faint, soft-edged celestial
bodies that drift slowly right to left and wrap around. Pure Core Graphics —
no bitmaps, negligible cost, zero extra memory.

## Parameters
| Element      | Value |
|--------------|-------|
| stars        | ~1 per 9000 pt^2 (60-1400); alpha 0.10-0.45; 35% twinkle |
| star tints   | white / warm / cool (20% warm, 20% cool, 60% white) |
| bodies       | 2-6 (area / 700000); radius 14-44 pt; alpha 0.05-0.13 |
| body drift   | 2-7 pt/s leftward, wraps around |
| body palettes | ice blue, gold, lavender, tan |

## Requirements
- R1. Star density MUST be ~1 per 9000 pt^2, clamped to [60, 1400].
- R2. 35% of stars MUST twinkle (amplitude 0.05-0.18, frequency 0.2-0.8 Hz);
  the rest are static.
- R3. Celestial bodies MUST be 2-6 faint radial-gradient disks (radius 14-44
  pt, alpha 0.05-0.13) drifting slowly leftward and wrapping around.
- R4. The background MUST be drawn with Core Graphics only (no decoded
  bitmaps) so it adds no memory beyond the toaster sprites.
