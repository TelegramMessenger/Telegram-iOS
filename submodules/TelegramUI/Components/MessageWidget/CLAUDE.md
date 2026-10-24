# Message widgets (`messageMediaWidget`)

A widget message carries `messageMediaWidget width:int height:int payload:bytes` (layer 233): a bot's size anchors and
the widget's HTML, compressed by the server: a zlib stream (PHP's `gzcompress($html, 9)`; gzip before widget-sandbox
v0.1.3). It is the only way widgets are delivered. TelegramCore stores it as `TelegramMediaWidget` (Postbox keys `w`,
`h`, `p`; `html()` inflates zlib or gzip, checking the header first, with no size check of its own; a local message is
compressed as the server does, zlib at level 9, through the SDK's `zlib`, never Compression's `COMPRESSION_ZLIB`, which
is raw deflate);
`ChatMessageWidgetBubbleContentNode` draws it as a live widget in a bubble of its own, the message's text as its
caption below. The authority is widget-sandbox, vendored at tag v0.1.3 in `third-party/widget-sandbox` (`corpus/`,
`conformance/`); the client's spec is `docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`
(milestones V1–V6; §8, §9 and §10 hold this client's v0.1.1, v0.1.2 and v0.1.3 decisions). The runtime, `WidgetRuntime`, has its own record:
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
  bubble's. Height 0 is the widget's own: 160 pt until it reports, then the reported height clamped to 50…600 and
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
  **The chat keeps that edge everywhere, at its bottom too** (the user: "The anchor should win if scrolled to bottom
  too"): a top-anchored newest widget that grows leaves the chat scrolled up by its growth. Three rules around it,
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
  and its old tiles sit on the anchored edge until the new ones are drawn (`MessageWidgetView.tileOffset`). A chat that
  fits the screen cannot scroll, so there the list's own placement decides. `WidgetHarnessResizeTests` (Tier 1,
  `Fixtures/resize/`), `testTheFaqsQuestionStaysUnderTheFinger` and `testAFlingPastAResizingWidgetKeepsItsMomentum`
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
  within one allowance per run-loop turn: 1,000,000 units of the waited tasks' own work (the uncharged parse counted)
  and a 20 ms cap that is never a verdict (`MessageWidgetWaitPolicy`, `MessageWidgetTurn`, reset at `beforeWaiting`).
  A task not done goes on, and its snapshot is applied later from the handshake's mailbox, before anything newer. The
  handshake's `drain()` is not re-entered: a task run while it applies (a snapshot asking for its draw) mailboxes its
  result behind the ones still to apply.
  **Only the size is on the critical path** (by user decision): a snapshot carries size and state, never tiles;
  applying one with `needsDraw` queues a `.draw` task main never waits for, which draws the changed 128 pt tiles in
  parallel (`WidgetTileDrawer`), so a size change can show the old tiles for a frame. A boot not done is the offered
  width × 160 pt (`MessageWidgetInstance.placeholderHeight`); its late snapshot moves `layoutVersion` so the bubble
  lays out again (a late start failure too, which then shows the pill). Taps always wait and carry their permission;
  timer ticks and frames wait unless the widget is hidden or demoted (a timer, wake or frame task past 1,000,000 units,
  its whole drain, which is what main waits for, demotes it for good; boots and taps never do). Keyed tasks (`timer-<id>`, `wake`, `frame`, `visibility`, `width`,
  `draw`) replace one still queued, and one frame task is in flight at a time. Tests run each widget on a pool of its
  own with `.unbounded` (each wait ends with its task); background-path tests pass a capped policy and hold a task
  with `gateNextTaskForTesting()` (never with `.unbounded`: main would wait for a task that waits for main).
- **A hostile message must not crash, freeze or exhaust the app, and every limit on its JS is a budget of work, never
  of time** (user decisions: fully deterministic, per-task limits only, **no rate limits**). Whether a widget is
  stopped depends on what it does, never on device speed, thread or machine load (`DeterminismTests`). The unit is
  QuickJS's work counter (`third-party/quickjs-ng` VENDOR.md change 2): 1 per interrupt poll (calls, branches, loop
  back-edges), 1 per 4 bytes allocated, and charges inside every native builtin whose work grows with its input (list
  in VENDOR.md). `WidgetRuntime` charges its own native work in the same units, before doing it
  (`wr::charge`/`chargeScan`; the per-binding-call, per-node, per-selector, per-byte and per-box rates are in
  `WidgetRuntime/Sources/Support/Work.h`). **Budgets** (`MessageWidgetCore`; tests replace them via
  `budgetsForTesting`; a million units is ~10 ms at the cost suite's reference rate), each set so the corpus's largest
  honest task of its kind stays under a quarter of it:
  - **parse** of the markup, `parseWorkUnits` 400,000,000: ours, not charged to the widget (by user decision), a
    ceiling no honest widget nears; past it nothing is published and the widget does not start (`.failedToStart`, the
    pill). The client adds no source-size check of its own, so this also bounds a source's size;
  - **boot** (its scripts, then `load`, on one budget; what the layout pass waits for), `bootWorkUnits` 48,000,000;
  - every later **step** (an event, timer, frame, or a width or theme rebuild), `taskWorkUnits` 28,000,000. One core
    task's drain runs at most 256 steps (`maximumStepsPerTask`) and stops once it has spent one task budget, so a
    widget that keeps a task runnable cannot hold its queue.

  A session's memory limit is 64 MiB (`WRSession`); a memory stop is fatal. The budget is read at QuickJS's interrupt
  poll (every 100 polls: `JS_INTERRUPT_COUNTER_INIT=100`, change 1) and at every native charge; once it stops the
  widget nothing is catchable by script (change 10), so no `try`/`catch` keeps a loop going. **With no clock behind
  it, an uncharged native path is an unbounded freeze** (a one-line `trim` on 4 MB, BigInt division or `join` on
  `{length: 2**40}` runs for hours without its charge). A new native path, in `WidgetRuntime` or QuickJS, needs its
  charge and a row in a cost suite; a QuickJS change or upgrade also needs a run of the native-path sweep
  (`//third-party/quickjs-ng:QuickJSNativeSweep`, manual, `-c opt`, quiet machine), which calls every builtin with
  large inputs and reports any call slow per unit or never ending.
  **Calibration:** each rate holds its attack to at most 2× the reference loop's wall time per unit:
  `QuickJSWorkCostTests` (host, `-c opt`, an alarm per attack so a hang fails) for QuickJS's rates,
  `:WidgetRuntimeWorkCostTests` (manual, `-c opt`) for `WidgetRuntime`'s, and `LimitsTests`'
  `testAHostCallLoopCostsNoMorePerUnitThanJS`/`testAWordDenseRebuildLoopCostsNoMorePerUnitThanJS`
  (`MessageWidgetTests`) through the app. They are wall-time ratios (best of three): under machine load, suspect noise
  before a regression.
  **Corpus check:** `//submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetCorpusTests` (size
  large, ~6 min) boots every widget-sandbox corpus file except `attacks` (`out-of-profile` included: the runtime must
  boot what the profile leaves out without stopping), taps a 4×6 grid and runs 1.2 s of timers and frames on lifted
  budgets; it fails when an honest widget passes a quarter of a budget. `MessageWidgetTests` runs the `attacks`. Two
  files are not honest widgets, per widget-sandbox's README: the Hang button (`11-live-scripts/15-pixel-bare`, a
  runaway, stopped) and the Buggy button (`17-pixel-bare`, throws on purpose). `knownGaps` lists, by message, the
  uncaught errors that are APIs not built yet; `testWhatTheParseCostsPerByte` prints the uncharged parse per folder.
  **Determinism:** the runtime reads no clock; the host hands each step its `now`. Counts can still shift with the
  system allocator across OS versions (QuickJS reads usable sizes for its GC threshold and in-place string appends).
  **Bounds:** the render limits (elements, form controls, `<style>` and text bytes, …) are `WidgetRuntime`'s, in the
  runtime record's "Limits". A message has one widget (registry path `[]`).
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
  (`WidgetRuntime/Sources/Render/Bidi.cpp`). **A request never carries a unicode extension** (`intl::resolveLocale`):
  on a tag like `ar-EG-u-nu-arab` upstream's glue and Foundation itself trap, which crashes the app. Passing
  extensions on waits for upstream's glue to build its locale with `Locale.Components`; see widget-sandbox's
  VENDOR.md. The runtime record's Intl section has the protocol and the divergences.
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
- **No network, ever.** A widget can never cause a network request from the device, and `openLink` always prompts.
  - **One way out.** Widget JS reaches native code only through the generated bindings, none of which resolves a URL.
    The only way out is the bridge: `openLink` behind its prompt, one per tap (`MessageWidgetCore.bridge`). SDK v1 has
    no `sendMessage` (sdk-v1 §2.10).
  - **Loads.** Profile 1 decides the renderer's copy first (below): its hooks drop a remote `url()` declaration and an
    `@import` before any load is asked for, and `scanAttributes` turns a refused `<img src>` into the 48 px
    placeholder. Behind it the runtime's litehtml container, `WidgetContainer`, is the boundary: it accepts only
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
    it too.
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
  - **A stop is final.** A budget trip, out-of-memory or an internal failure latches the runtime; an allocation
    refused at the memory limit latches it inside QuickJS's allocator (fork change 9). From then on nothing is
    catchable by script, every poll site throws (fork change 10), and no step calls into JS, because QuickJS cannot
    drop queued jobs.
  - **Profile 1 is enforced on the renderer's copy, never on the DOM**: the DOM keeps what the widget wrote, while
    litehtml gets elements as `markup::renderTagFor` decides (kept, an inert span or div with `data-tg-tag`, or
    dropped with its subtree), attributes as `markup::renderAttribute` decides in `scanAttributes` (an external
    `a[href]` becomes `#` plus `data-tg-link`; a tap still reads the DOM's href), CSS through twidget edit 29's hooks
    answered by `css::policy` (keep, augment, rewrite or drop; `CSS.supports` agrees), images by one predicate
    (`imageSourceKept`) in layout and the DOM, and the strict text and node budgets in tree order. Each rule is one
    decision that a rebuild, the patches and the render input read alike. litehtml's master, UA and host sheets are
    parsed once per process and cached, so the hooks pass them through whole (`trusted_styles`); every cache is keyed
    on the container's `sanitizer_key`. **Hooks are pure functions of their text and post no diagnostics** (litehtml
    caches their answers by text). There is no focus (`focus()` is a no-op). Record and divergences: the runtime doc's
    "Profile enforcement (V4)".
  - **The flush is atomic and runs no JS**, and the first one is in `boot`, after the parse and before any script, so
    a first script that never ends still leaves the parsed markup laid out.
