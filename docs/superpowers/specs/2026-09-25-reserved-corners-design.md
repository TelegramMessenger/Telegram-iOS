# Reserved corners in `ContainerViewLayout` (iPhone Duo)

Date: 2026-09-25. Status: design approved in conversation, spec awaiting review.

## Goal

`ContainerViewLayout.safeInsets` currently carries everything the system reserves on a screen
edge. On iPhone Duo (iPhone19,4, iOS 27.1) most of that reservation is not an edge at all but a
**block in one corner**: the system status corner (clock + connectivity). UIKit widens that block
to a full-edge `safeAreaInsets` inset, so the whole right edge of the unfolded landscape screen is
inset by 84pt although only its top 120pt are occupied. In unfolded portrait the opposite happens:
the block sits in the bottom-right corner and `safeAreaInsets` does not cover it at all.

Split the reservation into two facts:

- `safeInsets` — what is reserved along a whole edge (home indicator, status bar strip).
- `reservedCorners` — the size of the reserved block in each of the four corners.

and carry the fold (`division`) as a third, separate fact.

Success: on iPhone Duo, content that runs along an edge is no longer inset along the full edge for
a corner block, and every layout derived from the window (including split panes) carries the
corners that actually overlap it. On every other device nothing changes.

## Measured facts this design rests on

All measured on the iPhone Duo simulator, iOS 27.1, with a throwaway probe app. Values in points.

| State | Window | `safeAreaInsets` | Active `.occlusion` rect | `.division` |
|---|---|---|---|---|
| Closed, portrait | 466x678 | t0 l0 b34 **r84** | (382,0) 84x170 + 37x37 camera inside it | none |
| Closed, landscape-left | 678x466 | t0 l0 b34 **r84** | (594,384) 84x82 + 37x37 camera | none |
| Closed, landscape-right | 678x466 | t0 **l84** b34 r0 | (0,0) 82x84 + 37x37 camera | none |
| Open, landscape (both) | 951x669 | t0 l0 b34 **r84** | (867,0) 84x120 | (455.5,0) 40x669, inactive when flat |
| Open, portrait | 669x951 | **t82** l0 b34 r0 | (587,817) 82x134 | (0,455.5) 669x40, inactive when flat |
| Open, ~128° | 951x669 | t0 l0 b34 r84 | (867,0) 84x120 | **active** |

- `UIView.reservedRegions(kind:options:)` (iOS 27.1) reports rects in the receiving view's own
  coordinates; a view that does not overlap a region gets nothing for it.
- The active occlusion block is the system status corner, confirmed by screenshot, not the camera.
  The inner-screen camera is an **inactive** occlusion (58x37) that rotates with the device; this
  design ignores inactive regions.
- Occlusion `margins` were always zero. Division `margins` are 20/20, so the reserved area is a
  zero-width line on the screen's midline and `frame` is that line plus the margins.
- Every region change arrived through a `layoutSubviews` pass. It did **not** always coincide
  with a safe-area change (the corner block briefly became 134x82 mid-unfold with no inset change),
  so `viewSafeAreaInsetsDidChange` alone is not a sufficient trigger.
- Programmatic orientation changes are refused while unfolded; the cover screen has no
  upside-down orientation.

## Design

### 1. Types (Display)

```swift
public struct ContainerViewLayoutCorners: Equatable {
    public var topLeft: CGSize
    public var topRight: CGSize
    public var bottomLeft: CGSize
    public var bottomRight: CGSize
    public static let zero: ContainerViewLayoutCorners
}
```

`ContainerViewLayout` gains:

```swift
public var reservedCorners: ContainerViewLayoutCorners
/// The fold, in this layout's coordinates, while the system reports it active. Nil when there is
/// no fold, when it is inactive, or when it does not cross this layout.
public var division: CGRect?
```

`division` is the reported frame **including** its margins, as the API reports it; consumers that
want the bare line use its midline.

Both are **required initializer parameters, with no default value.** There are 42
`ContainerViewLayout(size:…)` construction sites; most derive a child layout from a parent by
copying fields one by one. A default would compile at all 42 and silently drop the corners in
every derived layout. Requiring the parameters makes the compiler list every site, and each one
makes an explicit choice (see 4). The `withUpdated…` helpers forward both fields.

### 2. Reading the regions (Display, window layer)

`WindowHostView` gains a fileprivate accessor returning the active occlusion rects and the active
division rect of `eventView`, via `reservedRegions(kind:)` behind `#available(iOS 27.1, *)`. It
returns empty on earlier systems.

`WindowLayout` gains `reservedCorners` and `division`, updated wherever `safeInsets` is updated:
`updateSize`, `updateSystemInsets`, and the initial layout.

Because region changes are not always accompanied by a safe-area change, the window's
`layoutSubviewsEvent` also runs the multi-display system-insets update. That update compares the
freshly read values with the current `WindowLayout` and does nothing when they are equal, so the
extra trigger costs one region query per window layout pass on iPhone Duo only.

All of this is gated on `DeviceMetrics.hasMultipleDisplays`, like the existing system-inset path.
Every other device keeps `reservedCorners = .zero`, `division = nil`, and the per-model inset table.

### 3. From regions to corners and safe insets (pure function, Display)

