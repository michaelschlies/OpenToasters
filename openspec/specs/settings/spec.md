# Settings

## Overview
A settings sheet (the "Settings" button in the screensaver picker) exposes
every configurable option. Values persist in the saver's own NSUserDefaults
domain and are applied live: Speed/Size rescale the running scene without a
visual jump; Toasters/Characters/Specials rebuild it.

## Options
| Option             | Type   | Range   | Default | Key |
|--------------------|--------|---------|---------|-----|
| Toasters           | int    | 1-48    | 16      | numberOfToasters |
| Speed              | double | 0.25-3.0| 1.0     | speed |
| Size               | double | 0.5-2.0 | 1.0     | size |
| Bounce             | double | 0-2.0   | 1.0     | bounce |
| Flap               | double | 0-2.0   | 1.0     | flap |
| Wind               | double | 0-2.0   | 1.0     | wind |
| Special maneuvers  | bool   | on/off  | on      | specials |
| Characters         | 32 tog | -       | all on  | enabledCharacters |

## Requirements
- R1. The settings sheet MUST expose all eight options above with live value
  labels and persist each to the saver's NSUserDefaults domain (the bundle
  identifier).
- R2. Bounce/Flap/Wind MUST treat a missing key as 1.0 (a missing key is told
  apart from a legitimate 0.0), so a fresh install gets the defaults rather
  than 0.0 (no motion).
- R3. Changing Speed or Size MUST rescale the running scene proportionally
  (no visual jump); changing Toasters/Characters/Specials MUST rebuild it.
- R4. The 32 character toggle buttons MUST show sprite thumbnails and persist
  the enabled set; respawns only use enabled characters.
