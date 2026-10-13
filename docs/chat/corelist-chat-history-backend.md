# CoreList chat-history backend

`CoreListChatHistoryBackend` (`submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift`) is an
alternative chat-history list backend built on the vendored `CoreList` module's `CoreVirtualListView`
(a from-scratch UIKit virtualized list — see `submodules/TelegramUI/Components/CoreList/CLAUDE.md`).

## Selection

Chosen in `ChatHistoryListNodeImpl.init` and applied by
`makeListView(rotated:useCoreListBackend:)` (`submodules/TelegramUI/Sources/ChatHistoryListNode.swift`),
in this order:

1. **`rotated` is the default.** CoreList backs the rotated history — the bottom-up chat proper, the
   only surface it has been built and verified against. `rotated` defaults to `false` on that
   initializer, so every list that does not name it (the overlay audio player's playlist, the
   shared-context message list, an embedded chat preview) stays on `ListViewImpl` without saying so.
2. **`coreListChatBackend`** (Debug Settings) keeps its original meaning — force CoreList on — which
   after the default flip is only reachable for those non-rotated lists.
3. **`ios_killswitch_disable_corelist_chat_backend`** (server app config) forces `ListViewImpl`. It
   outranks the debug switch deliberately: setting it must guarantee no CoreList in the field, and a
   device-local opt-out for the switch already exists (turn it off).

The chosen backend is published as `ChatHistoryListNodeImpl.usesCoreListBackend`. **Chat-layer code
that is deliberately CoreList-only must read that**, not re-derive the policy — one site already
drifted when the default moved and the Debug Settings switch stopped being the whole answer.

See the "ChatHistoryListNode composition" section of the root `CLAUDE.md` for the backend seam
(`ChatHistoryListViewBackend`) this conforms to.

## Scope

The backend targets **display / scroll / load-more only**. Every `ChatHistoryListViewBackend` member
outside that scope is a **safe stub** — no-op closure or plain stored property — that must never
crash. Real geometry/range values are populated only for the members the display path needs
(`displayedItemRange`, `visibleContentOffset`, `contentHeight`) plus the item-node enumerators
(`forEachItemNode` / `forEachVisibleItemNode` / `enumerateItemNodes` — see below) and
`didInteractivelyDragFromTopOrigin`, which is outside that scope but was implemented because its stub
silently disabled a user-visible behavior (see "Interactive drag start"). `ListViewScrollToItem` is
supported in full, and `ensureItemNodeVisible` with it (see "Scroll to item"). Floating date headers
and gutter avatars are implemented on top of CoreList's attachment feature (see "Floating headers and
avatars"), which makes `forEachItemHeaderNode` real.

## Architecture

- **Composition, not inheritance.** It is an `ASDisplayNode` that hosts a single
  `CoreVirtualListView` (`self.coreList`) as a subview and conforms to `ChatHistoryListViewBackend`.
- **Rotation invariant (load-bearing).** The chat wrapper (`ChatHistoryListNodeImpl`) applies the
  chat's π rotation to *itself*, and each item node (`ChatMessageItemView.init(rotated:)`) applies its
  own π; those compose to upright content in a bottom-anchored inverted list. **The hosted
  `CoreVirtualListView` must stay at IDENTITY** — a third rotation here renders the whole chat
  180°-rotated. So CoreList lays out index 0 at its own *top*, and the wrapper's π flips it to appear
  at the screen *bottom* (index 0 = newest). `rotated` is stored only to satisfy the `makeListView`
  contract; it applies no transform. `layout()` sizes the child via `bounds` + `center` (not `frame`)
  so it stays transform-safe.
- **Entry array is the source of truth.** `private var entries: [CoreListEntryItem]` mirrors the
  ListView transaction model (delete/insert/update over indices). `CoreListEntryItem` is a
  `final class` conforming to `CoreListItem`, keyed on the message **`stableId`** as `identity`
  (matching the diff indices produced by `mergeListsStableWithUpdates`); a monotonic `stableVersion`
  is its content-equality discriminator, so a same-stableId entry whose content was swapped
  reconfigures its reused view.
- **Eager view load.** `let _ = self.view` in `init` forces the node's view to load, because the
  composed wrapper gates its history dequeue on `isNodeLoaded` (mirroring `ListViewImpl`).

## Transaction flow

`chatHistoryTransaction(...)` applies a ListView-style batch to `entries` in ListView's own order
(**deletes first** — descending index so earlier removals don't shift later ones — **then inserts**
in ascending index order, **then updates**), maps size/insets, then re-renders the full settled set
via `CoreVirtualListView.applyChanges`:

- `items:` — the rebuilt `entries` on a structural change **or a horizontal-inset change**, else `nil`.
- `newSize:` / `newInsets:` — the current size and the **vertical** insets (an unchanged inset is an
  exact no-op in CoreList, so passing it on every pass is safe and correctly propagates
  `setTopContentInset` deltas). Horizontal insets are deliberately *not* passed — see below.
- `scrollTo:` — a `CoreListScrollTarget` mapped from `ListViewScrollToItem` (see "Scroll to item").
- `additionalScrollDistance:` — passed straight through. Both backends fold it into the same addend as
  the inset compensation, so a pass can re-inset and scroll by a caller-chosen delta as one movement;
  positive moves content down. **The chat never sends a non-zero value** —
  `ChatControllerNode.containerLayoutUpdated` declares `let additionalScrollDistance: CGFloat = 0.0`
  (`ChatControllerNode.swift:2451`) and has since the repo's first commit, and
  `ChatHistoryListNodeImpl.updateLayout` zeroes it again whenever the live sibling `scrollToTop` is set.
  It is implemented so the two backends answer a non-zero value the same way if one is ever wired up,
  not because anything depends on it today. Two divergences from `ListViewImpl`, both unreachable from
  that producer: ListViewImpl drops the value entirely unless the pass also changed size/insets (the
  addend sits inside `if let updateSizeAndInsets`, `ListView.swift:3257`), and its momentum halt does not
  need the pass to run.
- `anchorMode:` — `.preserveVisibleContent` when `stationaryItemRange != nil`, else `.automatic`.
- `transition:` — derived once and reused as both the applied animation and the reported transition, in
  ListViewImpl's own precedence: an animated `scrollToItem` (its own `.curve`, mapped case-for-case),
  then a size/inset update's curve, then `.AnimateInsertion` (`.spring(0.4)`), else `.immediate`.

`applyChanges` fires when *any* of structural / size / scroll / displacement changed.

### Horizontal insets go to the item, not the viewport

A side inset (the topics sidebar) reaches the hosted node as
`ListViewItemLayoutParams.leftInset`/`rightInset` — rows are always laid out at the **full viewport
width**. `coreListInsets` therefore zeroes `.left`/`.right` before `applyChanges`, and
`CoreListEntryItem` / `CoreListHeaderAttachedItem` carry the values instead.

This is `ListViewImpl`'s arrangement, not a workaround for it: there is no `x: insets.left` anywhere in
`ListView.swift`, its rows are full width, and the inset is a layout param (`ListView.swift:2384`,
`:4098` for headers). Letting CoreList's viewport insets frame the row instead — its natural mode,
`contentWidth = width - left - right` (`CoreVirtualListView.swift:2262`) — breaks in two independent
ways:

- **Orientation.** Item nodes carry their *own* π (`ChatMessageItemView.init(rotated:)`, which flips x
  as well as y). Item π + wrapper π = identity, so an inset applied **inside** the item lands on the
  screen side the chat named; framing the row takes only the wrapper's π, so `insets.left` came out on
  the screen *right*. Measured: the sidebar's 92pt shrank the bubbles by 92pt on the right and moved
  nothing away from the left, so the sidebar overlapped the content it was making room for. Swapping
  left/right at the boundary fixes this symptom alone, and was the first attempt.
- **Animation.** Framing the row cannot animate the move, swapped or not. Subviews do not follow their
  superview's `bounds.size.width`, so the content only moves when the hosted node is re-laid out — at
  the destination width, immediately, mirrored about a centre that had itself jumped by half the inset.
  The visible result was items animating correctly while sitting 46pt (half of 92) off from the first
  frame. As a layout param it is an ordinary item relayout, animated on the pass transition.

The trigger is content equality, not a special case: `isEqual(to:)` on both the entry item and the
header attachment compares the insets, so a sidebar opening makes every row a **survivor whose content
changed** — the same path an edited message takes — and each host is reached with the pass transition.
`withSideInsets(left:right:)` re-pins the entries while preserving `stableId`/`stableVersion` so they
reconcile as survivors rather than replacements. Vertical insets need none of this: both backends let
the list place a row vertically, one π either way, which `ChatControllerNode.swift:2500` already
accounts for.

## Node hosting

`CoreListNodeHostView` (a `UIView & CoreListItemView`) hosts one `ListViewItemNode`. `update(width:)`
rebuilds when the node is missing, content is dirty, or the width changed, then stamps
`node.view.frame` to the measured height. `rebuild(width:)`:

