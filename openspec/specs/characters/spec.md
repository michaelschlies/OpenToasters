# Character classes

## Overview
32 sprite types (character1 to character32) are grouped into three classes by
frame count. Spawn is weighted across the classes so the common wingbeaters
dominate, spinners appear regularly, and rare 1-frame "surprise" characters
show up occasionally.

## Classes
| Class    | Frame count | Characters | Spawn weight |
|----------|-------------|-----------|--------------|
| normal   | 2-19        | 1,2,3,4,6,7,8,10,11,17,19,20,26,27,28,30,31 | 0.56 |
| spinner  | >= 20       | 5,15,18,21,25 | 0.28 |
| surprise | 1           | 9,12,13,14,16,22,23,24,29,32 | 0.16 (0.08 if specials off) |

## Requirements
- R1. Characters MUST be grouped by frame count: 1-frame = surprise,
  20+ frame = spinner, otherwise = normal.
- R2. Spawn MUST pick a class by weight (surprise `singleW`, spinner
  `longW` = 0.28, normal the remainder), then pick a uniformly random enabled
  character of that class.
- R3. The surprise weight MUST be 0.16 when special maneuvers are on and
  0.08 when they are off.
- R4. Only characters enabled in the settings grid MUST be eligible; if a
  class has no enabled character, spawn MUST fall back to the other classes.
- R5. The set of enabled characters MUST be user-configurable (32 toggle
  buttons with sprite thumbnails) and persisted.
