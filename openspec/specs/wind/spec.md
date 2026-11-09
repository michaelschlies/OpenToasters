# Wind drift

## Overview
A slowly-varying global wind vector bends every toaster's path so nothing
flies in a perfectly straight line. The wind is sinusoidal (two summed
harmonics) and scales with the Speed and Wind settings.

## Parameters
| Component | Formula |
|-----------|---------|
| wx | (sin(t*0.13)*6 + sin(t*0.07 + 1.7)*4) x speed x wind |
| wy | sin(t*0.11 + 0.9)*6 x wind |

## Requirements
- R1. The horizontal wind component MUST be `(sin(t*0.13)*6 + sin(t*0.07 +
  1.7)*4) x speedSetting x windSetting`, added to each toaster's x velocity.
- R2. The vertical wind component MUST be `sin(t*0.11 + 0.9)*6 x
  windSetting`, added to each toaster's y velocity.
- R3. The horizontal wind MUST stay small enough that even the slowest,
  farthest toasters keep drifting leftward (net x-velocity stays negative).
- R4. The Wind option (0-2.0, default 1.0) MUST scale both components; 0
  disables wind drift.