- **Incremental reuse:** when an `itemNode` already exists, it calls `listItem.updateNode(...)` to
  update in place (the node's view stays a subview), taking the height from the returned
  `ListViewItemNodeLayout`.
- **Fresh build:** when there is no node yet, it calls `listItem.nodeConfiguredForParams(...)` and adds
  the resulting `node.view`.

### `synchronousLoads` is a property of the pass, not of the row

The fresh-build path is reached by **every row that scrolls into view**, so the `synchronousLoads`
argument it passes cannot be a constant. `ListViewImpl` reads it off the transaction's options
(`.PreferSynchronousResourceLoading` → `nodeForItem`, `Display/Source/ListView.swift:2135`) and so
applies it only to the nodes *that* transaction creates. The chat asks for it on two paths: the first
view of a chat opened without an animation (`.Initial(fadeIn: false)`,
`PreparedChatHistoryViewTransition.swift:94`) and the send animation
(`Chat/ChatControllerLoadDisplayNode.swift:929`).

`chatHistoryTransaction` therefore parks the option in
`CoreListChatHistoryBackend.prefersSynchronousResourceLoading` for the duration of the transaction
(`defer`-cleared), and both host views read it **live** at the moment they build a node —
`CoreListNodeHostView.rebuild` for rows and `CoreListHeaderHostView.update(width:)` for headers,
whose `ChatMessageAvatarHeader` forwards it into `AvatarNode.setPeer(..., synchronousLoad:)`.

A live read rather than a value seeded at `view()` time (which is what the sibling
`isFlashingOnScrolling` does): the question is *which pass is building this node*, and only the
backend can answer it. Outside a transaction — a scroll rebalance, an overscroll hold — it is false,
which is the right answer for every node those passes create. A re-entrant transaction that CoreList
defers to its scheduler (`CoreVirtualListView.swift:964`) finds the flag already cleared and builds
asynchronously; that is the safe direction, and the one `ListViewImpl` errs in too when a transaction
queues behind another.

Both were hard-coded `true` in the PoC, which decoded every arriving bubble's images — and every
gutter avatar of every sender run — on the main thread mid-fling.

Both paths drive the item **synchronously** (`async: { f in f() }`); this is sound because
`ChatMessageItemImpl.updateNode`/`nodeConfiguredForParams` wrap work in `Queue.mainQueue().async`,
which runs inline when already on the main queue (the transaction path is main-thread). CoreList owns
the insert/move/height animations of the **row**; the pass transition is handed to the item as its own
`ListViewItemUpdateAnimation` so it can animate its **internals** (mapped through
`ComponentTransition` → `ContainedViewLayoutTransition`, with the immediate case mapped to `.None` —
`ListViewItemUpdateAnimation.isAnimated` is true for *any* `.System` regardless of duration, and
`ChatMessageBubbleItemNode` branches on it in ~20 places to run its own hard-coded animations).

### Height changes need the node's content compensated

`update(width:transition:)` frames the node at the **settled** height and never animates that write —
the engine animates the row. But the node carries its own π and anchors at its centre, so its content
reads `screenY = height - localY`: a height change displaces the content by the full delta, instantly,
while the row's height and position animate underneath it. That is a vertical snap of the whole item,
and it is what remained after the horizontal fix above (bubbles genuinely rewrap taller/shorter at a
new width, so the height change is real and unavoidable).

The host compensates with an additive `bounds.origin.y` animation on the node, decaying that
displacement to zero across the pass. Its exact form is load-bearing and is **not** a plain
`animateBoundsOriginYAdditive` — see "Item height is replaced from scratch each pass" below.
Conceptually this is `ListViewImpl`'s own compensation, taken from the one branch of it that ports:
`ListViewImpl` has two, and the display-link branch seeds `node.transitionOffset` (with an explicit
`node.rotated` formula, `ListView.swift:2515`/`:2554`/`:2581`) and relies on `updateAnimations()` to
walk it back to zero — **nothing drives that here**, so seeding it would displace the content
permanently. The CA-driven branch, taken when `customAnimationTransition` is set, instead calls
`animateOffsetAdditive(node:offset:)` with `previousApparentHeight - updatedApparentHeight`
(`ListView.swift:3035`) and needs no driver. Being additive, the model value stays the settled one and
only the presentation starts displaced, so it composes with the engine's own tracks and there is
nothing to unwind. Skipped for a fresh view, which has no previous height to travel from.

Each row is measured **once per pass** (the `buildWindow` anchor plus the two extension paths, and the
pre-build `consumedDirty` sweep which already carries the animated pass transition), so the delta
cannot be consumed by an earlier immediate call in the same pass.

**`from` is THIS property's own current presentation value**, expressed against the new target — the
residual the node's `bounds.origin.y` still carries, plus this pass's height delta. That is the same
rule the row's height track follows: a re-issue cancels the previous animation and starts the new one
from the current presentation value.

**Deriving it from the ROW's rendered height instead was tried, and is worse.** The reasoning was that
the content must match the height the row is really rendering at, so read
`hostPresentedHeight - lastHeight`. The two readings disagree by whatever drift has accumulated
between the node's compensation and the row's height track — instrumented over 149 real streaming
passes: 0.00pt with nothing in flight, growing with the residual to a median of 0.23pt and a max of
4.05pt — and that disagreement was mistaken for evidence that the height reading was the correct one.
It is not. Starting from a value the property is not currently at makes the content JUMP by the drift
at the start of every pass, a visible artifact; starting from its own presented value is
C0-continuous and lets the drift decay into the new animation. Reverted.

**Also ruled out as the cause of a reported streaming wobble**: `beginTime` phase skew between the two
animations. `CoreAnimationCompiler` stamps the height track with the pass clock (deliberately in the
past, so phase survives a rebind) while the compensation goes through `CAAnimationUtils` and starts at
commit. Measured over 87 passes that skew is a median of 4.5ms against a 150ms duration — 3% of the
curve, under 1pt of displacement. Real, but far too small to see.

**What DID matter on that path was `customAnimationTransition` being dropped** — see the deferred-items
entry. The streaming node asks for 0.15s ease-in-out and the row was running spring-over-0.4s.

Both paths also stamp `contentSize` / `insets` / `apparentHeight` on the node, as `ListViewImpl` does
on every node it lays out. This is not bookkeeping for its own sake — see "Item visibility" below for
what reads it. Note `ChatMessageItemImpl` assigns `contentSize`/`insets` itself on the
`nodeConfiguredForParams` path but **not** on `updateNode`, which is why the host must.

### Item height is replaced from scratch each pass, never amended

> **Superseded 2026-08-06.** The height compensation described below no longer exists. The node's box
> is animated directly (`ListViewItemNode.hostOwnsFrame` — see "Hosted node geometry"), and CoreList
> now resumes a changed **absolute** property — height, width, opacity — from what the layer is
> **rendering** rather than from its analytic value on the pass clock. The two differ by the pass's
> commit delay, which is what made the row and its hosted node drift by up to 3.2pt per streamed token
> and produced the wobble this compensation was invented to hide. Additive properties, row position
> included, still resume analytically and must: the pass has already overwritten the base a presented
> sample would have to be measured against, and sampling one anyway double-counted every displacement.
> See `submodules/TelegramUI/Components/CoreList/CLAUDE.md`. The section is kept
> because the reasoning about *why* a decaying displacement cannot be retargeted like an ordinary
> property is still correct, and still worth reading before adding one.

**This applies to the item's height compensation and to nothing else.** Every other animated property —
row position, opacity, x/width, the shared viewport offset, and the item's own internal animations — is
retargeted and re-timed in the ordinary way, and must be: CoreList replaces a changed property from its
analytic current value on the pass clock, and an unchanged endpoint stays an exact no-op preserving its
phase, curve, generation and deadline. Those are values with real targets that legitimately move between
passes.

Height compensation is not one of them. It is a transient displacement whose target is always exactly
zero, so there is no endpoint to re-aim: each pass introduces a fresh displacement that must be composed
with whatever the previous pass still owes and then decayed **once**, on that pass's curve and duration,
from that pass's start. So it is written as a replacement under a stable key
(`coreListHeightCompensationKey`) whose `from` is the **full remaining displacement** — the residual read
off the presentation layer, plus this pass's delta — not the delta alone. With nothing in flight the
residual is zero and the expression reduces to the historical `previousHeight - newHeight`.

Getting this wrong is silent, and it shipped. `animateBoundsOriginYAdditive` forwards no key, and
`CAAnimationUtils.animate` maps a keyless additive animation to `add(_:forKey: nil)`
(`CAAnimationUtils.swift:248`), so Core Animation assigns a fresh key and every pass **stacks** another
animation onto the ones still in flight. The stacked sum is exactly correct at the instant of the pass —
the displacement the in-flight tracks still owe, plus this pass's delta, *is* `presented - newSettled` —
so one pass looks right and no single-shot test can see it. But each copy then decays from its own start
on its own timeline, so the content follows a sum of N phase-shifted curves while the row's height track
is one curve replaced at the pass clock. Item content and its own row diverge in **shape**, only under
repeated passes, compounding with every re-issue.

Two consequences worth keeping:

- **A zero-displacement pass must remove the key, not install the animation.** Core Animation never runs
  a `from == to` animation, so it would neither move anything nor ever report stopping, while leaving the
  previous animation installed would keep displacing the content. This is the same rule CoreList states
  for its own no-op tracks.
- **The emitted begin time is irrelevant here**, which is why this is not a phase problem in disguise. An
  animation that starts from where the content presently *is* and ends at the settled value is
  self-correcting whether Core Animation begins it at the pass clock or at commit. Phase matters only for
  a track whose `from` is a remembered value rather than a sampled one.

The trap generalizes past this one call. `ListView.swift:3035` is keyless too and is **correct there**,
because it is `ListViewImpl`'s `customAnimationTransition` branch — one-shot, never twice in flight.
`ListViewImpl`'s *repeated* path does not use it at all: `addApparentHeightAnimation` /
`addTransitionOffsetAnimation` go through `setAnimationForKey`, which removes the same-key animation
first (`ListViewItemNode.swift:430-442`), and it additionally no-ops a re-issue toward an unchanged
target (`ListView.swift:3044-3051`, the deliberately-empty branch). **Before porting any `ListViewImpl`
mechanism, establish which of its two paths it came from**: this backend routes every pass through the
CA-driven one, so a mechanism that is safe there only because it fires once becomes a mechanism that
fires on every re-issue.

### The apply runs between those writes, and the order is load-bearing

`rebuild` stamps `contentSize` and `insets` **before** `nodeApply(...)` and `apparentHeight` **after** —
the order `ListViewImpl` uses in `.UpdateLayout` (`ListView.swift:3008-3015`; `apparentHeight` is
assigned only in its post-apply branches, `:3021`/`:3053`/`:3083`). Neither setter is a plain store:
both rewrite the node's `frame` with its origin pinned (`ListViewItemNode.swift:209-224`), so once they
have run the node is at its new height while CoreList has not yet rendered the row's new frame.

That matters because **`apply` runs caller code synchronously, and that code measures the screen.**
`ChatMessageBubbleItemNode`'s `awaitingAppliedReaction` fires at the end of its apply closure
(`ChatMessageBubbleItemNode.swift:5717`); adding a reaction from an open context menu routes through
it to `ContextController.dismissWithReaction`, and `ContextControllerExtractedPresentationNode` then
fixes — in the same runloop — where the extracted bubble travels back to, sampling it with a bare
`UIView.convert` off the item node. Under the chat's π the node's **own** height is what maps its
content to screen, so applying first meant sampling through a node still at the old height: the bubble
landed a full height-delta low (34pt for a reaction row), visibly sliding down and snapping back when
the animation finished. Writing the geometry first makes that convert chain report the settled
position despite the unrendered row, because the row's container origin is the sum of the **lower**
indices' heights, which this row's own growth cannot change.

Nothing in the build catches a regression here: both orders compile, and the symptom is a silently
mispositioned overlay in one interaction. Note the double-tap quick reaction
(`ChatMessageBubbleItemNode.swift:5794`) makes the identical height change with nothing extracted, so
it looks correct under either order — it is a useful **bisector** (it isolates the extract/put-back
path from the row animation) but **not** a regression test for this.

## Item visibility

`CoreVirtualListView` pushes each loaded row its visible rect through
`CoreListItemView.visibleRectUpdated(_:)` (see the CoreList `CLAUDE.md` embedding-seam paragraph);
`CoreListNodeHostView` maps it onto `ListViewItemNode.visibility` — `subRect` is the rect as given,
`fraction` is its overlap with the node's content box over that box's height, matching what
`ListViewImpl` derives from `apparentContentFrame`. That property is what makes animated stickers,
GIFs, video and instant video play, flips `visibilityStatus`, registers one-time media as seen, and
fades ad messages in. Before this existed every hosted row sat at `.none` for its whole life, so none
of that happened at all.

Three things about it are load-bearing:

- **The fraction divides by the node's content box**, so the host must keep `insets` / `contentSize` /
  `apparentHeight` stamped on the hosted node exactly as `ListViewImpl` does — including on the
  update path, which `ChatMessageItemImpl.updateNode` does not do for itself.
- **The rect is measured against the full viewport**, not the inset-reduced band. This diverges from
  `ListViewImpl`, which reduces by `visualInsets ?? insets`; a row sliding under the input panel keeps
  playing. `forEachVisibleItemNode` / `itemNodeVisibleInsideInsets` deliberately keep the
  inset-reduced `visibleBand`, because they drive read tracking and unseen-reaction animations, where
  under-reporting is the safe direction.
- **There is no `onlyPositive` deferral and no animation-completion pass.** `ListViewImpl` needs both
  because its geometry is settled-only while an inset transition animates; here the loaded window and
  the reported rects are both destination-based within one pass, so a single full update is coherent.

Rotation needs no handling: CoreList lays index 0 at its own top and the wrapper's π maps that to the
screen bottom — the convention `ListViewImpl(rotated: true)` uses — so the values are already in the
space `ChatMessageBubbleItemNode.mapVisibility` expects.

## Pagination

`CoreVirtualListView.onVisibleWindowChanged` / `onLoadedEdgeReached` call
`updateVisibleItemRange(force:)`, which is how the history controller paginates. Callbacks are read off
`self` at call time so a later controller assignment is picked up. See "Content offsets and displayed
item range" below for the range computation and its firing conditions.

## Interactive drag start

On `CoreVirtualListView.willBeginDragging` (fired when the scroll engine's pan reaches `.began`) the
backend mirrors `ListViewImpl`: it walks every loaded item node and **cancels any in-flight
`ContextGesture`** (so a message's long-press/context menu doesn't fire once the user starts
scrolling), then reports `beganInteractiveDragging` to the history controller. The walk uses
`itemNodes` — a lazy, non-copying view over the loaded nodes, built from
`CoreVirtualListView.loadedItemViews` (each loaded item view is a `CoreListNodeHostView`, mapped to
its hosted `ListViewItemNode`). Nothing materializes an array. `beganInteractiveDragging` is passed
`.zero`: CoreList doesn't surface the touch point and every consumer ignores it.

It also **samples the drag's origin** for `didInteractivelyDragFromTopOrigin` — "the current-or-most-recent
gesture was a real drag, and it began pinned to the newest-message edge". The chat's one consumer reads it
after the keyboard is dismissed by dragging, to decide whether to snap back to the newest message
(`ChatControllerNode.swift:2453`). Two pieces of state, both reset on drag **begin** and never on drag end,
so the value survives to the layout pass that reads it (`ListViewImpl` likewise resets `trackingOffset` only
in the pan's `.began`):

- *began pinned* — `visibleContentOffset()` is `.known(value)` with `value <= 10.0`, the tolerance copied
  verbatim from `ListView.swift:4959`. `ListViewImpl` samples this at `touchesBegan` (finger down) while
  the earliest hook here is drag-begin, after the pan recognizer's threshold; 10pt is wide enough to absorb
  that difference, which is plausibly why the tolerance is 10 and not 0.
- *content moved* — set on any `onVisibleWindowChanged`, which is the `engine.onScroll` sink and therefore
  user-driven movement only: programmatic offset writes are isProgrammatic-guarded, and the additive
  viewport track moves content with no engine offset change at all. It also fires during momentum, where
  `ListViewImpl` has stopped accumulating; harmless, since momentum only follows a drag that already moved
  content.

This was previously two stubbed constants (`trackingOffset = 0.0`, `beganTrackingAtTopOrigin = false`),
which made the predicate permanently false and silently disabled the snap-back under this backend. The
contract now carries the single combined member, so a backend can no longer implement one half.
**Manually verified working** (2026-07-28) on the CoreList backend — this is behavior no build or test
in the repo covers, so it is the only kind of evidence available for it.

### Inset changes while tracking (keyboard dismissal)

A third piece of drag state, `isTracking`, is the analogue of `ListViewImpl.isTracking`: a finger is on
the list **right now**. Unlike the two above it does not survive drag end — it is set on
`willBeginDragging` and cleared on `didEndDragging`, and is false throughout momentum. `ListViewImpl`
keeps the same distinction (momentum is `isDeceleratingAfterTracking`, and the suppression below tests
only `isTracking`).

Its single consumer is inset-compensation suppression. **The chat's insets change while the list is being
dragged, by the same finger.** `Window1` installs a `WindowPanRecognizer` implementing interactive
system-keyboard dismissal (`Display/Source/WindowContent.swift:1332`), and its delegate returns `true`
from `shouldRecognizeSimultaneouslyWith` (`WindowContent.swift:254`), so one downward drag both scrolls
the history and shrinks `inputHeight` frame by frame. Each frame therefore reaches the list twice — once
as a scroll delta, once as a smaller bottom inset — and compensating the inset change on top of the
scroll moves content by **double** the finger's travel. `ListViewImpl` answers this by zeroing
`offsetFix` while tracking:

```swift
if (self.isTracking && !self.allowInsetFixWhileTracking) || isExperimentalSnapToScrollToItem {
    offsetFix = 0.0                       // Display/Source/ListView.swift:3276
}
```

The backend reproduces it by passing `compensatesInsetChange: !self.isTracking` to `applyChanges`, which
drops CoreList's `newTopInset - oldTopInset` anchor projection — the exact analogue of `offsetFix` — and
nothing else. Three properties are load-bearing:

- **The insets themselves still apply.** Content x/width, the viewport band, the load band and the
  loaded-top pin all move. That is what keeps the bottom of the chat following the keyboard down under
  suppression: under the wrapper's π rotation the newest message is CoreList's *loaded top*, and
  `pinsLoadedTop` puts index 0 on the new inset edge regardless of the anchor projection. `ListViewImpl`
  splits it identically — `self.insets` is still assigned and `snapToBounds` still runs.
- **`additionalScrollDistance` is untouched.** It is a caller-chosen displacement, not compensation;
  `ListViewImpl` orders it the same way (the `+=` comes after the tracking branch).
- **The flag is read at the call site**, not inside CoreList, so the value is the one that held when the
  transaction was submitted even if `applyChanges` defers it past a re-entrant pass.

Cancelling the compensation with `additionalScrollDistance: -topInsetDelta` instead looks equivalent and
is not: a non-zero distance halts momentum and opts the pass out of `pinsLoadedTop`, so the newest
message would stop tracking the inset edge — the one case that must keep working.

`didEndDragging` was added to the seam for this (`ScrollEngine.onDidEndDragging` → both engines →
`CoreVirtualListView.didEndDragging`). It now also calls the backend's `endedInteractiveDragging`,
which drives overscroll-to-open-next-channel — see "Overscroll actions" below for the landing that
callback runs into.

Covered by `CoreListDemoTests/InsetCompensationSuppressionTests` on the CoreList side (8 tests). The
chat-side wiring — that a real interactive keyboard dismissal no longer double-offsets — has no
automated coverage; it was **manually verified working** (2026-07-28) on the CoreList backend, which is
the only kind of evidence available for it. Before the fix the history visibly moved by roughly twice the
finger's travel as the keyboard was dragged away.

### The dismissing flick must not also fling (`shouldStopScrolling`)

The same simultaneity that causes the double-offset above has a second consequence at the *release*.
A downward flick over the history can end by dismissing the keyboard, and the list would then fling on
its own momentum on top of that — two motions from one gesture.

The two dismissals have separate owners and both are decided in **touch delivery**:

- the system keyboard, in `Window1.panGestureEnded`'s `canDismiss` branch
  (`Display/Source/WindowContent.swift`);
- the entity keyboard (the input node), in `ChatControllerNode.panGestureEnded`'s.

`WindowPanRecognizer` invokes its `began`/`moved`/`ended` closures inline from `touchesEnded(_:with:)`
rather than through target/action, and touch delivery precedes gesture ACTION dispatch — which is where
`PhysicsScrollEngine.handlePan(.ended)` → `startDeceleration()` → `launchFlight()` runs, and equally
where `UIScrollView` calls `scrollViewWillEndDragging`. (This is the same ordering fact
`PhysicsScrollEngine.noteTouchDown` relies on, documented at `PhysicsScrollEngine.swift:163`.) So the
answer is already settled by the time the list asks for it, and the coordination can be a **pull**:

- `ChatControllerNode.dismissedInputByCurrentGesture` combines the two halves. The entity-keyboard half
  is a latch on the node itself; the system-keyboard half is `WindowHost.dismissedKeyboardByCurrentGesture`,
  because `Window1` owns that gesture. Both are set at their dismissal and cleared when their recognizer
  next sees a touch sequence begin.
- `ChatControllerImpl.setupChatHistoryNode` installs that as `historyNode.shouldStopScrolling`, and the
  backend forwards it to `CoreVirtualListView.shouldStopScrolling` →
  `ScrollEngine.shouldStopScrollingOnRelease`, consulted once in `applyPanUpdate(.ended)`.

Three things are load-bearing:

- **It is not `dismissedInputByDragging`.** That flag (`ChatControllerNode.swift:1393`) asks the same
  question but is derived in `containerLayoutUpdated`, i.e. from a completed layout pass — which happens
  after the release, and for the system keyboard only once the dismissal has run its ~0.38s spring. It is
  the right concept at the wrong time; using it would halt a flight that had already been playing.
- **Suppression is a zero-velocity release, not a skipped one.** See the CoreList `CLAUDE.md`
  scroll-engine seam: `.stop` still springs back from an overscrolled release, and it expires the
  repeated-flick streak exactly as a slow release would.
- **It is installed only under the CoreList backend.** `ListViewImpl` implements the identical hook and
  would honour it, but this is a deliberate behaviour change on an experimental backend: today a
  dismissing flick also flings the history, and the only thing that stops it is the snap-back at
  `ChatControllerNode.swift:2461` — which needs the drag to have begun at the newest message
  (`didInteractivelyDragFromTopOrigin`) and lands a keyboard animation late. Under the new predicate that
  snap-back still runs, but it now springs from where the finger left the content rather than from
  wherever a fling had carried it.

`shouldStopScrolling` therefore joins the `ChatHistoryListViewBackend` contract as a member both
backends implement honestly — `ListViewImpl` already had it (`Display/Source/ListView.swift:266`, and
the chat list installs one of its own), so the contract widened without new behavior there.

Covered by `CoreListDemoTests/ReleaseSuppressionTests` (6 tests) on the CoreList side. The chat-side
wiring — that a real dismissing flick no longer flings — has no automated coverage.

### Gesture arbitration

**`PhysicsScrollEngine` grants no gesture simultaneity to anything, and declares no failure
dependency.** Whoever recognizes first owns the touch, which is plain UIKit exclusion and the whole
of `ListViewImpl`'s mechanism (`ListViewScroller` denies everything but
`ListViewTapGestureRecognizer`, `Display/Source/ListViewScroller.swift:15`).

That single rule covers three behaviours that used to be separate machinery:

- **A content pan owns its drag.** An in-bubble scroll view — `ChatMessageJoinedChannelBubbleContentNode`'s
  recommendation carousel, `InstantPageScrollableNode` for rich-message tables and wide code — or
  `ChatSwipeToReplyRecognizer` competes for the same drag, and exactly one of the two may have it.
- **The stopping tap is absorbed.** A pan force-begun on moving content (`shouldBeginImmediately`)
  fails the content recognizer at touch-down.
- **A press-and-hold on a coasting list is cancelled cleanly.** `ContextGesture` is failed before its
  0.12s `beginDelay` elapses, so no press animation appears at all.

Granting simultaneity instead is invisible from the content side, because UIKit takes *either*
delegate's yes and the refusals live elsewhere: a nested scroll view's UIKit default, and
`ContextGesture`'s explicit `other is UIPanGestureRecognizer -> false`
(`Display/Source/ContextGesture.swift:66`). Both were overridden in turn, and the second bug was the
repair for the first — see the gotcha in the CoreList `CLAUDE.md` for the full mechanism.

One consequence worth naming: starting a drag now cancels a pending long-press, where previously the
press could still activate mid-drag. That is `ListViewImpl`'s behaviour — a drag past the threshold
owns the touch.

`PhysicsScrollEngine` also implements `gestureRecognizerShouldBegin`, ported verbatim from
`ListViewScroller` (`:22-38`): the scroll pan defers to a two-touch pan on the same view, and to a
`UIControl` that is already tracking. The second is live here — `ChatMessageActionButtonsNode` puts
real `UIButton`s inside the list for inline bot keyboards.

`ListViewScroller`'s one exception (`ListViewTapGestureRecognizer` keeps simultaneity) is **not**
reproduced. Under `ListViewImpl` it defeats the stopping-tap absorption so the date-header pill and
gutter avatars (`ChatMessageDateHeader.swift:676,1220`) stay tappable while the list coasts; under
this backend they are absorbed like any other tap. That has never worked here, so it is not a
regression — it needs a host-supplied predicate seam, deferred deliberately. Not runtime-confirmed.

## Item-node enumeration

`forEachItemNode` / `enumerateItemNodes` / `forEachVisibleItemNode` are real (they were no-op stubs
in the first PoC cut). Two private lazy, non-copying sequences back them, both derived from
`CoreVirtualListView.loadedItemViews` (ascending item index; a COW snapshot of the settled window, so
a callback that re-enters `applyChanges` cannot corrupt iteration):

- `itemNodeHostViews` — the loaded `CoreListNodeHostView`s. This is the **geometry-bearing** level: a
  host view sits in the CoreList hierarchy, whereas its hosted node's frame is host-local.
- `itemNodes` — each host view's hosted `ListViewItemNode`, skipping any not-yet-built. Also used by
  the `willBeginDragging` gesture-cancel walk.

`ListViewImpl` guards each node on `index != nil` to skip removed-but-still-animating nodes; CoreList
needs no analogue, because genuine departures move to the non-interactive `exitOverlay` as ghost
blocks and never appear in `loadedItemViews`.

`forEachVisibleItemNode` applies `ListViewImpl`'s own filter — `frame.maxY > insets.top &&
frame.minY < height - insets.bottom` — to each row's rect obtained via `listFrame(of:)`, i.e.
`coreList.presentedFrame(of: hostView)`. Two load-bearing details:

- **The filter is not optional.** CoreList's loaded window is viewport **plus preload margin**, so
  forwarding to `forEachItemNode` would report off-screen rows as visible and misdrive
  `hasVisiblePlayableItemNodesPromise` (video with sound), unseen-reaction animations,
  `isMessageVisible(id:)`, and read tracking.
- **The band uses `currentSize`/`currentInsets`, not the protocol-exposed `visibleSize`/`insets`,**
  because `setTopContentInset(_:)` writes only `currentInsets.top`. Orientation already matches:
  CoreList lays index 0 at its own top and the wrapper's π maps that to the screen bottom — the same
  convention `ListViewImpl(rotated: true)` uses — and both backends receive identical insets from the
  same transaction. Before the first `updateSizeAndInsets`, `currentSize` is `.zero` and nothing
  reports visible, matching `ListViewImpl` with a zero `visibleSize`.

**All row geometry goes through `CoreVirtualListView.presentedFrame(of:)`, never a bare
`UIView.convert`.** The `convert`-based reasoning still holds — it walks whatever ancestor path the row
currently has (`container` normally, `crossingOverlay` while a structural transition carries it), so it
cannot drift from what is rendered — but `convert` alone composes ancestor **model** `bounds.origin`, and
CoreList's `contentHost` model origin is the additive base of whatever animates the viewport. Under a
`.keyframe` flight it is parked at the flight's *destination* for the entire fling, and a programmatic
`scrollTo` leaves the settled endpoint there while an additive `viewportOffset` track carries the motion.
So a bare `convert` reported every row hundreds of points from where the user saw it for the whole
momentum phase — visible range, content offsets, read tracking and unseen-reaction animations all
described the end of the fling rather than the middle of it. `presentedFrame(of:)` applies the correction
(only CoreList holds both the model base and the engine position). It is presented **as of the last
sampling tick**, which is what a host wants: these callbacks all run per frame, where the two coincide.
`ListViewImpl` reads settled endpoints too, but there the model *is* the presented value — that is why
the original reasoning did not transfer. Verified in the app: with this fix (plus the two engine-side ones it
shipped with) the occasional stutter while flinging through unloaded history is gone. See
`submodules/TelegramUI/Components/CoreList/docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`.

### Index lookup, relative offset, inset visibility

`itemNodeAtIndex` / `itemNodeRelativeOffset` / `itemNodeVisibleInsideInsets` are real. All three of
`ListViewImpl`'s versions are index-based, and `ListViewItemNode.index` is `public internal(set)` to
`Display` — so a hosted node can never carry a ListView index and each needed a CoreList-native
equivalent:

- **`itemNodeAtIndex`** resolves through `CoreVirtualListView.loadedItemView(at:)`, the index-keyed
  sibling of `loadedItemViews`. CoreList owns `activeWindow` and is the authority on the index ↔ view
  mapping; the backend must not re-derive it by walking `loadedItemViews` to a position inferred from
  `loadedIndexRange`, which would leak CoreList's contiguity and index-base invariants into TelegramUI.
  `index` is in the `entries` index space, matching the one caller (the ad-message anchors, built as
  `filteredEntries.count - 1 - i`).
- **`loadedFrame(of:)`** is the shared helper behind the other two: it scans `itemNodeHostViews` for
  the host view whose `itemNode ===` the argument and returns its converted rect. **Its nil case is the
  liveness guard** — absence from the loaded window is the CoreList equivalent of `index == nil`, since
  genuine departures move to the `exitOverlay` and never appear there.
- **`itemNodeVisibleInsideInsets`** applies the same band as `forEachVisibleItemNode`; both read the
  single private `visibleBand` property so they cannot drift.
- **`itemNodeRelativeOffset`** returns `frame.minY - currentInsets.top`, matching `ListViewImpl`
  exactly. This convention is load-bearing: the value is persisted as
  `ChatInterfaceHistoryScrollState.relativeOffset` and restored as
  `ListViewScrollToItem(position: .top(offset))`, which `ListViewImpl` resolves to
  `frame.minY == insets.top + offset` — the exact inverse. CoreList's `scrollTo.pointOffset` uses the
  identical convention (screen target = `viewportInsets.top + pointOffset`), so **no unit conversion is
  needed**. Both sides are live: the restore path resolves `.top(offset)` through the scroll resolver.

`loadedFrame(of:)` is also what backs `itemNodeFrame(_:)` — see "Item-node geometry" below.

### Horizontal insets are mirrored on the way to CoreList

`coreListInsets` swaps `left` and `right` before handing the pass's insets to
`CoreVirtualListView.applyChanges(newInsets:)`. Vertical passes through untouched. This is not
symmetry for its own sake — the two backends apply a horizontal inset at **different levels**, so the
chat's single mirrored value (`ChatControllerNode.swift:2500` mirrors all four) takes a different
number of π flips in each:

- **`ListViewImpl`** keeps rows FULL WIDTH — there is no `x: insets.left` anywhere in `ListView.swift`
  — and hands the inset to the **item** as `ListViewItemLayoutParams.leftInset`/`rightInset`. The item
  applies it inside a node carrying its own π (`ChatMessageItemView.init(rotated:)` →
  `CATransform3DMakeRotation(π, 0, 0, 1)`, which flips **x as well as y**). Item π + wrapper π =
  identity, so `insets.left` lands on the screen **left**.
- **CoreList** frames the row itself at `x = viewportInsets.left` with
  `contentWidth = width - left - right` (`CoreVirtualListView.swift:2262`), and the backend passes
  `leftInset: 0, rightInset: 0` to the hosted item because that framing already happened. Only the
  wrapper's π applies, so without the swap `insets.left` lands on the screen **right**.

Vertical needs no such correction because both backends let the *list* decide a row's vertical
position — one π either way, which the chat's pre-mirror already accounts for.

**It is invisible until the two sides differ**, which is why it survived: portrait phone has
`left == right == 0`, and the `.regular`/`.regular` case adds 6.0 to both. It shows up with the
topics sidebar (`floatingTopicsPanelInsets.left`, added to `.left` only) and with landscape safe
areas. Measured before the fix: forcing the sidebar's 92pt onto `listInsets.left` shrank the bubbles
by exactly 92pt **on the right** and moved nothing away from the left, so the sidebar overlapped the
content it was meant to make room for. After: the 92pt band is on the left and the avatars sit
against it.

Swapping in the backend rather than the chat is deliberate: this is CoreList's framing convention,
not a chat-layer fact, and `currentInsets` stays exactly what the chat submitted, so every other
reader (`visibleBand`, both content offsets, the scroll resolver — all vertical) is unaffected.
`applyChanges` is the only place CoreList receives insets and nothing else in the backend reads
`.left`/`.right`, so `coreListInsets` is the single point of truth. The attachment hosts are framed
at `viewportInsets.left` too, so they are corrected by the same swap.

**No test covers this** — it is a TelegramUI-level fact and TelegramUI has no test target. CoreList's
half (that it *does* offset rows by `insets.left` and shrink `contentWidth`) is locked by
`CoreVirtualListAnimationTests.testImmediateInsetsSetTopOffsetAndHorizontalFrames`.

## Content offsets and displayed item range

`visibleContentOffset()` / the bottom offset (reached through `settledContentOffsets()`) /
`updateVisibleItemRange(force:)` follow `ListViewImpl` (`ListView.swift:1380`, `:1412`, `:4673`).
They previously returned
`.known(rawEngineOffset)`, a constant `.known(0.0)`, and nothing — which broke real behavior, since
chat reads `abs(offset) <= 0.9` as "pinned to the newest message"
(`ChatHistoryListNode.swift:2425`) and short-circuits `scrollToEndOfHistory` on `value <= ulpOfOne`
(`:3690`).

- **`.known` is reserved for a loaded list edge.** `visibleContentOffset()` is `.known` only when the
  settled window starts at collection index 0, and its value is that row's distance from the top inset
  edge, **negated** (`0` = flush against `insets.top`, positive = scrolled away). The bottom offset is
  `.known` only when the window ends at the last entry, valued `maxY - (height - insets.bottom)` and
  **not** negated. Both then read as "how much content lies beyond that edge". An empty window is
  `.none`; a loaded window not reaching the edge is `.unknown`. `ListViewImpl`'s fold over
  removed-but-animating nodes above the top item has no analogue — CoreList departures live in the
  `exitOverlay`.
- **The bottom offset is not on the backend contract; `settledContentOffsets()` is.** Chat asks for it
  in exactly one place — the ad-insertion check at `ChatHistoryListNode.swift:2425`, which tests "am I
  pinned to the newest message" against `visibleContentOffset` and "does the content fill the screen"
  against the bottom one. Two facts follow. It has **no per-frame consumer at all**, so unlike its
  sibling there is no reading of it for which the mid-animation position is the question — settled is
  simply right. And the caller **compares the two**, so exposing them as separate members let them
  describe different moments of the same animation; one member returning both makes that
  unrepresentable. The thresholds stay in the chat layer — this fixes only the instant. `ListViewImpl`
  satisfies it by returning its own two values unchanged, so the default backend is bit-for-bit as
  before.
- **`updateVisibleItemRange(force:)` is the only writer of `displayedItemRange`,** and fires
  `displayedItemRangeChanged` only on an actual change, against a private optional
  `internalDisplayedItemRange` mirror (optional so the first computation always counts). The mirror is
  committed before the callback fires, so a callback that triggers another update cannot recurse.
- **`immediateDisplayedItemRange()`** reports `loadedRange` as the settled window's index span and
  `visibleRange` as the sub-span intersecting the viewport band — a real visible range, replacing the
  earlier placeholder that reported the loaded span for both. It walks
  `CoreVirtualListView.loadedItemEntries`, the `(index, view)` sibling of `loadedItemViews`, so indices
  come from the window rather than from an iteration counter.
  **Deliberate divergence:** `ListViewImpl`'s first-visible scan tests `minY < visibleSize.height +
  insets.bottom` (`:4711`) while its last-visible scan tests `- insets.bottom` (`:4723`); the `+` looks
  like an upstream typo, so both scans here use the symmetric bound.
- **`visibleContentOffsetChanged` fires on all scrolling.** `onVisibleWindowChanged` covers every
  user-scroll frame including momentum (`handleUserScroll` is the `engine.onScroll` sink and calls it
  unconditionally, whether or not the window rebalanced — its "after each user-scroll rebalance" doc
  comment understates it). Programmatic movement is covered at **transaction end**, because
  `setOffset` / `applyShift` / `setEdges` are `isProgrammatic`-guarded in `UIKitScrollEngine` and the
  additive viewport track moves content with no engine offset change at all. `ListViewImpl` is
  structured the same way, so no CoreList scroll seam was needed. The transaction passes a transition
  matching the applied animation; `ContainedViewLayoutTransitionCurve` has no `.easeOut`, so a standard
  ease-out bezier approximates CoreList's, which is cosmetic (consumers only co-animate chrome with it).
- **The two emission points want two different geometries, and this is the one place `settledFrame(of:)`
  is correct.** The scroll path reports `.presented` — it fires per frame while content moves, so "where
  is it now" is both question and answer, and a frame that is slightly off is corrected by the next one.
  The transaction point reports `.settled`, because it is reporting the *outcome* of the pass it just
  submitted: the pass has been applied but its animation has moved nothing yet, so the presented value
  there is the **pre-animation** position, and **no per-frame hook exists to correct it** —
  `onVisibleWindowChanged` fires only on user scrolls. `OffsetGeometry` in the backend selects between
  them; `visibleContentOffset()` (the protocol member, a question about now) stays `.presented`.

  Reporting presented at the transaction point is what made the scroll-to-bottom button misbehave under
  this backend: tapping it left the button on screen until the next manual scroll (the emission described
  where the jump *started*), and opening the keyboard or emoji panel at the bottom of a chat made the
  button appear — mid-inset-animation the emission read ~98pt against a settled `-0.0`, past the 40pt
  `minOffsetForNavigation` threshold in `ChatControllerLoadDisplayNode.swift:5393`. Both are single-shot
  errors that persist until the user drags.

  Settled is self-correcting in the one case where the two disagree for a reason — a transaction landing
  mid-fling, where settled is the flight's destination — because the next scroll frame re-reports
  presented, and the consumer's own alpha change is animated anyway.

**Why `ListViewImpl` needs no such distinction:** its model *is* its presented geometry.
`replayOperations` writes final item-node frames immediately and animates the layers additively, so the
single value it reports at transaction end is already the endpoint. It additionally updates the offset
per-frame during animations (`ListView.swift:4908`); CoreList animates through analytic CA tracks with no
per-frame host callback, which is exactly why the transaction emission must carry the endpoint rather
than a sample of the way there.

## Overscroll actions

Swiping up past the newest message raises the next-channel-to-read control
(`ChatHistoryListNode.maybeUpdateOverscrollAction`, `:2722`). The control is created and destroyed by
**one** predicate over the reported content offset — `offset < -0.1` keeps it, anything else removes
it — so it is entirely downstream of the section above. Releasing at full expansion either navigates
(and the node dies with its controller) or, when there is no next channel, holds the control on
screen for a beat and ramps it away.

That hold is `holdOverscrollAction(distance:)` on the backend protocol. **It displaces the newest
edge; it is not an inset**, and the distinction is the whole reason the member is named for its
intent:

- `ListViewImpl` holds it with `scroller.contentInset.top`, a SECOND inset that is zero at rest and
  independent of the list's own `insets`.
- `CoreListChatHistoryBackend` holds it in `overscrollHoldDistance`, folded into `coreListInsets`
  — and **nowhere else**. `insets`, `visibleBand` and `visibleContentOffset` all keep reading
  `currentInsets`, so while held the list reports `.known(-distance)`, which is precisely what keeps
  the control alive and sized. Fold the hold into the offset read and the control dismisses itself at
  the instant it is meant to be held.

**`holdOverscrollAction` must report the offset its pass produced, and that is the load-bearing half.**
It moves content without going through `chatHistoryTransaction`, so it is the only thing that can
report — and this backend has no per-frame hook once motion stops ("nothing re-reports when the
animation lands", `settledFrame`). Without the report the ramp's FINAL step, hold → 0, is invisible:
the last value the chat ever hears is whatever the last scroll frame caught mid-ramp, and since that
value is still negative `maybeUpdateOverscrollAction` keeps the control alive over a content offset
that is really zero. `ListViewImpl` needs no equivalent — `scroller.contentInset` re-reports through
`scrollViewDidScroll` every frame of the ramp on its own.

Measured on the K2 simulator, which is how this was finally pinned down rather than reasoned out. The
last two emissions of a repro, and then silence:

```
[offset] presented value=known(-120.5) minY0=199.5 insetsTop=79.0 hold=106.0
[offset] presented value=known(-7.7)   minY0=86.7  insetsTop=79.0 hold=6.7   ← last emission ever
[overscroll] KEEP offset=-28.0 … hasView=true inHierarchy=true
```

**The general rule: on this backend, any geometry mutation outside a transaction owes a
content-offset report, because nothing else will make one.** That is the same property that forces
the `.settled` geometry at transaction points, seen from the other side — there, the endpoint must be
reported because no later frame will; here, the mutation must be reported at all.

The member used to be spelled `setTopContentInset(_:)`, and that name caused a second, independent bug
on the same path — worth keeping on the record, because nothing about it looked wrong and because
fixing it alone did NOT fix the symptom, it only changed which stale negative value got stuck (a
permanent `-insetsTop` instead of a mid-ramp `-7.7`). CoreList reasonably read "top content inset" as
the list's own top inset and wrote `currentInsets.top`. On `ListViewImpl` the ramp's final
`set(0.0)` is a restore to neutral; here it **destroyed** the real inset — in the rotated chat that
is the input-panel band (`ChatControllerNode.swift:2510`), 45–90pt. Every subsequent
`visibleContentOffset()` then read `.known(-T)`, a permanent apparent overscroll, so the control was
rebuilt on every emission and the removal branch became unreachable: a dead 94pt band at the bottom
of the chat that swallowed touches until the next layout pass restored the inset. Two further
consequences of the same clobber, worth recognising if it ever recurs: `visibleBand.top` went to 0,
so rows under the input panel counted as visible; and `coreListInsets` feeds
`applyChanges(newInsets:)` on *every* transaction (`:833`), so the next arriving message re-pinned
the newest row 45–90pt lower.

Two general lessons, both instances of rules this file already states elsewhere:

- **A member named for a mechanism invites each backend to pick its own referent.** "Top content
  inset" is a `UIScrollView` fact with no unambiguous meaning in a list that owns its own geometry.
  `holdOverscrollAction(distance:)` has exactly one meaning and both backends implement the same one.
- **This one could not fail to build and did not look wrong at the call site.** The same shape as
  `didInteractivelyDragFromTopOrigin` and `enableUnreadAlignment`: a plausible implementation of a
  raw member, silently wrong.

CoreList's implementation also **submits a pass** (`applyChanges`, `compensatesInsetChange: false`)
rather than only writing a field. `pinsLoadedTop` translates a window starting at index 0 onto the
inset edge outright (`CoreVirtualListView.swift:2768`), so the larger top inset *is* the held edge.
Writing the field alone was inert until some later transaction happened to carry it, which is why the
hold-and-release read as an instant disappearance rather than an animation.

**The landing is one-at-a-time.** `beginOverscrollActionLanding()` tears down any landing already
running before starting its own, and `cancelOverscrollActionLanding()` stops both of its stages —
the 0.3s dwell and the 0.2s ramp — without touching the hold or `freezeOverscrollControlProgress`,
because each caller owns what happens to the geometry next. This is not hypothetical bookkeeping: the
control sits at full expansion for the landing's whole 0.5s (the hold pins the reported offset at
`-holdDistance`, which is what `maybeUpdateOverscrollAction` recomputes progress from), so a second
release inside the window arrives with `expandProgress` back at 1.0 and qualifies again. Each release
used to schedule its own `Queue.mainQueue().after` dwell and its own animator with nothing relating
them, and every interleaving landed somewhere wrong — an early ramp's completion clearing
`freezeOverscrollControlProgress` out from under a later one still running, a jump to full hold
overwritten by an older ramp's next tick, a dwell firing for a release long superseded. The
navigate branch cancels too, since `prepareSnapshotState` bakes the current geometry into the
outgoing snapshot and a surviving ramp would keep moving it as it animates away.

Two further adjacent defects fixed alongside it:

- `currentOverscrollExpandProgress` is written only in `maybeUpdateOverscrollAction`'s create branch;
  the removal branch left it standing. A swipe that reached full expansion and then stopped being
  reported as overscrolled parked it at 1.0 forever, arming the action on the next unrelated drag
  release anywhere in the chat. `endedInteractiveDragging` now consumes it into a local and zeroes
  it, which kills the cross-gesture leak without changing what any single release does. This one was
  never CoreList-specific.
- `globalIgnoreScrollingEvents` was plain storage read by nothing. `prepareSnapshotState` sets it
  when this node's view is handed to the next-channel transition as the outgoing snapshot;
  `ListViewImpl` honours it by returning early from `updateScrollViewDidScroll` — the one function
  that moves its item nodes — so its content freezes and it stops calling back. **CoreList's engine
  moves the content host itself, so suppressing a host callback does not suppress the motion**, and
  it needs three parts: `CoreVirtualListView.haltScrollMotionInPlace()` freezes motion already in
  the air, dropping `isUserInteractionEnabled` stops a new drag, and a guard at the top of
  `onVisibleWindowChanged` stops the host reacting to whatever slips through.

  Broader than `ListViewImpl` on the interaction half — there the scroller keeps scrolling, only the
  item nodes hold, and taps still land. A snapshot being animated away should accept neither.

**The hold is applied DURING the drag, and moving an edge under a finger takes two things.**
`launchFlight` integrates its release hand-off and bakes the whole flight inside the pan's `.ended`,
firing `didEndDragging` only afterwards — so a hold applied at release is always one step late, and
out of bounds that step is spring-shaped and proportional to the overscroll (measured: a 12.9pt jump
opening a spring whose own rate was 5.5pt/sample). Holding from the moment the control fills gives
the gesture ONE edge. `holdsOverscrollActionDuringDrag` gates it — false on `ListViewImpl`, whose
`scroller.contentInset` cannot move an edge without moving content, and which needs none of this
because `UIScrollView` owns its own bounce.

Moving an edge without moving content needs BOTH halves, and each was a separate device-visible jump:

1. **`applyChanges(absorbsEdgeChangeIntoOverscroll:)`.** `presentationOverscroll` preserves the
   rubber-band MAGNITUDE across a geometry pass — right when the edge stays put (rotation, keyboard),
   a teleport when the edge itself moves under stationary content. Measured:
   `newBounds = -185 + (-156.37) = -341.37`, i.e. still 156pt past an edge that just moved 106.
   Absorbing instead holds the presented position and lets the band re-measure (156 → 50).
   It is NOT `compensatesInsetChange`, which governs the anchor projection: `pinsLoadedTop`
   translates the window onto the new inset edge outright whenever index 0 is loaded — always, while
   an overscroll action is live — so the anchor knob cannot hold content still here.
2. **`ScrollAxis.reanchorDragToCurrentOffset()`.** Holding the engine offset is only half of holding
   the content. A drag maps finger travel through the rubber band, so a moved edge re-scales that
   mapping and the content jumps on the NEXT drag frame — one frame after the offset was preserved,
   which is what made it look like the absorb had failed. Measured: 116pt past the old edge became
   10pt past the new one, the band stopped resisting, and the content shot out 64.8pt. The anchor is
   moved by the difference between this offset's pre-images under the new and old edges
   (`RubberBand.inverse`). `DragReanchorTests` pins it, with the un-re-anchored jump as its control.

The **ramp** back to zero uses the opposite mode (`movesContent: true`): there the magnitude-preserving
reading is what carries the content down as the edge closes. Same policy, opposite desirability — which
is why it is a caller choice rather than a fix.

**Halting motion instead looks like it solves the same symptom and does not.** It strands the content wherever the finger
happened to lift — neither the resting position nor the held one — and makes the landing depend on
gesture timing. Moving the edge is a durable trajectory invalidation, so an in-flight spring rebakes
and settles into the held position on its own. Let the flight finish; just move where it is going.

**The cause that actually shipped was none of the above — it was a third of a point of physics.**
The two defects above are real and are fixed, but each only changed WHICH stale negative value got
stuck. `Deceleration.settled()` accepted a rest position within 0.5pt of an edge without moving the
offset there, and the ⅓pt device grid put every bounce at exactly −0.333. Measured, last emission
before silence:

```
[offset] presented value=known(-0.3333) minY0=79.3 insetsTop=79.0 hold=0.0 overscroll=-0.33 flight=false
[overscroll] KEEP offset=-0.3 … hasView=true inHierarchy=true
```

`-0.333 < -0.1`, so the control is kept; the list is genuinely at rest, so nothing re-reports; and
`expandDistance = max(0.333 - 12, 0) = 0`, so it draws at zero expansion while its 94pt host view
eats every tap. `Deceleration.settleIfNeeded` now clamps a settle to its edge — see the CoreList
`CLAUDE.md` gotcha; `FlightLaunchPreconditionTests` inverted with it, since it had been asserting the
−1/3 rest as expected.

**The lesson for this backend:** `ListViewImpl` cannot reach any of these states — a `UIScrollView`
bounce lands exactly on `-contentInset`, and it re-reports every frame regardless — so a threshold
the chat has used safely for years is not evidence that a new backend can satisfy it. Anything
downstream comparing a content offset against a small constant is exposed to sub-point physics
residue here.

**How to reproduce.** A partial swipe up is enough — the control need only appear — and it clears on
any layout pass, so focusing the input field hides it. The full-expansion release exercises the
`holdOverscrollAction` path instead.

## Neighbor awareness

Rows are laid out with the descriptors published by their adjacent entries, so bubbles merge and
date headers collapse the way they do on `ListViewImpl`. Before this existed the backend passed
`previousItem: nil, nextItem: nil`, which rendered every message unmerged with its own date header.

`CoreListEntryItem` carries a `ListViewItemNeighbors`, computed in one pass **after** the
insert/update/delete operations have settled — neighbors are a function of final adjacency, so
computing them per-operation would use indices that later shift. The index bases match
`ListView.neighbors(at:)`; that is valid because the backend feeds items in `ListView` index order,
and it means the `isRotated` flip inside `ChatMessageItem.merged(with:isRotated:)` needs no
special-casing here.

The value participates in `isEqual(to:)` alongside `stableId`/`stableVersion`, so a row whose
neighbors changed is unequal and re-applies. That is the backend's equivalent of `ListViewImpl`'s
descriptor-diff invalidation.

See the "Neighbor descriptors" section of the root `CLAUDE.md` for the load-bearing invariant: a
descriptor must encode everything a neighbor reads, or the omitted fact goes stale on screen.

## Floating headers and avatars

Date separators and group avatars are `ListViewItemHeader`s adapted onto CoreList's
`CoreListAttachedItem` feature by `CoreListChatHistoryHeaders.swift`. The mapping is near-exact —
key = `header.id`, `combines(with:)` = `combinesWith(other:)`, `edge` = `stickDirection`,
`isFloating` = `isSticky` — because CoreList's attachment solve is `updateItemHeaders`' math, down
to the clamp order and its degenerate-band comment citing `ListView.swift:4019`/`:4032`.

Four things are load-bearing:

- **`.overlay`, never `.reservesSpace`.** Chat rows already carry the header's 34pt in their own
  `layoutInsets.top` (`layoutConstants.timestampHeaderHeight`), so reserving it again would double
  the gap. CoreList's reservation path is unused by chat.
- **The edge mapping is direct, not flipped.** `ListViewImpl(rotated: true)` and CoreList both lay
  index 0 at their own top and let the wrapper's π put it at the screen bottom, and the chat headers
  already resolve `stickDirection` against `chatIsRotated`. The header node carries its own π exactly
  as item nodes do, so it counter-rotates inside its host.
- **The stick factor and `updateFlashingOnScrolling` are one feature.** The date pill's alpha is
  `flashingOnScrolling || stickDistanceFactor < 0.5`, so reporting the factor without driving the
  flashing hides the pill for exactly as long as it is parked at the display edge — strictly worse
  than reporting neither. Flashing needs no CoreList seam: `onVisibleWindowChanged` is the
  `engine.onScroll` sink and ticks through momentum, so "no content movement for 0.3s" is the
  predicate `ListViewImpl`'s timer expresses (`ListView.swift:859`).
- **`attachedItems` is built once per entry**, not computed per access: `AttachmentRuns.pendingRuns`
  consults it per row during stacking as well as once per window build. It depends only on the item's
  headers, so a geometry-only pass cannot invalidate it.

The header host passes `leftInset: 0` because CoreList already frames an attachment at
`viewportInsets.left` with `contentWidth`, where `ListViewImpl` hands header nodes the full width plus
the real insets. The avatar lands identically; the date pill centres in the content width rather than
the full width — a deliberate divergence, visible only under a landscape safe-area inset.

Headers reach the backend from the **item**, via `ChatHistoryItemWithHeaders` in the `ChatMessageItem`
module, because CoreList computes runs before any row view exists. `ChatUnreadItem` and
`ChatReplyCountItem` conform for a specific reason: an item between messages that publishes no key
breaks the run, so an unread separator mid-day would float two pills for one date.

Two CoreList additions serve this: `loadedAttachmentViews` (the attachment sibling of
`loadedItemViews`, and the live set — departed runs are in the fade-out path) and
`AttachmentOffsetMap.stickDistance(atOffset:)`. See the CoreList `CLAUDE.md` gotcha for why the
attachment's frame and its stick distance deliberately solve at different offsets.

### Deferred

- ~~**Topic headers**~~ Done, and as an ENGINE feature: `CoreListAttachedItem.stackingGroup` tags an
  attachment into a group, `stackingYield` names the group it defers to plus a minimum gap. The chat
  maps a header's own `id.space` onto the group and its `stackingId.space` onto the yield, at the
  27pt (`7 + 20`) gap `ListView.swift:4047` uses; the engine never learns what a date pill is. The
  skip is gone, so a monoforum's thread separators reach `attachedItems` like any other header.

  **The resolution lives INSIDE `AttachmentOffsetMap.y(atOffset:)`, and that is the whole design.**
  `composedKeyframe` *samples* that function to bake the additive `CAKeyframeAnimation` a momentum
  flight rides, and nothing on the render server can consult another attachment — so the obvious
  implementation, a post-solve fix-up over view frames, would be absent from the baked track: the
  header would ride un-nudged for the entire deceleration and snap into place when the flight ended.
  It can live there because a partner's position is `y(atOffset:)` too, equally pure, and sampling
  bakes a piecewise conditional function exactly as well as a linear one.
  `testComposedKeyframeCarriesTheNudge` is the guard, and it was confirmed to fail when the yield is
  moved out.

  Two deliberate divergences from `ListViewImpl`, both confined to inputs where its own answer is
  arbitrary. It picks ONE partner by a comparison that never consults the `intersectionHeight` it
  computes (`ListView.swift:4064-4070`) while iterating a `Dictionary`; we take the `min` over every
  overlapping partner, so there is nothing to tie-break. And its `for _ in 0 ..< 2` becomes iteration
  to a fixed point — the second pass exists because pushing clear of one partner can create a new
  overlap, which is the same idea without the magic count. `ListViewImpl` is not modified.

  Two things that are NOT free and each earn their own test. The stick distance measures against the
  adjusted bound (`naturalOverlapLowerBound`, `:4039-4052` and `:4084`), which for a partner sharing
  this run's boundary reduces to exactly one gap off the raw distance — without it a header riding
  its run reports a full gap of stick and fades as though parked. And z-order: `pendingRuns` sinks a
  yielder below its target group via a leading rank (a pairwise comparator clause would not be a
  strict weak ordering), but the sort alone would not have produced the z-order it exists for —
  `renderAttachments` only ever APPENDED a view it had not seen, so sibling order followed the order
  runs first entered the loaded window, and a topic header and its date pill rarely arrive in the
  same pass. The render now re-asserts the order every frame.

  **Not runtime-verified.** It needs a monoforum whose topics span a day boundary, which cannot be
  synthesized on the simulator, and the check must include a momentum **fling** rather than only a
  slow drag — a nudge that works while dragging but not while flinging means the yield is not
  reaching the baked track. Note the precedent recorded below: of six chat behaviors verified during
  the scroll-to-item work, two failed on first contact and neither failure was visible to a green
  suite.
- ~~**`ListViewItemNode.attachedHeaderNodes`**~~ Done, and as an ENGINE feature rather than a chat
  one. `CoreListItemView.attachedItemsUpdated(_:)` hands each row the attachments hanging off it, and
  `CoreVirtualListView` resolves it inside the attachment solve — the same max-intersection-within-the-
  run question as `ListView.swift:4203-4221`, including the guard that a zero-height intersection binds
  nothing. It belongs there because the answer is a function of the attachment's *solved* position,
  which moves as a run scrolls and its floating attachment parks against the display edge: it changes
  with no item and no run changing, and the intersection is a subtraction in window space rather than a
  view-tree conversion from outside. The chat host's whole job is then attachment host → header node.
  Delivered every solve, unconditionally, like `stickDistanceUpdated`; `setAttachedHeaderNodes` (the
  one `Display` addition, since the array's setter is `internal`) compares before notifying, which is
  what keeps a per-frame push from re-applying transform state mid-animation.

  It unblocks the two consequences that were dead, both pushed by `ChatMessageBubbleItemNode`'s apply
  step (`:4018-4021`): `updateAttachedAvatarNodeOffset`, which slides the gutter avatar 100pt aside
  while a round video plays unexpanded (`ChatMessageInstantVideoBubbleContentNode.swift:279`), and
  `updateAttachedAvatarNodeIsHidden(isHidden: isSidePanelOpen)`, which hides it behind the floating
  topics side panel. **Both runtime-verified on screen (2026-08-03)**, which is the only check that
  means anything here — the suite cannot see a binding that is never consulted, and the failure mode
  of the old state was silence rather than breakage. `updateAttachedDateHeader(hasDate:hasPeer:)`
  needs nothing —
  `ChatMessageDateHeaderNodeImpl.updateItem` has an empty body. The avatar's selection-mode offset,
  which ListViewImpl also routes this way, needs nothing either — and must not be given anything.
  The app pushes it to every live header node itself, through `forEachItemHeaderNode`
  (`ChatController.updateItemNodesSelectionStates`), and a node built later seeds itself in `init`
  from `controllerInteraction.selectionState`; ListViewImpl's `attachedHeaderNodesUpdated` push is
  `animated: false`, i.e. that same seeding rather than the animated toggle. A backend-side re-push
  replaces the app's in-flight `sublayerTransform` animation with a degenerate `from == to` one and
  makes the avatars snap — see the selection-mode note under `itemHeaderNodes` in
  `CoreListChatHistoryHeaders.swift`.
- ~~**Band trim for `stickOverInsets: false`.**~~ Done. `CoreListAttachedItem.spansMemberInsets`
  (default `true`) and `CoreListItemView.attachmentBandTrim` (default `0`) carry
  `ListView.swift:4274-4279` into the engine: the run's far bound is now a max over
  `frame.maxY - attachmentBandTrim` rather than over raw `frame.maxY`. The header side answers
  `stickOverInsets`, so only the gutter avatar trims; the host answers
  `rotated ? insets.top : insets.bottom`, so a rotated chat trims by the node's TOP inset — which is
  where the row folded `timestampHeaderHeight`, even though it renders at the visual bottom. CoreList
  takes the max over trimmed member bounds where ListViewImpl takes whatever its last member computed;
  the two agree whenever a trim is smaller than the row it trims, which it always is.
- `.topEdge` stick direction (no chat header declares it; the adapter maps it to `.top`),
  `itemHeaderNodesAlpha` (chat never sets it), and `contributesToEdgeEffect` (nothing in the repo sets
  it — the one assignment is commented out).

## Scroll to item

`chatHistoryTransaction` maps `ListViewScrollToItem` onto a `CoreListScrollTarget` whose **resolver**
computes the row's offset once CoreList has measured it. That indirection is the whole design: three
of the four `ListViewScrollPosition` cases need the target row's height, and on a history jump the
target is not loaded — the entries array is replaced wholesale — so the backend has nothing to
measure. CoreList measures the anchor as the first act of `buildWindow` and calls back there.

`pointOffset(for:index:height:view:)` holds `ListViewImpl`'s arithmetic
(`Display/Source/ListView.swift:3166-3204`), translated from "a delta added to every frame" into "the
target row's `minY`, minus `insets.top`" — CoreList's convention, where the projected screen target
is `viewportInsets.top + pointOffset`. It reads `scrollPositioningInsets` and the `.center(.custom)`
quote/subject rect off the hosted `ListViewItemNode`, which exists because `update(width:)` has
already driven a synchronous layout. **All ListView placement semantics live here**, not in CoreList,
which learns nothing about chat.

The curve maps case-for-case onto `CoreListTransition` (`ListView.swift:3611-3618`) instead of
collapsing to one spring, and `directionHint` becomes the carousel's travel direction —
`.Down → .forward`, `.Up → .backward`. That mapping is what `ChatHistoryViewForLocation.swift:59`
means: it picks `.Down` when the target is *older*, and chat's index space is reversed, so older is a
higher index, which is forward. The hint is consumed **only** when the viewport transition has no
anchor witness; a full replace is exactly that case, and without it every long jump travelled forward
regardless of direction.

A jump also fades nothing at either end. CoreList suppresses insert and exit opacity on a
**full-replace** carousel — one whose loaded windows are disjoint *and* whose destination window is
entirely new content — because that is a rigid travel between two strips already owned by the shared
viewport track. The fades were an artifact of the chat expressing a jump as delete-all + insert-all.
`ListViewImpl` likewise slides its `temporaryPreviousNodes` out at full opacity.

**The destination window is the load-bearing unit**, and getting it wrong is easy in both directions.
Testing only loaded-window disjointness fades a genuinely new row inserted among survivors at the
destination. Testing whole-*collection* disjointness — which this did at first — never fires here at
all: `ChatHistoryEntry` gives the non-message rows **constant** stable ids (`UnreadEntry` is
`4 << 40`, `ReplyCountEntry` `5 << 40`, `ChatInfoEntry` `6 << 40`), so a wholesale history replace
always leaves one identity alive and the collection-level test was permanently false. It looked
correct in CoreList's own tests, whose synthetic collections are cleanly disjoint, and failed on
every real jump. What decides it is whether anything in the place being travelled *to* was already
there.

`ensureItemNodeVisible` is built on the same path (as it is in `ListViewImpl`), with the collection
index resolved through `CoreVirtualListView.loadedItemEntries` — a hosted node can never carry a
`ListViewItemNode.index`.

**Jumping to the newest message is the edge case of the edge case.** A jump renders as a carousel:
two strips travelling rigidly, both carried by CoreList's one shared additive viewport track. A
departing row also joins a ghost block, and a ghost block normally attaches to a live boundary
witness so it stays glued to its neighbourhood — but a carousel's departed strip *has* no live
neighbourhood, and attaching one gives it a second vertical owner that walks it across the incoming
window. CoreList's `initialGhostWitness` proposes the head of the new collection when no predecessor
survives, which a wholesale history replace guarantees; that proposal resolves only when collection
index 0 is loaded, i.e. only when the destination is the newest message. Jump-to-reply and
jump-to-date leave it unloaded and stayed rigid, which is why the six verified behaviors above did
not catch it. Fixed CoreList-side (carousel passes attach no witness) and **runtime-verified
2026-07-31**; locked by `FullReplaceCarouselStripSeparationTests`, which covers both collection edges
(the far end had the same bug through `initialGhostWitness`'s `ordinal == newItems.count` branch), a
mid-collection control, and the mechanism itself. Note the shape this bug shares with the two below:
**a chat's jump differs from CoreList's synthetic fixtures precisely at the collection edges and at
the constant-identity rows, and all three times that difference was invisible to a green suite.**

**Two jumps in a row, the second reversing the first mid-flight** (for example, jump to a reply,
then tap scroll-to-bottom before the travel ends) drew the previous window through the new one. The
first jump's outgoing strip was still parked in the viewport, and CoreList placed the second
destination against the loaded window alone, which put it exactly on that strip for the whole
travel. Fixed CoreList-side on 2026-09-29 (see "The outgoing strip is everything on its way out" in
the CoreList `CLAUDE.md`) and locked by `CarouselChainOverlapTests`, including the chat's own shape
where the second jump reloads the very history the first one left. Runtime-verified in the chat
on 2026-09-29.

**Verification status (2026-07-31): runtime-verified.** `CoreListDemoTests` covers resolver placement
against a far unloaded target, the direction fallback, carousel fade suppression from both sides, and
carousel strip separation at both collection edges (620 tests green). All six chat behaviors were
then confirmed on screen: scroll-to-unread (including
in a chat whose navigation bar changes height mid-open), long-jump travel direction and opacity,
jump-to-reply centering, quote centering in an over-tall bubble, scroll-position restore on chat
open, and reply-thread unread refocus.

**Two of those six failed on first contact, and neither failure was visible to the test suite.** The
unread separator landed ~70pt off because `enableUnreadAlignment` was dead code under this backend
(see "Unread item alignment"), and long jumps still cross-faded because the fade-suppression
predicate tested whole-collection disjointness, which never holds for real chat data (see "Scroll to
item"). Both bugs had green CoreList tests over them the whole time — the synthetic fixtures use
disjoint identities, uniform row heights, and no constant-id rows, so they are systematically cleaner
than what the chat produces. **Treat CoreList test coverage as necessary and not sufficient for
anything in this backend; the on-screen check is the real gate.**

**A third of the same class surfaced only in use**, after those six passed: jumping to the newest
message dragged the outgoing window across the incoming one (see "Jumping to the newest message" in
"Scroll to item"). It never reached a screen during the sweep because the six behaviors exercise
jumps to *interior* targets, and the bug needs a destination window touching a collection edge. Two
things generalize. Enumerate the **edges** of whatever a host actually asks for — first index, last
index, empty, single-row — not just a representative interior case; the carousel suites all sat at
index 50. And when a symptom is a wrong *animation*, measure it instead of watching it: sample
`ListAnimationModel` for the two strips' screen bounds at several phases and assert the overlap, as
`FullReplaceCarouselStripSeparationTests` does. That turned an eyeballed "heavy intersection" into a
348pt number and a named owner (a ghost block's position track) in one 15ms run, with no app build.

## Item-node geometry

`ListViewItemNode.frame` is list-space **only on `ListViewImpl`**. Here a node's view is a subview of
its `CoreListNodeHostView` at `(0, 0, width, height)`, so the node's own frame is host-local and every
comparison against it reads the wrong space — silently, since the values are plausible.
`ChatHistoryListViewBackend.itemNodeFrame(_:)` is the list-space accessor both backends implement
(`ListViewImpl` returns `node.frame` guarded on `index != nil`; the CoreList backend returns
`loadedFrame(of:)`), and its nil case is the liveness guard on both.

Nine chat-layer sites were migrated onto it: the visible-message scan, both scroll-reset anchor
offsets, the animate-in delay factor, the next-item scroll-restore check, `messagesAtPoint`, and both
snapshot inset loops. `messagesAtPoint` is the one that was outright broken — it tested a point
against a host-local rect and could never match.

## Unread item alignment

The chat re-pins the unread separator to the bottom inset edge whenever that inset changes
(`enableUnreadAlignment`, default true). This is **not** cosmetic: when the navigation bar changes
height mid-open — a Report Spam bar appearing, which lives in `navigationBar.additionalContentNode`
and so grows the chrome without moving `containerInsets` — the separator must be re-pinned, or it
keeps the position computed against the pre-panel geometry.

It used to live in `ChatHistoryListNodeImpl.updateLayout` gated on `itemNode.index`, which is
`public internal(set)` to `Display` and therefore **always nil for a hosted node** — so the entire
behavior was dead code under this backend, with no build error. It is now the
`maintainsUnreadItemAlignment` parameter on `chatHistoryTransaction`.

**One member, not two, deliberately.** The predicate ("is the separator currently pinned?") must be
evaluated against the OLD insets and the re-pin applied with the NEW ones. As a measure-then-reapply
pair a backend could implement one half and stub the other — precisely how
`trackingOffset`/`beganTrackingAtTopOrigin` silently disabled keyboard-dismissal snap-back before they
were collapsed into `didInteractivelyDragFromTopOrigin`.

The two backends realise it differently, which is the point of the seam: `ListViewImpl` cannot compose
a scroll with an inset change, so it measures, runs the transaction, and re-issues the scroll from the
completion. The CoreList backend evaluates the predicate before overwriting `currentInsets` and
submits the re-pin as the `scrollTo` of the *same* `applyChanges` — one movement, one animation, no
intermediate frame. The read-at-the-call-site pattern is the same one `compensatesInsetChange` uses,
and for the same reason: the value must be the one that held when the transaction was submitted.

**Deliberate divergences from `ListViewImpl`:**

- **`displayLink` is unused.** `ListViewImpl` re-samples the quote rect per frame during the scroll;
  CoreList animates through analytic CA tracks with no per-frame host callback, so `.center(.custom)`
  resolves once, at pass time.
- **The insets used are the pass's *new* ones.** `ListViewImpl` reads the old `self.insets` here —
  `ListView.swift:3143` still carries a commented-out `// updateSizeAndInsets?.insets ?? self.insets`
  — and applies the size/inset change separately afterwards. The backend resolves both in one
  coordinate system.
- **`.center` uses the single measured height.** `ListViewImpl` guards on
  `apparentFrame.size.height` but divides `itemNode.frame.size.height` (`:3173-3174`).
- **`.visible` on an unloaded target** falls back to center-with-top-overflow. Only reachable from
  the `experimentalSnapScrollToItem` path, which nothing in chat enables; `ensureItemNodeVisible`
  always holds a loaded node.
- **A pin-to-edge target ignores the requested position entirely** — see "Pin to bottom edge" below.
  `ListViewImpl` does the same (`ListView.swift:3146-3170`); the divergence is that the override here
  omits `scrollPositioningInsets.bottom`.
- **`resetScrolledToItem()` remains a no-op**, which is correct while nothing sets
  `experimentalSnapScrollToItem = true` (the only assignments, `ChatHistoryListNode.swift:1023` and
  `ChatController.swift:7674`, are both `false`).

## Pin to bottom edge

While a bot streams a reply, the chat pins the user's last outgoing message to the screen top
(`pinToTopStableId` → `ChatMessageEntryAttributes.pinToTop` → `ListViewItem.pinToEdgeWithInset`).
Both backends realise it the same way — a latch for placement plus a clamped inset for scroll room —
and CoreList's halves are `holdsPinnedRow` and `bottomEdgePinSlack`. The contract, the open
released-state defect, and the three approaches already known not to fix it are in
`submodules/TelegramUI/Components/CoreList/CLAUDE.md`;
`docs/superpowers/specs/2026-08-04-corelist-pin-to-edge-design.md` describes the superseded
slack-only mechanism.

**The chat arms the latch exactly once per streamed answer.**
`ChatHistoryListNode.swift:2238-2253` watches the view for a `TypingDraftMessageAttribute`, names the
last outgoing Cloud message before it as `pinToTopStableId`, and sets `scrollToPinToTopStableId` **only
when that stableId changes**. `:2521-2530` turns that into a `.top(0.0)` scroll, and
`pointOffset(for:index:height:view:)` (`:369-372`) replaces the requested position wholesale for a
lowest-pin-to-edge index — `ListViewImpl` does the same at `ListView.swift:3146-3170`, and the chat
relies on the list to know better. CoreList engages `holdsPinnedRow` when a `scrollTo` names
`lowestPinnedItemIndex`, so this one scroll is the entire engagement path. Cold start is covered: a
fresh history node has `pinToTopStableId == nil`, so opening a chat with an answer already streaming
fires it on the first view.

**Release is permanent for that answer**, and is an event rather than a measurement: finger-down
(`engine.onWillBeginDragging`), the pinned row leaving the collection, or a full replace. Dragging away
mid-stream and scrolling back does **not** re-pin — only a new pinned message does. That is
`ListViewImpl`'s behaviour, and it is why nothing here infers release from geometry.

**The slack still has to be computed inside the pass, and that is why it lives in CoreList.** It
depends on the measured heights of the rows above the pin, which change on every streamed token — and
some of those changes arrive as `onContentDidChange` self-update flushes that never reach
`chatHistoryTransaction` at all. A backend computing it before the pass would be one pass stale on some
tokens and blind on others.

**Never un-clamp the slack.** It was, for one revision, on the theory that the edge could carry the
hold without a latch — CoreList had no latch then. A negative slack is placement leaking into a
scroll-range quantity: it reached `loadedEdgeRange`'s minimum and extended the range into empty space,
so on device a tall streaming reply **could not be scrolled down to at all** — it overscroll-bounced.
The clamp is safe because the latch now owns placement, and the two are matched by construction (see
`CoreList/CLAUDE.md`).

Two consequences worth knowing:

- **`isStrictlyPinnedToBottomEdge` reads the latch**, plus a presented-frame check that the animation
  has landed. Its old `slack != 0 || ext > 0` guard was a proxy for "held rather than coincident", and
  it reads false in exactly the tall-content regime where the pin is most firmly held.
  `ChatControllerLoadDisplayNode.swift:900-904` uses this to decide whether **sending a message drops
  the pin**, so the scroll-to-bottom button is not the only consumer that depends on it.
- **The effective-inset compensation reads a slack DELTA** (`:1026`, `:1088`), and the clamp bounds
  inset absorption by the slack running out. Pushing the top inset past the slack the pin holds absorbs
  only what there is; the remainder moves content
  (`testPartiallyAbsorbedInsetChangeMovesContentByTheUnabsorbedRemainder`).

**The pinned row is not loaded when you would expect it to be** — while the latch is *disengaged*. It
sits at a *higher* index than the anchor on exactly the passes that matter, so
`prependUntilCoveredOrAtTop` has not loaded it and a slack measured there reads 0; CoreList runs a
bounded `appendUntilPinnedRowLoaded` first. This was a real bug in the first implementation and it
presents as the feature simply not working, with correct edges and a correct-looking window. An
*engaged* latch cannot hit it: the pinned row is the anchor, so it is window member zero.

Three chat-side specifics:

- **`pointOffset` overrides the requested position** for the lowest pin-to-edge entry. The chat's
  `scrollToPinToTopStableId` asks for `.top(0.0)` and relies on `ListViewImpl` knowing better; here
  `.top(0.0)` would land the row on the screen *bottom*.
- **`scrollPositioningInsets.bottom` is omitted from that override**, unlike `ListViewImpl`. CoreList's
  resting pin cannot see it, so including it would desynchronise an explicit scroll-to-pin from the
  position every later pass re-pins to. It is zero for every row that can carry the flag.
- **`visibleContentOffset()` reads `−slack` while pinned**, because index 0 sits at
  `insets.top + slack` and the backend subtracts the raw inset. `ListViewImpl` produces the identical
  value for the identical reason — its pin inset is a local `effectiveInsets` and never reaches
  `self.insets` — so the scroll-to-bottom button and the `scrollToEndOfHistory` short-circuit behave
  the same on both backends.

**Verification status (2026-08-04): tests green, partially runtime-verified.** `BottomEdgePinTests`
(30 cases) covers placement, the bottom extension, invariance across a growing neighbour through both
a transaction and a self-update flush *and at every phase of the animation rather than only its
endpoints*, the latch in both directions, effective-inset compensation including partial absorption
and suppression, the strict query, and the collection edges — including the fresh-bot-chat shape where
both loaded edges are reachable. The full suite is 811 green and the app builds.

Confirmed on screen against a real streaming bot chat: the pin engages and holds the outgoing message
while the reply streams (the held bubble's edge measured at the SAME PIXEL on every frame of a 40s
30fps recording), and shows the shrinking slack below the reply. **The over-tall question, drag-away
-and-re-latch, and a second send while pinned were confirmed on 2026-08-05.** Still not run: the
keyboard, floating headers, and the scroll-to-bottom button — checks 5, 7 and 9 in
`docs/superpowers/plans/2026-08-04-corelist-pin-to-edge.md`.

That same session found what this entry previously recorded as correct — "releases once the reply
outgrows the viewport" — to be the clamp bug described above. It is not a release; the pin is supposed
to hold until the user drags away or the flag clears, as it does on `ListViewImpl`. Fixed by letting
the slack go negative.

**Driving this chat from XcodeBuildMCP does not work well**, which is worth knowing before planning a
check around it. Beyond the accessibility gaps already recorded (the scroll-to-bottom button, gutter
avatars and date-header pills are not in the tree), a *streaming* bot chat invalidates the runtime UI
snapshot faster than a follow-up call can use it, so `swipe`/`tap` fail with `SNAPSHOT_EXPIRED` in a
loop. Taps immediately after a fresh snapshot work; scrolling generally does not. Note also that
absent debug borders are NOT evidence the CoreList backend is off — a bubble taller than the viewport
puts both its borders off screen.

**Two pre-existing issues this work surfaced.** The height-compensation clock skew is described above
and is FIXED. The other is not: UIScrollView clamps a negative `bounds.origin.y` on a layout pass, so
an offset established at construction is lost — in `CoreListDemoTests`, a plain 100pt top inset with
no pin involved goes `-100 → 0` across `layoutIfNeeded()`, leaving index 0 at 0 instead of 100. Every
existing CoreList suite applies its geometry *after* `VirtualListDriver.init` and so never meets it;
`BottomEdgePinTests` introduces the pin in a pass for the same reason (which is also how it arrives in
reality). Whether this reaches the app — where a layout pass can land between `applyChanges` and the
next frame — has not been established.

## Trailing item space

When the whole collection fits on screen with room to spare, the list tells its **last** item how much
empty viewport lies beyond it (`ListViewItemNode.updateTrailingItemSpace`, driven from the tail of
`ListViewImpl.snapToBounds`, `ListView.swift:1345-1357`). Three chat items opt in via
`wantsTrailingItemSpaceUpdates` and all do the same thing with it — shift their content container by
half the space, centring the block in the gap: `ChatBotInfoItemNode` and `ChatUserInfoItemNode` (set in
`init`), and `ChatMessageBubbleItemNode` per-layout, for the centred-link `.messageOptions` preview
only. (`ChatNewThreadInfoItemNode` overrides the method with a commented-out body and never sets the
flag.)

The last item is the **oldest** entry — index 0 is the newest — which the wrapper's π renders at the
top of the screen with the free space above it. The offset the item applies is `y: -space/2` in its own
coordinates, and the item's own π composes with the wrapper's to identity, so that reads as "up the
screen, into the gap".

**The quantity is offset-independent, deliberately.** `ListViewImpl` computes it as
`visibleAreaHeight - completeHeight` rather than from where the last node currently sits, and the
backend keeps that property: `settledContentHeight` is an intra-window height and
`currentBottomEdgePinSlack` an intra-window span. Reading a presented or settled *frame* instead would
make the centred item drift under a rubber-band overscroll — the one kind of scrolling an underfilled
list allows.

**The pin slack is part of the answer.** `ListViewImpl` measures the leftover against
`effectiveInsets.top`, which `calculatePinToEdgeTopInset` has already widened; CoreList spends the same
slack in its underfill alignment (it places the window on `viewportInsets.top + pinSlack`), so the gap
really is smaller by that much. `CoreVirtualListView.currentBottomEdgePinSlack` was added as the public
read of `bottomEdgePinSlack(for:)` so there stays one implementation of that formula. In an underfilled
chat the slack always exceeds the leftover, so a short chat with an unread separator reports zero and
the info item stays put — the pin has pushed the oldest content off the far edge and taken the info
item with it. That is `ListViewImpl`'s answer too.

**Two call sites, and the zero matters as much as the positive value.** The transaction end (on the
pass transition, so the re-centring travels with the content-height or inset change that caused it) and
`onVisibleWindowChanged` (immediate — where `ListViewImpl` reaches `snapToBounds` from as well, and
where a rebalance can move both terms of the "whole collection is loaded" test). The zero is what
*resets* an item centred by an earlier pass once the content grows past the viewport. There is no third
site: `CoreListNodeHostView` declares `onContentDidChange` but never calls it, so no chat row's height
changes behind the backend's back — a row that re-measures itself returns through
`chatHistoryTransaction` as `customAnimationTransition`.

Known imprecision, unreachable in practice: the leftover is measured against `currentInsets` (which
excludes `overscrollHoldDistance`, matching `ListViewImpl` reading `self.insets` rather than
`scroller.contentInset`), while CoreList's slack is computed against the held insets and so shrinks by
the hold. It would need an underfilled chat that also has a pinned row — where the leftover is already
zero with margin — and the error is bounded by the hold distance.

**Runtime-unverified.** Built and reasoned against `ListViewImpl`; the empty-bot-chat and
new-private-chat greetings have not been eyeballed on this backend.

## Send animation

The outgoing-message morph (`ChatMessageTransitionNodeImpl`) parents its animating content **under the
item node**, so the bubble rides the list's scroll for free and only its *starting* offset has to be
calibrated. That calibration converts the input field's window rect down the layer chain into the item
node's space — and the conversion has to describe where the input field renders **when the morph
starts**, not where the geometry is headed.

`CALayer.convert` cannot answer that: both backends schedule the pass's scroll as an animation and
leave the MODEL at the destination, so a plain convert returns end-of-scroll geometry and the bubble
starts a whole scroll's worth away from the input field. `convertAnimatingSourceRectFromWindow`
therefore corrects each parent→child step by that step's pending rendered-minus-model translation. It
reads the mechanism off the layers rather than asking the list, because the two backends move content
in different ways and a row can be moving under its own track while the viewport moves too:

| | carries the travel in | model holds |
|---|---|---|
| `ListViewImpl` | additive `sublayerTransform` on its own layer (`ListView.swift:3775`) | the destination |
| CoreList | additive `bounds.origin.y` on `contentHost`, additive `position` per row (`CoreAnimationCompiler.keyPath(for:)`) | the destination |

Only the first of those was handled, so under this backend the morph started ~37pt below the input
field on a one-line message. That reads as a *fixed* offset however tall the message is, which is what
makes it look like a constant rather than a scroll: the pass's travel is `newItemHeight −
inputPanelShrink`, and every extra line of text grows both terms by the same amount.

Two CoreList specifics the correction has to respect, both learned the hard way:

- **`presentation()` is not the answer.** CoreList rebases its container with a model write and no
  animation in the same turn; that write renders immediately, so its presentation layer is stale by
  exactly the rebase. Only a property that is *actually animating* may be read as displaced — which
  is why the scan is keyed on the animation rather than on a model-vs-presented difference.
- **A CoreList track is already partway through when a transaction completion runs.** Every track in a
  pass is stamped with the time that pass BEGAN (`ListAnimationController.now()`), which is
  milliseconds in the past by then, so it renders past its start value on its very first frame.
  The correction therefore evaluates each animation's curve at the current time instead of taking its
  `fromValue`; a `ListViewImpl` animation has `beginTime == 0` and evaluates to exactly its start
  value, so that path is unchanged to the last bit.

**Also suppressed: the entering row's fade.** CoreList gives every new row an opacity track on its
**host view** (`ListAnimationController.insert`), which would cross-fade the bubble a second time
while the morph is already carrying it. The chat's own suppression cannot reach it —
`ChatMessageItemView.cancelInsertionAnimations()` walks the item node's *subnodes*, and the host is a
superview — and removing the CA animation behind the controller's back would leave `ListAnimationModel`
still believing it owns a fade. So the backend states it up front instead, passing
`animatesInsertions: false` whenever the pass carries `.RequestItemInsertionAnimations`. That is the
option `ListViewImpl` reads as "hand the insertion animation to the node", which the morph then
cancels; CoreList has no node-animation step, so the same statement lands as "do not fade".

The flag sits next to `isFullReplaceCarousel` on the same call and says the same kind of thing: the
arrival is real, but something outside the list is already staging it. It is **pass-level**, and it
must be forwarded through `applyChanges`'s re-entrancy deferral — a send pass landing inside another
pass is re-dispatched through the scheduler with its arguments listed explicitly, and would otherwise
regain its fade intermittently, only under load. `InsertionFadeSuppressionTests` pins all three
cases, the deferral included.

Under reduce-motion or with an ad in view the flag is still set but no morph runs
(`ChatControllerNode.swift:5464`), so the row simply appears rather than animating in — accepted, see
`docs/superpowers/specs/2026-08-04-corelist-insertion-fade-design.md`.

Related: a send that happens while the bottom-edge pin is held takes no `scrollToItem` at all (see
"Pin to bottom edge"), so the calibration above is exercised on both paths. Until
`isStrictlyScrolledToPinToEdgeItem()` answered honestly it was a hard `false`, and every send here
went down the `scrollToItem` path — `ListViewImpl` at the bottom of a chat took the pin-to-edge path
instead and never scrolled.

## Arriving messages slide in as a block

A message arriving at the newest edge enters from beyond that edge and slides into place, rather than
fading in where it will sit. `ListViewImpl` produces the same movement, and **not by a mechanism this
backend can reuse** — which is the whole reason this is a CoreList track:

- `ChatMessageItemView.animateInsertion` (`ChatMessageItemView.swift:712`) is the slide. It sets
  `transitionOffset = -bounds.height * 1.6` and animates it back to zero.
- `transitionOffset`'s `didSet` early-returns under `hostOwnsFrame` (`ListViewItemNode.swift:275`),
  which `CoreListNodeHostView.rebuild` sets on every hosted node. The write reaches nothing. The
  comment at `ListViewItemNode.swift:226` states the assumption outright: *"`transitionOffset` is
  written only by `ListViewImpl` … neither of which runs under a host that sets this."*
- `addTransitionOffsetAnimation` parks a `ListViewAnimation` that only `ListViewItemNode.animate(timestamp:)`
  advances, and its sole caller is `ListViewImpl`'s display link (`ListView.swift:4823`).

So calling `animateInsertion` from here would compile, run, and animate nothing — twice over. (Its
other half, `ChatMessageBubbleItemNode`'s per-subnode alpha, *would* work, but that only duplicates the
host-layer fade CoreList already installs.)

**The track must be list-owned, not a raw CA animation on the row's layer.** Position tracks in
`ListAnimationModel` are additive offsets decaying to zero, and `capturePresentedPositionOffsets()`
reads `presented − model` on every bound live layer at the START of the next pass to recover exactly
that quantity. An animation the backend added itself is indistinguishable from a track the model owns,
so a second message landing mid-slide would resume against a displacement the model never issued —
the same class of double-count that shipped once as every row snapping a whole growth backwards (see
"Granular animation contract" in the CoreList `CLAUDE.md`). Going through
`CoreVirtualListView.animateInsertedBlock(identities:origin:transition:)` also makes an overlapping
arrival compose: `transitionPositionOffset` folds the in-flight `currentOffset` into the new track.

**The block, not the row, is the unit.** Every named row takes the SAME offset — the run's total
settled height, reserved space included — so a run arriving together keeps its spacing for the whole
travel and lands as one piece. Per-row displacement would fan them out.

**The host names the edge; the list measures the distance.** The backend cannot compute the height:
it comes from the very pass the call follows. `origin` is in CoreList's **content order**, and the
chat passes `.beforeBlock` — index 0 is the newest message and sits at the start of CoreList's
content, which the wrapper's π renders at the visual bottom. Reading the case off the screen instead
is how the sign gets inverted.

**Which passes qualify** (`arrivingBlockStableIds`): a non-empty insert run that is contiguous and
anchored at index 0, not covering the whole collection, without `.RequestItemInsertionAnimations`, and
whose deletes — if any — form a contiguous run at the far END of the old array. Positional rather than
by message direction, so a bot reply, a message from another peer and one sent from a second device
all qualify by the same rule, and the backend needs no message semantics.

**Neither deletes nor updates disqualify an arrival, and assuming either does breaks the commonest
case.** Both were wrong in the first draft of this predicate:

- **The history view is a sliding window of bounded size**, so a message landing at the newest edge
  pushes the oldest one out of the view in the same transaction. `entries[0]` is the newest, so that
  departure sits at the far end of the old array. `deleteIndices.isEmpty` therefore rejects nearly
  every real arrival — the animation would appear only in a chat short enough not to have filled its
  window yet. What actually disqualifies a pass is a departure anywhere *else*, which is a message
  being removed rather than the window sliding. Note `deleteIndices` indexes the OLD array, so the
  predicate needs `previousEntryCount`, captured before the transaction rewrites `self.entries`.
- **A message from the author who sent the one before it changes that bubble's merge state**, which
  arrives as an `updateIndicesAndItems` entry beside the insert.

Like `animatesInsertions`, the call must survive `applyChanges`'s re-entrancy deferral — but here the
danger is sharper, because the caller reads the window rather than passing a flag: `applyChanges`
landing inside another pass re-dispatches itself and **returns having done nothing**, so a synchronous
read afterwards would find the previous window and displace the wrong rows. `animateInsertedBlock`
defers itself onto the same FIFO scheduler, behind the deferred pass. `InsertedBlockSlideTests` pins
the geometry, the rigidity, the direction, the unloaded-row skip, the deferral, and the mid-slide
composition, each with its own non-vacuity control.

## Deferred items / known limitations

These are still open with the backend now default for the rotated history, and are what
`ios_killswitch_disable_corelist_chat_backend` exists to roll back if one of them bites:

1. **Per-item animation selectivity.** The pass transition is now derived from `scrollToItem` /
   `updateSizeAndInsets` / `options` (see Transaction flow), but it applies to the pass as a whole:
   `options` distinctions finer than "does this animate, and on what curve" — `.AnimateCrossfade`,
   `.AnimateTopItemPosition` — still have no analogue.

   **Insertion animations are now selective**, though not by per-index membership: the entering rows
   of an arrival at the newest edge get their own position track (see "Arriving messages slide in as a
   block"), which is the one place `ListViewImpl`'s per-index insertion animation was visible in the
   chat. What is still missing is the general form — `requestItemInsertionAnimationsIndices` naming an
   arbitrary subset, rather than the contiguous-run-at-index-0 case the chat actually produces.
2. **Fine-grained transaction features ignored.** `stationaryItemRange` is mapped only by its
   nil-ness (to `anchorMode`): the range's actual bounds are discarded, so a transaction asking to
   hold a *specific* index range stationary gets CoreList's general visible-content preservation
   instead.

   **`customAnimationTransition` is now honored** — it sets the pass transition, outranking the
   generic `.AnimateInsertion` fallback. It used to be dropped, on the recorded reasoning that "the
   chat sets it in exactly one place — a floating topics side panel change", and **that reasoning was
   wrong**: it conflated two different fields with the same name. The side panel sets
   `ListViewUpdateSizeAndInsets.customAnimationTransition` (`ChatControllerNode.swift:2619`), which
   reaches the `updateSizeAndInsets` branch and never needed the standalone parameter. The standalone
   `chatHistoryTransaction(customAnimationTransition:)` has a second, much hotter producer that the
   survey missed: any content node calling `requestFullUpdate`
   (`ChatMessageBubbleItemNode.swift:5047` → `requestMessageUpdate` →
   `ChatHistoryListNode.swift:4920/:4941`). A streaming bubble does that on every chunk, asking for
   `ControlledTransition(duration: 0.15, curve: .easeInOut)`, and the dropped value left the ROW on
   the `.AnimateInsertion` fallback of spring-over-0.4s while the node animated its own content over
   0.15s ease-in-out — a 2.7× duration difference and a different curve, per token.

   The lesson generalises past this entry: **"the chat only sets X in one place" is a claim about a
   grep, and a grep for a field name finds two fields when a struct member and a parameter share it.**
3. **Config/geometry stubs.** The `// Config flags` and `// Geometry / range` members are plain
   storage with no behavior; only the display-path values are real. (`didInteractivelyDragFromTopOrigin`
   used to be two of these and is now real — see "Interactive drag start". It is worth reading that
   entry as a warning about the rest: a stub that returns a plausible constant reports *no* problem,
   and this one disabled a user-visible behavior for as long as it existed.) `globalIgnoreScrollingEvents`
   has since left the block too — it was written by `prepareSnapshotState` and read by nothing, so the
   outgoing snapshot stayed live; see "Overscroll actions". The three scroll callbacks
   that used to sit here — `endedInteractiveDragging`, `didEndScrolling`,
   `didEndScrollingWithOverscroll` — are now wired, and `didEndScrolling` was the same class of bug as
   `didInteractivelyDragFromTopOrigin`: nothing ever cleared `isInteractivelyScrollingValue`, so after
   the first drag the chat believed it was being scrolled forever and the video-unmute tip
   (`ChatControllerNode.swift:5688`) could never appear again.

   CoreList gained `didEndScrolling` (flight → nil), `isScrollFlightActive` and `overscrollDistance`
   for them, and the backend reproduces `scrollViewDidEndDragging`'s body in its order. The
   `willDecelerate` split UIKit hands ListViewImpl is read off `isScrollFlightActive`, which is only
   meaningful because the engine fires `didEndDragging` *after* launching deceleration; and the
   `!isTracking` guard on the momentum half works for the same reason in reverse —
   `onWillBeginDragging` precedes `catchFlight`, so a flight caught by a new touch is already flagged
   as tracking. `overscrollDistance` is sampled at drag end, where `core.offset` still holds the
   release position (`launchFlight` parks only the layer at the settled offset).
4. **`itemNode.frame` is still host-local** — the *fact* is unchanged, but every chat-layer consumer
   has been migrated off it (see "Item-node geometry" above), so nothing in the chat currently reads
   it. A hosted node's view remains a subview of its `CoreListNodeHostView` at
   `(0, 0, width, height)`, so any **new** caller reaching for `ListViewItemNode.frame` will silently
   read the wrong space. Use `itemNodeFrame(_:)`, and `itemHeaderNodeFrame(_:)` for header nodes —
   a header node's view is a subview of its attachment host, so its frame is host-local for exactly
   the same reason, and `forEachItemHeaderNode` handing out real nodes is what makes that reachable.
   **The enumerator being right does not make the geometry right.**

   Both now sit on the public `ChatHistoryListNode` protocol as well as the backend, because the live
   consumer is outside this module: `ChatLoadingNode` stages its placeholder-to-content fade by
   `frame.minY / heightNorm` at three sites (`:264`, `:329`, `:369`), all of which were reading zero
   under this backend and collapsing the cascade onto one beat. (`:249` reads `frame.height`, which is
   correct host-local — the host frames the node at `(0, 0, w, h)` — so it is left alone.)

   Watch out for `ChatHistoryListNode.swift:4429`, which looks like a fourth consumer and is not: its
   whole block is guarded by `(transition.animateIn || animateIn) && !"".isEmpty`, and `!"".isEmpty` is
   constant `false`. That cascade is dead on **both** backends.
5. **The hosted node's content offset is applied unanimated.** Under `hostOwnsFrame` the node no
   longer maintains `bounds.origin.y == -insets.top` itself (`insets.didSet` is suppressed), so
   `rebuild` writes it — with a plain assignment, while the box beside it travels on the pass curve.
   If the insets ever change mid-conversation, that term steps instead of sliding. This is the
   analogue of ListViewImpl's `insetPart` (`ListView.swift:3063`), which folds the same quantity into
   the `transitionOffset` seed so it decays on the height's curve.

   **Dormant today:** the chat's items no longer carry insets, so the term is constant and the snap
   has nothing to show.

   Routing it through `pendingTransition.setBoundsOriginY` — the obvious fix, and the same
   resume-from-presentation setter the box uses — was tried on device and **brought back the height
   wobble that `hostOwnsFrame` had just removed.** It was reverted, and the mechanism was never
   established; do not re-apply it without one. Two things found while looking are the places to
   start, both concerning who accounts for a non-zero `bounds.origin`:

   - `CoreListTransition.setFrame` derives position as `frame.minY + frame.height * anchor.y`,
     ignoring `bounds.origin` entirely.
   - `ASDisplayNode`'s frame setter derives it through `ASBoundsAndPositionForFrame`
     (`ASDisplayNode+UIViewBridge.mm:314`), which *does* fold in the current `layer.bounds.origin`.
   - `ListViewItemNode.frame`'s own setter caches `_position = (value.midX, value.midY)`, ignoring it
     again.

   `rebuild` calls all three in sequence, so they agree only while `bounds.origin` is zero — which is
   exactly the condition that makes this entry dormant, and exactly the condition that animating the
   origin would break.
