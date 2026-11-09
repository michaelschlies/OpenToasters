# Flapping & spin

## Overview
Toasters animate their sprite frames. 12-frame characters loop a gentle
wingbeat; long-loop characters (20+ frames) are "spinners" whose animation
IS the rotation. The Flap option scales the animation rate (0 = glide with
no flapping).

## Character classes
| Class    | Frame count | Animation               |
|----------|-------------|-------------------------|
| normal   | 12 (or 2-19) | wingbeat, 6-9 fps x Flap |
| spinner  | >= 20       | rotation, 8-14 fps x Flap |
| surprise | 1           | static (frameRate 1.0)  |

## Requirements
- R1. The frame rate MUST be: 1.0 fps for 1-frame (surprise) characters;
  uni(8, 14) fps x Flap for spinners (20+ frames); uni(6, 9) fps x Flap for
  normal characters.
- R2. The Flap option (0-2.0, default 1.0) MUST scale the frame rate; 0
  produces a static glide with no flapping.
- R3. Spinner characters (frameCount >= 20) MUST rotate continuously
  (`angle += spin x dt` with spin uni(0.8, 2.4) rad/s, random sign) — their
  animation is the spin, independent of the Flap setting.
- R4. Normal wingbeats MUST run at ~0.5-0.75 beats/s (softer than the
  original's up to 1.3) so flapping reads as gentle against the bob.