- **Lifetime.** A widget lives as long as its bubble shows the same message (`MessageWidgetRegistry`, keyed by path +
  source; a new message stable id destroys it; a widget that failed to start is remembered, not re-booted). Height
  changes ride the layout (`reportedHeight`, then the height cache) and `requestMessageUpdate`.
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
  on or inside a disabled form control, as in browsers.
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
  `MessageWidgetSelectableText`). The export is the host's work: never waited for, on a budget of its own
  (`MessageWidgetCore.selectionWorkUnits`, 6,000,000) that never reaches the widget's meter, stops it or demotes it;
  past it, that layout selects nothing. The bubble puts a `TextSelectionNode` over a `TextNodeProtocol` adapter of the
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
  followed by its reference pictures) to Saved Messages, and "Insert widget corpus" the corpus, as Local-namespace
  messages through `engine.messages.debugInsertLocalWidgetMessages(peerId:posts:)` (`LocalWidgetMessages.swift`:
  nothing is sent, pictures are tagged like sent ones). "Insert widget games" posts the client's game examples
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
  //third-party/quickjs-ng:QuickJSWorkTests //third-party/quickjs-ng:QuickJSSmokeTests`, and the cost suite optimized,
  `… test -c opt //third-party/quickjs-ng:QuickJSWorkCostTests --test_output=all` (not `//third-party/twidget:all`: it
  includes the iOS test). `WidgetRuntime`'s own host suites (`:WidgetRuntimeTests`, the WPT runner, the render gates,
  the gumbo and twidget fork tests) are in the runtime record's "Tests".
