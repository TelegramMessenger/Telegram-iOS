# GradientBackground — agent notes

This module builds with `copts = ["-O"]` in every configuration, which is why `composeSoftLightOverBackground` lives here (root `CLAUDE.md`, "Per-module `-O` and pixel loops").

## Reimplementing a CoreGraphics operation

- **CoreGraphics' `.softLight` is not the PDF/CSS soft light.** It omits the `D(Cb)` highlight branch, so it is linear
  in the source with no kink at 0.5; a spec-faithful reimplementation is visibly wrong. `±1/255` against CG is the
  floor (CG's internal fixed-point rounding): float, double, integer and two-step formulations all cap there.
- **`vImageScale_ARGB8888` is not CoreGraphics' resampler.** It is ~5.5x faster for the wallpaper's 36x80 → full-screen
  stretch but moves the composed result by up to 5/255, so that stretch stays on `CGContext.draw`.
- **The wallpaper pattern is transparent.** `WallpaperResources.swift` builds it with `DrawingContext(..., clear: true)`
  and no `opaque:`, over a `.clear` background, so its alpha decides which pixels blend at all. Compositing it into an
  opaque buffer silently discards that and leaves untouched regions reading uninitialised memory. A fixture validating
  the compose must use a transparent, premultiplied, **two-colour** pattern: the symbol image is tinted white while
  `customPatternColor` may be black, so "the pattern is monochrome" is false.
