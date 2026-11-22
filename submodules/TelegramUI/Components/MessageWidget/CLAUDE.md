# Message widgets (`messageMediaWidget`)

A widget message carries `messageMediaWidget width:int height:int payload:bytes` (layer 233): a bot's size anchors and
the widget's HTML, compressed by the server: a zlib stream (PHP's `gzcompress($html, 9)`; gzip before widget-sandbox
v0.1.3). It is the only way widgets are delivered. TelegramCore stores it as `TelegramMediaWidget` (Postbox keys `w`,
`h`, `p`, and since widget-sandbox v0.2 `f` (the server's flags), `cd`/`pd` (the bot's states, kept as the UTF-8 of the
TL `string`s since the 2026-10-27 schema), `ph` (`public_data_hash`) and `wi` (`widget_id`), each absent when unset;
`html()` inflates zlib or gzip, checking the header first, with no size check of its own; a local message is
compressed as the server does, zlib at level 9, through the SDK's `zlib`, never Compression's `COMPRESSION_ZLIB`, which
is raw deflate);
`ChatMessageWidgetBubbleContentNode` draws it as a live widget in a bubble of its own, the message's text as its
caption below. The authority is widget-sandbox, vendored at tag v0.5.0 in `third-party/widget-sandbox` (`corpus/`,
`conformance/`, `stress/`; v0.3.0 brought strict limits, the finger rule, held requests, `openTelegramLink` and the
stress kit, v0.4.0 the time over the widget, the content safe area, v0.5.0 the wallet); the client's spec is
`docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md` (milestones V1–V6; §8, §9 and §10 hold this client's v0.1.1, v0.1.2 and v0.1.3 decisions), and v0.2's (the bot's
state, the message context, requests) is `docs/superpowers/specs/2026-10-26-message-widgets-v0.2-design.md`. The runtime, `WidgetRuntime`, has its own record:
[`docs/message-widgets-native-runtime.md`](../../../../docs/message-widgets-native-runtime.md). Code:
`submodules/TelegramUI/Components/MessageWidget/{MessageWidget,MessageWidgetRendering,WidgetRuntimeIOS,WidgetRuntime}`
and `…/Chat/ChatMessageWidgetBubbleContentNode`.

On by default, by user decision, with no Debug Settings flag. `chatMessageWidgetRenderingEnabled()` is false only
while the app config carries `ios_killswitch_disable_message_widgets` (`MessageWidgetKillSwitch.isEngaged`, set once
per app configuration by `AccountContextImpl`, because `getAppConfigValue` is expensive). Then, or when the payload
does not decode or the widget fails to start, the bubble shows the shared "please update" pill
(`UnsupportedContentPill`) inside a normal bubble (so the caption keeps its bubble) and no date. When the kill switch
flips with a chat open, its setter posts `MessageWidgetAvailability`'s change and a bubble whose last pass answered
the gate differently asks for its own relayout, because nothing else lays out a widget whose size never changes
(`WidgetHarnessAvailabilityTests`). The chat list and forward panels show the caption, or "Widget" when there is none
(`MessageContentKind.widget`). None of what follows shows up as a build error:

- **Size** (`MessageWidgetBubbleSize`). Width 0 is the bubble's width; any other width is clamped to 200…the
  bubble's. A widget message's bubble has no share button beside it and may take the chat's full width
  (`ChatMessageBubbleItemNode`: `allowFullWidth`, as a channel post's; the user, 2026-10-26), so a width-0 widget
  spans the list but for the bubble's edge and content insets, past the narrow maximum (`maximumWidthFill`, the list
  less 36 pt on a phone) that a bubble without the full width keeps
  (`WidgetHarnessSizingTests.testAWidgetBubbleHasNoShareButtonAndTheFullWidth`). Height 0 is the widget's own: 160 pt until it reports, then the reported height clamped to 50…600 and
  cached per message with its resize anchor (`MessageWidgetHeightCache`, 4,096 messages) so scrolling back does not
  jump; any other height is
  clamped to 50…600 and clips the widget. The runtime clamps what it reports to 50…600 too (`WidgetTreeRenderer`), and
  to a fixed height under it: the node passes it on every main-thread pass (`MessageWidgetRegistry.maximumHeight` →
  `MessageWidgetInstance.maximumHeight`, applied on its next `layout`; an anchor edit keeps the runtime and changes
  it), so the document ends at the clip and a stopped widget's badge, drawn at the document's bottom, stays visible.
- **Which edge stays put** (`TelegramWidget.setResizeAnchor`, sdk-v1 §2.12 and §5.6, integration.md; widget-sandbox
  v0.1.3). A widget chooses the edge of its bubble that stays put on screen when its auto height changes: `top`, the
  default, grows the bubble downward (what is below it moves), `bottom` upward (what is above it moves). The runtime
  keeps the latest (`HostState::resizeAnchor`, checked by the vendored SDK policy's `checkResizeAnchor`) and the
  snapshot carries it with the size (`MessageWidgetInstance.resizeAnchor`, `MessageWidgetRegistry.resizeAnchor`).
  The chat keeps that edge, **but at its bottom the chat stays at its bottom** (the user, 2026-10-28, replacing
  2026-10-24's "The anchor should win if scrolled to bottom too"): there a top-anchored widget grows upward, as a
  bottom-anchored one does, until its row's top reaches the screen's top inset (the navigation bar's side, the list's
  bottom inset), which it then keeps, the rest of the growth going downward and the chat leaving its bottom by it. A
  top already past the inset has reached it, so it stays and the widget grows downward (the user's call: the inset is
  a ceiling, never crossed); a shrink at the bottom keeps the bottom. "At the bottom" is the settled list at its newest
  end, an overscroll hold included. **While the list holds a pinned row** (the user's message while a bot streams its
  reply, until a drag or until the chat holds a jump to another message, which ends the pin: under a held jump the
  widget's edge wins, the user's call of 2026-10-29, `testUnderAPinnedPostAHeldJumpLetsAWidgetKeepItsEdge`; CoreList's
  `holdsPinnedRowAtBottomEdge`) there is no resize target at all: every pass re-places
  that row, so a target that moved it would see it jump back on the next pass. The pin anchors the pass and every
  widget grows away from it, a bottom anchor included (`testUnderAPinnedPostATopAnchoredBubbleKeepsItsTop`,
  `testUnderAPinnedPostABottomAnchoredBubbleLeavesThePinInPlace`). A resize target never arms the pin
  (`CoreListScrollTarget.pinsRow` false): aimed at a released pin's row, it would arm it again
  (`testAResizeDoesNotPinAReleasedPinnedPostAgain`). Three rules around it,
  also the user's: a widget's **first height** after the 160 pt placeholder with nothing cached is placed as any new
  message is (at the bottom the chat stays at its bottom); the list **clamps at its ends** (a shrink that would need
  space past the end moves the edge instead); a bubble **off screen** leaves the screen still. The path: the widget
  node's `resizeAnchor`, decided by `MessageWidgetBubbleSize.resizeAnchor` from the last layout and the registry's
  `runState` (the widget's own edge once it has reported, else the cached one: a widget that has not run never chose;
  nil for the first height, a fixed height and an update that leaves the height as it is; a start that failed is a
  change, to the pill) → `ChatMessageItemView.resizeAnchor` → `ChatHistoryListViewUpdateItem.resizeAnchor`
  (from `ChatHistoryListNode.requestMessageUpdate`, not when it scrolls to the message) → the CoreList backend's
  `keepingEdge(of:anchor:)`, a pass-scoped scroll target placed from the row's new height. The list keeps what is on
  the screen-bottom side of a changed row by itself, a bottom anchor's edge; the target is set for both anchors, since
  a held jump re-places its own row instead. A row below the screen keeps the lowest visible row. **A target ends a
  held jump and stops momentum**, so there is none while the finger is down or the list decelerates (during a flight
  the settled frames are its destination: the rest of the fling would jump there), the list's own placement deciding
  then, and none for an update that changes no height (the bubble's re-layouts). A real change on screen releases a
  held jump; its row moves with its side. ListViewImpl ignores it. **While the height animates** the widget's clip, mask and tail follow the bubble's own
  animation (the widget never shows past the bubble's edge), a bottom-anchored widget's view rides the clip's bottom,
  and its old tiles sit on the anchored edge until the new ones are drawn (`MessageWidgetView.tileOffset`). A
  top-anchored widget growing upward at the chat's bottom stays laid from the clip's top: its picture rises with the
  bubble's top and the new part is uncovered at the bottom, which stays (recorded on the harness 2026-10-28: the caption
  under it still within 0 pt, the widget's top and the posts above it moving together). A chat that
  fits the screen cannot scroll, so there the list's own placement decides. `WidgetHarnessResizeTests` (Tier 1,
  `Fixtures/resize/`), `testAtTheBottomTheFaqGrowsUpward` and `testAFlingPastAResizingWidgetKeepsItsMomentum`
  (Tier 2) cover it.
- **The widget fills its bubble** (sdk-v1 §5.1): the bubble adds no padding
  (`ChatMessageWidgetBubbleContentNode.bubbleInset` = 0; the widget's body margin, the text tokens' padding, is the
  inset), clips at its own radii (`chatBubbleCorners`, the auxiliary radius where merged) and is square where the tail
  joins. Below a document shorter than the bubble the view paints the canvas colour (runtime record, "The tree carries
  the canvas colour"). The tail continues the widget's bottom-corner colour (sampled with each tile draw,
  `WidgetFrame.bottomLeftColor`/`bottomRightColor`) through `chatBubbleMediaCorner`'s mask, as a photo's does; a
  transparent corner leaves the bubble's own. The date sits where a photo's does, 8 pt from the edges. Check in the
  widget harness with `-widget-caption off` and `-harness-side incoming`: the harness draws no outgoing gradient
  bubble (it has no wallpaper backdrop).
- **The time over the widget is its content safe area** (widget-sandbox v0.4.0, sdk-v1 §2.17, §5.12). With no caption
  below the widget (none, or one shown above it, `invert_media`) the bubble draws the date over its bottom right corner,
  as on a photo, and tells the widget what it covers (`MessageWidgetContentSafeArea`, through the registry each pass):
  `bottom`, the pill's height plus its 8 pt margin on both sides, and `cornerRight`, its width likewise (34 and 67 pt for
  a plain date), the pill in the middle of its box as upstream's reference draws the time; clamped to 64 and 200, the
  most the runtime keeps. The date is on the right in every interface direction here, so `cornerLeft` stays 0; the corner
  assumes the widget fills the bubble (centred in a wider one, its true corner is narrower). With a caption below, all
  0. The date's layout comes before the widget's pass, so the boot has it and the first height has the band
  (`MessageWidgetInstance.contentSafeArea`, read by `layout`; a change is a waited `.layout` task, an equal value
  nothing, as is any change to a frozen widget, so it changes only with the bubble's layout: a caption edited
  above or below, "edited", a wider views count; `testACaptionEditChangesTheBandOnce`). The widget sees
  it as `env(safe-area-inset-*)`, the `--tg-content-safe-area-*` root variables, the UA layer's body padding (an
  unstyled widget is that much taller; a full-bleed one sets `body { padding: 0 }`) and `TelegramWidget.contentSafeAreaInset`
  with `contentSafeAreaChanged` (runtime record, "The content safe area"; `env()` in an SVG attribute that is no CSS
  value, a `stroke-width`, is the renderer's own, as upstream keeps it). The date, and the box around it (`timeCorner`:
  the pill with its margins on both sides, within the widget), are the bubble's, never the widget's: the content node
  takes touches there (`hitTest`), its tap action is `.none` (a reaction button of the date keeps `.ignore`) and it
  claims no drag, so swipe-to-reply asks the widget nothing (asking presses it early). The box, not just the pill: a
  long press's activation, the tap recognizer's own 0.3 s long tap and a tap's up all convert the down point through the
  press's shrink, several points toward the corner (the runtime record's v0.4.0 divergence 12). The box is anchored at the pill, so
  in a bubble wider than a fixed-width widget it covers only the part of the widget the pill is near, and it is nil
  without a date (a widget that failed to start). While the bubble is lifted (the context menu) nothing shrinks and the
  text selection takes touches there, its end knob included. Left open: a touch begun just inside the box's inner edge
  can still drift out of it under the shrink when the pill is wide against the widget (an incoming 200 pt widget with
  views and "edited", or on iPad; computed 2–5 pt, not measured, not reproducible in the harness). The harness:
  `WidgetHarnessSafeAreaTests`, posts with `captionAbove`, `WidgetHarnessListHost.replaceCaption`.
- **Widgets exist only where the bubble lays out on main.** A widget's instance and the height cache are main-thread
  only, so the node boots and queries a widget only in a main-thread pass. The chat history's CoreList backend lays
  out on main; `ListViewImpl` (other lists, and the chat under `ios_killswitch_disable_corelist_chat_backend`) lays
  out off main except in a `.Synchronous` transaction, so there the bubble keeps its placeholder or cached height and
  shows no widget until a main-thread pass. The widget harness hosts the chat's CoreList backend
  (`makeCoreListChatHistoryBackend`), never `ListViewImpl`.
- **Off main, on a pool of two threads.** `MessageWidgetCore` (its `WRSession`, `WidgetTreeRenderer`,
  `WidgetTileDrawer`) runs only inside the widget's tasks on `MessageWidgetPool` (two 8 MB threads, a serial queue per
  widget, no thread pinning: QuickJS re-reads its stack top on every entry); `MessageWidgetInstance` (main) applies
  the `WidgetSnapshot` each task ends with, in task order. Main never calls into a core. It queues a task and waits
  within one cap per run-loop turn: 20 ms of wall time over every waited task, never a verdict
  (`MessageWidgetWaitPolicy`, `MessageWidgetTurn`, reset at `beforeWaiting`).
  A task not done goes on, and its snapshot is applied later from the handshake's mailbox, before anything newer. The
  handshake's `drain()` is not re-entered: a task run while it applies (a snapshot asking for its draw) mailboxes its
  result behind the ones still to apply.
  **Only the size is on the critical path** (by user decision): a snapshot carries size and state, never tiles;
  applying one with `needsDraw` queues a `.draw` task main never waits for, which draws the changed 128 pt tiles in
  parallel (`WidgetTileDrawer`), so a size change can show the old tiles for a frame. A boot not done is the offered
  width × 160 pt (`MessageWidgetInstance.placeholderHeight`); its late snapshot moves `layoutVersion` so the bubble
  lays out again (a late start failure too, which then shows the pill). Taps always wait and carry their permission;
  timer ticks and frames wait unless the widget is hidden or demoted (a timer, wake or frame task whose steps spend more
  than 10 ms of the widget thread's CPU, `MessageWidgetInstance.demotionCpuMilliseconds`, demotes it for good; boots
  and taps never do, and the boot lifecycle's own steps, its scripts and its load, do not count for their first two
  slices of CPU in all wherever they run, the boot task's own included, the core's wakes once the boot task has spent
  its slice:
  `WidgetSnapshot.bootCpuMilliseconds`, `MessageWidgetCore.bootDemotionExemptionSlices`). Keyed tasks (`timer-<id>`, `wake`, `frame`, `visibility`, `width`, `draw`) replace one still
  queued, and one frame task is in flight at a time. Tests run each widget on a pool of its
  own with `.unbounded` (each wait ends with its task); background-path tests pass a capped policy and hold a task
  with `gateNextTaskForTesting()` (never with `.unbounded`: main would wait for a task that waits for main).
