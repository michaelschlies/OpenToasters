# Special maneuvers

## Overview
An optional "Special maneuvers" toggle adds extra organic variety: a few
non-spinner characters get a gentle spin tumble. (The global wind is a
separate feature — always active and scaled by the Wind setting.)

## Parameters
| Parameter    | Value | Meaning |
|--------------|-------|---------|
| toggle       | on by default | "Special maneuvers (tumbles & wind)" |
| tumble chance | uni() < 0.05 | ~5% of non-spinners |
| tumble rate   | uni(0.6, 1.4) rad/s, random sign | gentle rotation |

## Requirements
- R1. When special maneuvers are ON, ~5% of non-spinner characters MUST get a
  gentle spin tumble (spin uni(0.6, 1.4) rad/s, random sign).
- R2. When special maneuvers are OFF, non-spinners MUST NOT tumble (only true
  spinners rotate, via their own animation).
- R3. The toggle MUST be persisted and default to ON.
