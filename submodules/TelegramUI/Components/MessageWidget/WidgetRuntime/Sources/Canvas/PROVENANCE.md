# Canvas 2D: where this code came from

`CanvasOps.h` and `CanvasInterpreter.{h,cpp}` are a port of twidget's portable canvas interpreter, this project's own
earlier renderer (`~/build/twidget`, commit `e10b2f5`, "Draw rounded borders whose sides differ as per-side rings"):

- `Sources/TwidgetCore/src/canvas_ops.h` → `CanvasOps.h`;
- `Sources/TwidgetCore/src/canvas.h` and `canvas.cpp` → `CanvasInterpreter.h` and `CanvasInterpreter.cpp`;
- `Sources/TwidgetCore/src/display_list.h`'s `Color`, `Stop` and `Path::Op` → `CanvasOps.h`'s `Color`, `Stop` and
  `PathVerb`.

It is owned here from the port on (V5d plan, Task 1): edit it in place. Nothing re-syncs it from twidget.

## How it differs from twidget

1. **No JSON.** twidget ran widget-sandbox's `canvas` command lists (`Canvas::run(const Json&)`) and answered
   `canvasCall` queries as JSON (`Canvas::call`). Here the bindings call one typed method per canvas call, and the
   queries return C++ values. `Value`, `Value::of`, the method and property name tables and `base64` are gone.
2. **Gradients and paths are objects the caller holds.** twidget kept gradients and `Path2D`s in id maps capped at
   4,096 (`MAX_OBJECTS`, the oldest evicted). Here a `CanvasGradient` or `Path2D` owns a `GradientData` or `PathData`
   and the state holds a `shared_ptr` to the gradient, so stops added after `fillStyle = g` reach later draws, as in
   browsers, and an object lives as long as the script keeps it. The maps and the cap are gone.
3. **Path building is free functions** (`namespace path`) over a `PathData` and a transform, shared by the current
   path and `Path2D`, rather than `Canvas::path_method` dispatching on a method name.
4. **HTML's argument rules.** twidget read a non-finite number as 0; here a non-finite argument makes a call do
   nothing (HTML's "if any of the arguments are infinite or NaN, then return"), `isPointInPath`/`isPointInStroke` on
   a non-finite point answer false, a `maxWidth` that is NaN or not positive draws no text, `fillRect`/`clearRect`
   with a zero side and `strokeRect` with two do nothing, and ASCII whitespace in text becomes spaces.
5. **`drawImage` clips its source rect** to the source and moves the destination with it, as HTML says (twidget left
   that to the backend), and flips negative sizes.
6. **`roundRect` takes four corners**, each with its own x and y radius, scaled down together when they overlap and
   swapped when the width or height is negative (HTML); twidget used the first radius for every corner.
7. **`arcTo` adds no zero-length line.** twidget lined to the first tangent point and then started the arc there with
   a second line; the arc's own line is enough.
8. **Caps.** A path holds at most `path::kMaxPathPoints` (1,000,000) points: a segment that would pass it is dropped
   whole (twidget had no cap). Saves past `kMaxStack` (512) are counted rather than dropped, so restores stay
   balanced (twidget ignored them, and a later restore popped an earlier state).
9. **Left out, because profile 1 never draws them:** `globalCompositeOperation`, shadows, `putImageData` and its
   `PutImage` op. A conic gradient or a pattern is `GradientData::Kind::None`, which paints nothing (as the reference
   validator makes either a zero-length linear gradient).
10. **The host** is `CanvasHost` with fonts as `HostFont` and images as `HostImage`; colours are parsed by the
    bindings (twidget's interpreter parsed them with its own `css::parse_color`); SVG path numbers go through
    `strtod` instead of `css::number`. Fonts come with their ascent and descent, which place a `Text` op's baseline.
11. `CanvasOp`'s `Text` keeps twidget's convention: the alignment offset `textDx` is applied before the horizontal
    `scaleX` a `maxWidth` gives.
12. **What a context keeps is in the JS heap** (V5d final review, C2 and C3; fix-wave review, I-C). Paths
    (`RetainedGeometry`), gradient stops, the state stack and a state's font and dash allocate through `JSAllocator`,
    so the widget's memory limit bounds them; the font and dash are immutable values a save copies by pointer. A clip
    is one link of a `ClipNode` chain that each saved state shares, at most `kMaxClipDepth` (64) deep, a clip past it
    ignored. twidget kept all of these in std containers and copied every clip path into every saved state. An op's
    geometry stays a std container: it is dropped within the call.
13. **Dashes are counted** (fix-wave review, C-B; wave-2 review, C-1). A dashed stroke's dashes and gaps
    (`dashSegments`) are counted where `CanvasBitmap` dashes: the device path through the inverse
    of the op's float matrix (none when that matrix is singular to it), per subpath, since the pattern restarts at
    each. Past `kMaxDashSegments` (100,000), or when a length is not finite, the stroke is drawn solid
    (`dashDropped`). twidget passed the pattern through whatever it made.
