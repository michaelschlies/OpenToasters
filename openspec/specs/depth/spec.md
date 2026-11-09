# Depth & parallax

## Overview
Each toaster gets a depth value z in [0.35, 1.0] (0.35 = far, 1.0 = near).
Far toasters are smaller AND slower and are drawn behind near ones, giving
the flock a sense of depth.

## Parameters
| Parameter | Value | Meaning |
|-----------|-------|---------|
| z         | uni(0.35, 1.0) | depth (0.35 far ... 1.0 near) |
| scale     | (96 x size / maxDim) x z x jitter | image-px to points |
| speed     | x z | far toasters are slower |

## Requirements
- R1. Each toaster's depth z MUST be uniform in [0.35, 1.0], re-rolled on
  every respawn.
- R2. A toaster's draw scale MUST be proportional to z (far toasters are
  smaller): `TARGET_TOASTER_PTS x sizeSetting / maxDim x z x jitter`.
- R3. A toaster's speed MUST be proportional to z (far toasters are slower).
- R4. Draw order MUST sort far to near (ascending z) so near toasters are
  drawn on top; the sort MUST be in place with no per-frame allocation.
