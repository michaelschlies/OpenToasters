# Bounce

## Overview
Each toaster bobs vertically with a sinusoidal bob so the flight reads as
organic rather than a straight line. The default amplitude was reduced 50%
from the original (9-28 pt to 4.5-14 pt) so the bob reads as a gentle, soft
bounce; the Bounce option multiplies it.

## Parameters
| Parameter      | Value                      | Meaning |
|----------------|----------------------------|---------|
| bobAmp base    | uni(4.5, 14.0) pt          | "soft" default (half of the original 9-28) |
| bobAmp         | base x bounceSetting       | final amplitude (bounceSetting default 1.0) |
| bobFreq        | uni(0.35, 1.3) Hz          | bob rate |
| bobPhase       | uni(0, 2*pi)               | phase offset |

## Requirements
- R1. The vertical bob MUST be `sin(drawTime x bobFreq x 2*pi + bobPhase) x
  bobAmp`, added to the toaster's y position at draw time.
- R2. The default bobAmp base MUST be uniform in [4.5, 14.0] pt — exactly
  half the original [9, 28] pt range (the 50% bounce reduction).
- R3. The Bounce option (0-2.0, default 1.0) MUST multiply the base
  amplitude; 2.0 restores the original range, 0 disables the bob.
- R4. bobFreq MUST be uniform in [0.35, 1.3] Hz and bobPhase uniform in
  [0, 2*pi), both re-rolled on every respawn.
