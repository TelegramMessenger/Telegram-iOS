# MessageWidgetRendering provenance

A widget's pixels on `WidgetRuntime` (the native runtime, `docs/message-widgets-native-runtime.md`). Written here
on 2026-10-19 (M1d plan, Task 8); this copy is ours, edit it here. It depends only on
`//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS`.

## Sources

- `Sources/WidgetTreeRenderer.swift`: `WidgetTreeRenderer`, called only inside the widget's tasks, as the session is.
  - It keeps the last `WRTree` its session published, which outlives the session and paints on any thread.
  - Its size, `documentSize`, is the width laid out at (not the content's natural width) and the content's height
    rounded up and clamped to `minimumHeight`...`maximumHeight` (50...600, the spec's bounds: widget-sandbox integration.md, "Bubble sizing"),
    or to a bubble's fixed height under 600 (`init(width:maximumHeight:)`, `setMaximumHeight` after an edit).
  - `generation` moves on every publish, freeze and frozen width change, and a bounded history of each generation's
    changed rects (64 entries; nil is everything) answers `changedRects(since:)` for the tile drawer.
  - `image(rect:scale:)` paints a rect of the tree through `WRTree` (`LayerTreePainter`): at most 16 Mpx here, and
    at most 4096 px a side in the painter.
  - `freeze(label:)` stops taking trees and draws the stopped badge over the bottom left in CoreGraphics (the widget
    bubble's date pill sits at the bottom right). Its look
    is the old renderer's frozen chrome (`frozenStyle`, `font: 11px/1.3 -apple-system`, white on rgba(60,60,60,.75),
    padding 2 x 7 px, radius 9 px, 6 px from the edges), drawn rather than built into the document. A frozen
    renderer keeps its height and clips its last tree to a new width rather than reflowing it.

The tile drawer that calls it, `WidgetTileDrawer`, is in `../MessageWidget/Sources/WidgetFrame.swift`.

## Removed 2026-10-19 (M1d, `a85f21a602`)

The ops-fed renderer this module held from 2026-10-13: `MessageWidgetRenderer.swift` (written from twidget's
`LiteHTMLWidgetRenderer.swift` and the branch's earlier core), `CSSFont.swift`, its `RendererTests`, and the
compiled-in `WidgetDOM.swift` and `WidgetSandboxProtocol` from `third-party/twidget`, with the `MessageWidgetDocument`
guard module beside it. `git show a85f21a602^:<path>` has them.

## Tests

The module has no test target of its own. In
`//submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests`, `SnapshotTests` drives it over a
`WRSession` with the tile drawer, and the frozen checks read its badge (`frozenLabel`) through the core;
`//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS:WidgetRuntimeIOSTests` covers the painter it draws
with.