- **A hostile message must not crash, freeze or exhaust the app, and its limits are widget-sandbox's, on the widget
  thread's CPU clock** (the user, 2026-10-30: "move closer to the upstream", exact parity; the spec is
  `docs/superpowers/specs/2026-10-29-message-widgets-cpu-clock-limits-design.md`). The values are upstream's
  `LIMIT_DEFAULTS` (`wr::CpuLimits`, `MessageWidgetCpuLimits.product`), in every build and under both limit policies:
  - **a task's slice, up to 500 ms of CPU.** Every runtime step (an event, a timer, a frame, each boot script and the
    load, a width or theme change's task) runs in one: 500 ms for a boot task, otherwise min(500 ms, what the JS quota
    has left, at least 50 ms) (`CpuBudget::decide`). Past it the widget stops, uncatchably, with upstream's "CPU limit
    exceeded: more than <slice> ms of continuous execution (<where>)" (`StopReason::Cpu`). A wall-clock backstop,
    max(10 × slice, 5 s), stops a step whose thread is starved;
  - **the JS quota, 300 ms per 1000 ms window, and the main-thread window, 100 ms per window** (the host's work for
    the widget: its layout queries' time and upstream's modelled cost of its operations, 0.025 ms an op and 0.002 ms a
    canvas command). Past either, deferrable tasks (timers, frames, viewport, resize, theme, bridge) wait apart until
    the retry time, which `nextTimerDeadline` includes; events and taps still run, and the `cpu-throttled` diagnostic
    says so in upstream's words. Our renderer's other flushes are measured but charged to no window: upstream's
    renderer is the browser's (the plan's Task 6 ruling; `EventLoop::endStep` is the one line to revert);
  - **layout queries, 100 ms per task**: past it the widget stops ("Layout query limit exceeded: …").

  The parse is ours: it runs outside any slice, bounded by gumbo's count limits (`wr::ParseLimits`), and the client
  adds no source-size check of its own (the server bounds the payload, widget-sandbox integration.md). The slice is
  read in QuickJS's interrupt handler, at the stock 10,000 polls, never inside our renderer's scopes (a flush's time is
  not the slice's). **Native code is not interruptible** (the user's call: exact parity): a builtin that does not poll
  (a `trim` of 4 MB, BigInt division, a generic `join` of `{length: 2**40}`) runs to its end, and the stop lands at the
  next poll, so one hostile message can hold one of the pool's two threads for as long as that call takes. Once a stop
  latches nothing is catchable by script (quickjs-ng change 10), so no `try`/`catch` keeps a loop going. A session's
  memory limit is 8 MiB under the strict policy, 64 MiB under compat (`WRSession`, from `wr::Limits`); a memory stop is
  fatal. One core task's drain runs at most 256 steps (`maximumStepsPerTask`) and stops once its steps have spent a
  slice of CPU (`cpuLimitMs`; the step that crosses it runs to its own end), and so does the boot's own loop in
  `WRSession` (the rest of the lifecycle runs on wakes), so a widget that keeps a task runnable leaves the pool thread to
  the others between drains: a chain of follow-ups inherits its root's kind, and a boot's, an event's or a visibility
  change's is never deferred by the JS quota (the final review's I1, the fix wave's I-A); a chain of timers or frames
  is, too. A down whose task the touch's drains do not reach is `.unanswered` (`WRSession.pressDownPending`), as
  when main's wait ends first, never the claim of the press before it (the fix waves' I-B); a widget the drains stopped
  answers none, the bubble's. `getAnimations()` flushes
  as a layout query does (`layoutForQuery`): its time is the query's, and past the 100 ms it stops at that flush
  (upstream's is a host query too, `query({q: 'anims'}, false)`, and ends the operations batch as ours does). The CPU
  windows read the host's clock at a step's admission and record the step at its end, as upstream does
  (`EventLoop::quotaNow`). **Script our renderer runs is the widget's**: the
  style-change step settles CSS animations' promises, which reads a `then` a widget may define, so it runs in a
  `Runtime::ScriptScope` (checked against the slice, counted as JS), a width, theme or reduced-motion change's flush
  is a step of its kind that no window defers (`EventLoop::flushForHostChange`: its own slice and operations batch,
  follow-ups of its kind, recorded as a step), and script reaching a poll anywhere else inside a render scope still meets the wall backstop
  (the final review's C1). Where a runaway stops depends on the device and its
  load, as upstream's does: tests use the harness's fake clock (1 ms per interrupt check, the product's slice by
  default; `wr_test::ScopedProductSlices`, `stopAfter`) or, in Swift, a wall-clock-as-CPU fake (`useWallTimeAsCpu`),
  and compare costs on the thread's CPU clock (`wr_test::threadCpuMs`), never by a count. `CpuSliceTests`,
  `CpuQuotaTests`, `StopGuardTests` (the memory limit, the uncatchable stop and the count caps still stop),
  `//third-party/widget-sandbox:CpuBudgetTests` (the vendored `CpuBudget`), `LimitsTests` through the app (runaways
  stopped with upstream's message, on the real clock) and `:WidgetRuntimeNoWorkUnitsScanTests` (the deleted work-unit
  API does not come back) pin it.
  **Corpus check:** `//submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetCorpusTests` (size
  large, ~7 min) boots every widget-sandbox corpus file except `attacks` (`out-of-profile` included: the runtime must
  boot what the profile leaves out without stopping), taps a 4×6 grid and runs 1.2 s of timers and frames on the
  product's limits; it fails when an honest widget's largest step passes 125 ms (a quarter of the slice), its JS passes
  75 ms a second while it runs on, or it is throttled. `MessageWidgetTests` runs the `attacks`. Four files are
  exempt: the Hang button (`11-live-scripts/15-pixel-bare`, a runaway, stopped) and the Buggy button (`17-pixel-bare`,
  throws on purpose), per widget-sandbox's README; upstream's throttling demo (`16-pixel-bare`) and
  `12-motion-lab/09-mo-bare` (the grid's 24 taps a second of layout queries pass the main-thread window, as upstream
  charges them), from the throttle checks only. `knownGaps` lists, by message, the uncaught errors that are APIs not
  built yet.
  **Bounds:** the render limits (elements, form controls, `<style>` and text bytes, …) are `WidgetRuntime`'s, in the
  runtime record's "Limits". A message has one widget (registry path `[]`).
- **widget-sandbox v0.3.0's limits are counts, and the strict policy stops a widget past one** (`wr::Limits`,
  `Runtime/Limits.h`; the table with each cap's site is the runtime record's "Limits"). Under `strict`, the default
  (`MessageWidgetLimitPolicy`, passed to `MessageWidgetInstance` and `WRSession`): a text value of 32,768 UTF-16 units,
  48K of document text, an attribute or inline style of 8,192, 10,000 operations per batch (upstream's shim sends a
  flush's difference, so: a node's first insertion 2, a later insertion or removal 1, a move in one batch 1 in all, an
  attribute or a text changed in a batch 1 however often, a property of an inline style that predates the batch 1 each
  (a new style 1 in all), nothing for a node inserted in the same batch or removed from a tree outside the document (a
  fragment's), a sole text replaced by `textContent` 1, a canvas drawn on 1; a batch is a task, a frame, or what a layout query flushes), 400 CSS
  rules and 32 `@keyframes`, and canvases of 2048² pixels
  together stop the widget (`StopReason::Limit`), its reason upstream's text ("Ops limit exceeded: …"), which
  `WRSession.stopDetail` carries to the badge's dead reason; a stop before the first publish freezes with the badge
  alone, never the pill. 10,000 commands to one canvas in a task throw a `RangeError`; 64 timers, 64 live script
  animations (CSS animations are not counted), 4 KB of storage and an 8 MiB heap are the other strict counts, and a
  `data:` image claiming more than 1024² pixels (its header read, `Host/DataImageSize.cpp`) is the placeholder under
  either policy. `compat` keeps the old values and never stops; the stress kit's measure pass and tests of the
  renderer's worst case run under it (`wr_test::ScopedLimits`). The time limits are upstream's too (above).
- **The stress kit** (`MessageWidgetStress`, widget-sandbox `stress/`, CLIENTS.md): the widget harness's `-widget-stress
  measure|production` and DEBUG builds' Debug Settings ▸ "Run widget stress kit (measure)" and "(production)" run its
  127 widgets in a stand-in bubble and write a run file (`run.schema.json`) into the app's Documents (the Debug Settings
  entry shares it). The run files the maintainers ask for come from devices: no debugger, low power mode off, the device
  cool.
- **The master sheet ends in the renderer's UA layer** (widget-sandbox `profile.json` `tables.uaStylesheet`, generated
  into `ProfileTables.inc` with each `:where(X)` written as X and its `@layer tw-ua{…}` kept): root font and colour
  from the theme and text tokens, the body margin as the padding token, defaults for headings, lists, tables, quotes,
  `pre`, links (no underline) and `<button>`. Its `user-select: none` on the root makes text unselectable until the
  widget writes `user-select: text` (D18; profile 1's value sets, `css.values`, hold for every property that has one);
  such text selects in the lifted bubble ("Text selection" below). The bubble passes text tokens from the chat's message text (`messageWidgetTheme`: Text Size,
  line height 1.3, the text bubble's insets as padding), so a Text Size change alone is a theme change that lays the
  widget out again. In the master a `@layer` is an origin above litehtml's own rules whatever their specificity, and
  `revert` skips it (twidget edit 41), as a browser rolls an author layer back to its UA sheet; author rules win over
  all of it. Then comes the host sheet, the spec renderer's root CSS (`RenderOptions::hostCSS`, `RenderHost.h`):
  `html { display: flow-root; position: relative; min-height: 0 } head { display: none } body { display: block }`. The
  layer puts positional rules (`body>:first-child`, `td:last-child`) and a fractional line height (1.35) into every
  document; patching stays cheap and exact because a rule positional in its subject alone re-matches only the touched
  parent's other children (twidget edit 42), and the layer mirror repaints content moved by a fraction of a pixel
  rather than framing it (`LayerMirror::moved`). Test oracles that build a document beside the env read
  `env.render().options()` (its root declarations, which the layer's `var()`s need), never the construction's.
- **Visible = bubble visible ∧ view in a window ∧ app active.** The list's visibility is geometric (a chat under a
  pushed screen keeps it) and the app stays alive in the background during calls and audio, so the instance also
  follows its view's `didMoveToWindow` and `MessageWidgetApplicationState`, fed by one subscription to
  `applicationBindings.applicationIsActive` (`feedMessageWidgetApplicationState`). Hidden, a widget gets no frames and
  1 Hz timers.
- **Reduce Motion is the system's.** `MessageWidgetInstance` reads `UIAccessibility.isReduceMotionEnabled` when it is
  made and follows `reduceMotionStatusDidChangeNotification`; the runtime answers `prefers-reduced-motion` in `@media`
  and `matchMedia` from it (`WRSession.setReducedMotion:`, set before the boot for the first layout;
  `HostState::setReducedMotion` after it, which reports the lists whose answer flipped).
- **The renderer is twidget's litehtml fork** (Telegram for macOS's renderer, vendored in `third-party/twidget/`).
  `:litehtml_fork` (not `:litehtml`: APFS case collision with `:LiteHTML`) lays out the document `WidgetRuntime`'s
  `RenderTree` builds from its DOM. The ObjC++ `LiteHTML` layer is reused only through `LHHostSupport.h`
  (`LHHostContainer`, one `LHContainer` driven without an `LHDocument`): `WidgetRuntimeIOS`'s `CoreTextRenderHost`
  supplies fonts, text and ImageIO decoding, and `LayerTreePainter` the CoreGraphics drawing. Every local edit is
  numbered in `third-party/twidget/VENDOR.md`. Re-syncing: re-copy from twidget, re-apply VENDOR.md's edits, run both
  suites.
- **Rendering follows Chromium's answers, as widget-sandbox's conformance set encodes them**, held by the harness's
  ratchet. Its one partly is upstream's: a `data:` PNG in `auto/05-colour-backgrounds-b` is corrupt from its sixth row,
  which Chromium leaves transparent and ImageIO draws black. Right-to-left covers `direction`, `dir` (`auto`
  included) and each line's bidi order from our UAX #9 (`WidgetRuntime/Sources/Render/Bidi.cpp`,
  `document_container::bidi_levels`), not floats, absolutely positioned static positions or table columns. A
  `calc()` mixing a percentage with a length is a counted tree in `css_length` (16 bytes) of at most 64 nodes, because
  a cached declaration's one tree is evaluated for every element it styles at every layout. What still differs: the
  runtime record's "Rendering fidelity".
- **Intl's locale data is widget-sandbox's iOS glue, never ICU's formatting API.** The runtime keeps ECMA-402's option
  handling and asks `Host::intl` for everything locale-dependent, with the request upstream's shim sends; the session
  delegate (`MessageWidgetCore`'s `session(_:intl:)`) answers through `WidgetSandboxIntl`
  (`third-party/widget-sandbox/ios/`, Foundation only). App Store review rejects libicucore's
  `unumf_*`/`udat_*`/`ucol_*`/`ubidi_*`: they link, but only what the SDK's `unicode/*.h` declare is public.
  `build-system/Make/ICUImportCheck.py` fails `Make.py build` on any other libicucore import; bidi is our UAX #9
  (`WidgetRuntime/Sources/Render/Bidi.cpp`). **A request's unicode extension keeps only the keywords its constructor
  reads, with values from conservative tables** (`intl::resolveLocale`, ECMA-402 ResolveLocale). Upstream's shim sends
  the tag whole. In its glue, though, an unknown numbering system (`en-u-nu-bogus`) makes Foundation's relative
  formatter trap, crashing the app, and an extension breaks the plural rules (widget-sandbox VENDOR.md). The glue
  applies what is kept on iOS 16 and later. **A glue change or a new table value must keep `WRIntlExtensionTests`
  green**: it runs every call a widget can make with every CLDR numbering system, calendar, hour cycle and collation on
  iOS, and a trap there is the app's crash. The runtime record's Intl section has the protocol and the divergences.
- **Swift reaches the runtime only through `WRSession`**, on the widget's queue, one call at a time. It catches what
  C++ throws, latches `failed` and drops the runtime; every later call answers its empty default. A stop or failure
  after the boot published freezes the widget, and **a frozen widget is a picture**: `WidgetTreeRenderer` keeps its
  last tree and draws the badge over it in CoreGraphics at the bottom LEFT (a captionless widget's bubble draws its
  date pill at the bottom right, over the widget; sdk-v1 §5.7); the height is latched, touches are ignored, and a new
  width clips it rather than reflowing it. A snapshot's width is the layout width (`WidgetTreeRenderer.documentSize`),
  not the content's natural width; its height is the content's, rounded up and clamped to 50…600.
- **Tile rule.** `MessageWidgetView` shows 128 pt tiles whose `contents` are `CGImage`s made by a `.draw` task, each
  `WidgetTreeRenderer.image(rect:scale:)`: `LayerTreePainter` into a bitmap context of its own. Never paint the tree
  inside `CALayer.draw(in:)`: `LHContainer`'s box-shadow code converts offsets through the CTM and assumes an identity
  base CTM, which a layer backing context at 2x/3x lacks (shadows vanish). Tile memory follows the widget's area
  (≤ ~8 MB for 360×600 pt at 3x), whatever the CSS. The view's own layer has transparent 1x1 contents so touches
  arrive on iOS 26/27 (see "iOS 26/27 windows and touch delivery" in the root `CLAUDE.md`).
  A tile paints the whole tree clipped to its rect. **A draw's tiles share one `WREffectStore`** (twidget edit 64):
  each filter and backdrop result is made once per draw, only for the tiles it touches, and the bottom corners'
  colours are read from the drawn tiles (`WidgetTileDrawer.draw`); a store kept past its draw keeps its images. A box
  shadow with a blur past 24 device pixels is one low-resolution raster, whatever its sub-pixel position or rotation
  (edit 65); a smaller one is painted by every tile its ink reaches. On an animated widget, blurred effects are still
  the frame's cost (the runtime record's "Measured", paint cost per frame). **Measure paint cost in the widget
  harness's app process**: the hostless test processes have no Metal device and paint no CSS filter.
- **Every flush after the boot is incremental**: a patch of litehtml's render tree published as mirror operations.
  The runtime builds its litehtml document once, at the boot (`RenderTree::build`), and has no other build: a path that
  cannot patch hands the change to the next (the text and attribute path, the structure path, its walk of the cut), and
  a refusal at the last is an inconsistency that stops the widget with a `render-internal` diagnostic
  (`RenderTree::stopInternally`), as is a report the mirror cannot place (`LayerMirror::Inconsistent`). The fork never
  re-creates its render tree after the boot: a block-level child of a block formatting context inserted or removed is
  linked or unlinked alone (twidget edit 89), any other patch replaces the render subtree of its nearest boundary in
  place (edit 74), and the mirror re-places what they bring (`LayerMirror`'s file comment). A patch's time is the
  renderer's, never the widget's slice (above).
  `:WidgetRuntimeCorpusIncrementalTests` runs every corpus document and fixture (one build each, no inconsistency), and
  the randomized oracles (`testRandomEditsMatchARebuild`, `testOpsMatchAFreshMirror`) fail on any flush that builds or
  stops the widget. A fork predicate's refusal names its reason (twidget edit 76). A patch equals a
  fresh build in its style bytes too, and the elements it restyled reach the style-change step (CSS transitions) as a
  build's elements do. A patch near a cap cuts where a fresh build would: both hand the caps out in one order,
  counting only what renders (the runtime record's "A patch cuts where a build cuts").
- **The runtime opens nothing; the app asks Telegram's server for a widget in exactly two ways** (widget-sandbox v0.2;
  the user's decision, `docs/superpowers/specs/2026-10-26-message-widgets-v0.2-design.md` §4.A). Both requests go only
  to Telegram's server, carry only the bot's data and never a URL, and `openLink` always prompts.
  - **`messages.getBotWidgetQueryAnswer`** answers a widget's `TelegramWidget.request`, and (v0.5.0) reports a wallet
    call's outcome to the bot (the wallet below; its query type says which). The runtime's request gate (the
    vendored policy's `RequestGate`, `HostState::decideRequest`) admits it only in these cases:
    - on a tap, where the message's server flags say `can_query`;
    - without a tap, in the bot's private chat when the server sets `background_query`: one when the widget appears on
      screen, then at most one per 5 s while it stays visible. **One made while the widget is off screen waits for it to
      appear** (widget-sandbox v0.3.0, the gate's `Held`): it keeps its data and the in-flight slot and is sent from the
      task that shows the widget (`HostState`'s `setVisible(true)` → `RequestGate::show` →
      `TelegramWidget::sendHeldRequest`); a widget destroyed first sends nothing.

    One request is in flight at a time.
  - **`messages.getWidgetPublicData`** is polled for a widget on screen that has a `widget_id` and has called
    `watchPublicData()`: one message per `widget_id`, at the period the server returns.
  - **One way out.** Widget JS reaches native code only through the generated bindings, none of which resolves a URL.
    The only way out is the bridge (`MessageWidgetCore.bridge`):
    - `openLink` behind its prompt, `openTelegramLink` as a link in the message's text opens (below), one per tap;
    - `request`;
    - a wallet call (v0.5.0), on a tap or the gate's grant;
    - `copyText`, on a tap;
    - `watchPublicData`;
    - haptics.

    A preview (an inline result not sent yet) posts only `ready`. SDK v1 has no `sendMessage` (sdk-v1 §2.10).
  - **Loads.** Profile 1 decides the renderer's copy first (below): its hooks drop a remote `url()` declaration and an
    `@import` before any load is asked for, and `scanAttributes` turns a refused `<img src>` into the 48 px
    placeholder. An image's state is a browser's (widget-sandbox v0.2.3):
    - from a `src` change until its `load` or `error` fires from a task, it is pending: not complete, no natural size,
      drawn as nothing on a canvas, `null` from `createPattern`;
    - a newer `src` replaces the pending event;
    - a script's image loads before it is inserted, and a parsed one a script takes out before the window's load
      still loads; one of a `<template>`'s contents loads once moved into the document;
    - `width` / `height` are the rendered content size while the image is rendered (a layout query; while pending, 0
      for a dimension the CSS leaves auto), else the attribute, else the natural size;
    - at the window's load, an image whose `src` a handler changes fires once, for its new `src`.

    Behind it the runtime's litehtml container, `WidgetContainer`, is the boundary: it accepts only
    `data:` images of the profile's types (PNG, JPEG, GIF, WebP) and the placeholder, and refuses and counts every
    other load (`WRSession.refusedLoads`). `CoreTextRenderHost` decodes those under the image policy
    (`LHHostContainer::createImage`: ImageIO's sniffing, ≤ 4096 px a side and 16 Mpx; the placeholder, the one SVG it
    is handed, through `LHCreateSVGImage`) and keeps at most 24 MiB of decoded pixels alive per session
    (`kMaxDecodedImageBytes`): an image whose raster would pass what is left is refused before it is drawn
    (`createImage`'s `maxPixelBytes`). The app installs no script loader, so every external `src` is `script-skipped`.
  - **The runtime itself.** Nothing in `WidgetRuntime` may open a URL, a file or a socket
    (`:WidgetRuntimeNoIOScanTests`, a text scan); `InstanceTests.testAttackCorpusRequestsNothing` drives the attack
    pages under a recording `URLProtocol` and requires no request.
  - **The prompt.** A widget's `openLink` (≤ 4 KB) asks "Open link?" in the chat whatever the URL: the bubble passes no
    `message:` (a verified author skips the prompt) and sets `OpenUrl.forceConcealed` (`parseUrl` clears `concealed`
    for t.me, Telegram's other hosts and `tel:`). `ChatController`, `PeerInfoScreen` and the admin log
    (`ChatRecentActionsControllerNode`, which otherwise never asks) honour the flag, and `ChatController`'s
    link-options preview (`performOpenURL`, which fetches a preview of the URL) ignores such a link; the other
    `ChatControllerInteraction`s open nothing or show list items, not bubbles. A new opener of `OpenUrl` must honour
    it too. **`openTelegramLink` has no prompt of its own** (widget-sandbox v0.3.0): the bubble opens it as the message's
    own t.me link (`controllerInteraction.openUrl(OpenUrl(url:, concealed: false, message: item.message))`), so the
    chat's handling of t.me links decides, as for a link in the message's text; the runtime admits only t.me,
    telegram.me and telegram.dog URLs there (`Links.cpp`). `WidgetHarnessLinkTests` (`Fixtures/open-telegram-link.html`).
- **The message's context and state** (widget-sandbox v0.2). The bubble hands the registry the message's context
  (`messageWidgetContext`, `MessageWidgetMessageContextBuilder.swift`: the media's `isCopy` / `canQuery` /
  `backgroundQuery` as the server set them, the chat's type, the account as `viewer`) and its state (the media's
  `chatData` / `publicData`) on every main-thread pass. The context is part of the registry's key, so a context that
  changes (the server's flags on an edit) re-boots the widget; the state never is: a new state reaches the running
  widget through `setState` (its `chatDataChanged` / `publicDataChanged` events), never a re-boot, so a bot's edit
  keeps the widget's own state. The rules:
  - **The chat type is the peer's, mapped as upstream's.** `.user` and secret chats are `private`, a legacy group
    `group`, a channel `supergroup` or `channel` by its info; a chat with no peer has none.
  - **The viewer is the account's user, or id-only.** The chat history's first transition waits for
    `associatedData.accountPeer` (`ChatHistoryListNode` combines it in), so its passes have it. A list that passes none
    gets an id-only viewer (`item.context.account.peerId`), which the policy accepts. The viewer is part of the
    context, hence of the key, so a change to the account's own name, username or Premium restarts every widget on
    screen once.
  - **No network marker** (the user, 2026-10-29: "remove the network access icon/pill next to the date from all widgets
    even if they access network"; a recorded divergence from sdk-v1 §5.11). No widget shows one, `can_query` or not,
    and nothing in the widget area is the bubble's but the date and the corner box around it (the time over the widget,
    above; `testNoNetworkMarkerEvenWithCanQuery`).
  - **`copyText` copies only where the widget's text selection may** (the same `copyAllowed`: the chat's
    `isCopyProtectionEnabled`, the message's `isCopyProtected()`, verification codes excepted), and always says what
    it copied (`displayUndo(.copy(text:))`), so a widget cannot show one text and copy another unnoticed. Where copying
    is forbidden nothing reaches the pasteboard and the chat's own copy-protection notice shows instead.

  `WidgetHarnessStateTests` (Tier 1, `Fixtures/widget-state.html`) covers the state, an edit, the absent marker and the
  copy.
- **A request reaches the bot from the bubble** (W2). The bubble sends each admitted `request` through
  `MessageWidgetNetwork.requestAnswer`, whose default is `engine.messages.requestBotWidgetQueryAnswer`.
  `MessageWidgetRequests` holds each on a disposable of its own until its outcome reaches the widget. The rules:
  - **Exactly one outcome.** The engine's call maps the server's errors as the tag says (`WIDGET_RESPONSE_TIMEOUT` a
    timeout, `FLOOD_WAIT_*` a rate limit, anything else a failure) and fails a request still unanswered after 30 s.
  - **Flood waits are not waited out** (`automaticFloodWait: false`). Otherwise a short one would be waited out
    silently and the guard would fire first.
  - **A local message never reaches the server.** Its request fails at once (the DEBUG insertion's posts).
  - **Requests in flight are cancelled** when the node shows another message (its widget is destroyed) and with the
    node. A late answer reaches nothing, since a destroyed instance ignores `completeRequest`.
  - **The harness replaces the seam** (`WidgetHarnessNetworkTests`, `Fixtures/widget-request.html`). The engine's call
    is pinned in TelegramCore (`WidgetQueryRequestTests`), and the cancellation in `MessageWidgetRequestsTests`.

- **The wallet** (widget-sandbox v0.5.0, sdk-v1 §2.18, §5.13; the user's decisions of 2026-10-30 and 2026-10-31; the plan
  `docs/superpowers/plans/2026-10-30-message-widgets-v0.5.0.md`, its ledger's rulings). A widget pays
  (`TelegramWidget.wallet.sendTransaction`, TON Connect's transaction) or signs (`wallet.signData`, TON Connect's
  payload) through Gram Wallet, and `request(data, { wallet: true })` gives its bot the user's wallet card. The rules:
  - **Who has it.** The context's `wallet` (`MessageWidgetWalletAvailability`, per account and per owner, set by
    `AccountContextImpl`, whose release clears only its own answer: an older context of the account released after a
    newer one answered leaves the newer answer) is
    the app configuration's `wallet_available` ∧ a wallet context (the main app) ∧ a wallet this device can sign for
    (`WalletContext.widgetWalletReady`). The last is the user's call and a divergence from §5.13: without a signing
    wallet here `TelegramWidget.wallet` is null, so a widget never makes the server create a wallet. The context is
    part of a widget's key: the wallet set up or removed re-boots the widgets on screen once (the bubble's availability
    observer compares `laidOutWallet`; `testTheWalletSetUpReachesAWidgetOnScreen`).
  - **The runtime** checks every argument as upstream's shim does and runs the gate's grant (the runtime record's "The
    wallet"); a call that passes is `BridgeCall.wallet` with the checked TON Connect JSON
    (`MessageWidgetWalletCall`), answered through `completeRequest` with `.rejected` / `.badRequest` among the outcomes.
  - **The bot of the message** asks (`messageWidgetBot`): the via bot, else the author if a bot, else a forward's
    original author if a bot; none, `FAILED`. Its avatar, name and `@username` are the window's header; its id the
    signature's domain `bot<bot_id>`. Nothing the widget says reaches the window. **A channel post a bot sent names no
    bot** (its author is the channel, and the media carries no bot id), so its wallet calls are `FAILED` with no window:
    an open question for the maintainer (the bot's id on `messageMediaWidget`).
  - **The window is the TON Connect one** (`WalletTransferScreen` through `makeWalletTransferScreen`, pushed on the
    chat's navigation): `requester` puts the bot's avatar in its header and names it under the title
    (`WalletRequesterLineComponent`: the name on one line, shortened with an ellipsis to what `· @username` leaves it;
    when that is not even a few letters, `@username` alone, shortened in the middle only when even it does not fit, so
    its `…_bot` end stays; the name in the secondary colour, the username in the accent, so a long name, or one that
    reads like another username, neither pushes the real one off nor looks like it; the request's `domain` is
    `@username`, or the name when there is none), and `ignoresTouchesFor` (0.8 s, `MessageWidgetWalletWindow.ignoresTouchesFor`: counted from the
    push, the sheet's 0.22 s slide-in leaves about 0.58 s once it is in place, within §5.13's 0.5–1 s; measured on the
    iOS 27 simulator with Debug Settings ▸ "Show widget wallet window", which also showed the shield taking a Confirm tap
    and a dim tap on iOS 27) lays a clear shield over the
    whole window that swallows every touch, so the second tap of a double tap over the widget neither confirms nor
    reaches the chat behind the sheet (switching the window's interaction off would let it fall through). A dApp's window
    passes neither. Binary and cell payloads show its warning. **The window holds its call**
    (`MessageWidgetWalletWindowLifetime`, an associated object of the screen): a window that goes any way but its own
    buttons (an account switch, a navigation stack replaced) ends its call as declined, freeing the one-window flag and
    the widget's gate; once Confirm has begun it ends nothing, the send's own outcome does.
  - **A transaction goes out the wallet's own way** (the user: `wallet.sendTransfer`): `WalletContext.prepareWidgetTransaction`
    checks it against the wallet as a TON Connect wallet would, emulates it (`previewSend`) and registers a prepared
    transfer of all its messages (no gasless); `submitWidgetTransaction` sends it with `submitTransfer`, and the bot's
    query carries the server's message hash (`updateSentWalletTransaction`), never a local one. A signature is the TON
    Connect signing path's, for `bot<bot_id>`, and the query carries TON Connect's `SignDataResponse` with the card's
    public key and StateInit (`userWallet.state_init`).
  - **Outcomes:** a decline (or a cancelled passcode) `REJECTED`; the wallet's refusal before the window (expiry, another
    network or sender, a testnet or malformed destination, cells) `BAD_REQUEST` with no window. An emulation whose trace
    failed or did not finish opens the window with its warning, as a dApp's does. **A short balance offers the top-up**
    (§5.13; the user, 2026-10-31): the engine's preview refuses a transaction the balance cannot cover with its fees, so
    no window can show it (a dApp gets only a generic alert); `MessageWidgetWalletWindow.offerTopUp` shows the wallet's
    "Not Enough Grams" alert over the chat, whose Top Up pushes the wallet's receive screen, and the call is
    `BAD_REQUEST` at once (`WidgetWalletFailure.insufficientBalance`), so the user pays again with a new tap. After the
    confirmation a short balance does the same, only an expiry is still `BAD_REQUEST`, anything else `FAILED`, the
    window closed first so it shows no alert of its own. The query's own failures map as a request's. **A send whose server reply is lost** (`.submissionUnknown`: the transfer accepted
    with no `sentTransfer`) answers `FAILED` and asks the bot nothing, though the transfer may resolve later: §2.18's
    "may have been sent", which the bot settles from the chain by the card's address; reporting it once the wallet
    resolves it is a follow-up.
  - **The coordinator holds the call, not the bubble** (`MessageWidgetWalletCalls`): the bot's query that reports a
    payment is never cancelled with the bubble (`MessageWidgetRequests.cancelAll`), so money that moved always reaches
    the bot; a late answer reaches nothing. One wallet window at a time in the app: a call while one is up is
    `REJECTED`.
  - **Seams:** `MessageWidgetWallet.perform` (the window and the wallet; the harness's mock wallet) and
    `MessageWidgetNetwork.requestAnswer`, which takes the query type. `MessageWidgetWalletCallsTests` (the coordinator),
    `WalletWidgetCallsTests` (the wallet's pure parts), `WidgetHarnessWalletTests` (Tier 1, `Fixtures/wallet/pay.html`)
    and the runtime's `WalletTests` pin it; the window's look and its touch delay are checked on a device or the
    simulator, not by a test.
- **A shared widget's state is polled while it watches on screen** (W2; design §4 calls 3–4, upstream integration.md).
  The bubble subscribes to `MessageWidgetNetwork.pollPublicData` (default `engine.messages.pollWidgetPublicData`)
  exactly while all of these hold:
  - its message is a cloud message with a `widgetId`;
  - the widget's `MessageWidgetInstance.wantsPublicDataPolling` is true: it watches and is effectively visible, so not
    off screen, out of the window (a pushed screen) or with the app in the background.

  `onPublicDataPollingChange` (delivered on a later main-queue turn, as `onBridge` is, so never inside the layout pass
  before the bubble takes its item) and each applied item re-evaluate the subscription. TelegramCore's
  `WidgetPublicDataPolling` (held by `AccountViewTracker`; timing in the pure `WidgetPublicDataPollingState`):
  - polls one carrier per widget id: the first poll at once, with the hash of the state the message carries
    (`public_data_hash`, 2026-10-27 schema) or 0, then after each answer's period (5–3600 s), 30 s after a failure;
  - writes a new state into the stored widget of every registered message, so the bubble hands it to the widget through
    `setState` as any edit does, and records it as the message's edit (`recordMessageEdit`), so a history fill in
    flight does not write the older state back;
  - **never writes over a message's own state on registration.** Hashes are not ordered, so a message whose hash
    disagrees with the id's may carry the newer state. The disagreement owes a full poll (hash 0): at once, or after
    the poll in flight if that one answers "not modified", or when a widget comes back on screen while it is still
    owed. Its answer is written to every registration, and no message's hash is adopted until it goes. Only a message without a hash (stored before the 2026-10-27 schema) gets
    the id's latest state at once;
  - makes a widget back on screen within its id's period wait for the next poll.

  Pinned by `WidgetPublicDataPolling*Tests` (TelegramCore), `StateTests.testPollingInterestFollowsVisibilityAndWatching`
  and `WidgetHarnessNetworkTests` (`Fixtures/widget-watch.html`).
- **Forwards** (W2; design §4 calls 8, 10; tgw-format.md "a forward is a copy", "never forwarded without its author").
  - **The echo is the copy the server will make.** A forward's local echo, and the forward preview, show the widget as
    `TelegramMediaWidget.forwardedCopy()`: `isCopy`, no `canQuery`, no `backgroundQuery`, no chat state, its shared
    state and widget id kept (`EnqueueMessage`'s `forwardedMediaForLocalEcho`). Without this the echo of an original
    booted as a non-copy with the source's queries and chat state. The server's message brings its own flags (a live
    copy's `can_query` depends on `fwd_allow_queries`, which the client cannot see); the context changes, so the widget
    restarts once.
  - **The sender's header stays under "hide sender names"**, as for dice: the echo (`forwardKeepsSenderHeader`), the
    preview (`ChatControllerNode`), and the option itself is not offered for a selection of widgets and dice
    (`chatForwardOptions`, `PeerSelectionControllerNode`). The send path keeps the echo's header, so dropping it there
    would lose it until a refetch.
- **An inline result that is a widget is a preview** (W3; sdk-v1 §2.16, design §5 W3; the row shape is the user's,
  2026-10-27).
  - **The result.** `botInlineMessageWidget` parses to `ChatContextResultMessage.widget`: the widget with the result's
    state and no flags (a result is not a message), and its text. Sending it enqueues the widget as the echo's media
    (no queries). The server's message replaces the echo with its own flags, so the widget restarts once. A secret chat
    cannot carry a widget: the result sends its text alone, or nothing.
  - **The preview.** `MessageWidgetPreviewNode` (the bubble's module) runs the widget as a preview:
    - a registry of its own, keyed by the result: another result is another widget;
    - context `isPreview`, so no viewer and no chat type;
    - no storage and no bridge;
    - no touches: the node takes none, so a tap selects the result;
    - the app's language and stopped label, as the sent bubble has;
    - a widget only while on screen: the list's preload rows run none, a row leaving the screen stops its own, and a
      row shown again boots afresh, so a fling through many widget results runs only the visible ones. On screen is
      anywhere in the panel but behind the keyboard: in the room above the vertical list's first result (its top
      inset), which rows scroll up into, and under the input panel's glass (the user, 2026-10-29), which rows show
      through. The list is CoreList, whose visible rect counts its insets as visible; `visibleRectInsets` ends it at
      `ChatInputContextPanelNode.coveredBottomInset`, the part of the panel's bottom inset the keyboard (or the chat's
      own input, else the home indicator's strip) covers, which the chat sets before each layout. A row wholly inside
      the home indicator's strip with no keyboard up does not run. `ListViewItemCoreListHostTests` (the band, and
      `ListViewImpl`'s visibility formula on the hosted node), CoreList's `VisibleRectNotificationTests`;
    - a late snapshot (a boot past the pass's wait, a new height, a failure) re-runs its pass on a later main-queue
      turn, as the bubble's relayout does, so a late boot is not left at the 160 pt placeholder;
    - a widget that failed to start is remembered and never booted again for that result, when the failure lands
      while the row is on screen (a slow parse failing after the row left is parsed again on the next show).
  - **The vertical list.** A row with the result's title and the widget at its sent bubble's width and its own height,
    scaled down past `MessageWidgetPreviewLayout.maximumListHeight` (240 pt). The panel keeps each reported height, by
    result id, and re-lays that row out from it with no animation; a row scrolled out and back in is a new view, whose
    widget starts at that height. Ids are the bot's own, so the heights are dropped when results come from another
    bot (the panel stays for any list-presented results). A fixed height reports nothing. The list is CoreList with the
    chat's render-server scrolling (`.keyframe`, the user's call of 2026-10-29), its rows the `ListViewItem`s they were
    (`ListViewItemCoreListHost`: the item's own node, `ListViewImpl`'s tap highlight and selection), a short list
    stacked above the input panel (`stacksFromBottom`).
  - **The gallery strip.** A cell the size of an image result's widest crop, with the widget fitted inside and no peek.
  - **Layout off main.** The gallery strip lays out off main (the vertical list on main, in CoreList's pass), so a row's
    layout uses only the anchors and the height passed in, and the widget boots in the item's apply. A height report arrives one main-queue turn after the pass, never inside
    a list's apply.
  - **Elsewhere.** With the kill switch engaged, a widget result draws as any other result. The Mini App share preview
    shows its text.
  - **Tests.** Pinned by `ChatContextResultWidgetTests` (TelegramCore), `MessageWidgetPreviewLayoutTests` and
    `WidgetHarnessPreviewTests` (`Fixtures/preview/widget-preview.html`). The two panels live in TelegramUI, which has no
    test target.
- **A widget's storage is in its message's derived data** (`DerivedDataMessageAttribute["widgetStorage"]`,
  `MessageWidgetStorage`; by user decision), so it goes with the message, the chat and the account by itself. Three
  traps: an area with no entries is written as one, never removed, because Postbox's attribute merge re-appends a
  `DerivedDataMessageAttribute` an update leaves out; the area is one flat `[String]` (keys and values alternating),
  because Postbox's Codable adapter has no nested containers and an array of arrays traps when decoded; and the key
  must not be `"widget"`, which development builds used for widget sources in another shape. Writes never come from
  the admin log (synthetic ids that can name a real message) or a preview (`messageWidgetStoragePersists`); their
  areas are kept in memory under keys of their own (`Key.persists`) so they never become a real message's starting
  state. A widget keeps the commit sink it was made with, so a recycled node cannot store its areas under the next
  message; the sink is per stable id and follows the message's id, because a sent or forwarded message renders under
  its local id first and its widget keeps running when the cloud id replaces it.
- **The runtime is `WidgetRuntime`**: a C++ DOM built into our QuickJS fork (nodes are QuickJS objects, bindings
  generated from WebIDL by `build-system/WidgetIDL`), parsed by our gumbo fork (`third-party/gumbo`, changes 1–13),
  rendered by feeding litehtml the DOM and published as a `LayerTree`, plain data that outlives its document and the
  runtime. `MessageWidgetCore` drives it inside the widget's tasks. What SDK v1 still needs (the release checks, V6)
  is in the client spec's milestones. Its sharpest facts:
  - **gumbo's reconstruction re-clones attribute values**, so parse memory is bounded by attribute *bytes* (8 MiB);
    counting attributes alone lets a 256 KB document peak at 486 MB.
  - **A stop is final.** A CPU or layout-query stop, a count cap, out-of-memory or an internal failure latches the
    runtime; an allocation
    refused at the memory limit latches it inside QuickJS's allocator (fork change 9). From then on nothing is
    catchable by script, every poll site throws (fork change 10), and no step calls into JS, because QuickJS cannot
    drop queued jobs.
  - **Profile 1 is enforced on the renderer's copy, never on the DOM**: the DOM keeps what the widget wrote, while
    litehtml gets elements as `markup::renderTagFor` decides (kept, an inert span or div with `data-tg-tag`, or
    dropped with its subtree), attributes as `markup::renderAttribute` decides in `scanAttributes` (an external
    `a[href]` becomes `#` plus `data-tg-link`; a tap still reads the DOM's href), CSS through twidget edit 29's hooks
    answered by `css::policy` (keep, augment, rewrite or drop; `CSS.supports` agrees), images by one predicate
    (`imageSourceKept`) in layout and the DOM, and the strict text and node budgets in tree order. Each rule is one
    decision that the build, the patches and the render input read alike. litehtml's master, UA and host sheets are
    parsed once per process and cached, so the hooks pass them through whole (`trusted_styles`); every cache is keyed
    on the container's `sanitizer_key`. **Hooks are pure functions of their text and post no diagnostics** (litehtml
    caches their answers by text). There is no focus (`focus()` is a no-op). Record and divergences: the runtime doc's
    "Profile enforcement (V4)".
  - **The flush is atomic**, and the first one is in `boot`, after the parse and before any script, so a first script
    that never ends still leaves the parsed markup laid out. Its only script is the style-change step's (a `then` a
    widget defined, read as animations' promises settle), run in the step's slice (above).
- **Lifetime.** A widget lives as long as its bubble shows the same message (`MessageWidgetRegistry`, keyed by path +
  source + the message context, never its state; a new message stable id destroys it; a widget that failed to start
  is remembered, not re-booted). Height changes ride the layout (`reportedHeight`, then the height cache) and
  `requestMessageUpdate`.
- **Touches** follow widget-sandbox's shared gesture policy (sdk-v1 §5.5; the C++ copy, `twidget/gesture_policy.h`
  in `third-party/widget-sandbox/gesture/`, whose `claimOf` and `GestureArbiter` the runtime runs, thresholds included:
  slop 10 px, hold 500 ms, double tap 300 ms / 40 px, a 20 px leading strip). **Every tap and double tap over a live
  widget is the widget's**, on every element: `tapActionAtPoint` answers `.ignore`, so the bubble's tap recognizer fails
  at the down, and the quick reaction stays outside the widget (the caption, the time); the runtime sends `dblclick`
  after the second click. **A hold is by touch-action**: a press whose target or an ancestor up to `<html>` is
  `touch-action: none` claims it (`MessageWidgetPress.hold`): `hasLongTapAction` keeps the bubble's context gesture
  off, and the runtime sends `contextmenu` at 500 ms. Any other press's hold is the message's menu, at the chat's own
  timing (`ContextGesture`, not the policy's 500 ms: the user, "it should be as it is now"), and the menu taking the
  bubble (`willUpdateIsExtractedToContextPreview(true)`) ends the widget's touch with `pointercancel`
  (`MessageWidgetView.cancelTouches`); a press held 500 ms within the slop makes no click either way. A press starting
  in the widget's leading 20 pt claims nothing, whatever its touch-action. `takesTaps` (`TapState::takesTaps`: a
  listener on the press's path, the document's and the window's included, activation behaviour outside a disabled
  control, or a drag claim) now decides only whether the widget's recognizer recognizes at the touch's end, which fails
  the chat's own taps waiting on it (the keyboard's dismissal). The context gesture asks only at the touch's down,
  before the widget's recognizer has the touch, and UIKit decides which of the touch's recognizers hears it first: a
  question that finds no press starts it there and the recognizer adopts it (`MessageWidgetView.pressClaimsHold`,
  `MessageWidgetTouchRecognizer.pressAnswerOrBegin`), and while the touch is down its press answers wherever the
  question comes from (the press animation scales the bubble, so a held finger's point drifts). **The widget view takes touches
  through `MessageWidgetTouchRecognizer`, never `touchesEnded`:** a recognizer above the bubble recognizes every tap
  and cancels the touched view's touches, so a view-level widget sees began → cancelled and never clicks. The
  recognizer cannot be prevented by a tap, can be by a pan, and recognizes on the touch's end. A tap makes no `click`
  on or inside a disabled form control, as in browsers. **A finger's `pointerdown` is no gesture** (widget-sandbox
  v0.3.0's finger rule): a touch's or a pen's down carries no activation, so a link, request, copy or haptic from its
  handlers is refused; the gesture counts from the release (`pointerup`, `click`). A mouse's `pointerdown` still carries
  it (`Taps.cpp`, its `PressScope`). **A `contextmenu` carries none**, a finger's claimed hold or a mouse's secondary
  click (upstream numbers gestures for clicks, presses and releases only, and a call carries its own event's), so no
  link, copy or request comes from a hold before the finger lifts (`ActivationTests.testAContextMenuIsNoGesture`).
- **iPad pointers** (a trackpad or mouse: the user, "we should include it if possible for iPads with a trackpad"). A
  `UITouch` of type `.indirectPointer` presses as the policy's mouse (`MessageWidgetPointerKind`: `pointerType:
  'mouse'`, `mousedown`/`mouseup`, its button from `UIEvent.buttonMask`): there is no hold menu and no swipe, so its
  press answers `hold` and the horizontal claim whatever its touch-action (`MessageWidgetCore.touch`), and a press that
  claims its hold takes the touches at its down, failing the context gesture and the swipes above; a vertical drag
  still scrolls the chat. A secondary click claims holds only where a finger would (`none`: the widget's
  `contextmenu`); elsewhere its end opens the message's menu (`MessageWidgetView.onSecondaryClick` →
  `ChatMessageBubbleContentNode.secondaryTap` → the bubble's own secondary-tap path), since the bubble's tap
  recognizer, which handles secondary clicks elsewhere, fails over a live widget. The bubble's questions carry no
  touch: where the pointer last hovered (a pointer-only `UIHoverGestureRecognizer`) they get the mouse's answer and
  start nothing (`MessageWidgetPress.pointer`), so the press starts with the pointer's touch and its real button;
  elsewhere they start a finger's press, which a pointer's touch retracts before pressing again (`.retracted`,
  `WRPointerPhaseRetract`: a cancel to the widget, while the runtime restores its gesture arbiter as it was before that
  press, so a double click it came between is still one; a cancel proper ends a double tap, as the policy says). A
  mouse's secondary click where no hold is claimed is the message's menu from its down: the widget's press ends there
  with `pointercancel` (the policy's verdict's cancel, which a touch gets from the host's own recognizers). A press the widget did not answer in time (`.unanswered`, a busy game) claims its hold. No
  hover events reach the widget. XCUITest has no pointer: `TouchRecognizerTests` and `WidgetHarnessGestureTests` cover the host's side, a
  device the rest.
- **Several fingers** (the user: a game played with two thumbs). Each finger is its own pointer, up to five
  (`MessageWidgetTouchRecognizer.maximumTouches`, the runtime's `kMaxPointers`; another is ignored whole): its own
  pointer id (counting up per press), `pointerdown`, moves and `pointerup`/`pointercancel`, the first finger down while
  none is the primary, and only the primary clicks. In the runtime each press keeps its own target, capture, canceled
  defaults, `:active` entry (`UserActions`, removed by its own press's end or its element leaving the document; `:hover`
  follows the primary) and activation (`HostState::endPress` forgets a press's, so fingers can lift in any order).
  With one finger everything above holds unchanged. With two or more, the rules are the user's:
  - **The chat steps back**: a finger that lands while another is down, when either press claims its hold
    (`touch-action: none`, a game's control), takes the touches for the widget until every finger has lifted: the recognizers above fail (as for a
    claimed drag, but the chat's own pans until a finger moves sideways: see "The chat always scrolls" below), and every
    question the bubble asks meanwhile answers as the widget's (`tookTouches`, forgotten when
    the host takes the touches). `TapLongTapOrDoubleTapGestureRecognizer`, set to `.failed`, ends its highlight and stops
    its long-tap timer at once (a `state` observer keyed on the value set; a long tap it cancelled itself on a drift
    still reports), where UIKit would reset it only after every finger had lifted. A finger that slides sideways off
    its control, past the widget's edge too, stays the widget's. Two fingers landing in one event adopt the press the
    bubble's question started for one of them, whichever order UIKit hands them over.
  - **While the chat drags, no finger does anything**: a finger that lands while a pan above the widget has begun (the
    list's, swipe-to-reply, the back swipe) starts no press, nor does the bubble's early question for it, and a pan
    that begins while fingers are on the widget ends them as cancelled (the widget's recognizer on its next move; the
    lock for a held control, which may not move). Only a pan is a drag (`isChatDrag`): the bubble's tap waiting for a
    double tap leaves a single finger as it always was.
  - **A held control makes the rest of the chat inert**: while a finger's press claims its hold, the widget holds
    `MessageWidgetTouchLock`, and `MessageWidgetChatLockRecognizer` on `ChatControllerNode`'s view (the history,
    the panels and the top bar) makes every finger landing elsewhere in the chat inert until it lifts, even after the
    control's finger lifts: it fails what the finger reaches (cancels what has already begun there; the chat's own pans
    only once the finger moves sideways, so it still scrolls the chat), cancels it in its view and delays its
    `touchesBegan` while the lock is held (no highlight). Another widget in the chat is elsewhere too: it starts nothing while one
    holds the lock (`MessageWidgetTouchLock.isHeld(elsewhereThan:)`). The lock lifts on every end path, the widget view
    leaving its window included; a claimed drag and the chat-drag check spare the lock recognizer, and neither
    recognizer prevents the other. The system keyboard is a window of its own, out of the lock's reach.
  `WidgetHarnessUITests`' multitouch tests drive all of it (`Tests/WidgetHarness/Fixtures/multitouch.html`,
  `performFingers`).
- **Text selection is the lifted bubble's** (sdk-v1 §2.4, §5.10; the user, 2026-10-22: as in a text or rich bubble,
  Copy only, the widget keeps running). Lifting the bubble into its menu (`updateIsExtractedToContextPreview`) calls
  `MessageWidgetView.setExtracted(true)`: the widget keeps running and drawing but takes no input (a cancel still ends
  the press the lift interrupted), main waits for none of its tasks, and after every publish a `.selection` task
  exports what it lets the reader select (`RenderTree::selectableText` → `WRSession.selectableText` →
  `MessageWidgetSelectableText`). The export is the host's work: never waited for, outside the widget's slices, and it
  never stops or demotes the widget; it is linear in the text (`testTheSelectableExportIsLinear`). The bubble puts a `TextSelectionNode` over a `TextNodeProtocol` adapter of the
  export (`MessageWidgetTextSelectionAdapter`, swapped in place, since the node keeps its text node for good), as the
  rich bubble does its page. A selection follows the Text nodes its ends are in across exports, widened to whole
  characters, and is dropped when either goes; its menu stays where it appeared and Copy reads the live selection; the
  menu is Copy and Select All, and where the chat forbids copying nothing selects. One selection per bubble: a content
  node that begins one resigns the others' (`ChatMessageBubbleContentNode.resignTextSelection`, from
  `ChatMessageBubbleItemNode`). **Every un-lift path removes the overlay and dismisses its menu** (both extraction
  hooks, the widget replaced, stopped or turned into the pill): the overlay takes every point of the widget. A point
  within 4 pt of a word's glyphs hits it. Harness: `-harness-menu hold`, the `selectionMenu`/`copy` events,
  `WidgetHarnessUITests`' selection tests and `WidgetHarnessSelectionTests`.
- **The chat always scrolls** (the user, 2026-10-23: "widgets should not be able to prevent vertical scrolling,
  ever"; widget-sandbox v0.1.3's decision G2 since). A vertical drag is never a widget's, whatever it declares: the
  shared policy's `claimOf` never claims `y`, and its arbiter gives a vertical move to the chat even after a hold the
  widget won (`MessageWidgetCore` keeps only `x` regardless), and
  nothing on the widget's side stops one. When the widget takes the touches (a second finger, or a pointer press that
  claims its hold) or the lock takes a finger,
  every recognizer above fails as before but the pans inside the chat's view (`MessageWidgetTouchLock.chatView`, the
  lock recognizer's: the history's scroll, a bubble's swipe-to-reply); those wait for each finger's first 4 pt
  (`claimDistance`): sideways, they fail too (swipe-to-reply needs 10 pt), vertically they are left to begin
  (`MessageWidgetTouchRecognizer.failsAbove(_:pans:chat:)`). A pan on the chat's view or above it (the navigation's
  back swipe, which begins at 2 pt) fails at once. Each keeps pans out by exclusion (`canPrevent`) only once a finger
  went sideways (`preventsPans`): before, the widget's recognizer beginning for two fingers would fail every pan still
  possible, the chat's scroll included; from then, it is what keeps out a pan beginning in the same touch event, which
  failing it from inside that event does not (a claim sets it before beginning the recognizer, or a fast drag swipes
  to reply). The scroll then ends the widget's fingers as cancelled: the widget's recognizer on its next move, the
  lock for a held control. A horizontal
  claim fails the chat's pans with the rest, so after a finger went sideways the chat does not scroll until every
  finger lifts (UIKit fails a recognizer for the whole touch sequence): direction is decided by the first movement.
- **Drags are decided per press** (sdk-v1 §5.5). The runtime answers each press's claim once its down task has run
  (`TapState::claim`, `WRSession.gestureClaim`), by the policy's `claimOf` over the touch-action of the target and its
  ancestors up to `<html>`: `none` anywhere claims `x` and the hold, a value without a horizontal pan `x` (`pan-x`
  claims nothing), never `y`; a canceled `pointerdown` or `touchstart` claims `x`, never the hold; a press in the
  leading 20 pt nothing. Touch-action is read before the handlers run, as browsers fix it at touchstart. The host takes
  `x` and the hold only (above). Without `x`, a drag is the chat's (the list scrolls, swipe-to-reply and the back swipe
  work) and the widget's touch ends as cancelled. A horizontal drag on a claimed press begins the recognizer at 4 pt
  (`claimDistance`), which fails every recognizer still possible above it but the pans: exclusion alone does not,
  because `ContextGesture` recognizes alongside anything that is not a pan. For a press that leaves its hold to the
  bubble (`pan-y`) the non-pans, the menu's long press among them, fail only once the finger passes the policy's 10 pt
  slop (`dragSlop`, `sparesUntilSlop`), so a hold that drifted short of it is still the message's menu
  (`testAHoldOnPanYAfterASmallSidewaysDriftOpensTheMenu`). **4 pt, not the policy's 10:** the list's
  pan begins at about 10 pt and took a claimed drag whose decision came there too
  (`testAClaimedHorizontalDragIsTheWidgets`); the runtime still tells a tap from a drag by the 10 px slop, whoever holds
  the touch. **The back swipe and swipe-to-reply ask in their own `touchesBegan`, before the widget's recognizer has the
  touch**: `interactiveTransitionGestureRecognizerTest` and swipe-to-reply's `shouldBegin`
  (`ChatMessageBubbleContentNode.claimsHorizontalDrag(at:)`) start the press themselves
  (`MessageWidgetView.claimsHorizontalDrag(at:)`) and the recognizer adopts it; a claimed press keeps the back swipe to
  the screen's edge. Swipe-to-reply cancels the bubble's long press when it begins
  (`ChatMessageBubbleItemNode.swipeToReplyGesture`): its beginning does not fail `ContextGesture`, and on the CoreList
  chat the menu opened 0.23 s into every swipe over a widget. `WidgetHarnessUITests` drive all of it
  (`Fixtures/touch-drag.html`).
- **Local widget messages, for development** (DEBUG builds). Debug Settings ▸ "Insert widget conformance set" posts
  widget-sandbox's conformance channel (`conformance/channel.json`, parsed by `MessageWidgetChannel`, each widget
  followed by its reference pictures) to Saved Messages as Local-namespace messages through
  `engine.messages.debugInsertLocalWidgetMessages(peerId:posts:)` (`LocalWidgetMessages.swift`: nothing is sent,
  pictures are tagged like sent ones). "Insert widget games" posts the client's game examples
  (`Fixtures/11-tetris` to `14-pacman`, `WidgetGamesBundle`), to play with several fingers. Replying to or forwarding
  such a message is not supported (its local id and local media mean nothing to the server).
- **The widget harness** (`Tests/WidgetHarness`, its own [`CLAUDE.md`](../../../../Tests/WidgetHarness/CLAUDE.md))
  hosts the real chat bubbles (`ChatMessageItemImpl` → `ChatMessageWidgetBubbleContentNode`) over the composer
  harness's loginless app context, with the conformance set, the corpus or its fixtures, and a readout
  (`harness.readout`) that Tier 1 reads in process and Tier 2 (XCUITest) out of process. Develop and regression-test
  widget behaviour there, on K1, never K3.
- **Tests.** `Make.py test --target //submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests`
  (incl. `BubbleSizeTests`, `ChannelTests`, fixtures 01–05 within 4 pt of WebKit; `Fixtures/` holds examples 01–10),
  `…/MessageWidget:MessageWidgetCorpusTests` (the corpus check above), `…/WidgetRuntimeIOS:WidgetRuntimeIOSTests`,
  `//third-party/twidget:TwidgetRenderingTests`, `//submodules/TelegramCore:TelegramCoreTests`
  (`TelegramMediaWidgetTests`, `LocalWidgetMessagesTests`), `//submodules/ChatListUI:ChatListUITests` (the preview
  text), the Intl glue alone on the host (`./build-input/bazel-9.2.0-darwin-arm64 test
  //third-party/widget-sandbox:WidgetSandboxIntlTests`); the harness: `./build-input/bazel-9.2.0-darwin-arm64 test //Tests/WidgetHarness:WidgetHarnessTests
  //Tests/WidgetHarness:WidgetHarnessUITests`; host: `./build-input/bazel-9.2.0-darwin-arm64 test
  //third-party/twidget:TwidgetForkTests //third-party/twidget:TwidgetLitehtmlSmokeTests
  //third-party/quickjs-ng:QuickJSSmokeTests //third-party/quickjs-ng:QuickJSHostTests
  //third-party/widget-sandbox:CpuBudgetTests` (not `//third-party/twidget:all`: it includes the iOS test).
  `WidgetRuntime`'s own host suites (`:WidgetRuntimeTests`, the WPT runner, the render gates, the gumbo and twidget
  fork tests) are in the runtime record's "Tests".
