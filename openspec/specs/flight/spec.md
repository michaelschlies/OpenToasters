# Flight stream

## Overview
Every toaster is part of one unified flock that crosses the sky right to
left, as if the whole sky is a single stream of traffic. No toaster flies
randomly or spins in place; all base motion is forward along the stream,
with per-toaster variation in angle, speed, and size.

## Parameters
| Parameter        | Value                        | Meaning |
|------------------|------------------------------|---------|
| BASE_SPEED_PTS   | 70.0                         | horizontal pts/sec at z=1, speed=1 |
| flight angle     | M_PI +/- 0.35 rad            | leftward, +/- ~20 degrees |
| speed jitter     | x0.6-1.4                     | per-toaster speed multiplier |
| facing           | flip = 1.0                   | sprites face left natively; never mirrored |

## Requirements
- R1. Every toaster's base velocity MUST point leftward (flight angle within
  +/-0.35 rad of M_PI), so the whole flock streams right to left.
- R2. Each toaster's speed MUST be `BASE_SPEED_PTS x speedSetting x z x
  jitter` with jitter uniform in [0.6, 1.4].
- R3. Non-spinning toasters MUST have their nose aligned along their flight
  path (the sprite faces left natively; `flip = 1.0`, never mirrored).
- R4. When a toaster exits the screen (beyond a margin of `180 x scale + 80`
  points on any edge) it MUST respawn just off the opposite edge, re-rolling
  all per-toaster variation.
- R5. On first spawn the flock MUST be scattered across the whole screen; on
  respawn toasters enter off-screen so they fly in naturally.
