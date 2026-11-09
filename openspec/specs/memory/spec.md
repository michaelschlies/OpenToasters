# Memory

## Overview
The original 2012 saver had a large memory leak (per-frame object
allocation). This rebuild targets zero per-frame allocations: fixed-size C
struct pools, sprites decoded exactly once per session and freed when the
saver stops. Measured: 12 MB after load, 14 MB after 12 s (flat).

## Requirements
- R1. The frame loop MUST allocate no objects: fixed-size pools (`Toaster` x
  96, `drawOrder` x 96) plus prebuilt sprite bitmaps and sky gradients;
  per-frame work is pure math + `CGContextDrawImage`.
- R2. Sprite bitmaps MUST be decoded exactly once per session
  (`kCGImageSourceShouldCacheImmediately`) and released when the saver stops,
  returning the ~10 MB to baseline between runs.
- R3. Draw order MUST be sorted in place (insertion sort on the `drawOrder`
  index array) with no per-frame allocation.
- R4. A 2.5 s watchdog MUST start a 60 Hz fallback timer if the engine has not
  driven `animateOneFrame`, so the saver animates regardless of engine version.
