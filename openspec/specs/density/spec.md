# Density

## Overview
The number of toasters scales linearly with screen area so a 4K display gets
proportionally more than 1080p (the same toasters per square inch). The
"Toasters" setting (1-48) is the reference count at 1080p.

## Parameters
| Parameter       | Value | Meaning |
|-----------------|-------|---------|
| settingCount    | 1-48 (default 16) | reference count at 1080p |
| area scale k    | area / (1920 x 1080) | linear area density |
| pool cap        | MAX_TOASTERS = 96 | hard cap |

## Requirements
- R1. The effective count MUST be `round(settingCount x area / (1920 x 1080))`,
  clamped to [1, 96].
- R2. The pool MUST be a fixed-size array (MAX_TOASTERS = 96) — no
  per-frame allocation regardless of the count.
- R3. The "Toasters" setting MUST be an integer 1-48 (default 16).
