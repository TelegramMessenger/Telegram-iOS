# Object Studio: six projected 3D widgets

These self-contained profile-1 widgets use canvas 2D to project, shade and depth-sort
small 3D scenes. The planet uses perspective ray/sphere intersections and
normal-based lighting, presented through supported canvas fillRect color runs. They use no WebGL, CSS 3D transforms, bundled library, image asset,
network access or experimental native side channel. The models and planet surface are procedural illustrations; the molecules are
educational shapes.

| File | Model control |
|---|---|
| `01-robot.html` | Cycle ready, wave and resting poses |
| `02-camera.html` | Assemble or separate the lens elements |
| `03-orbits.html` | Orbit a single smoothly shaded planet and toggle cloud cover |
| `04-island.html` | Cycle low, rising and high tide |
| `05-molecules.html` | Cycle water, methane and ammonia |
| `06-cat.html` | Mouse X/Y rotation of a sculpted cat with a raised-tail pose |

All six support horizontal drag to orbit, elevation buttons, bounded zoom and reset.
Vertical touch drags belong to the chat; pointer cancellation rolls back the tentative
orbit without saving it. A second pointer cannot replace an active drag. The view
and model selection are saved only on completed interactions in per-message
`localStorage`, with corrupt or unavailable storage tolerated. Reset restores the
initial model, angle and zoom and saves that state.

Drawing happens on load, resize, a theme change or an interaction. The robot,
camera, island and molecules coalesce redraws to one animation frame. The color
scheme is cached and updated by media-query change events, so redraws do not query the host for it. There is no idle timer,
animation loop or layout read per frame.
Mesh canvas backing resolution follows the box and device pixel ratio, capped
at 2x. The cat coalesces active redraws with a 200 ms timer; its full mouse-controlled
vertical angle survives recreation. The planet has a fixed 128×128 backing,
throttles active redraws to 250 ms, and uses no pixel read-back/image-data APIs.
Both chat themes and widths 200–600 px are supported; the 200 px layout uses a
shorter viewport. Controls keep a 20 px inset from the leading edge.

## Run the checks

From the widget-sandbox root:

```sh
corepack pnpm exec tsx --test packages/core/tests/unit/showcase-3d.test.ts
corepack pnpm test:showcase --grep '3d/'
TW_RENDERER=shadow corepack pnpm test:showcase --grep '3d/'
corepack pnpm dev
```

The dev picker discovers `showcase/3d/*.html` automatically. For example, open
`http://127.0.0.1:5173/?file=showcase/3d/01-robot.html`. Existing native demo corpus
sync commands discover the folder too; these additions do not require rebuilding
the shared runtime bundles or bytecode.

In telegram-macos, the companion patch mirrors these six files under the
HTMLBubbles test fixtures. The existing recursive demo catalog discovers them
when the test fixture catalog is installed; production app code is unchanged.

## Manual client check

At narrow and wide chat widths, inspect the model in light and dark themes. Orbit
horizontally and scroll vertically over it, cancel a drag, use every control, then
scroll away and back and restart the app. The chosen view/model should persist;
reset should survive recreation. Compare the same packed payload on each client
before shipping. No native-client visual validation is claimed by this patch.