```swift
struct ReservedAreaResolution: Equatable {
    var safeInsets: UIEdgeInsets
    var reservedCorners: ContainerViewLayoutCorners
}

func resolveReservedArea(size: CGSize, systemSafeInsets: UIEdgeInsets, occlusions: [CGRect]) -> ReservedAreaResolution
```

`systemSafeInsets` is the system's `safeAreaInsets` with the bottom excluded (it is carried as the
on-screen navigation height), i.e. what `windowSafeInsets` returns today.

Rules:

1. **Corner assignment.** An active occlusion rect belongs to a corner when it touches both of that
   corner's edges (within 0.5pt). The corner's size is the rect's extent measured from the corner:
   for the top-right corner, `width = size.width - rect.minX` and `height = rect.maxY`, and
   likewise for the others. Several rects in one corner combine to the largest extent on each axis
   (the closed-state camera circle sits inside the status block and adds nothing). A rect that
   touches fewer than two edges is ignored.
2. **Edge inset moved into a corner.** For each of the top, left and right edges: if the edge has a
   nonzero system inset and exactly one corner block on it, and that block does not span the whole
   edge, the inset is moved into the corner. The edge's safe inset becomes 0 and the corner's
   extent perpendicular to that edge becomes `max(block extent, inset)`, so no reserved space is
   ever lost.
3. Otherwise the system inset is kept unchanged. This covers an edge with no corner block, and an
   edge with blocks in both of its corners (the reservation is then genuinely edge-wide).

Applied to the measurements:

- Open landscape: `r84` and the 84x120 top-right block, which spans 120 of 669 → `r = 0`,
  `topRight = 84x120`.
- Closed landscape-right: `l84` and the 82x84 top-left block → `l = 0`, `topLeft = 84x84`. (The
  block is 2pt narrower than the inset; rule 2's `max` keeps the full 84.)
- Closed portrait: `r84` and the 84x170 block → `r = 0`, `topRight = 84x170`.
- Open portrait: the 82x134 block is in the bottom-right corner; the right edge has no inset and
  the bottom is excluded → safe insets unchanged, `bottomRight = 82x134`. The `t82` has no top
  corner block, so rule 3 keeps it. What occupies it is not identified by the measurements; keeping
  the system value is the conservative choice, revisited when step 3 of the rollout reaches the top
  of the screen.

Rule 2 turns a full-edge inset into a corner block, so a pane can now extend into space the system
used to keep it out of along that edge. The corner size always goes with it: a consumer that sits
in that corner reads `reservedCorners`.

### 4. Derived layouts

Each of the 42 construction sites is one of:

- **Same frame as the parent** (most sites): forward `reservedCorners` and `division` unchanged.
- **Split panes** (`NavigationSplitContainer`): extends the rule `c52abe84fe` applied to safe
  insets. The master pane gets the parent's `topLeft`/`bottomLeft` and zero on the right; the
  detail pane the reverse. `division` is translated into each pane's coordinates and dropped for a
  pane it does not cross.
- **Not at the screen corners** (form sheets, inset modals, popovers, context previews):
  `.zero` and `nil`, the same way these sites already pass reduced or zero safe insets.

A site whose category is unclear gets the conservative choice for its safe insets' treatment:
whatever it does to `safeInsets` (forward, zero, or split), it does the same to the corners.

### 5. Rollout

1. **Plumbing, no behavior change.** Types, window reading, derived layouts. `safeInsets` still
   uses the system value on iPhone Duo (`resolveReservedArea` computes the corners only). Nothing
   reads the new fields. Verified by building, and by the unit tests below.
2. **Corner-free safe insets on iPhone Duo.** `windowSafeInsets` uses `resolveReservedArea`'s
   `safeInsets`. Visible change: full-edge insets caused by the status corner disappear.
3. **Adopt corners where content sits in a corner**, one surface per change, each verified on the
   Duo simulator: the chat navigation bar (avatar in the top-right), the chat list header buttons
   and scroll indicator, the chat input panel (unfolded portrait puts an 82x134 block over the
   send/mic button, and today nothing avoids it), and the tab bar.

This spec covers steps 1 and 2. Step 3's surfaces each get their own short design.

## Testing

- **Unit tests** for `resolveReservedArea`, in a new `//submodules/Display:DisplayTests`
  `ios_unit_test` (pinned runner as in `TextFormatTests`, run via `Make.py test --target`). One
  case per row of the measurement table, plus: no occlusions, a rect touching one edge only, two
  rects in one corner, a block that spans a whole edge (inset kept), blocks in both corners of one
  edge (inset kept), a block narrower than the inset (corner takes the inset).
- **Split-pane corner assignment** as a pure helper next to `resolveReservedArea`, tested the same way.
- **Step 1 verification**: full `Make.py build`; then on the Duo simulator a log line of the
  window's `reservedCorners`/`division` per layout, checked against the table in both fold states
  and all three orientations. The user drives folding and rotation (the Simulator frontend is the
  only way; see Measured facts).
- **Step 2 verification**: screenshots of chat list + chat in the split layout, unfolded landscape
  and portrait, compared with the current build. Non-Duo devices: build only, since the path is
  gated off.

## Out of scope

- Consuming `division` in any layout (the split line does not currently follow the fold).
- Inactive occlusion regions (the inner camera).
- `UIView.LayoutRegion` corner adaptation for rounded screen corners; the existing per-component
  corner handling is unchanged.
- Any device other than iPhone Duo.
