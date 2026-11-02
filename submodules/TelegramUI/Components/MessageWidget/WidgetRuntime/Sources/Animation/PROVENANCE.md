# Provenance: the animation code

Ported from twidget (`~/build/twidget`, this project's own earlier renderer) at `e10b2f5`
(2026-10-19), as the native-runtime spec's §7 asks ("Vendor twidget's portable
`Sources/TwidgetCore/src/animations.{h,cpp}`"). It is owned here from the port on (V5e plan, Task 1): edit it in place.
Nothing is re-synced from twidget.

| Here | twidget |
|---|---|
| `CSSText.{h,cpp}` | `Sources/TwidgetCore/src/css.{h,cpp}`: `trim`, `lower`, `iequals`, `number`, `split_top_level`, `normalize_colors` (with `parse_hex`, `components`, `rgba_string`), `format_number` |
| `Easing.{h,cpp}` | `Sources/TwidgetCore/src/animations.{h,cpp}`: `Timing` (`css`, `web`, `parse_uncached`), `bezier_at`, `linear_function` |
| `Interpolation.{h,cpp}` | `animations.cpp`: `tokenize`, `functions`, `arguments`, `primitive`, `identity`, `padded`, `translation_list`, `scaled_tokens`, `pair_tokens`, `interpolate`, `web_tokenize`, `web_render`, `opened_function`, `web_combine`, `web_add`, `web_scaled`, `web_value` |
| `CSSAnimationRules.{h,cpp}` (V5f) | `animations.cpp`: `parse_keyframes`, `AnimationSpec::list`, `TransitionSpec::list`; `css.cpp`: `parse_declarations`, `is_property_name`, `parse_time` |

Not ported: `WebAnimation` and its JSON (`parse`, `apply_web`, `css_animations`; the WAAPI objects here are native, so
no records cross a boundary), the `Animator` (V5f's CSS animations and transitions are `Animation`s whose effects carry
the CSS timing, driven by the style-change step) and the compositor plans. V5f took the keyframes parser and the two
list parsers.

## Changes from twidget

1. **Names follow this repo** (camelCase: `trimmed`, `splitTopLevel`, `normalizeColors`, `formatNumber`, `Easing`,
   `effectValue`, …) and live in `wr::animation`.
2. **No JSON and no records.** `web_value` took a `WebAnimation` record; `effectValue` takes the frames that set one
   property (`PropertyFrame`) and the effect's composite and iteration composite, so the caller decides what a frame
   is. With no frames it returns the underlying value (twidget returned nothing).
3. **The easing grammar is the reference's** (widget-sandbox v0.1.0's `parseEasing`), stricter than `Timing::parse`:
   `cubic-bezier()` takes four plain numbers (no units, no `calc()`) with `x1`, `x2` in [0, 1]; `steps()` an integer
   1..100,000, and `jump-none` needs at least 2; `linear()` 2..256 items, inputs only as percentages; no nested
   parentheses; at most 4,096 characters. Twidget's text field became `canonical`, the reference's canonical form
   (`steps(1, start)` for `step-start`, `steps(n)` for an end position, `cubic-bezier(a, b, c, d)` and `linear(o p%, …)`
   with numbers as JavaScript's `String(number)`), made at parse time.
4. **An `Easing` lives in the JS heap** (`std::allocate_shared` with `JSAllocator`, its points a `Vector`), because a
   widget can make 10,000 keyframes each with its own `linear()`. Twidget's per-thread parse cache (256 entries) is
   gone: an easing is parsed once per keyframe or effect and shared.
5. **`pair_tokens`' per-thread cache is gone** (2,048 entries of up to 4,096-byte keys, on the system heap and shared
   by every widget on the thread): each call tokenizes its pair afresh.
6. **Colours:** `#hex` and `rgb()`/`rgba()` are normalised exactly as twidget did (their components stay exact, so
   `rgb(0 0 0 / 50%)` keeps alpha 0.5). Named colours and `hsl()`/`hsla()` go through litehtml's colour parser
   (`litehtml::parse_color`, componentized as litehtml's own style values are: its full named table, where twidget had
   its own, and `hsl()`, which twidget did not normalise at all), with alpha as litehtml's byte. `currentcolor` and the
   colour functions litehtml does not parse (`hwb()`, `lab()`, …) stay as written. A colour function with a nested
   parenthesis is left as text.

## Changes in the V5f port (`CSSAnimationRules`)

1. **Keyframes are JS-heap data** (`CSSKeyframe`, `Vector`, `SharedText`) under V5e's caps (10,000 keyframes per rule,
   512 properties per keyframe, 4,096-byte values; past them a keyframe or value is dropped). A keyframe's
   `animation-timing-function` is kept as its own easing; one without it takes the animation's when the animation is
   made, which twidget decided while sampling.
2. **A keyframe selector outside 0%…100% is dropped** (CSS Animations 1 §3); twidget kept it.
3. **Lists stop at 64 entries** (`kMaxCSSListEntries`).
4. **`parseTimeMs` returns milliseconds** and takes no `calc()` (twidget's `TimeScanner` is not ported).
5. **A transition's combined duration decides** (`max(duration, 0) + delay > 0`, CSS Transitions 1): `opacity 0s 1s` is a
   transition; twidget dropped every entry whose duration was not positive.
