# Message widgets: the native runtime (`WidgetRuntime`)

A native runtime for message widgets on iOS. It is a C++ DOM built into our QuickJS fork, parsed by our gumbo fork,
and rendered by feeding litehtml the DOM directly, with no JavaScript sandbox, no JavaScript validator and no HTML
in between. Its design was approved 2026-10-16 and amended 2026-10-17 (there is no validator, and the runtime owns
litehtml's container and outputs a layer tree) and 2026-10-18 (no comparison harness against the old runtime, and the
switch in M1d with no flag); this document is its record. It was built in milestones M1a–M1d, then the widgets v0.1.0
client's V milestones.

**Status (2026-10-19): M1a to M1d are done, and the app runs every message widget on `WidgetRuntime`.** Since V1 of
the widgets v0.1.0 client (spec `docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`) a widget
arrives as `messageMediaWidget` in a
bubble of its own, on by default since 2026-10-22 (only the app config's kill switch turns it off); `submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`
has the client side. V1 changed three runtime facts recorded below: the host sheet is the spec renderer's root CSS, a widget's height
is clamped to 50…600, and there is no source cap. V1 also re-vendored widget-sandbox at tag v0.1.0 (237 listed
files, 99 attacks, 19 compat, 9 out-of-profile, and the conformance set); the corpus suites pass on it, but the
measurements below (230 documents, 93 attacks) were taken on the earlier corpus and are not re-measured.
Since V4 (2026-10-21) profile 1 is enforced on the renderer's copy of the document, never on the DOM: "Profile
enforcement (V4)", below, which replaces M1c's "there is no validator"; "Divergences from widget-sandbox v0.1.0" lists
where it differs from the reference on purpose.
The old runtime (widget-sandbox's JavaScript shim and trusted validator, `MessageWidgetEngine`, `WidgetDOM` and the
ops-fed `MessageWidgetRenderer`) is deleted from the app (spec D14); what the corpus still trips on is below. M1a
built:
- the QuickJS fork changes for engine built-in interfaces (changes 3–5);
- the WebIDL binding generator;
- the core DOM (nodes, tree algorithms, attributes, collections);
- gumbo parsing straight into the DOM;
- serialization (`innerHTML`, `outerHTML`, `insertAdjacent*`);
- selectors (`querySelector*`, `matches`, `closest`).

M1b built:
- the `Window` global, a host-class global object (QuickJS change 6);
- deterministic time and randomness hooks (change 7);
- the final stop: an uncatchable error through a `Promise` executor (change 8), a hook at the memory limit (change
  9), nothing catchable once stopped (change 10); charged walks of the loaded modules (change 11, removed 2026-10-30
  with the work units); and the same memory in every build configuration, with no dumps unless asked for (change 12);
- callbacks, `[Global]`, `[LegacyUnforgeable]` and `[Replaceable]` in the generator;
- `EventTarget`, `Event` and dispatch, and inline `on*` handlers;
- the event loop: tasks, the microtask checkpoint, timers, animation frames;
- error and rejection reporting;
- script elements and the boot sequence;
- a headless WPT runner (`:WidgetRuntimeWPTTests`, ratcheting `wpt-expectations.txt`).

M1c built the rendering, in `Sources/Render/`:
- `RenderTree`: the main document built into one litehtml document element by element (no HTML string, no
  validator), the node↔element maps, the mutation journal and the flush, with in-place paths for text, attributes and
  inline style, and inserted, removed and moved subtrees, each equal to a fresh build;
- `WidgetContainer`, the runtime's own litehtml container, and `RenderHost`, the interface the app implements for fonts,
  text, images and path containment (a deterministic `FakeRenderHost` in the tests);
- `LayerTree`, plain data that the app paints, kept current by operations (`LayerMirror`: `Insert`, `Remove`, `Move`,
  `Frame`, `Content`, `Clip`, `Group`; the boot's publish is `Insert`s of the whole tree) and published with the rects
  that changed;
- hit-testing and boxes (`nodeAt`, `borderBox`, `clientRects`), read from the published layout;
- the render limits, the corpus and attack gates, and a scan that nothing in the runtime does I/O;
- twidget edits 12–21 in the litehtml fork.

M1d switched the app to it:
- in `WidgetRuntime`: the host's side of rendering (`RenderTree::contentSize`, recording pixel-snapped at
  `RenderOptions::pixelSnapScale`; a work observer, removed 2026-10-30 with the work units); UI events and taps
  (`Sources/Events/Taps.*`, `UIEvents.*`); activation, the default actions, the focus model and the user-action
  pseudo-classes (`UserActions.*`); the `TelegramWidget` bridge (`Sources/Host/TelegramWidget.*`); and
  `element.style` (`Sources/DOM/StyleDeclaration.*`), pulled forward from M2 (the user, 2026-10-19);
- `WidgetRuntimeIOS`, the platform half: `CoreTextRenderHost` (the `RenderHost`, from `LHContainer`'s text and image
  code), `LayerTreePainter` (a published tree into a `CGContext`, through `LHContainer`'s drawing code) and `WRSession`,
  the one facade Swift calls;
- in the app: `MessageWidgetCore` drives `WRSession`, `WidgetTreeRenderer` keeps the published tree and draws the frozen
  badge, and the tiles are drawn by a task of their own that main never waits for: only the size is on the critical
  path (the user, 2026-10-19);
- the old runtime deleted: the shim and validator bundles, `MessageWidgetEngine`, `TrustedValidator`,
  `QuickJSContext`, `WidgetDOM`, `MessageWidgetRenderer`, `MessageWidgetDocument` (spec §4 lists every file).

Each milestone's plan and carry-over (its rulings, deferred items and measurements) stayed with the development
branch, `feature/message-widgets`; what still binds the code is recorded here.

## Where things are

| Path | What |
|---|---|
| `submodules/TelegramUI/Components/MessageWidget/WidgetRuntime` | The runtime. `Sources/Support` (values, errors, `JSAllocator`), `Sources/Runtime` (the runtime, its counted caps, its CPU limits and clocks: `Limits.h`, `CpuLimits.h`), `Sources/DOM`, `IDL/` (the WebIDL it binds), `Tests/` |
| `build-system/WidgetIDL` | The WebIDL → C++ binding generator (Swift), run by a Bazel genrule |
| `third-party/quickjs-ng` | QuickJS fork, changes 1–12 in `VENDOR.md`; since 2026-10-30 change 1 (the interrupt poll every 100 operations) is reverted to the stock 10,000, and changes 2 (the work counter) and 11 (charged loaded-module walks) are removed. M1a added change 3 (host auto-init), change 4 (class prototype on first use) and change 5 (string access). M1b added change 6 (a host-class global), 7 (host time and randomness), 8–10 (the final stop: a `Promise` executor, the memory-limit hook, nothing catchable once stopped), 11 (charged loaded-module walks, since removed) and 12 (no dumps unless asked for, so every build configuration counts memory the same) |
| `third-party/gumbo` | gumbo fork (moved out of twidget's litehtml in M1a; litehtml links it). Changes 1–13 in `VENDOR.md` |
| `third-party/wpt/interfaces` | WPT IDL, vendored at d2727a54348e (2026-10-15). `IDL/README.md` lists every rewrite of it |
| `…/WidgetRuntime/Sources/Events`, `Sources/Host` | M1b: `EventTarget`, events and dispatch, handlers; `HostState`, `Window`, the event loop, timers, frames, scripts, boot |
| `…/WidgetRuntime/Sources/Render` | M1c: `RenderTree` (`RenderTree.*`, `Builder.*`, `Journal.*`, `HitTest.*`), `WidgetContainer`, `RenderHost.h`, `DataUrl.*`, `RenderDump.*`, `LayerTree.*`, `LayerMirror.*`, `LayerDiff.*`. `Tests/FakeRenderHost.*` and `RenderHarness.*` are the fake host and `RenderEnv` |
| `third-party/twidget` | The litehtml fork (`LiteHTML/litehtml`), edits 1–21 in `VENDOR.md`. M1c added edits 12–21 and their host tests (`tests/*_test.cpp`, the `Twidget…Tests` targets) |
| `third-party/wpt/{resources,common,dom,html,css}` | The WPT tests the runner runs, vendored at the same commit (`FILES.txt` lists every blob id); `css/cssom/` is the inline style block's tests (M1d) |
| `…/WidgetRuntime/wpt-expectations.txt`, `wpt-skip.txt` | The WPT results, per subtest, that only ratchet up; the tests not run, with reasons |
| `…/WidgetRuntime/Sources/Events/{Taps,UIEvents,UserActions}.*` | M1d: taps and the UI events; activation, the default actions, focus and the user-action state |
| `…/WidgetRuntime/Sources/Host/TelegramWidget.*`, `IDL/telegram.webidl` | The SDK (V2a, widget-sandbox v0.1.0 sdk-v1.md): `TelegramWidget` v1, `HapticFeedback`, `navigator` (`language`, the clipboard and sharing refused) |
| `…/WidgetRuntime/Sources/Host/{Links,ThemeParams,Storage,Inert}.*` | V2a: the link rules and routes, the theme palette, Web Storage, and the network and dialog APIs that do nothing |
| `…/WidgetRuntime/Sources/Host/{Crypto,Base64,Encoding,StructuredClone,URL,URLParser,Abort,Blob,Sequences}.*`, `IDL/builtins.webidl` | V5a: the built-ins, each against its own standard |
| `…/WidgetRuntime/Sources/Host/{Intl.h,IntlCore.cpp,IntlNumberFormat.cpp,IntlDateTimeFormat.cpp,IntlText.cpp}`, `third-party/widget-sandbox/ios/` | V5b: Intl over widget-sandbox's `intl` capability (`Host::intl`), answered in the app by widget-sandbox's iOS glue |
| `…/WidgetRuntime/Sources/Host/ICU.h`, `…/Sources/Render/Bidi.{h,cpp}` | The system ICU's public part (character properties, case mapping, IDNA) and UAX #9 over it |
| `…/WidgetRuntime/Sources/Canvas/`, `…/WidgetRuntimeIOS/Sources/CanvasBitmap.{h,mm}` | V5d: Canvas 2D (the interpreter, the context and its objects, the canvas and img elements) and the iOS bitmap |
| `…/WidgetRuntime/Sources/Animation/`, `IDL/web-animations.webidl`, `Sources/Support/Promises.*`, `third-party/wpt/web-animations` | V5e: Web Animations (the objects, easing, interpolation and timing, the per-runtime `AnimationState` with the update step and the sampler) and its WPT; `Sources/Animation/PROVENANCE.md` lists what is ported from where |
| `…/WidgetRuntime/Sources/Animation/CSS*.{h,cpp}`, `IDL/css-animations.webidl`, `third-party/wpt/css/css-{animations,transitions}` | V5f: CSS animations and transitions (the `@keyframes` and declaration parsers, `CSSAnimation`/`CSSTransition`, the style-change step and the events) and the event interfaces' WPT |
| `…/WidgetRuntime/Sources/Host/{CSSNamespace,CSSSupports,Profile}.*`, `ProfileTables.inc`, `IDL/generate-profile-tables.py`, `Sources/DOM/CSSComponents.*`, `third-party/widget-sandbox/profile/profile.json` | V5c: the `CSS` namespace, profile 1's tables and their generator, and the component-value pipeline shared with the selector parser |
| `…/WidgetRuntime/Sources/Host/{CSSPolicy,MarkupPolicy}.*`, `third-party/twidget` edit 29 | V4: profile 1 on the renderer's copy: the CSS verdicts the fork's hooks ask for, and the element and attribute rules |
| `…/WidgetRuntime/Tests/{URLDataTests.cpp,url-data-expected-failures.txt}`, `third-party/wpt/url/resources/` | V5b: WPT's URL data through `URL` (`:WidgetRuntimeURLDataTests`), and the cases it still fails |
| `…/WidgetRuntime/Sources/Runtime/PairIterators.cpp` | V5a: WebIDL pair iterators (`iterable<K, V>`), with the generator's adapters |
| `…/WidgetRuntime/Sources/DOM/StyleDeclaration.*`, `IDL/cssom.webidl`, `IDL/css-properties.txt` | M1d: `element.style`. `IDL/cssom-properties.webidl` and `Sources/DOM/CSSProperties.inc` are generated from the property list by `IDL/generate-css-properties.py` and checked in |
| `submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS` | M1d: the iOS half. `Sources/CoreTextRenderHost.*` (the `RenderHost`), `Sources/LayerTreePainter.*` (the painter), `Sources/WRSession.mm` and `PublicHeaders/WidgetRuntimeIOS/WRSession.h` (the facade), `Tests/` (`:WidgetRuntimeIOSTests`) |
| `third-party/twidget/LiteHTML/LHHostSupport.h` | M1d: `LHHostContainer`, one `LHContainer` behind a textual C++ header for the host and the painter; its implementation is appended to `LHContainer.mm` |
| `…/MessageWidget/MessageWidget/Sources` | The app's widget: `MessageWidgetCore` (on `WRSession` since M1d), `MessageWidgetInstance`, the pool, handshake, registry and view; `WidgetFrame.swift` holds the tile drawer (`WidgetTileDrawer`) |
| `…/MessageWidget/MessageWidgetRendering/Sources/WidgetTreeRenderer.swift` | M1d: a session's published tree, its height and changed rects, and the frozen badge |

## How it works

- **Nodes are QuickJS objects** whose payload is a C++ object. Interfaces are engine built-ins: static generated
  tables, an auto-init global entry per interface name, and each class's prototype made the first time it is used.
  A widget pays only for the interfaces it touches.
- **Bindings come from WebIDL.** `IDL/*.webidl` are hand-kept subsets of the vendored WPT IDL. The generator emits
  the glue and the C++ classes implement the members. Indexed interfaces get `@@iterator` =
  `Array.prototype.values`.
- **Parsing.** gumbo's output tree is built into DOM nodes directly. Adjacent text runs merge into one node. Template
  contents live in an inert owner document. Fragment parsing follows HTML's context rules. Scripts from fragment
  parsing are inert.
- **Selectors.** Our own parser for the profile's Selectors 4 subset runs over litehtml's CSS Syntax tokenizer.
  Matching is right to left with WebKit's match results, so a failed ancestor search stops instead of backtracking.
- **Rendering (M1c).** `RenderTree` listens to the main document and only records changes in a journal. The flush
  (end of every task and animation frame, after the microtask checkpoint; in `boot` after the parse; and
  `HostState::flushRender`) builds the litehtml document once, at the boot, and from then on applies the journal by
  patching it in place, lays it out, and publishes the layer tree with its operations and changed rects. A fresh build
  is the oracle: `testRandomEditsMatchARebuild` holds the patched document, its render input and its layer tree equal
  to a fresh build's after seeded random edit sequences. The environment patches in
  place: a width, reduced motion and the theme (the scheme and the root's theme declarations) are applied in the
  flush's patch session, the rules whose media list flips and the elements whose style read the viewport or the scheme
  matched again (twidget edits 79, 80). So do sheets: a `<style>`'s text, or a `<style>` inserted or removed, has the
  author sheets parsed again in tree order, an unchanged sheet keeping its rules (edit 81), within Ruling 7's 64 KiB and
  profile 1's budgets, cut where a build cuts them (`RenderTree::planSheets`). A replaced document element is built detached
  and replaces the old tree in place (`RenderTree::flushRoot`, edit 82), as is one whose children changed which head or
  body is the document's own or moved either; any other child of it patches as an element's does; a comment beside it
  renders nothing. After
  every flush that publishes, the container's font and image caches are cut to what the document names
  (`WidgetContainer::prune`), so a widget cycling image sources keeps only what it shows decoded. Not rendered: `script
  noscript template iframe frame frameset noframes object embed noembed applet param portal fencedframe video audio
  source track math link meta base title area` (any namespace), comments, doctypes and template contents; everything
  else renders as the DOM holds it (spec §4 item 3).
- **The layer tree.** `WidgetContainer::record` draws litehtml's paint calls into plain data (text shaped by the host,
  images decoded). `LayerMirror` publishes the same painting as `Context`, `Box` and `Inline` nodes with stable ids,
  context-relative origins and clip chains, built by one walk of litehtml's own `draw()` loop
  (`walk_paint_order`, twidget edit 20) and then kept current by operations the fork reports at its mutation points.
  Nothing is compared on a patched flush. litehtml's render tree is made once, at the boot: a block-level child of a block formatting context inserted or
  removed is linked or unlinked alone, its parent and the other children keeping their render items (twidget edit 89;
  the cases it does not link are named, `structure: <op>: <why>`), any other patch that gives up a render item replaces
  the render subtree of its nearest boundary in place and keeps the rest (edit 74), and the mirror re-places what a
  link or a replacement brings: the old items' nodes go, and a walk that captures only the new subtree (and the runs of
  the inline contexts it paints in) builds its nodes, inserted by the placement rule. A change
  of paint order or visibility anywhere but a plain in-flow block is re-placed the same way, and so is the root's
  replacement (an edit of the document element, a media query or the viewport), the root Context keeping its id. The
  boot's publish is `Insert`s of the whole tree, the root's first; a report the mirror cannot place stops the widget as an
  inconsistency (`LayerMirror::Inconsistent`). `record()` stays as the
  oracle: a mirror flattens to what it records, after `wr_test::normalized` drops empty clip pairs and lone
  `del_clip`s.
- **Taps and events (M1d).** The host's pointer phases (`HostState::pointer`) are hit-tested on the runtime's own
  layout and dispatched as touch browsers dispatch a tap, each phase one trusted task (spec §5 has the order and the
  click rule). Each finger is its own pointer with a press of its own, up to `kMaxPointers` (5; a down past them, or
  for a pointer already down, is dropped with its later phases): its target, capture, canceled defaults and press
  number, so lifting one disturbs no other; only the primary pointer clicks. A click runs the activation behaviour and the default actions: a checkbox or radio toggles before its
  listeners and reverts when the click is canceled, a label clicks its control, a summary toggles its details, a
  submit is canceled, and a link follows its `href` by SDK v1's route (below). Focus, `:hover` and
  `:active` live in `UserActions` (`:active` one entry per press, removed by that press's end or by its element leaving
  the document, so a second finger on an element holds it after the first lifts, even when the element left and came
  back between their downs; `:hover` the primary pointer's). A change to them is a patch, made only when the build's
  `<style>` text names `:hover`, `:active` or `:focus` or the document has a form control (the UA sheet's pressed
  button): the elements whose state changed (the old and new target's inclusive ancestors) are journaled
  (`JournalKind::State`), and the flush sets their classes on litehtml's elements together and matches again what that
  reaches, each element once, so a deep chain costs its subtree once (twidget edit 75), beside any structure in the same
  flush.
- **Who gets a press (widget-sandbox's shared gesture policy, v0.1.2 and v0.1.3).** The policy's C++ copy is vendored
  (`third-party/widget-sandbox/gesture/`, the `GesturePolicy` library, its fixture run by the host `GesturePolicyTests`),
  and `TapState` runs it rather than restating it. Every press decides its claim at its down task (sdk-v1 §5.5;
  `TapState::claim`, read by the host through `WRSession.gestureClaim`): `claimOf` over the computed touch-action of
  the target and its ancestors up to `<html>`, read from the layout the press was hit-tested on before its handlers
  run (`none` anywhere: `x` and `hold`; a value without a horizontal pan `x`; never `y`, v0.1.3's G2), `x` but never
  `hold` when the widget cancels the press's `pointerdown` or `touchstart` (the reference learns that from the previous
  press; ours dispatches before it answers), and nothing for a touch starting in the leading 20 px. A vertical move
  past the slop is the chat's even after a hold the widget won (the arbiter's).
  The primary pointer's press feeds a `GestureArbiter`, so the thresholds are the policy's (slop 10 px, hold 500 ms,
  double tap 300 ms / 40 px): a press still within the slop at 500 ms is held and makes no click at its up, and on a
  `hold` claim it gets a cancelable `contextmenu` at its target then (a press-scoped task on the loop's own clock,
  `EventLoop::queueTaskAt`; button 0 and buttons 1 from a finger); the second tap of a double tap dispatches `dblclick`
  after its click, on every element, only when that click was dispatched. A mouse press (`PointerKind::Mouse`, an iPad
  pointer) carries `pointerType: 'mouse'` and its button, with `mousedown`/`mousemove`/`mouseup` of its own, goes to
  its hit target unless captured, has no edge strip and no hold; its secondary button gets `contextmenu` at its down on
  a `hold` claim. The client takes `x` and `hold`: a vertical drag always scrolls the chat (the message widgets guide,
  "The chat always scrolls"). The press also answers whether it lands on something the widget handles
  (`TapState::takesTaps`, `WRSession.pressTakesTaps`): a listener for a press's events on the event's path, an element
  with activation behaviour outside a disabled control, or a drag claim; the client then recognizes the touch for the
  widget at its end. The client's side is the message widgets guide's
  (`submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`) "Touches", "iPad pointers" and "Drags are decided per
  press".
- **The SDK (V2a, widget-sandbox v0.1.0 `docs/sdk-v1.md`).** `window.TelegramWidget` (unforgeable) is SDK v1, and the
  runtime applies its policy itself; the app's core only passes the calls on. Calls reach `wr::Host::bridgeCall` as a
  method and a JSON array of strings: `ready`, `openLink`, `openTelegramLink` and `haptic`.
  - *Members* (`TelegramWidget.cpp`): `profile` 1, `isProfileAtLeast`, `colorScheme` (and its alias `theme`),
    `isActive` (`!document.hidden`), `onEvent`/`offEvent` for `themeChanged`, `activated` and `deactivated` (16
    handlers per type, a handler added once, unknown types and non-functions ignored; `this` is the widget), and the
    deprecated `onTheme`, whose 16 callbacks are a list of their own, called at once and after `themeChanged`'s with
    the scheme. `activated`/`deactivated` fire after `visibilitychange`. `sendMessage` and `on` are gone.
  - *Resize anchor* (widget-sandbox v0.1.3, sdk-v1 §2.12, §5.6): `setResizeAnchor(edge)` takes exactly `'top'` or
    `'bottom'` (the vendored SDK policy's `checkResizeAnchor`, `third-party/widget-sandbox/gesture/sdk_policy.cpp`, its
    fixture run by the host `SdkPolicyTests`; only a 16-byte prefix of the string is converted), anything else is a
    `TypeError`; it needs no tap, posts nothing to the bridge, and sets `HostState::resizeAnchor` (top until set), which
    the host reads with the height (`WRSession.resizeAnchor`). The client's side is the message widgets guide's "Which
    edge stays put".
  - *Theme* (`ThemeParams.cpp`, sdk-v1 §2.3): `themeParams` has every Mini Apps key as lowercase `#rrggbb`, the host's
    palette (`HostState::setThemeParams`, checked as the reference's `checkThemeParams`) over `DEFAULT_THEME_PARAMS`
    for the scheme; one frozen object until the next change. The root gets `--tg-theme-<key>` and `--tg-color-scheme`
    as `!important` declarations after its own style attribute (twidget edit 26: parsed on their own, so no sheet, no
    root style and no unclosed construct in one replaces them). A change of scheme or of any completed colour updates
    all of it at once and then fires `themeChanged`; anything else fires nothing. The iOS host (V2b) passes the chat's
    palette with the scheme, at creation (so the first build has it) and on every change, one theme change
    (`HostState::setTheme`): the bubble's `messageWidgetTheme` maps the colours of the bubble the widget sits in, incoming
    or outgoing (v0.1.1), to every key (a colour with alpha composited over the bubble, a gradient bubble its colours'
    average, the button the bubble's own filled control: `polls.bar` and its knocked-out foreground). With it come §2.4's button tokens (`ThemeButtonTokens`, set on the root as
    `--tg-button-*` when passed) and, since v0.1.1, its text tokens (`ThemeTextTokens`: the chat's Text Size, a line
    height of 1.3 and the text bubble's insets as the padding; the root always carries all three `--tg-text-*`, the
    reference set 15px, 1.35, `8px 12px` standing for a token not passed or refused), each checked against the
    reference's grammar. The profile's UA layer reads both, so a widget with no CSS of its own sets its text as a
    message does and a `<button>` it did not style is the client's solid button. A text-size change alone is a theme
    change: the widget lays out again and `themeChanged` fires.
  - *Links* (`Links.cpp`, §2.5): `openLink`/`openTelegramLink` check the URL as the reference's `checkLink` does and
    throw `TypeError` for anything else; the host gets it normalised (scheme and host lowercase, non-ASCII after the
    host as UTF-8 escapes). A checked call is posted only while a trusted press dispatches, one call per press, on a
    visible widget (below); otherwise it is dropped with `activation-blocked`. An `<a href>` and `window.open` go to
    `openTelegramLink` for t.me, telegram.me and telegram.dog, to `openLink` for another valid URL, and are ignored with
    `navigation-blocked` otherwise; `window.open` returns null. The bubble confirms an `openLink` before opening
    (`forceConcealed`), shows the whole URL (§5.2), and shows one confirmation at a time; since widget-sandbox v0.3.0 an
    `openTelegramLink` opens as a link in the message's text does, with no confirmation of its own (the message passed
    as `OpenUrl.message`, so the chat's own handling of t.me links decides). For `openLink`: `MessageWidgetLinkDialog`, told by `openUserGeneratedUrl`'s `alertDisplayUpdated` which
    confirmation appeared and when it goes, drops a widget link that comes while one is up. It holds the confirmation
    weakly, so one that was never presented (its chat had left the window) or went by a path that does not report it
    stops blocking once released.
  - *Haptics* (§2.6): `HapticFeedback`'s three methods return it and throw `TypeError` for an unknown style or type.
    A call posts `haptic` only when the vendored SDK policy's `HapticGate` admits it (`HostState::admitHaptic`, on the
    step's clock). It needs:
    - a visible widget;
    - a token in the bucket (5, refilled at 10 per second);
    - since widget-sandbox v0.2.2, a touch: while the primary press is down and for 5 s after it is lifted. Outside a
      touch, the first call opens a 1 s series; the next series waits for a touch or 10 s.

    The press and release are `TapState`'s primary down, up and cancel (`hapticPressed` / `hapticReleased`). A drop is
    reported as `haptic-limit` at most once a second. The bubble plays them as Mini Apps do.
  - *Storage* (`Storage.cpp`, §2.8): `localStorage` and `sessionStorage` over `Host::storageArea`, 4,096 bytes of
    UTF-8 keys and values per area (the vendored policy's `STORAGE_QUOTA_BYTES`; 16,384 before widget-sandbox v0.3.0), committed through `Host::storageCommit` at the end of the step that changed them,
    after its rendering update (a media query's change listener or a ResizeObserver callback may write). A stored area
    over the quota is dropped whole (`storage-rejected`, §3.1), and nothing is committed once the widget has stopped.
    The client's half (V2b, `MessageWidgetStorage`): `MessageWidgetStorageStore` keeps every shown widget's latest areas
    per (account, message) and writes `local` into the message's `DerivedDataMessageAttribute["widgetStorage"]` 1 s
    after the widget's last commit and at once on hide, teardown, background and terminate; `session` stays in memory
    until the app restarts. A widget built again before its write lands reads its last commit, and the commits of the
    task running when its widget is destroyed still arrive (the core posts them itself). Deletion with the message, the
    chat or the account is the row's own; "Clear cache" (Storage Usage's whole-cache clear, whatever categories) empties
    every message an account index (`ApplicationSpecificPreferencesKeys.messageWidgetStorageIndex`) lists. In the admin
    log and in previews the storage is kept in memory only, under keys of its own (`persists: false`). Each message's
    widget commits through one `MessageWidgetStorageSink` per stable id, which follows the message from its local id to
    its cloud id when it is sent (a forwarded copy renders while pending first).
  - *Restarts* (§5.7, `MessageWidgetRestartPolicy`): a stopped widget is built again the next time its bubble is shown;
    after 2 stops in a row (per message and source, in memory) it is made `startsStopped`, the badge alone with none of
    its code run, until the app restarts or the message gets new HTML.
  - *Locale* (§2.9): `navigator.language` is the host's (`HostState::setLocale`, `WRSession setLocale:`, the bubble's
    `strings.baseLanguageCode`), `navigator.languages` a fresh frozen `[language]`; a tag that is not BCP 47-shaped or
    is longer than 35 characters is `en-US`. `Intl` does not exist yet (V5).
  - *Inert* (`Inert.cpp`, §2.10): `fetch` rejects and the network constructors and `sendBeacon` throw
    `NetworkDisabledError`; `alert`, `confirm` (false) and `prompt` (null) do nothing; the clipboard and `share` reject
    with `NotAllowedError`.
- **`element.style` (M1d).** CSSOM's inline declaration block over the element's `style` attribute: parsed on every
  access and written back serialized on every change, so the render tree restyles from the attribute as for any other
  attribute change and the two never disagree. Values are kept as text (spec §10.3).
- **The app's half (M1d).** A widget is `MessageWidgetCore`, which runs only inside the widget's tasks on the pool,
  and `MessageWidgetInstance` on main, which applies each task's `WidgetSnapshot` in order. The core owns a
  `WRSession`, which owns the runtime, the `CoreTextRenderHost`, the render tree and the production `wr::Host`
  (`CACurrentMediaTime()` in milliseconds as the clock the steps are given; the wall clock for `Date`; diagnostics and
  bridge calls to the core; `console` lines are dropped). Each core task runs its steps, each on the CPU slice its kind
  gets ("Limits"), hands the session's tree and changed rects to its `WidgetTreeRenderer`, and returns a snapshot with
  the size, the state, the bridge calls the policy allowed, the diagnostics and the CPU milliseconds its steps spent on
  the widget's thread (`cpuMilliseconds`, the difference of `WRSession.stepCpuMilliseconds` around the drain, which
  demotion reads less the boot's own steps within their exemption, `bootCpuMilliseconds`). The snapshot carries no tiles. When main applies one whose tree changed, it queues a `.draw` task,
  never waited for and keyed so that a draw still waiting is replaced, which paints the 128 pt tiles under the changed
  rects in parallel through `LayerTreePainter`.

## Invariants (none of these shows up as a build error)

- **Lifetime.** Every raw pointer between nodes is paired with a counted, traced reference (`Held`):
  - parent, document, `Attr`'s owner;
  - each live collection's root, and the document it holds;
  - the template ↔ contents pair, both ways (the contents' host).

  Each `trace` marks exactly its counted references. No finalizer touches another payload: QuickJS may finalize a
  cycle in any order. Freeing a deep tree goes through QuickJS's zero-refcount list, so it does not recurse.
- **No script runs inside a native algorithm.** Conversions run before an implementation body starts. Native code
  never calls through JS-visible properties, except where WebIDL itself requires it (new-target `prototype`,
  `[PutForwards]`, dictionary members). Script is entered only from:
  - the event loop's steps;
  - `dispatchEvent`'s listener calls, with the event path held as `Ref`s;
  - script execution at a task or at mutation depth 0;
  - WebIDL-mandated reads during conversion (dictionary members, a callback interface's `handleEvent`);
  - compiling an event handler's text (HTML "getting the current value of the event handler"), from the handler's
    IDL getter or its listener during dispatch, at native depth 0 and counted as a call into JS;
  - the string conversions a standard makes of a script's value: `console`'s ToString of each argument, inside its
    binding call, and "report the exception"'s ToString of the exception and read of its `stack` (PF21). The
    report's conversions do not recurse: one that throws gives a fixed text (or no location) instead of being
    reported in turn, and each counts as a call into JS (`Runtime::ConversionScope`). `console`'s conversion is part
    of the script's own call: what it throws propagates to the caller as an ordinary exception.

  The document reaches native code through `DOMState`, never through `globalThis.document`.
- **The limits are read at QuickJS's polls, and native code is not interruptible** (since 2026-10-30, the user's
  "exact upstream parity"). A widget's limits are widget-sandbox's, on the widget thread's CPU clock ("Limits"). The
  slice, the wall-clock backstop and the layout-query limit are checked in QuickJS's interrupt handler
  (`Runtime::interrupt`), which stock QuickJS calls every 10,000 polls, between bytecodes and in its regex engine, and
  nowhere else (the layout-query limit also after each query's flush). Our renderer's work runs in a
  `Runtime::RenderScope`: measured on the CPU clock, kept out of the slice (both deadlines move on by its time), and
  the handler checks nothing inside one. Nothing in the runtime counts or charges work: no counter, no rates, no work
  limit (`:WidgetRuntimeNoWorkUnitsScanTests` fails on any of the deleted names in the runtime, its iOS glue and
  quickjs-ng). So a native path that runs long without returning to bytecode (a builtin over a huge array-like such
  as a generic `join` of `{length: 2**40}`, a `trim` of 4 MB, BigInt division, a DOM walk, a layout, a render build)
  runs to its end, and the stop lands at the next poll after it. The count caps, the memory limit and litehtml's own
  caps bound such paths; one can hold one of the pool's two threads, never main, which waits at most its 20 ms a turn.
  Tests that compare two paths' costs read the thread's CPU clock (`wr_test::threadCpuMs`, `leastCpuMs`), never a
  count. `CpuSliceTests` and `StopGuardTests` pin the slice and the stops that remain.
- **Stack.** No recursion grows with input size. Cloning, `isEqualNode`, serialization and gumbo's destroy are
  iterative. The parse builder, the selector matcher and litehtml's componentizer recurse only to fixed caps (see
  Limits). Tests run deep inputs on 512 KiB stacks.
- **Memory.** DOM allocations go through QuickJS's allocator (`js_malloc*`, `wr::JSAllocator`), so they count
  against the widget's memory limit. The documented exceptions are two transient parse structures on the system
  heap:
  - gumbo's tree;
  - litehtml's selector tokens.

  Each is bounded by the caps below, with its bound written at the code (`Parser.cpp`, `Selectors.cpp`) and pinned
  by a test.
- **Only the CPU limits read a clock.** They read the widget thread's CPU clock (`CLOCK_THREAD_CPUTIME_ID`) and,
  for the backstop, the monotonic wall clock, through `wr::CpuClock` (`Runtime::Options::clock`, injectable); no other
  decision reads one. So where a runaway stops, and when a widget is throttled, depend on the device and its load, as
  upstream's do. Tests get repeatable runs from the harness's fake clock (`wr_test::FakeCpuClock`: 1 ms per
  interrupt-handler check, `renderStepMs` per render scope; `ScopedProductSlices`, `stopAfter`) or, in Swift, from a
  wall-clock-as-CPU fake (`useWallTimeAsCpu`).
- **Two depth counters.**
  - **Mutation depth.** `Runtime::nativeDepth()` counts nested native frames (`wr::NativeFrame`): every binding call
    (`wr::glue`) and every `wr::MutationScope`. A call into JS through `callFunction`, `callInterface`, `runScript`
    or a handler's compilation starts it at 0 again (`Runtime::ScriptBoundary`). JS that argument conversion runs (a
    dictionary member's getter) does not, so a script inserted there waits for the binding call being converted for
    (spec §10.1). Inserted scripts are prepared only when the outermost frame is left normally
    (`afterOutermostNative`) and after every task, never inside `insertNode`, whose callers hold raw pointers.
  - **Callback depth.** `Runtime::scriptDepth()` counts nested calls into JS. The microtask checkpoint runs when the
    outermost one returns, and after every task and every animation frame. A report's reads of the value it reports
    (ToString of the exception, its `stack`, an unhandled rejection's reason described for the host) count as one
    (`Runtime::ConversionScope`) without a cleanup of their own, so a callback that author code makes is not
    outermost and no checkpoint runs inside the conversion: the task's or caller's checkpoint after it drains what
    it queued. The ErrorEvent's listeners are ordinary outermost calls.
- **Stops are final.**
  - A CPU or layout-query stop, a counted cap, out-of-memory or an internal failure latches `Runtime::stopReason()`
    (`Cpu`, `LayoutQuery`, `Limit`, `Memory`, `Internal`). An allocation refused at the memory limit latches Memory
    inside QuickJS's allocator (fork change 9).
  - After that, every step returns `Stopped` without calling into JS, and the interrupt handler always says stop.
    Nothing is catchable by script any more, bare `null` included, and every poll site throws (fork change 10).
  - QuickJS cannot drop queued jobs, so the latch, not the queue, is what keeps a stopped widget stopped.
  - `wr::Aborted` carries an uncatchable error out through every native frame to the step boundary.
- **Time is the host's.**
  - The loop's time is the host's. The host passes `now` into `runNextTask` and `runAnimationFrame` (or
    `advanceTime`), and timers, the CPU windows and their retry times are reckoned in the loop's current time: the
    `now` of the step running, or of the last one. The loop reads the CPU clock only to measure what a step spent.
  - Script-visible time (`performance.now()`, `Event.timeStamp`, `Date.now()`) comes from `wr::Host`, and
    `Math.random` from the runtime's seed.
  - A virtual host clock and the harness's fake CPU clock therefore make a run repeatable. The WPT runner and the
    corpus boot both use them.
    Local-time `Date` output (`toString`, `getHours`, `getTimezoneOffset`) still reads the process time zone, so a
    repeatable run also pins `TZ`, as the corpus goldens do.

### M1c's invariants (rendering)

- **Profile 1 is the renderer's, never the DOM's** (V4, 2026-10-21; it replaces M1c's "there is no validator"). The
  widget's DOM keeps everything it wrote, and script reads it back unchanged; what litehtml gets follows widget-sandbox
  v0.1.0's validator, ported as rules from its tables, not as code. One decision per rule, read alike by the build, the
  in-place patches and the render input:
  - **elements:** `markup::renderTagFor` (`Sources/Host/MarkupPolicy.*`): kept, rendered as an inert `span` or `div`
    carrying `data-tg-tag` (legacy, unknown, `dialog`, a second `body`), or dropped with its subtree (form controls but
    `button`, media, embedding, `progress`, `meter`, an HTML `title`);
  - **attributes:** `markup::renderAttribute`, applied in `scanAttributes`: `on*` and malformed names dropped, data-* and
    aria-* kept, the rest by the namespace's table; an `a[href]` is its fragment, or `#` with `data-tg-link` for an
    external or empty one (a tap still reads the DOM's href); an SVG `use` or gradient `href` must be a fragment; every
    other URL attribute is dropped; `data-tg-*` is the host's;
  - **CSS:** twidget edit 29's hooks, answered by `css::policy` (`Sources/Host/CSSPolicy.*`) with four verdicts (keep,
    augment, rewrite, drop) for a declaration, a selector group, an `@media` query, an `@supports` condition and a
    value after `var()` substitution; `CSS.supports` gives the same verdict. litehtml's, the UA and the host sheets
    are trusted and pass whole (`trusted_styles`), and the caches are keyed on the sanitizer key;
  - **images:** `css::policy::imageSourceKept` (PNG, JPEG, GIF or WebP `data:` URLs) in layout and in
    `HTMLImageElement::state` alike; a refused `<img src>`, the empty one included, renders the 48 px placeholder
    (`WidgetContainer::kPlaceholderURL`, `placeholderSVG`) with `data-tg-placeholder`, and the element loads at 48 × 48.
    Since widget-sandbox v0.2.3 the element's state is a browser's. It is pending from a `src` change until its load or
    error fires from a task (`imageSourceChanged`, a source generation so a newer `src` replaces the pending event; the
    parsed images' at the window's load, those a script took out of the document included, from the list
    `CanvasState` keeps of them; one of a template's contents on its adoption into the document): not complete, no
    natural size, drawn as nothing on a canvas, `null` from `createPattern` (`CanvasImageSource::usable`). `width` and
    `height` are the rendered content size while it is being rendered (`renderedContentSize`,
    `RenderTree::beingRendered`), else the attribute, else the natural size. While pending, a dimension the CSS leaves
    auto is 0: the render tree already knows the decoded size, a browser does not.
    Consequences of laying it out at its decoded size meanwhile (the v0.2.3 review's M3, recorded, not changed):
    `offsetWidth` / `offsetHeight` and `getBoundingClientRect()` read the laid-out size in the same frame (a browser:
    the padding and border alone, for an auto dimension); `min-width` (or `min-height`) on an auto dimension does not clamp what `width` reads
    (0, a browser gives the minimum); an image a flex or grid container stretches, or one `aspect-ratio` sizes from its
    `width`/`height` attributes with the other dimension auto, also reads 0 where a browser sizes it before the decode;
    and the ancestors' geometry and the widget's reported height already include the decoded size.
    At the window's load an image whose `src` changed meanwhile is left to its own task, so it fires once. V5d had made a `data:` image complete with
    its size at once.
  A hook is a pure function of its text and posts no diagnostic. The full record, with the strict budgets and the DOM
  side, is "Profile enforcement (V4)".
- **The container is the only way out.** litehtml has no I/O of its own: every load is a container callback
  (`load_image`, `get_image_size`, `draw_image`, `import_css`, `link`). `WidgetContainer` accepts `data:` images of
  profile 1's types and the placeholder (V4), and refuses and counts everything else, and `RenderHost` is never handed
  a URL, only the decoded bytes of an accepted image; the placeholder is the one SVG it is ever handed. Nothing in the runtime or the libraries compiled into it opens a URL, a file or a socket:
  `testNoIOInTheRuntime` scans 313 source files for it (a text scan, not a proof: its known gaps are in M1b's carry-over, in `feature/message-widgets`' history),
  `testAttackCorpusLoadsNothing` runs the 110 attack documents and `testLoadsAreRefused` pins each path. The fork's SVG
  painter never loads an `<image>` (`testAttackCorpusLoadsNothing` prints that a nested `data:` image is not decoded).
- **The tree is plain data and outlives its document.** A `LayerTree` holds no `Node*`, no litehtml pointer and no
  `uint_ptr` handle; fonts and images are held by `std::shared_ptr` and every paint argument is copied. Published, it
  is immutable: a `LayerTree` the host already holds may be read on any thread while the runtime builds the next. Getting
  one is not thread-safe: call `layerTree()`, `layerOps()` and `changedRects()` on the widget's queue or after a step returns,
  because a flush swaps the members they read. A `HostFont` or `HostImage` must be
  self-contained, because the tree outlives the host object that made it, and a host call never throws and never calls
  back into the runtime. Pinned by `testTreeOutlivesItsDocument` and `testTreeOutlivesTheRuntime`.
- **The tree carries the canvas colour** (v0.1.1, `LayerTree::canvasColor`, `CanvasColorTests`): the background colour
  litehtml paints on the root, its own or the body's it propagates, currentColor resolved, transparent when neither sets
  one; computed at every publish, so a patch that changes it republishes it. The tree paints it over the document only,
  and the painter rounds boxes to whole CSS px, so the iOS view paints it under the tiles from the document's floored
  height down (`WidgetTreeRenderer.canvas`, `MessageWidgetView`'s canvas layer) where the bubble is taller than the
  document: the 50 pt minimum, a fixed-height anchor. Starting at the rounded-up height left a band of the bubble's colour
  (`testTheCanvasHasNoSeamUnderAFractionalDocument`).
- **The flush is atomic in what it publishes, and its only script is the style-change step's.** It dispatches no event
  and is never run from `afterOutermostNative`; the style-change step settles CSS animations' promises, which reads a
  `then` a widget may define (`testScriptInsideTheStyleStepFreesNothingItHolds`). The boot builds on a new document
  with new maps and installs them only when the build, the layout, the mirror and the publish have succeeded. A patch
  plans before it touches litehtml; a stop during or after its commit leaves the published tree as it was, its
  document, maps and render input patched, which nothing reads once the widget has stopped
  (`testAStoppedWidgetKeepsItsLastFlush`, `testACutPatchStopsTheWidget`). A failure goes through
  `abortForCaughtException`, which latches the stop and throws `Aborted` to the step boundary. The CPU limits never
  stop a build or a patch partway: it runs in a render scope, where the slice is not checked. The style-change step's
  script is the widget's: it runs in a `Runtime::ScriptScope`, which books the render time so far, checks the slice and
  counts its time as JS (`testScriptInsideTheStyleStepStopsAtTheSlice`); a width, theme or reduced-motion change's
  flush runs in a slice of its own (`testScriptInAWidthChangesFlushStopsAtTheSlice`,
  `testScriptInAThemeChangesFlushStopsAtTheSlice`); and script that reaches a poll anywhere else inside a render scope
  meets the wall backstop, max(10 × slice, 5 s) from the scope's start (`testScriptOutsideAScriptScopeMeetsTheBackstop`;
  the final review's C1). A strict cap or a memory refusal can still land inside the boot's build, which then leaves
  everything as it was (`testABuildStoppedPartwayIsAtomic`). A flush entered from inside a flush returns at once (`testFlushIsNotReentrant`).
- **The journal only records.** The listener runs no script and reads no attribute value; it records the node and the
  kind of change, holding a `Ref<Node>`. It drops `attributeChanged` on an element with no parent (all of the parse's
  and of cloning's), records nothing detached, in a template or outside the rendered tree
  (`testDetachedBuildsAreNotJournaled`), and keeps an entry for every distinct node a task changes, each allocated
  under the session's memory limit, what a flush does linear in them (`testTheJournalKeepsEveryNode`,
  `testAMassChangePatches`). The fork's session lists (the restyled elements, the inserted roots, the
  position parents) are searched linearly: quadratic up to litehtml's caps.
  A failure in it latches the stop and throws `Aborted`.
- **`RenderTree` is destroyed first.** It is not a payload: it holds an untraced, counted `Ref<Node>` for every node
  it maps or journals, released when its entry goes and in its destructor, so it must go while the context and the
  main document are alive. `HostState` declares it last and `Runtime::~Runtime` resets the host's extension before the
  DOM's (`testRenderTreeReleasesNodes`). Inside it, the litehtml documents are destroyed before the container they call
  (the container is declared before the build), and the mirror before the document it observes.
- **The first flush is in `boot`**, right after the parse and before any script, so a first script that never ends
  still leaves the parsed markup laid out and published (`testBootBuildsTheParsedMarkup`,
  `testHangingFirstScriptLeavesTheParsedMarkup`).
- **Selector steps are a budget of each build or patch session.** litehtml counts a step per selector test, per build
  or patch session (twidget edit 18), not per outermost pass. The boot is cut by litehtml's own 4,000,000 (a hostile
  boot, whose first patch replays the style pass uncut: twidget edit 84); every patch (a replaced document element's
  build included) by `kPatchSelectorSteps`, 28,000,000 (`RenderTree.h`), and nothing counts what earlier patches took.
  A patch whose matching that cuts midway stops the widget (`RenderTree::stopInternally`), frozen on the tree published
  before (`testACutPatchStopsTheWidget`). No patch ends in an abort. These budgets and the count caps are what bound a
  render flush: nothing interrupts one.
- **A patch cuts where a build cuts.** A build and a patch hand every cap out in the same order, counting only what
  renders (twidget edit 83: an element its parent's own append refuses is in no build and counts toward nothing): the
  document's own content in tree order, then generated content (`::before`/`::after` content, a form control's `lh-*`
  parts) in match order. A flush plans against the rest of the document's sums; one whose plan would cross a cap, or
  that follows a build whose walk hit a limit, walks the cut instead (`RenderCut`, `renderCutDiff`: the build's own
  walk in a dry mode that decides and makes nothing) and builds again, in
  cut mode, each node whose fate differs from its entry; an element's own attribute change it still renders is set in
  place, whatever its length (`RenderTree.h`, "The caps"). Near litehtml's text-piece, pseudo-element or style-byte
  cap (a `summary`'s master content counting at its most: twidget edit 84) the commit replays the style pass in a
  build's order, within `kPatchSelectorSteps`, a replay cut there stopping the widget (`RenderTree::stopInternally`)
  frozen on the tree published before. The document's html, head or body
  cut at one is built again through the root, cut as a build cuts it (`RenderTree::flushRoot`). A
  cap's `render-limit` diagnostic is
  posted when a flush first reaches it, and again only after a flush that did not (`RenderTree::publishLimits`,
  `testDiagnosticsPostOncePerHit`).
- **The fork keeps its discipline** (`third-party/twidget/VENDOR.md`): each edit is numbered, cites the code it
  touches, is pinned by a test that failed before it, and records what it changes on macOS.

### M1d's invariants (the app's half)

- **One facade.** Swift reaches the runtime only through `WRSession`. Its calls run on the widget's queue, one at a
  time, and may move between the pool's two threads; `teardown` may come from any thread and waits for a running call
  (a recursive mutex). The delegate is called inside a session call, on its thread. A call it makes back into the
  session does nothing and answers its empty default (a depth guard): it would change the runtime under the running
  call's stack.
- **A caught failure is final.** Every entry catches what C++ throws, latches `failed` and drops the runtime. From
  then on every call is a no-op answering its empty default, and the getters keep their last values, which the freeze
  reads. A memory stop is fatal the same way: the runtime goes in the call that latched it, so nothing reads the
  litehtml document a stopped patch may have left mutated (spec §10.3), and the last published tree stays
  (`testMemoryStopIsFatal`).
- **The tree outlives the session.** A `WRTree` holds one `shared_ptr<const LayerTree>`; the renderer keeps it after the
  session is gone, and it paints on any thread, which is what lets the draw task paint tiles concurrently.
  `LayerTreePainter` reads nothing but the tree (`testTreeOutlivesItsRuntime`,
  `testTeardownDuringATaskKeepsTheLastTree`).
- **A boot that published nothing did not start.** `bootWithSource:` is NO for a caught failure, a stop before the
  parse's flush published (out of memory, or a counted cap, which the core freezes with the badge alone instead), or a
  second boot; the core then reports `.failedToStart` and the bubble shows the unsupported pill (V1; there is no source
  cap since then, and since 2026-10-30 no parse ceiling: the parse's count limits bound it). A boot whose scripts
  stopped it did start, and freezes with its parsed markup (`testHangingBootShowsTheParsedMarkupFrozen`).
- **Changed rects are the union of a step's publishes.** `WRSession` takes `RenderTree::takeChangedRects()` after every
  call that may publish: every publish since the last take, together (V3: a layout query's `flushForQuery` publishes
  mid-step, before the step's own flush; `testChangedRectsOfAStepAreTheUnionOfItsPublishes`). It pads each rect 2 px
  for glyph overhang and clips it to the tree's extent: the layout width (which a block reaches whatever its content's
  own width) and the height. A size change, or a publish that changed everything, answers nil, everything.
- **Layout queries** (V3, `Sources/DOM/Geometry.cpp`, `IDL/cssom-view.webidl`): `getBoundingClientRect`,
  `getClientRects` (`DOMRect`, `DOMRectList`), the client and scroll sizes (nothing scrolls: `scrollTop`/`scrollLeft`
  read 0 and ignore writes), `HTMLElement`'s offsets, `document.elementFromPoint` and `innerWidth`/`innerHeight` (the
  layout width and the document's height: a widget has no viewport). Each flushes what is pending
  (`RenderTree::flushForQuery`) and reads the published layout (`borderBox`, `clientRects`, `nodeAt`, `boxMetrics`).
  The flush runs in a query render scope: its CPU time is the task's layout-query time, kept out of the slice and
  recorded to the main-thread window. Past 100 ms of it in one task the widget stops with upstream's "Layout query
  limit exceeded: host queries blocked the renderer for more than 100 ms in one <kind> task (<where>)" (sdk-v1 §2;
  `StopReason::LayoutQuery`, checked after each query's flush and at every interrupt-handler check;
  `attacks/layout-query-loop.html` stops that way in its boot script). The read itself is native code on the slice,
  not query time, as upstream's is JS time whenever its shim's cache answers (host.ts `query` keeps an answer until it
  next sends operations, so a repeated read never reaches its host); a read that cache would miss (another element,
  another point) is its host's time there and the slice's here, bounded by the slice. Each task's slice starts the count again. Known cost, parked with its measurement (a parked patch in
  `feature/message-widgets`'s history, conformance first): litehtml's hit test and paint make one pass over a stacking
  context's children per distinct z-index, so 3,000 positioned divs with distinct values cost 42 ms per
  `elementFromPoint` and 79 ms per whole-document build.
- **matchMedia** (V3b, `DOM/MediaQueries.cpp`): a query is evaluated by litehtml's own media query parser against the
  container's media features (`RenderTree::matchesMedia`), exactly what `@media` sees, so the two agree:
  `prefers-color-scheme` follows the theme and `prefers-reduced-motion` the system's Reduce Motion
  (`HostState::setReducedMotion`), `hover` and `pointer` are unknown features and never match, `print` never applies. After every task's and frame's microtasks the loop reports changes
  (`Window::reportMediaChanges`): a list with a change listener whose answer flipped gets a `MediaQueryListEvent`. Such
  a list is held by the window (`EventTarget::listenersChanged`); one without listeners is not tracked and, when it
  gains one, takes its previous answer from the media features the last report kept. A media keyword is looked up
  with `_find_id` (twidget edit 24), so `matchMedia` cannot grow the process-wide id table.
- **ResizeObserver and IntersectionObserver** (V3b, `DOM/ResizeObserver.cpp`, `DOM/IntersectionObserver.cpp`): after
  the flush that ends a task or a frame, `EventLoop::deliverResizeObservations` gathers the observations whose content
  or border box changed since they last reported (0×0 at first), calls the callbacks, runs the microtasks and lays out
  again, at most `kResizeObserverRounds` (4, `EventLoop.cpp`) rounds, then fires "ResizeObserver loop completed with
  undelivered notifications." at the window and leaves the rest for the next update. Then
  `Window::updateIntersectionObservations` clips each target by its clipping ancestors (`RenderTree::overflowClip`)
  and the root rectangle grown by `rootMargin`, and queues an entry when the threshold index or `isIntersecting`
  changed; a task delivers them. The implicit root is the widget's whole area (no viewport); the bubble's
  maximum-height clip is not applied. An observer that observes something is held by the window, and holds its
  targets.
- **SVG geometry** (V3b, `DOM/SVGGeometry.cpp`, `RenderTree::svg*`): SVG's elements get SVG 2's interfaces
  (`SVGGeometryElement` for the shapes, `SVGTextContentElement` for text, `SVGGraphicsElement` for containers);
  `getBBox` is the box of `litehtml::svg_geometry`'s path in user units from its points and curve extrema (exact, not
  sampled), a container's the union of its shapes; `getTotalLength`/`getPointAtLength` come from `svg_path_length`;
  `getComputedTextLength` is the container's measure of the text in the font litehtml computed from its attributes. A
  shape has no CSS box, so its client and bounding rects are its user-unit box mapped through the `<svg>`'s viewBox
  (`xMidYMid meet`; transforms are not applied).
- **The built-ins** (V5a; widgets v0.1.0 design §5 V5), each our own C++ against its standard, bound through
  `IDL/builtins.webidl`; widget-sandbox's shims were read for behaviour only (§3: none of its code is adopted).
  - `crypto.getRandomValues`/`randomUUID` (Web Crypto §10.1, no `subtle`): integer typed arrays of at most 65,536 bytes,
    filled from `Host::randomBytes` (by default `arc4random_buf`).
  - `atob`/`btoa` (HTML §8.3, Infra's forgiving-base64).
  - `TextEncoder`/`TextDecoder` (the Encoding Standard, UTF-8 only): `encodeInto`, `fatal`, `ignoreBOM`, `stream`; the
    decoder (`UTF8Decoder`) is shared with `URLSearchParams` and `Blob`.
  - `structuredClone` (HTML §2.7): plain objects, arrays, errors, ArrayBuffers, typed arrays, `Map` and `Set` are walked
    here (getters run, references and cycles keep their identity); `Date`, `RegExp` and the wrappers go through
    quickjs-ng's own serializer, which reads their internal slots and runs no script for them; everything else is a
    `DataCloneError`, as is a detached buffer, nesting past 1,000 levels and a non-empty `transfer`. A `Map` or `Set`
    is walked with the entries copied first, through the constructors, methods and iterator `next` the runtime took
    when it was made (`Runtime::intrinsic`): the engine's serializer walked one without a reference to the record it
    was on, so a getter that cleared the map freed the record under it. The host reads a `DataView` the same way,
    through the `%DataView.prototype%` accessors taken then, never through the redefinable ones.
  - `URLSearchParams` and `URL` (the URL Standard, `URLParser.cpp`): the basic URL parser and serializer, a domain
    through "domain to ASCII" (V5b: an ASCII domain lowercased, as WPT's data has it for every ASCII case, `xn--`
    labels included; any other through UTS 46 from the system ICU, non-transitional, CheckBidi and CheckJoiners);
    a `URL` keeps only its serialization (a JS string) and parses it again on each read, its setters splice and
    re-parse, and `searchParams` and the query follow each other. Pair iteration (`entries`/`keys`/`values`/`forEach`,
    "URLSearchParams Iterator") is the generator's `iterable<K, V>` support, added for it.
  - `AbortController`/`AbortSignal` (DOM §3.1–3.2): no abort algorithms, `timeout` through a timer task.
  - `Blob` (File API §3), its bytes and its type in the JS heap; `URL.createObjectURL` answers `""` and makes nothing.
- **The `CSS` namespace** (V5c, `Sources/Host/CSSNamespace.cpp`, `CSSSupports.cpp`): a lazy global, hand-built as
  `Intl` is (the generator skips WebIDL namespaces), with `escape` and `supports` as enumerable data properties and the
  class string `"CSS"`. `CSS.escape` is CSSOM's "serialize an identifier". `CSS.supports` answers from profile 1's
  tables, as decision D23 says: `true` when the profile keeps the declaration, as written or augmented (V4: the verdict
  `css::policy` gives the renderer's hooks). The two-argument form
  checks the property (in the profile, or custom), every function, unit and `url()` of the value (a `url()` only as a
  `#fragment` or a `data:` URL of a profile image type), then the profile's value rules: `display` and `position`
  from their tables; the values the validator rewrites (`sticky`, `overflow: auto|scroll|overlay`), `background-clip:
  text`, 3D transform functions, a 3D `rotate`, a three-axis `translate` or `scale`, filters outside `blur`,
  `brightness` and `drop-shadow` (a `var()` or `attr()` item kept), and non-generic font families (a family holding
  `var()` or `attr()` kept) refused; a global keyword or a custom property kept; with `var()` or `attr()` only the
  `display` and `position` tables skipped, every other rule still applying (`env()` is not in the profile's
  functions, so it is refused). The one-argument form is CSS Conditional 4's
  `<supports-condition>` (`not`, `and`, `or`, nested parentheses, declarations, `selector()` against the profile's
  pseudo-classes and pseudo-elements, general-enclosed false), then the text in parentheses, as CSSOM says, so a bare
  declaration is true. Values are litehtml's component values, through the guarded pipeline the selector parser uses
  (`Sources/DOM/CSSComponents.h`, `css::componentValues`). The tables are profile 1's `profile.json`, vendored as data
  (`third-party/widget-sandbox/profile/`) and generated into `Sources/Host/ProfileTables.inc` by
  `IDL/generate-profile-tables.py` (sorted `constexpr` arrays, `Sources/Host/Profile.h`); V4's validator adds its HTML,
  SVG, event and canvas tables beside them.
- **Canvas 2D** (V5d, `Sources/Canvas/`, `IDL/canvas.webidl`), profile 1's `canvas.*`:
  - The state machine is twidget's portable interpreter, ported as owned code (`CanvasInterpreter.{h,cpp}`,
    `PROVENANCE.md` lists every change): each call becomes resolved `CanvasOp`s in canvas pixels. A
    `CanvasRenderingContext2D` runs them at once into its canvas's bitmap, a `HostCanvas` the render host makes
    (`RenderHost::createCanvas`; on iOS twidget's CoreGraphics backend, `WidgetRuntimeIOS/Sources/CanvasBitmap.mm`, with
    text clipped to its glyph outlines). The bitmap is made on the first op and never kept after a resize; a widget's
    canvases hold at most 4,194,304 pixels together and 16,384 per side (`CanvasState`), past which a canvas draws
    nothing and a `render-limit` `canvas-pixels` diagnostic is posted once. A dashed stroke's dashes and gaps are
    counted in the space the backend dashes in (the device path through the inverse of the op's float matrix) and per
    subpath, as the pattern restarts at each; past 100,000 (`CanvasInterpreter::kMaxDashSegments`), or when a length
    is not finite, the stroke is drawn solid (`canvas-dashes`).
  - What a canvas keeps between calls is in the JS heap (`Allocator.h`'s convention), so the 64 MB limit bounds it:
    paths (`PathData`, a `Path2D`, the current path), clip paths, gradient stops and both state stacks. Clips are a chain
    (`ClipNode`) a `save()` shares, at most 64 deep (`canvas-clips` past it). A state's font, filter and lang
    (`SharedText`) and its dash (a `shared_ptr<const Vector<float>>`) are not chains: they are immutable JS-heap values a
    save copies by pointer. A rect, which only its op uses, never enters the JS heap. `lang` is capped at 256 bytes, a
    font's family list at 1 KB, `Path2D(d)` data at 64 K units and `measureText` at 64 KB. Canvas text is measured by its
    shaped advances, never through the layout's measure, which on iOS keeps every text it sees in a process-wide cache.
  - Drawing: litehtml lays a `<canvas>` out as an image, with a `twcanvas:<serial>:<w>:<h>` source the builder gives it
    (its width and height are its intrinsic size, not dimension properties); the container draws the bitmap's current
    snapshot there, a copy-on-write `HostImage`. A paint of a rendered canvas republishes its box alone
    (`RenderTree::canvasPainted`): the mirror captures it again (`Content`) with the current snapshot, beside the
    flush's patch or with none, and nothing is laid out for it.
  - The context keeps two states: the interpreter's (what draws) and what the IDL reads back, saved and restored
    together. Profile 1's out features are API-visible and inert: `createConicGradient`/`createPattern` paint nothing,
    `globalCompositeOperation`, shadows, `filter` and the text-rendering attributes read back and never apply,
    `getImageData` is transparent, `putImageData` draws nothing, `toDataURL` is `"data:,"`, `toBlob` calls back with null,
    no WebGL and no `OffscreenCanvas`. `measureText` measures with the font DOM text gets for the same `font`
    (generic families only, D3b). `drawImage`/`createPattern` take a canvas or an `<img>` (`ImageElement.cpp`: its
    state is the container's decision for its `data:` src; the element keeps only that decision, never a copy of the
    src, until its src changes, and images with one src share one decode per runtime, keyed by the src's hash and length
    (`CanvasState::sharedImage`), except that an element which decides before layout (a preloaded `new Image()` its
    `onload` appends) is decoded again by the build (a deferred minor); a broken one is an `InvalidStateError`;
    `new Image()` is a hand-built lazy global). A solid `fillText` is drawn by CoreText in the fill colour, y-up from
    the baseline with an identity text matrix, so emoji draw, at the fill's alpha; gradient fills and `strokeText` clip
    to glyph outlines, where emoji draw nothing.
- **Web Animations** (V5e, `Sources/Animation/`, `IDL/web-animations.webidl`; Web Animations Level 1), profile 1's
  `anim.waapi`:
  - *The objects:* `Element.animate`/`getAnimations` (with `subtree`), `document.timeline`/`getAnimations`, `Animation`
    (every Level 1 member, `persist` and `commitStyles` included), `AnimationEffect` and `KeyframeEffect` (both keyframe
    forms, `getKeyframes`/`setKeyframes`, `composite`, `iterationComposite`), `DocumentTimeline` (with `originTime`) and
    `AnimationPlaybackEvent`. A `pseudoElement` is checked, kept and read back, and renders nothing (one `unsupported`
    diagnostic per runtime). The algorithms are the standard's (`Animation.cpp`): pending play and pause tasks that
    commit at the next frame, the effective playback rate, auto-rewind, the finished state and its notification steps.
    `ready` and `finished` resolve synchronously where the standard does, so the animation's `then` is read inside the
    call (WPT checks it), and a rejection with an `AbortError` is a queued job, because making the exception can run the
    widget's `Error.prepareStackTrace` (`Sources/Support/Promises.*`). Easing (the reference's grammar and canonical
    text, twidget's evaluation), interpolation and the computed timing are ported code; keyframes keep their values as
    text in the JS heap. Where the reference and Level 1 differ, Level 1 wins, except for easing's grammar and
    canonical text, which are the reference's.
  - *The update step:* the document timeline's time is the last frame's timestamp (origin 0). HTML's "update
    animations and send events" runs in `EventLoop::runAnimationFrame` before the frame callbacks: every pending task
    whose timeline has a time runs and every finished state is updated; replaced animations are removed (§5.5: an
    active, finished, filling animation whose target is in the document and whose every property a later replaceable
    one (active or persisted, itself finished and filling) on the same effect target, an element or one of its
    pseudo-elements, also animates, by the names as given; `play()` leaves a removed animation removed, rendering
    nothing while its timing still runs to its finish, and `persist()` brings it back); then a microtask checkpoint, the
    queued events (by scheduled event time, an unresolved or NaN one first, then composite order, then the order
    queued; at most 4,096 a frame), and `release`. `AnimationState` (per runtime, in
    `HostState`) holds every animation that can still do something with a counted reference, so a playing animation
    nobody holds keeps running. One with no pending task and no event queued that is idle; removed and paused, or
    removed and finished with `finished` settled; or finished, not filling and with `finished` settled is let go,
    and script that changes it tracks it again. `wantsAnimationFrame` asks a cached flag:
    any change sets it, and the update step recomputes it.
  - *Rendering* (twidget edit 27): an element's sampled declarations reach litehtml in a render-only attribute
    (`"animated style"`, a name no DOM attribute can have) that litehtml combines right after `style`, as the
    animations origin: above every normal declaration, below every `!important` one. At the start of every flush, a
    layout query's included, the elements whose animations changed or moved are sampled again
    (`collectRenderChanges`), and one is journaled only when its declarations' text changed: a seek is visible in the
    same task, and a paused or filling animation costs no relayout per frame. A change of only paint-only properties
    (`transform`, `opacity`, colours, `filter`, `visibility`, …) keeps litehtml's render tree and republishes as mirror
    operations, as a class change does, and so does one of a box's geometry (`width`, `left`, margins, padding:
    twidget edit 63); a property that shapes the render tree (`display`, `position`, `float`, …) replaces a render
    subtree, as it does in an inline style or a class's rules, and the mirror places it, as it re-places an element that
    becomes or stops being a paint group anywhere but in flow (an animation's first and last frames). A property's
    underlying value is what the animations below give, else the element's inline declaration, else the reference
    renderer's initial table (`opacity` 1, `transform` none, …); cascaded and computed values are V5f's. A change of the style attribute, and any change of an
    effect (its target, keyframes, timing, composite, pseudo-element, or the animation's effect itself), samples the
    element again. Sampling is linear in an effect's values (hash lookups; only a word that is a named colour reaches
    litehtml's colour parser). A value that would not stay inside its declaration (`;`, `{`, `}`, `!`, unbalanced
    brackets or quotes) is not rendered. `commitStyles` writes, for the properties the animation animates, the values
    the animations up to and including it give (a removed animation's own values included, Level 1 §4.4.20; the
    animations below it are the rendered ones, so past the 1,024 rendered animations those beyond the cap are left
    out) into the `style` attribute (a disconnected target is an `InvalidStateError`; a `display: none` one is not refused).
  - *Not yet:* computed underlying values (V5f made them the cascaded declaration, below) and `commitStyles`' style
    change events. Not in profile 1: Level 2 (scroll timelines, ranges, `overallProgress`), Typed OM values. Hit
    testing and the geometry queries (`getBoundingClientRect`, `nodeAt`) read the layout and ignore CSS transforms, as
    they did before V5e: an animated `transform` moves what is drawn, not the element's client rect or where a tap
    finds it.
- **CSS animations and transitions** (V5f, `Sources/Animation/CSS*.{h,cpp}`, `IDL/css-animations.webidl`; CSS
  Animations 1 and 2, CSS Transitions 1 and 2), profile 1's `at.keyframes`, `anim.keyframes`, `anim.transition`,
  `anim.play-state`, `anim.easing`, `anim.events` and `anim.waapi-css-control`. They are `Animation` subclasses
  (`CSSAnimation`, `CSSTransition`) whose `KeyframeEffect` carries the CSS timing, so V5e samples, renders, seeks and
  reports them like a script animation:
  - *What the step reads:* litehtml's cascaded declarations (the fork keeps the raw text of the properties named in
    `style.cpp`'s `-lh-raw-<name>` list; `RenderTree::declaredValue`). An underlying value is now that declaration
    (V5e's inline value is its special case). Cascaded, not computed: an inherited value, a `var()` or a percentage
    stays as written. `@keyframes` and `@-webkit-keyframes` are read from the build's sheets at every build
    (`parseKeyframesRules`, with V5e's keyframe caps; a later rule of a name replaces an earlier one). An `animation`
    or `transition` list is the shorthand's entries with each longhand cycled over them, at most 64.
  - *The style-change step* (`CSSAnimationState`, run by `AnimationState::stylesResolved`) runs inside
    `RenderTree::flush`, after its first publish: for every element after a build; else for the elements whose DOM
    attributes changed (their before-change values read from the published tree before the patch,
    `pendingStyleChange`), every element of an inserted subtree, and every element a patch restyled (the commit's
    restyled elements with their subtrees, `document::take_restyled`, `RenderTree::noteRestyled`: an ancestor's class,
    a hover, a custom property and a positional rule's siblings reach the transitions below them, as a build's would);
    a removal cancels the animations of the elements that left. A second pass publishes what the step started; a flush
    makes at most two passes. Frames, seeks and paused animations never run the step, and `getAnimations` flushes style
    first, as a layout query (its time the query's: `testGetAnimationsFlushesAsAQuery`), as upstream's is one (waapi.ts
    `cssAnimations`: `query({q: 'anims'}, false)`, uncached), whose flush ends the operations batch here as there.
    `@keyframes` are read again only when the sheets' text changed, so a patch that leaves them keeps what script
    did to a CSS animation's effect. The step can run script (creating or cancelling an animation resolves its `ready` promise, which
    reads `then`): a flush inside it does nothing, the rules' entries leave their map before they are cancelled, and a
    build's walk holds every element before it updates one. A play state from style resumes without auto-rewind and
    never throws.
  - *`CSSAnimation`:* one per `animation-name` entry that names a rule. An animation keeps its object while its name
    stays in the list (matched in list order); a dropped name is cancelled. The effect's timing is the entry's (delay,
    duration, iterations, direction, fill) with a linear easing; `animation-timing-function` applies per keyframe
    interval unless the keyframe declares its own. Style sets the play state until script calls `play()` or `pause()`.
  - *`CSSTransition`:* only the 28 watched properties transition (`kWatchedProperties`, the fork's list less the
    animation, transition and discrete ones). A `background` that is one plain colour counts as `background-color`
    (`watchedValue`, as a browser expands the shorthand), and a `transition: background` entry covers it; no other
    shorthand is expanded. The before-change value is the one kept at the element's last change
    (kept while it declares a transition or one runs), else the one the flush read before patching; an undeclared value
    is the reference renderer's initial (`opacity` 1, …), and a property without one does not transition, either way.
    The last entry covering the property (or `all`) with a positive combined duration wins. An interrupted transition
    hands over from its sampled value; a change to the value a running transition is already heading for starts
    nothing; a property no longer covered cancels its transition. Two keyframes, the entry's easing on the effect,
    `fill: backwards`.
  - *Order and events:* composite order is transitions, then CSS animations, then script animations, each by creation.
    Each update step compares a CSS animation's phase with the last one (CSS Animations 2 §4.2, CSS Transitions 2 §5;
    `afterUpdate`) and queues `animationstart`/`iteration`/`end`/`cancel` and `transitionrun`/`start`/`end`/`cancel`
    at its element, with V5e's events (by scheduled time, then composite order); a cancel has no scheduled time and so
    sorts first. The `onanimation*`/`ontransition*` handlers fire, and the legacy `webkitAnimation*`/`webkitTransition*`
    names reach listeners when nothing listens to the standard name.
  - *Not in V5f:* the reversing shortening factor (a transition reversed mid-way takes its full duration back),
    `transition-behavior: allow-discrete`, `@starting-style`, animations of `::before`/`::after` and computed values.
- **Intl** (V5b, ECMA-402 2024, `Sources/Host/Intl*.cpp`) over widget-sandbox's `intl` capability: `NumberFormat`,
  `DateTimeFormat`, `PluralRules`, `RelativeTimeFormat`, `ListFormat`, `Collator` and `getCanonicalLocales`, with
  `formatToParts` for the first two and `resolvedOptions` and `supportedLocalesOf` for all six; `Number`/`BigInt`/
  `Date.prototype.toLocale*String` and `String.prototype.localeCompare` go through the same code, and
  `toLocaleUpperCase`/`toLocaleLowerCase` are ECMA-402's TransformCase (v0.1.1): in a language with case rules of its
  own (az, el, hy, lt, tr) the system ICU's mapping (`u_strToUpper`, public), with no length limit but the engine's; in
  any other the engine's own mapping, kept at install. The classes are hand-built QuickJS classes, not WebIDL ones (an
  ECMA-402 object is not a WebIDL object: `NumberFormat`, `DateTimeFormat` and `Collator` construct when called as
  functions, `format` and `compare` are accessors returning a cached bound function, the class string is
  `"Intl.NumberFormat"`), allocated per runtime. `Intl` is a lazy global (a third host auto-init tag,
  `Runtime::defineLazyGlobal`); the prototype overrides are installed at startup and reach the runtime's own `Intl`
  object, never `globalThis.Intl`, and read `this` through the engine's `valueOf`/`getTime` taken at startup
  (`Runtime::intrinsic`).
  - **No locale data here.** ICU's formatting API is not public on iOS: App Store review rejects an app importing
    `libicucore`'s `unumf_*`, `udat_*`, `ucol_*`, … (only what the SDK's `unicode/*.h` declare may be called;
    `build-system/Make/ICUImportCheck.py` fails the build on anything else). So a constructor reads every option in
    ECMA-402's order, refusing what ECMA-402 refuses, and keeps the ones the widget gave (`GivenOptions`, JSON in the JS
    heap); everything that needs locale data is `Host::intl`, the request widget-sandbox's shim sends for the same call
    (`{"kind":"number","locale":…,"opts":{…},"value":…}`; a date format's options with ToDateTimeOptions' defaults
    added as the shim adds them, because its glue formats only the fields it is given) and its glue's answer back: the
    text, or JSON for `numberParts`/`dateParts` and `numberOptions`/`dateOptions`. A request is written in native code
    (`IntlRequest`), never through `JSON.stringify`, which would run a widget's `toJSON`, after every argument is
    converted, so nothing is held while script runs. The host's answer is the step's time like any other native call
    (the slice is read at the next poll after it). NaN and the infinities, which JSON cannot carry, are formatted here.
  - **The app's host is widget-sandbox's own iOS glue** (`third-party/widget-sandbox/ios/`, upstream's `IntlBridge` and
    CLDR plural rules, vendored unedited): Foundation's `NumberFormatter`, `DateFormatter` (from templates; parts by
    formatting each pattern field alone), `RelativeDateTimeFormatter`, `ListFormatStyle` and `String.compare`.
    `MessageWidgetCore`'s session delegate hands it each request (`WRSessionDelegate session:intl:`); a session without
    one has no locale data and formats "".
  - **The locale** a request names is the first requested tag (UTS 35's case), else the host's (`HostState::locale`,
    the app's language), **with the unicode extension keywords its constructor reads** (ECMA-402 ResolveLocale,
    `intl::RelevantKeys`):
    - NumberFormat and RelativeTimeFormat `nu`; DateTimeFormat `ca`, `hc`, `nu`; Collator `co`, `kf`, `kn`;
    - each value from a conservative table: ECMA-402's 22 numbering systems with simple digit mappings, the calendars
      Foundation has on iOS 15, the hour cycles, CLDR's collations but `standard` and `search`;
    - sorted by key; attributes, other extensions (`-t-`, `-a-`…) and private use dropped, as ECMA-402's resolved locale
      has none (Foundation read them as `@…=` keywords on the plural rules' language key).

    Upstream's shim sends the tag whole, but in its glue an unknown numbering system makes `RelativeDateTimeFormatter`
    trap (the app's crash), and an extension breaks the plural rules' language key (widget-sandbox VENDOR.md). The
    glue applies what is kept on iOS 16 and later and drops it before. `WRIntlExtensionTests` runs every call a widget
    can make with every CLDR numbering system, calendar, hour cycle and collation on iOS. Until widget-sandbox v0.2.2 any extension took the
    app down:
    the glue built its `Locale` with `Locale(identifier:)`, and Foundation's identifier parsing drops a numbering
    system's 4-letter value: `ar-EG-u-nu-arab` becomes `ar_EG@numbers=yes`, and `fa-u-nu-arab`, `hi-IN-u-nu-deva` and
    `en-u-nu-latn-ca-gregory` go the same way (`canonicalIdentifier(from:)` and `identifier(.icu, from:)` too).
    Formatters for such a locale are broken: `DateFormatter.dateFormat` and the `NumberFormatter` symbols are nil,
    which that glue force-unwrapped, and `RelativeDateTimeFormatter.localizedString(from:)` traps inside Foundation.
    Tags without a unicode extension are safe (`testTheExtremesAreAnswered`; a fuzz of 1,500 random tags across every
    request kind). `Locale(components: Locale.Components(identifier:))` (iOS 16+) parses such tags and formats with
    the extension applied (digits, calendar, hour cycle); v0.2.3's glue builds its locale that way
    (`IntlBridge.bcp47Locale`; before iOS 16 it drops the extension), so an extension no longer traps. With no list of available locales, every structurally valid tag is one, as in the shim, and
    `supportedLocalesOf` answers the canonical requested tags. `resolvedOptions` takes what needs
    locale data from the glue's answer where it has one (the locale it formats in, a currency's digits, a date's fields
    and time zone) and the rest from ECMA-402's resolution of the options here; PluralRules' `pluralCategories` are the
    categories the glue's rules give a set of samples.
  - **Parity with V8** is measured on widget-sandbox v0.1.1's fixture (`fixtures/intl-cases.json`, 166 requests with
    V8's answers) three ways: `//third-party/widget-sandbox:WidgetSandboxIntlTests` runs the glue alone on the host's
    Foundation (as upstream's `testSharedFixtureMatchesV8`); `:WidgetRuntimeIntlCasesTests` runs each case as a widget
    would (`Tests/IntlCases.js`) over a host that answers only the fixture's requests, so every case passes only when the
    runtime sends exactly the shim's request; `WRIntlCasesTests` runs them end to end on iOS, the glue answering, against
    the `ios` lines of `Tests/intl-cases-expected-failures.txt` (each with its reason; the list only shrinks).
- **getComputedStyle** (V3, `Render/ComputedStyle.cpp`): `CSSStyleDeclaration` in a read-only computed mode (every
  write throws `NoModificationAllowedError`, `cssText` is ""), each read a layout query that serializes what litehtml
  computed: keywords from litehtml's own tables, colors `rgb()`/`rgba()`, lengths in px (width, height, padding and
  the horizontal margins from the render box; top and bottom margins from the computed value, since collapsing moves
  the used ones), `transform` as one 2D `matrix()`, `::before`/`::after` from the pseudo-element litehtml made (a
  missing one reads its host's values with `content: none`). Custom properties are looked up with `_find_id`, which
  never adds the name to litehtml's process-wide id table (twidget edit 23;
  `testAnUnknownCustomPropertyDoesNotGrowTheIdTable`). **Every property profile 1 marks as in answers**
  (`ProfileSurfaceTests.testEveryInProfilePropertyComputes`, the families expanded, on an unstyled and a positioned
  element; computed-style plan, 2026-10-22): exactly from litehtml's getters where litehtml stores the property (the
  offsets as CSSOM resolves them, an absolute element's auto ones from its margin edge to its containing block's
  padding edge; the flex and box alignment properties on the containers and items litehtml computes them for, a
  container's `justify-content` and `align-content` as they lay it out; `z-index` as litehtml validated it (twidget
  edit 53); min/max sizes, the text properties, radii, `transform-origin` and `transform`'s percentages against the
  border box, as litehtml draws them; the grid tracks from the tokens litehtml lays a grid out from, as written; the
  SVG dashes as the painter reads them, presentation attributes included, …). Where litehtml computes none (the flex
  and box alignment longhands outside those containers and items) and for the gaps everywhere (litehtml computes an
  undeclared gap as 0), a longhand reads litehtml's own parse of the element's declarations (edit 54), which expands
  `flex`, `flex-flow`, `gap` and `place-*` into their longhands in cascade order: `flex: 2` on a block reads
  `flex-grow` 2; an invalid declaration is dropped, so an earlier one stands, else the initial value; `inherit` reads
  the nearest ancestor that does not inherit it too. Of `justify-content` and `align-content` at litehtml's default
  (flex-start, stretch), the raw declaration that wrote the parse tells the spelling (`normal`, `stretch`, or the
  default's own keyword), `!important` deciding between the longhand and `place-content` as the cascade does; so does
  the `flex` that wrote a flex basis, for its omitted basis's `0%`. `gap` and `place-*` expand as shorthands for
  CSS-wide keywords and `var()` too (twidget edit 55). The `animation-*` and `transition-*` longhands read what the
  runtime runs (`animationSpecs`, `transitionSpecs`): the element's own declaration, else its shorthand's entries, times
  in seconds. Otherwise a property reads the element's own declaration as written, `var()` substituted (twidget edits
  45, 51 keep the raw declarations), an inherited property from the nearest ancestor that declares it, else the
  property's initial value; a declaration whose `var()` never resolved reads as unset, a shorthand's longhands too (in
  layout as well: twidget edit 57). Edit 51's copies add 360,096 bytes (3.0%, 1.5 KB a document) to the 11.9 MB of style
  bytes the corpus's 243 documents charge (`testCorpusRenders` prints the total; the heaviest document charges 981,904
  bytes of its 16 MiB budget). The positional shorthands are serialized from their longhands, the complex ones
  canonically ("What still differs", below). A raw copy of a declaration is kept before litehtml validates it, so the
  spelling a read gives is the author's.
  `touch-action` and `user-select` read the element's own declaration, else `auto` (not inherited). Known differences
  from browsers: `text-decoration-line` is merged with the parent's (litehtml's), and a gradient `background-image`
  reads `none`.
- **Only the size is critical** (the user, 2026-10-19). Main waits for a task's snapshot within the turn's cap (20 ms
  of wall time over every waited task, `MessageWidgetWaitPolicy`), and that snapshot carries the size and no tiles;
  drawing is never waited for. A size change can show the old tiles for a frame before the new ones land. A tile that
  fails to draw keeps the last frame, with no diagnostic.
- **User activation is the runtime's (V2a).** A press is numbered when its `pointerdown` task runs
  (`HostState::beginPress`) and is active (`HostState::PressScope`) only while its `pointerdown`, `pointerup`,
  `mousedown`, `mouseup` and `click` dispatch and the click's activation behaviour runs, the microtask checkpoint after
  each of their listeners included (the reference drains a task's promise jobs inside it, with the gesture, so an
  `async` click handler keeps the press after an `await`); never in a touch event's listener, a timer, a frame, or a
  job of a later task. One link call consumes the press; each finger's press is consumed on its own, and forgotten
  after its last event (`HostState::endPress`), since fingers lift in any order. The app's core passes `openLink`, `openTelegramLink` and `haptic` on, refuses a URL
  over 4,096 bytes (`bridge-refused`) and ignores any other method (`bridge-ignored`); `ready` does nothing in the app.
- **A core task is bounded.** Each step runs on the slice its kind gets (`EventLoop::admit`, the vendored
  `CpuBudget`'s decision: a boot task 500 ms, any other min(500 ms, max(what the JS quota has left, 50 ms))). The
  windows read the host's clock when a step is admitted and record the step at its end, as upstream's `dispatch` and
  `task` do (`EventLoop::quotaNow`: never before the turn's time, which stays the drain's for the timers), so a drain's
  later step sees the time its earlier ones took, and a CPU stop's "CPU quota: … left" is the quota's at the kill
  (`testTheQuotaRecordsATaskAtItsEnd`, `testALaterStepOfADrainIsAdmittedAtTheHostsTime`,
  `testTheCpuStopSaysTheQuotaLeftAtTheKill`). One
  drain runs at most 256 steps (`maximumStepsPerTask`), stops once its steps have spent a slice of CPU (`cpuLimitMs`;
  the step that crosses it runs to its own end, so a drain can reach about two slices), and ends at the first step the
  CPU windows defer; the core's next wake is the retry time (`nextTimerDeadline`), or, with a task still runnable, at
  once (a hidden widget's a second on). `WRSession`'s boot loop stops at the same bound, the rest of the lifecycle
  running on wakes. A follow-up inherits its root's kind, and a boot's, an event's or a visibility change's is never
  deferred, so the per-drain slice is what leaves the pool thread to other widgets under such a chain
  (`testABootRootedChainHoldsNoThreadForLong`, `testABootChainThatDoublesHoldsNoThreadForLong`: a chain doubling at each
  boot script held the boot task 82 s; the final review's I1, the fix wave's I-A); a chain of timers or frames the JS
  quota defers as well. A press whose down task the touch's two bounded drains do not reach is `.unanswered`
  (`WRSession.pressDownPending`, `TapState::downPending`; `testAPressBehindABacklogIsUnanswered`; the fix waves' I-B),
  as when main's wait ends first: never the previous press's claim, and never a touch past its drains' slices; a widget
  that stopped during the touch answers none. Only the boot lifecycle's own steps (its scripts and its load:
  `EventLoop::bootLinkCpuMsTotal`, `WRSession.bootCpuMilliseconds`, `WidgetSnapshot.bootCpuMilliseconds`) are exempt
  from demotion, wherever they run, and only for their first two slices of CPU in all, the boot task's own included,
  so the wakes that finish a boot get a slice or less of it (`MessageWidgetCore.bootDemotionExemptionSlices`); what else a task runs while the document is incomplete counts,
  frames included (`testABootThatFinishesOnWakesIsNotDemoted`, `testABootChainThatKeepsTheLoadAwayIsDemoted`,
  `testARunOfHeavyBootScriptsIsDemotedPastTheExemption`). An async script the parse placed (a classic or a module one)
  runs as a link too (`queueExecution`'s `parserInserted`, `testTheParsesAsyncScriptsAreBootLinks`); one the widget
  inserts is its own. A width, theme or reduced-motion change lays out at the call, outside any step
  (`EventLoop::flushForHostChange`), as a step of its kind (resize, theme, viewport) that no window defers: a slice,
  an operations batch and follow-ups of its own kind, recorded as a step is (`testAHostChangeRecordsItsScriptAtItsTime`,
  `testAHostChangesOperationsAreABatchOfTheirOwn`, `testAHostChangesFollowUpIsOfItsKind`,
  `testAHostChangesCostIsCountedAsAStepsIs`). The flush's render time is measured and charged to no window, while
  script its style-change step runs is the widget's: its time goes to the JS quota, its queries and operations to the
  main-thread window. What the widget runs because
  of it waits for the windows as a step of its own (a `Viewport` task; the `onTheme` callbacks a `Theme` task).
- **A frozen widget is a picture.** A stop, a caught failure or a memory stop freezes it: the session is torn down, the
  renderer keeps its last tree and draws the badge over it, at the bottom left (V1: the widget bubble's date pill sits
  at the bottom right), the height is latched, touches are ignored, and a new width clips the tree instead of
  reflowing it. Its theme stays the one it froze in.
- **The size is the layout width.** A snapshot's width is the width the session lays out at
  (`WidgetTreeRenderer.documentSize`), as the old renderer's was, not `contentSize.width`, which is the content's
  natural width and would shrink every widget. The height is `ceil(contentSize.height)` clamped to 50…600
  (`WidgetTreeRenderer.minimumHeight`/`maximumHeight`, widget-sandbox v0.1.0's bounds, V1) or to a bubble's fixed height
  under 600 (`WidgetTreeRenderer(width:maximumHeight:)`, passed at the boot), and it includes the body's margin, the
  padding token of widget-sandbox v0.1.1's UA layer, which the master sheet ends in before the host sheet (the spec
  renderer's root CSS, `RenderOptions::hostCSS`: `html { display: flow-root; position: relative; min-height: 0 } head {
  display: none } body { display: block }`); an author's rules win over both whatever their specificity, as the spec's
  `:where()` makes them, and in the master the layer is an origin above litehtml's own rules that `revert` skips
  (twidget edit 41).

## The widget's state and requests (widget-sandbox v0.2)

The v0.2 design: `docs/superpowers/specs/2026-10-26-message-widgets-v0.2-design.md`. Every rule comes from the vendored
SDK policy (`third-party/widget-sandbox/gesture/twidget/sdk_policy.h`, `twidget::sdk`), as `checkResizeAnchor` already
did. The order of the checks is upstream's glue's (`packages/ios` `SandboxEngine.bridgeCall`).

**The context and the state** (`HostState`):
- **Fixed for the runtime's life:** `setContext` is called before the boot's scripts and stripped as the glue strips:
  - a preview's flags are ignored;
  - a copy and a preview have no chat type;
  - the viewer is there only with `canQuery`, its fields checked by `checkViewer`.
- **The state:** `setInitialData` and `setData` take the bot's two strings as bytes. `checkWidgetData` decides what is
  text. `data-rejected` is one report naming the rejected fields; a copy's `chatData` is dropped silently.
- **A change:** `setData` queues the task that puts the new values in place and runs `chatDataChanged`, then
  `publicDataChanged` (`TelegramWidget::Event`), each only for a value that changed. Nothing restarts. A change while
  the boot's tasks run waits for its load, in order with the content safe area's (the held inputs, released by the Load
  link: upstream's inputs wait for its boot; `testAStateChangeDuringTheBootWaitsForTheLoad`). The held list has no cap
  of its own, as upstream's queue of posted inputs has none.
- **What the widget reads:** `TelegramWidget` answers the members from `HostState`. `viewer` is one frozen object per
  context generation.

**Requests:**
- **Every call gets an id** (1 … `MAX_REQUEST_ID`) and a promise in `TelegramWidget::m_requests`. The list is traced
  like the handler lists: `HostState` holds no JS values.
- **The order of the checks:**
  1. a `data` that is not 1–64 bytes of well-formed UTF-8 is a TypeError at once;
  2. a preview refuses;
  3. the `RequestGate` decides, on the step's clock (`EventLoop::currentTime`), with `gesture` being an unconsumed press
     on the visible widget (`activationAvailable`);
  4. a `Foreground` verdict consumes the press.
- **Out to the host:** an admitted request is the bridge call `request ["<id>", "<data>"]`.
- **Every outcome settles in a task of its own, never inside the call:**
  - a refusal through `queueRequestRefusal`;
  - the client's outcome through `HostState::completeRequest` → `TelegramWidget::settleRequest`. This frees the gate
    first, checks the answer (`checkRequestAnswer`, else `INVALID_ANSWER` and `answer-rejected`), and resolves
    `{result}` frozen.
  - A rejection is an `Error` named `WidgetRequestError` with its `code`, made in a job. Its `message` is upstream's
    shim's (`requestErrorMessage`, globals.ts's `requestError`): the call's label (`request`, `wallet.sendTransaction`,
    `wallet.signData`), then the words for the glue's reason when the code is `NOT_ALLOWED` (`preview`, `disabled`,
    `no-wallet`, `no-activation`, the gate's verdict that `queueRequestRefusal` carries), else for the code, a wallet
    call's own words first (`WALLET_MESSAGES`). It is the error's own and not enumerable, as `new Error(message)` makes
    it (since 2026-10-31; before, the message was the code).
  - An outcome for an id that is not an outgoing pending request changes nothing.
- **The gate's `show()`** runs in `setVisible`'s task when the widget becomes visible.
- **Diagnostics:** `request-blocked` and `preview-blocked` are capped at `MAX_REJECTION_REPORTS` (`reportCapped`).

**The other calls:**
- **`copyText`:** 1–256 UTF-16 code units. It is privileged: one press, shared with the links and `request`; outside
  one it reports `activation-blocked`.
- **`watchPublicData` / `unwatchPublicData`:** post `watchPublicData ["true"|"false"]` on a change only.

**A preview** (`WidgetContext.preview`) runs as usual but:
- takes no input (`HostState::pointer` returns);
- posts no bridge call but `ready` (`refusedInPreview` reports, and `postBridgeCall` is the floor);
- never reads its storage preload or commits (`Storage::load`, `commitIfChanged`).

## The content safe area (widget-sandbox v0.4.0)

sdk-v1 §2.17, §3 (`contentSafeArea`, `safeArea`), §5.12.
A widget with no caption below it gets the client's time over its bottom corner, and is told the band and the corner it
takes. The bubble's numbers and its touches are the message widgets guide's ("The time over the widget").

- **The value** (`wr::ContentSafeArea`, `ThemeParams.h`): `{ top, right, bottom, left, cornerLeft, cornerRight }` in CSS
  px, checked as upstream's `checkContentSafeArea` (an inset 0–64, a corner 0–200, the range before the rounding to two
  decimals; anything else 0: `testTheValuesAreCheckedAsUpstreamChecksThem`).
- **CSS** (`css::policy`'s `rewriteEnv`, run by `declaration` and `value`, so stylesheets, style attributes, CSSOM writes,
  substituted values and the SVG attributes whose value is CSS meet it alike): `env(safe-area-inset-top|right|bottom|left[, fb])`
  becomes `var(--tg-content-safe-area-inset-…[, fb])` (Augment: `CSS.supports` and `@supports` say yes), an empty
  fallback kept (`env(safe-area-inset-bottom,)` is `var(--…-bottom,)`, as upstream's rewrite keeps it); another name
  becomes its fallback (Rewrite: they say no), or the declaration is dropped without one or with an empty one; names are
  exact, as in CSS; `url()` takes one string, so `env()` inside it stays out. The SVG attributes whose value is CSS are
  the profile's (`CSSValuedSVGAttributes`: paint, colours, urls, as upstream's validator judges them); any other SVG
  attribute is kept as written, as upstream keeps it, so `env()` in a `stroke-width` or a `width` is the renderer's own:
  0, or its fallback, never the band. `SafeAreaCSSTests` (`testAnSVGAttributeIsRewrittenWhenItsValueIsCSS`),
  `CSSPolicyTests`, `MarkupPolicyTests`.
- **The root variables**: the six `--tg-content-safe-area-*`, each `!important`, always set (`0px` until the host says),
  after the theme's (`RenderOptions::contentSafeAreaDeclarations`, apart from the theme's `rootDeclarations` so either
  changes alone; `wr::rootDeclarationsOf` joins them for the builder and the tests' parse paths). The UA layer's
  `body{padding-bottom:var(--tg-content-safe-area-inset-bottom,0px)}` comes from the profile's `uaStylesheet` (an origin
  of its own: any author rule on the body's padding wins).
- **The host's value** (`HostState`): `setInitialContentSafeArea` before the boot's first layout (in the variables and in
  `TelegramWidget.contentSafeAreaInset`, no event); `setContentSafeArea` after it: an equal value (once checked) is
  nothing; otherwise the variables change and the document lays out at the call (`flushForHostChange` of kind
  `safeArea`), and a `safeArea` task, which the CPU windows never defer (`TaskKind::SafeArea`, outside `CpuBudget`'s
  deferrable kinds), gives script a fresh frozen object and fires `contentSafeAreaChanged` once (nothing if script
  already has the numbers). While the boot's tasks run it waits for the load with the state changes, in order (the held
  inputs: upstream's inputs wait for its boot). A stopped widget takes nothing. `SafeAreaTests`.
- **`TelegramWidget.contentSafeAreaInset`**: upstream's field order, frozen, the same object until a change
  (`HostState::contentSafeAreaGeneration`); `contentSafeAreaChanged` is an `onEvent` type.
- **Upward**: `WRSession.setContentSafeAreaTop:…` (before the boot the initial value, after it a change),
  `MessageWidgetCore.boot(…contentSafeArea:)` and `setContentSafeArea`, `MessageWidgetInstance.contentSafeArea` (Swift
  `SafeAreaTests`): a change is a waited `.layout` task, which a frozen widget is not given
  (`testAFrozenWidgetQueuesNoChange`; one that failed to start still gets it, and its core drops it).

## The wallet (widget-sandbox v0.5.0)

sdk-v1 §2.18, §3 (the `request` and `wallet` bridge rows, the gate's wallet paragraph), §5.13. A widget pays and signs
through Gram Wallet in TON Connect's formats; the client's side (who has the wallet, the window, the send, the bot's
query) is the message widgets guide's ("The wallet").

- **`TelegramWidget.wallet`**: a frozen `{ sendTransaction, signData }` (two own enumerable methods, as the shim's
  `Object.freeze`), the same object for the runtime's life, where the context has the wallet and `canQuery`
  (`HostState::WidgetContextState::wallet`, never in a preview); else null. The IDL's attribute is `any`: the object is
  built natively, not an interface, so it is the shim's shape (`WalletTests`).
- **The arguments are checked as the shim checks the JS value.** The vendored policy's twin checks JSON
  (`checkWalletTransaction`, `checkSignDataPayload`, `checkRequestOptions`), so `walletArgumentJson` converts the value
  by the shim's rules: the value itself a non-null, non-array object that is not a function; below it `Object.keys` and
  `Array.isArray` (through proxies), an array read as the shim's `for…of` reads a transaction's messages (its `length`
  from 1 to 255, then the values of its own iterator through the runtime's @@iterator, `sequenceValues`, whatever its
  indices hold; since 2026-10-31), `undefined` kept as null so `onlyKeys` sees its key, a function, symbol or bigint as
  `{}` (refused wherever one stands), nothing read below the deepest field a check reads, and refusals before reading
  on for more keys than any check allows (5), an iterator past 255 values (the 256th read, the iterator closed) or a
  string past 65,536 code units. Getters and proxies run, as in the shim. A refusal throws `TypeError` with upstream's
  text; the label `data` is a request's.
- **The gate** (`HostState::decideRequest(ctx, withWallet)`, `decideWallet`): a request for the wallet needs the
  wallet (`no-wallet`) and a press, never the background, never held; a wallet call needs a press or the grant. The
  grant: the answer with no error to a call that went out on a press or the grant (`settleRequest`'s
  `finishRequest(answered)`, `RequestGate::finish(answeredAt)` on the step's clock) lets one wallet call follow within
  10 s; any call that goes out on a press or the grant uses it up; a refusal, a failure, `INVALID_ANSWER` or a
  background request's answer brings none. One call in flight with the requests (`BUSY`). The refusal diagnostics are
  upstream's glue's texts (`WALLET_REFUSED`, the wallet request's no-activation line).
- **Out**: a call that passes posts the bridge call `wallet` with `[id, method, the checked argument's toJson, data]`
  (`postBridgeCallJson`); a request for the wallet posts `[id, data, {"wallet":true}]`. Its outcome comes back as a
  request's (`completeRequest`), and its failures keep `REJECTED` and `BAD_REQUEST` (`walletFailureCode`) where a
  request's are `FAILED`, worded as the shim words a wallet call's (`wallet.sendTransaction: the user declined in the
  wallet window`).
- **Upward**: `WRSession`'s context gains `wallet:`, `WRRequestFailure` gains `Rejected` and `BadRequest`;
  `MessageWidgetContext.wallet` (part of the registry's key), `BridgeCall.request(id:data:wallet:)` and
  `.wallet(id:call:)`, `MessageWidgetRequestOutcome.rejected` / `.badRequest` (Swift `StateTests`, `RegistryTests`).

## Profile enforcement (V4)

V4 (2026-10-21) enforces widget-sandbox v0.1.0's profile 1 on the renderer's copy of a widget, never on its DOM: script
reads back everything it wrote (`getAttribute`, `tagName`, `element.style`, `<style>` text), while litehtml gets the
document as the reference validator would have handed it over. An element the profile drops answers 0×0 rects and empty
computed values, as any unrendered node does. Conformance went from in profile 124 / 30 / 8 / 0 and out of profile
50 / 7 / 19 (neutralised / not yet / failing) to **130 / 24 / 8 / 0 and 75 / 1 / 0**; the one out-of-profile id not yet
neutralised is `css.box.logical`, whose RTL check needs `direction` layout (out of V4's scope).

**Where each rule sits.**
- **The tables:** profile 1's `profile.json` plus the two lists it lacks (the text attributes and the CSS-valued SVG
  attributes), generated into `Sources/Host/ProfileTables.inc` by `IDL/generate-profile-tables.py` and read through
  `Sources/Host/Profile.h`. Nothing else holds a list.
- **The CSS core:** `css::policy` (`Sources/Host/CSSPolicy.*`), pure and ctx-free: a declaration, a value, a selector
  group, an at-rule, an `@media` prelude and an `@supports` condition each get a verdict, Keep, Augment (kept, with
  something added: `ui-monospace` gains `monospace`), Rewrite (`position: sticky` becomes `relative`, `:disabled`
  becomes `[disabled]`) or Drop. `CSS.supports` and `@supports` are true for Keep and Augment. The core never throws
  or interns a name.
- **The hooks:** twidget edit 29 asks the container at every place litehtml takes CSS from the widget, and
  `WidgetContainer` answers with the core: `profile_declaration` (a rewrite edits the tokens in place),
  `profile_substituted` (the value again after `var()` substitution), `sanitize_selector_list` (one group leaves its
  list), `sanitize_media_query`, `evaluate_supports` and `sanitize_at_rule`. `RenderTree::matchesMedia` (`matchMedia`)
  and the `@keyframes` reader (`CSSAnimationRules.cpp`) walk the same at-rules with the same verdicts, so an animation
  can only name keyframes the renderer kept.
- **Elements:** `markup::renderTagFor` (`Sources/Host/MarkupPolicy.*`), one decision for the build, both patches and the
  render input: kept, rendered as an inert `span` or `div` carrying `data-tg-tag` (legacy, unknown, `dialog`, a second
  `body`), or dropped with its subtree (form controls but `button`, media, embedding, `progress`, `meter`, an HTML
  `title`). Only the document's own `html`, `head` and `body` are themselves.
- **Attributes:** `markup::renderAttribute`, applied in `scanAttributes`, the one reading of an element's attributes:
  `on*` and malformed names dropped, `data-*` and `aria-*` kept, the rest by the namespace's table; an external or
  empty `a[href]` becomes `#` plus `data-tg-link` (a tap reads the DOM's own `href`), an SVG `use` or gradient `href`
  must be a fragment, every other URL attribute goes; a CSS-valued SVG attribute must pass the value rules.
- **Images:** `css::policy::imageSourceKept` (PNG, JPEG, GIF or WebP `data:` URLs), read by layout (`decide`), by the
  DOM (`HTMLImageElement::state`) and by `scanAttributes`, which gives a refused `<img src>` (the empty one included)
  `twplaceholder:` plus `data-tg-placeholder`. The container answers that URL with the reference's 48 px SVG, the one
  SVG the host is ever handed, and the element loads at 48 × 48. A parsed image's `load`/`error` waits for the window's
  load (`DOMState::parsingDocument`), when the page's listeners exist.
- **The strict budgets** (`Builder.h`, `Limits`): a text value of at most 32,768 UTF-16 units (compat 65,536), 49,152
  units in the document (compat 262,144), 8,192 complex-script units (>= U+0590) under both, 50,000 nodes; past the
  first two the strict policy stops the widget ("Limits"), compat leaves the text out as below. A build hands them out in tree order, counting only what
  renders: a Text that does not fit renders nothing, a text attribute or a `style` is left out, a sheet is not applied,
  and the walk goes on; past the node cap it stops. The patches keep the counts in step: a structure patch only adds
  to the node count, comments it inserts included, and an insertion the journal does not hear (under an element no
  build renders) is counted beside it (`RenderTree::nodeInserted`), so the count stays an upper bound until the next
  walk, and past the cap the flush walks the cut ("A patch cuts where a build cuts"). A removal the journal does not
  hear lowers the count, so once the published build was cut at the cap the next flush walks too
  (`RenderTree::nodeRemoved`, `Journal::markCut`): what the cut dropped may fit. The policy core's rewrites are single
  passes, linear in their input, pinned by `CSSPolicyTests.testTheRewritesAreLinear`.
- **The DOM side:** no focus (`focus()`/`blur()` no-ops, a tap focuses nothing, `activeElement` is the body),
  `HTMLDialogElement` as the sandbox has it, an input's selection methods no-ops, `matchMedia` false past 1,024 units,
  and selection only through the client: `user-select` computes as the widget writes it (the UA layer's `none` on the
  root, `text` where a widget enables it; profile 1's value set drops `all` and `contain`), the client selects what the
  selectable text export (below) gives it, and `getSelection()` stays the stub: the widget never learns what the reader
  selected.

**The agreement points** (where the build, a patch and the parity re-parse must read the same function), as built:

| Point | Read by |
|---|---|
| The CSS verdicts | litehtml only, through the container hooks: the build's finalize, the attribute patch's re-match, the sheet patch's re-parse (twidget edit 81), the parity re-parse. |
| An element's rendered tag | `renderTagFor`, through `tagOf`/`renderTagOf`: `Builder::element`, the attribute plan ("the rendered tag changed" refuses), the render input's tags. |
| The attribute filter, the rewrites and the host markers | `scanAttributes` only, for the build and the attribute patch. |
| Form-control counting | the rendered tag (`button` is the one control left). |
| The text and node budgets | `renderTextFits` in `Builder::text`, `styleSheet` and `scanAttributes`, and in the text and attribute plans; the structure patch's totals. |
| The image policy | `imageSourceKept`: `decide`, `decodeImageUncached`, `HTMLImageElement::state`, the placeholder rewrite. |
| `@keyframes` against the kept at-rules | the same `mediaQueryInProfile`/`supportsCondition` walk. |
| `matchMedia` against `@media` | one walker. |

**The trusted pass-through.** litehtml's master sheet, the profile's UA sheet and the host sheet are parsed once per
process per scheme and cached, so they must never meet a hook that would drop from them (`a:link`, the UA button's
`:active`): edit 29 brackets their parse with `trusted_styles(true)`, and every hook passes everything inside it. The
root declarations (the theme's `--tg-*` custom properties) are outside the bracket. Every author-sheet and declaration
cache is keyed on `sanitizer_key()` (`WidgetContainer`'s `0x57520004`), so another container's answers are never
served to a widget.

**Hooks are pure, and post no diagnostics.** A hook is a function of the name, the tokens, the scheme, the viewport and
the sanitizer key, because litehtml caches what it answered by text. So no hook reads widget state, and none posts a
diagnostic: the reference's `tag-dropped`, `attr-dropped`, `css-dropped`, `url-blocked` and `profile` diagnostics have
no counterpart. The strict budgets report through the render-limit channel (`text-node`, `text-budget`, `nodes`).

**Edit 29** is one entry in `third-party/twidget/VENDOR.md` (items 29.1–29.7): the new container virtuals and their
call sites in `style.cpp`, `stylesheet.cpp`, `document.cpp` and `media_query.cpp` (with `prefers-reduced-motion`),
insertions only, a replaced line kept under `#if 0`. `:TwidgetProfileHooksTests` tests it on litehtml alone.

**Tests.** `CSSPolicyTests`, `CSSSupportsTests` (the verdict), `ProfileCSSTests`, `ProfileTablesTests`,
`MarkupPolicyTests`, `ProfileElementTests`, `ProfileAttributeTests`, `ProfileImageTests`, `RenderTextLimitTests`,
`DialogTests` and the rewritten `FocusTests` in `:WidgetRuntimeTests`; the random-edit suite's "near the text budget"
group; the corpus checks that no honest document reaches a text or node limit (`RenderCorpusTests`) and that only
profile image types and the placeholder reach the host; `//third-party/twidget:TwidgetProfileHooksTests`; and the
conformance ratchet, which runs the set one widget at a time (`Tests/WidgetHarness/CLAUDE.md`).

## Rendering fidelity (widget-sandbox's conformance set)

Of widget-sandbox v0.3.0's in-profile catalogue the renderer passes **177, 2 partly, 0 failing of 196** (out of profile
75 neutralised / 0 / 0; 61 of 61 automatic runs loaded), judged by the harness's conformance ratchet (`Tests/WidgetHarness/CLAUDE.md`) against
Chromium's expectations, which the conformance set encodes. The two partly are `css.background.basic` (upstream's bad
PNG, below) and `behaviour.gesture-claim`, whose checks only the real bubble can satisfy and the Tier 2 run holds to
pass. The renderer's side is twidget edits 30 to 40, 46 to 48, 56 and 57 (`third-party/twidget/VENDOR.md`; 41 to 45
are the v0.1.1 update's); the runtime's side is below. Each change is pinned by `FidelityRenderTests` and, for litehtml, `fork_test.cpp`.

- **What a widget reads back** (edit 30): `getComputedStyle` answers `filter`, SVG `fill`/`stroke`/`stroke-width`,
  `touch-action`, the background longhands per layer (a gradient layer reads `none`: litehtml keeps no gradient text),
  `vertical-align`, `border-collapse`, `user-select`, `direction`, and a calc as its tree.
- **Styles** (edits 31 to 33, 39, 48): every named colour, `:lang()` (nothing matches without a `lang` in the chain, as
  in a browser with no Content-Language), `:empty` (any text piece counts, as in Blink; a child-list patch matches a
  flipped parent and its later siblings again: twidget edit 88),
  `initial`, `unset`, `revert` and `revert-layer` (resolved from the element's matched master rules at every compute:
  `revert` skips the UA layer to the engine's rules, `revert-layer` stops at it; on a pseudo-element both are
  `unset`), `word-break`, `word-spacing`, `quotes` (stored and read back; `<q>` keeps literal
  marks), `font-feature-settings` (`tnum` only, mapped to the host's tabular figures), `min-content`, `max-content` and
  `fit-content` widths, and `calc()`, `min()`, `max()`, `clamp()` mixing a percentage with a length (`text-indent`
  and `font-size` included, its em the parent's, and keyed by its tree in the font cache).
- **Layout and paint** (edits 31, 34 to 38, 40, 46, 47): empty `auto` table columns, `list-style-image`, `translate`,
  `rotate` and `scale` as properties (the transformed rects feed `getClientRects`, `getBoundingClientRect` and
  `IntersectionObserver`; layout boxes, `offset*`, `client*` and `ResizeObserver` stay untransformed, as CSSOM View
  says), the colour-stop fix-up, Blink's dash and dot metrics, `object-fit`/`object-position`, SVG `<use>` and per-run
  `tspan` text, `text-overflow: ellipsis`, and right-to-left: `direction`, `dir` (`auto` from the first strong
  character, drawn or not, kept current by text and structure changes and by a descendant's own `dir`), `start`/`end`
  alignment, and each line's items in bidi order from UAX #9's levels (`document_container::bidi_levels`, answered by
  `WidgetContainer` from `bidi::levels` in `Sources/Render/Bidi.cpp`, each item at the level of its first strong
  character). The algorithm is ours, over the bidi classes and paired brackets of the system ICU's public `uchar.h`
  (ICU's own `ubidi_*` is not public API on iOS); it passes all 91,670 cases of Unicode's `BidiCharacterTest.txt`
  (`:WidgetRuntimeBidiTests` runs a sample, the whole file with `--test_env=WR_BIDI_CHARACTER_TEST=<path>`). The direction `dir` gives
  reaches the UA's rules as the Builder's host marker `data-tg-dir`, so an author's `[dir=auto]` matches and
  `[dir=rtl]` does not match an `auto` that resolves to rtl, as in a browser.
- **The runtime's UA sheet** (`kWidgetUAStylesheet`, unlayered, after litehtml's master): `<q>`'s marks, the `[dir]`
  rules, and a pressed `<button>` without author CSS (a press restyles it in a patch).
- **Events:** `movementX` and `movementY` on pointer and mouse moves; Pointer Events' `setPointerCapture`,
  `releasePointerCapture` and `hasPointerCapture` (2026-10-22): an explicit capture takes the press's pointer events
  from the next one, `gotpointercapture` before it and `lostpointercapture` after the `pointerup`; touch events stay
  with the touch's target and the click with the down target, and a touch's implicit capture is not reported.
- **`devicePixelRatio`** (2026-10-22, profile 1's `canvas.hidpi`): the scale the widget is drawn at
  (`RenderOptions::pixelSnapScale`, the screen's), read without a layout. Games size their canvases' backing stores by
  it; without it four of the user's games (`Fixtures/11`–`14`, played by `GamesTests` at 1× and 3×) stopped at their
  first line.

What still differs, on purpose or for now (none is measured by a conformance check today):
- **`css.background.basic` stays partly:** the tiled `data:` PNG of `auto/05-colour-backgrounds-b` (also the tiled row
  of `visual/02-colours-gradients`; widget-sandbox v0.1.1) is corrupt: its IDAT inflates, but from the sixth of its 20
  rows the filter bytes are invalid, and its Adler-32 and CRC are wrong. ImageIO calls it complete and draws those rows
  black; the reference (Chromium) keeps the first five rows and leaves the rest transparent, so the tile is black
  where the reference is white (71.7 % of the stage's ink differs). Matching a browser's partial decode is not worth
  a decoder of our own; the fix is upstream's.
- **`visual/13-out-of-profile` shows its popover, with a white button label:** the profile drops the popover
  attributes, so the div is drawn where it stands (`auto/18-out-of-profile` checks that), while the reference picture
  hides it. The page's button sets only a background, and the bubble passes `button_text_color` as the button text
  token (sdk-v1 §2.4), so the label is white on `#dde` where the picture, drawn with no token, has it dark.
- **Right-to-left is the line's order only:** floats, the static position of an absolutely positioned box and table
  column order stay left-to-right, and the UA layer's `padding-inline-*` stay dropped (`css.box.logical` is out of the
  profile), so an RTL list indents on the left. Inside one text piece the order is the text engine's; in a reversed
  span the start padding sits on the inside. A left-to-right line is reordered only when it holds a right-to-left
  character or an RLM/RLE/RLO/RLI.
- **A blur past 24 device pixels** (a box or text shadow) is drawn from a raster of at most 24 px of blur and scaled up
  (twidget edit 65), as Skia's GPU blur scales its source down until sigma is at most 4: within 8 levels of a
  full-resolution blur (`ShadowRasterTests`).
- **Filters and backdrops under a transform:** a `filter` on content drawn under a rotation or skew paints the content
  unfiltered (`FilterTargetFor` takes only an axis-aligned CTM), and a `backdrop-filter` under any scale, rotation or
  skew draws no backdrop (`draw_backdrop` takes only a translation of its group).
- **`HTMLElement.dir` reflects as written** (a plain `[Reflect]`): `dir=RTL` reads `"RTL"`, not `"rtl"`.
- **Nested intrinsic widths:** a keyword box more than 8 keyword boxes deep lays out as `auto` (Limits).
- **Math:** a tree holds at most 64 nodes (Limits); a translation's math function is a tree too (twidget edit 56), its
  percentage the border box's, but every other transform argument (an angle, a scale) folds to one unit or is refused;
  a table column whose width is a calc with a percentage lays out as `auto`; `CSS.supports` answers from the property's value grammar, so it can say true for a product the renderer
  refuses (`calc(50% * 10px)`).
- **Kept but not drawn:** `word-break: keep-all` breaks as `normal`; `font-feature-settings` other than `tnum`;
  `quotes` on `<q>` and `open-quote`/`close-quote`; an SVG shape's `translate`/`rotate`/`scale` without `transform`.
- **`max-content` around a percentage child** resolves the child against the 1,000,000 px measuring width, so such a
  box is far too wide (`fit-content` is not affected).
- **`text-overflow`:** an atomic inline at the cut is hidden with no `…`; inline boxes' backgrounds after the cut still
  draw.
- **`touch-action: initial`** (and `unset`, `revert`) reads back as written; the hit test reads it as the parent's.
- **getComputedStyle's approximations** (computed-style plan; honest widgets read `display`, `fontSize` and
  `borderTopWidth` in the corpus): the complex shorthands are canonical rather than Chrome-exact (`background` per
  layer in Chrome's order; `font` without its initial parts; the grid placements without trailing autos;
  `animation` and `transition` their longhands' reads joined entry by entry and cycled, at most 64 entries, as the
  runtime runs, and "" past 64 KiB, so a long item cycled through them cannot build megabytes). An `animation-*` or
  `transition-*` longhand declared before a later shorthand still reads its own value, as the runtime runs it (Chrome
  takes the later); the grid tracks read as written, not as Chrome's resolved px. A property answered from its
  declaration reads it as written (`counter-reset: item`, not `item 0`). The enumeration (`[...getComputedStyle(e)]`)
  lists longhands only, each shorthand still answering by name; `justify-self`, which profile 1 has only inside
  `place-self`, answers by name unlisted. A length litehtml keeps as a calc (a percentage it resolves at layout)
  reads as CSS writes a computed one, font-relative terms in px and without the clamp at 0 litehtml adds for a
  length that may not be negative (`calc(10% + 20px)`, `min(10%, 30px)`). A grid line litehtml cannot lay out (an
  unresolved `var()`, a line name) reads as absent.
- **widget-sandbox v0.3.0's renderer patterns** (`auto/28` to `30`, twidget edits 66 to 72): `grid-template`; an aspect
  ratio under `max-width`; a percentage-sized replaced element's min-content (compressible) and its percentage height
  against an indefinite one (auto); a definite grid's `fr` rows; a percentage width as auto in a block's min-content
  (a poll's fill no longer widens its row's auto column); and `transform-box: fill-box` on SVG shapes, with
  `getBoundingClientRect` on an SVG element now applying its transform and its ancestors' up to the `<svg>`
  (`RenderTree::svgClientBox`, through the fork's `svg_element_transform`). Grid §12.5's rule for an item spanning a
  flexible track is not done.

## The selectable text (text selection, sdk-v1 §2.4, §5.10)

`RenderTree::selectableText(visibleHeight)` (`Sources/Render/SelectableText.h`) is what the client may let the
reader select of the published layout, built on the widget's queue while its bubble is lifted into the context menu
(the message widgets guide's "Text selection"):
- **Selectable:** a piece of a Text node whose effective `user-select` is `text` (`selectsText`: the nearest
  ancestor-or-self whose own value is not `auto` decides; the UA layer's root `none` ends the walk; `var()` arrives
  substituted, as litehtml substitutes every raw declaration), that is drawn (`visibility: hidden` is not, `opacity: 0`
  is), and that its ancestors' overflow clips and `[0, visibleHeight)` do not wholly hide. Generated content (`::before`,
  `::after`), list markers and the ellipsis are not selectable, as in Chromium. `clip-path` is not consulted.
- **Its text** is the drawn text (`display_text()`, text-transform applied, a piece cut at an ellipsis only its drawn
  part) in document order, one UTF-16 string: collapsible white space between two runs is one space, a `<br>`, a
  preserved newline and a change of block container one newline, never at the start, never two in a row. Spaces are
  separators, not runs; the client merges a line's runs into one highlight.
- **Each run** (a drawn render item; a word broken across lines is one run per fragment) carries its box, its caret
  offsets (`RenderHost::caretOffsets`: on iOS read back from LHContainer's own two drawing paths, twidget edit 52, so
  the knobs sit on the glyphs; a surrogate pair's inside takes its start), its ancestors' composed transform
  (`visualTransform`, shared with `transformRects`) and its Text node's `NodeKey` with its offset in that node's drawn
  text, which is how a selection survives a new layout.
- **Work:** the host's, never the widget's. It runs no script, flushes nothing, runs in no slice and has no budget of
  its own (`WRSession selectableTextWithVisibleHeight:`): the rendered text's caps bound it, and it never stops, fails,
  latches or demotes the widget (`WRSession` catches a failure inside it without latching). A pathological export
  holds a pool thread for its duration, never the widget's slice. On CoreText the carets of a run cost its length
  (twidget edit 52 enumerates them in one pass; a query per index was quadratic, final review C1), and building a line
  the cache no longer holds costs about as much again: `WRSessionTests.testTheSelectableExportIsLinear` holds the
  export linear on the thread's CPU clock (one no-wrap run of 4,096 and of 32,768 units, and 50 and 400 long words:
  eight times the text in under 24 times the CPU). The corpus is not a calibration here: only the conformance set's
  `visual/16-selection` and `auto/06-text-fonts-c` write `user-select: text`.

## Limits (decided in M1a to M1d)

| Limit | Value | Where | Past it | Why |
|---|---|---|---|---|
| Builder depth | 256 levels | `ParseLimits.maxDepth` | deeper content dropped | today's `MAX_PARSE_DEPTH`; bounds the builder's recursion |
| gumbo tree depth | 512 | gumbo `max_tree_depth` | content kept at the limit | bounds gumbo's own scans |
| Attributes per element | 256 | `ParseLimits.maxAttributes` | later attributes dropped | today's `MAX_ATTRIBUTES` |
| Nodes per parse | 100,000 | `ParseLimits.maxNodes` | the parse stops | bounds the tree |
| Attributes per parse | 100,000 | `ParseLimits.maxTotalAttributes` (gumbo fork change 12) | the parse stops | attributes are not nodes |
| Attribute bytes per parse | 8 MiB | `ParseLimits.maxTotalAttributeBytes` (fork change 13) | the parse stops | reconstruction **re-clones** attribute values, so counting attributes alone let a 256 KB document peak at 486 MB |
| Formatting elements | 512 | gumbo `max_formatting_elements` (change 10) | earliest dropped | a quadratic class |
| Markup set by script | 1,048,576 UTF-16 units | `MarkupMembers.cpp` | `NotSupportedError` | bounds the transient parse heap |
| Selector length | 16,384 UTF-16 units | `Selectors.cpp` | `SyntaxError` | litehtml's tokens cost about 545 B of system heap per byte |
| Selector nesting / compounds / brackets | 32 / 1,024 / 64 | `Selectors.cpp` | `SyntaxError` | bound the matcher's and the componentizer's recursion |
| Timers | 64 live (compat 256) | `Timers.h`, `Limits::timers` | `RangeError("too many timers")` | widget-sandbox v0.3.0's `maxTimers` |
| Animation frame callbacks | 256 live, a count of their own | `Timers::kMaxLive` | `RangeError("too many animation frame callbacks")` | bounds the table (upstream's shim caps none) |
| Promise rejection lists | 1,024 about to be notified / being notified; 256 outstanding | `Sources/Host/PromiseRejections` | dropped (one diagnostic) / oldest evicted | QuickJS calls the tracker from C, outside any poll: every list it searches is bounded |
| Rendered elements | 10,000 per document | `Builder.cpp` `kMaxElements` | not rendered, with their subtrees; `render-limit: elements` | litehtml and the tree cost ~10.4 KB per styled element; half of litehtml's own cap |
| Form controls | 256 per document | `Builder.cpp` `kMaxFormControls` | not rendered; `form-controls` | litehtml makes a control's parts outside its caps (20,000 inputs: 436 MB) |
| litehtml's caps | depth 256, 20,000 elements, 10,000 text pieces, 200,000 table cells | `document.h` | not built; `depth`, `elements`, `text-pieces`, `table-cells` | litehtml's own |
| `<style>` text | 64 KiB per document, in tree order | `Builder.cpp` `kMaxStyleText` | that sheet is not applied; `css` | ~545 B of litehtml heap per CSS byte |
| `style` attribute | 16 KiB | `Builder.cpp` `kMaxStyleAttribute` | that attribute is left out, the element renders; `style-attribute` | the same |
| Text and attribute values | 1 MiB (UTF-8) per document, in tree order | `Builder.h` `kMaxRenderBytes` | the node that would pass it and every node after it are not rendered; `bytes` | replaced the old runtime's 256 KiB serialized-document cap |
| List-valued CSS | 8 layers, shadows or transform/filter functions; 32 colour stops or points | `css_parser.h` (twidget edit 15) | later entries dropped | each element copies its lists, each entry paints (100 shadows: 105 MB per 1,000 divs) |
| CSS nesting | 64 blocks | `css_parser.h` (twidget edit 14) | the deeper block is parsed as empty | litehtml's componentizer recursed once per block |
| Pseudo-elements | none nest; `content` keeps 32 items; they count against the element cap | twidget edit 19 | not created | unbounded recursion, and 1,002,004 elements from 1,000 divs |
| Style bytes | 16 MiB of heap payload copied into styles; an inherited string (one the element does not declare as a string, an unresolved `var()` included) 1 KiB, but for the bullet URL, which is shared and charged per list item up to half the budget | `document.h` `max_style_bytes`, `style_charge_bullet` (twidget edits 21, 60) | declarations holding heap payload are dropped in document order; `style-bytes`. A bullet past half the budget falls back to the type, latching nothing | 16 KiB on `*` over 9,000 elements held 353.6 MB |
| `TelegramWidget` handlers | 16 per `onEvent` type, and 16 `onTheme` callbacks | `TelegramWidget.h` `kMaxHandlersPerEvent` | ignored, no exception | sdk-policy.ts `MAX_HANDLERS_PER_EVENT` |
| Link URLs | 256 UTF-8 bytes as given and 256 characters normalised; one link call per press | `Links.h` `kMaxLinkLength` | `TypeError`; a second call is `activation-blocked` | sdk-policy.ts `MAX_LINK_LENGTH` |
| Link diagnostics | 20 `activation-blocked` and 20 `navigation-blocked` per widget | `Links.h` `kMaxLinkDiagnostics` | not reported | the reference's 20 (and ours for navigation) |
| Haptics | a bucket of 5 refilled at 10 per second, and a touch (5 s after its lift; else a 1 s series per touch or per 10 s); `haptic-limit` once per second | the vendored `twidget::sdk::HapticGate` (`HAPTIC_*`) | dropped | sdk-policy.ts `HapticGate` (v0.2.2) |
| Storage | 4,096 bytes of UTF-8 keys and values per area (16,384 before v0.3.0) | `Storage.h` `kStorageQuotaBytes` | `QuotaExceededError` | sdk-policy.ts `STORAGE_QUOTA_BYTES` |
| Locale | 35 characters, BCP 47-shaped | `HostState.cpp` `kMaxLocaleLength` | `en-US` | sdk-policy.ts `MAX_LOCALE_LENGTH` |
| Random bytes | 65,536 per `getRandomValues` | `Crypto.h` `kMaxRandomBytes` | `QuotaExceededError` | Web Crypto's |
| Clone depth | 1,000 nested values | `StructuredClone.h` `kMaxCloneDepth` | `DataCloneError` | no native recursion without bound |
| A `CSS.supports` value or condition | 16,384 UTF-16 units, 64 nested blocks (the selector parser's caps) | `CSSComponents.h` `kMaxSelectorUnits`, `kMaxBracketDepth` | `false` | a browser answers `false` for what it cannot parse; bounds the tokenizer's and componentizer's native work |
| A string handed to the `intl` host | 1,048,576 UTF-16 code units (a list's items together) | `Intl.h` `kMaxIntlString` | `RangeError` | bounds a request and the host's work |
| An `intl` answer | 4 MiB | `Intl.h` `kMaxIntlAnswer` | `RangeError` | bounds what the host's answer makes in the JS heap |
| A locale tag | 157 bytes | `Intl.h` `kMaxLocaleTag` | `RangeError` | bounds the tag every request and object carries |
| Distinct tags in a locale list | 128 | `Intl.h` `kMaxLocaleList` | `RangeError` | the list is deduplicated through a hash set; no request needs more |
| Items a `ListFormat` reads | 10,000 | `Intl.h` `kMaxListItems` | `RangeError`, the iterator closed | the string cap alone lets a million empty strings through, each a string the host makes |
| A free-form Intl option (`timeZone`, `currency`, `unit`, …) | 64 UTF-16 units | `getStringOption`'s `maxLength` | `RangeError` | every one has a shorter grammar |
| Keyframes | 10,000 per effect, 10,000 values in a property's list, 512 properties per keyframe (the first by name), values of 4,096 UTF-16 units, property keys of 128, easing text of 4,096 | `KeyframeEffect.h`, `Easing.h` `kMaxEasingText` | `RangeError` (counts), `TypeError` (lengths); properties past 512 dropped | the reference's `processKeyframes` |
| Rendered animations | the first 64 live script animations with a target (compat 1,024), in tracking order, and at most 1,024 live animations with CSS ones; 64 keyframes and 64 properties of each; 16 KiB of declarations per element, which count toward the render's 1 MiB | `AnimationState.h`, `Limits::renderedAnimations`, `kMaxRenderedAnimations` | not rendered (`animation-limit` once) / left out | widget-sandbox v0.3.0's `MAX_LIVE_ANIMS` (its validator counts the shim's script animations, never CSS ones); litehtml keeps the text on the system heap |
| Animation events | 4,096 per frame | `AnimationState.h` `kMaxQueuedEvents` | dropped | the reference's `MAX_EVENTS_PER_FRAME` |
| URL input and href | 1,048,576 UTF-16 code units | `URLParser.h` `kMaxURLLength` | the URL fails to parse (`TypeError`); a setter that would pass it leaves the URL as it was | bounds the parser's native strings (browsers cap near 2 MiB); a stored href always parses back |
| Widget source | none since V1: the client adds no size check of its own (widget-sandbox v0.1.0, tgw-format.md; integration.md, "The widget payload": the server bounds it); the parse's count limits (above) and the memory limit guard the runtime (`WRSessionTests.testALargeSourceIsNotRefused`); the parse runs outside any slice | `WRSession bootWithSource:`, `ParseLimits` | — | M1d's 256 KiB `kMaxSourceBytes` removed; the parse's work ceiling went with the work units (2026-10-30) |
| A task's CPU slice | 500 ms of the widget thread's CPU (`cpuLimitMs`) for a boot task (each boot script and the load their own; the parse and the first flush are not the widget's) and otherwise min(500 ms, max(what the JS quota has left, 50 ms)); a wall-clock backstop of max(10 × slice, 5 s) | `wr::CpuLimits`, `MessageWidgetCpuLimits.product`, `Runtime::beginSlice`, `Runtime::interrupt`, the vendored `twidget::CpuBudget::decide` | a stop, `StopReason::Cpu`: "CPU limit exceeded: more than 500 ms of continuous execution (<where>)", naming the quota when it shrank the slice | widget-sandbox v0.3.0's `cpuLimitMs`, the same in every build and under both policies |
| JS quota | 300 ms of the widget's JS per 1,000 ms window (`cpuQuotaMs`, `cpuQuotaWindowMs`), in ten buckets; our renderer's time is not JS | `EventLoop` (`m_jsBudget`), `twidget::CpuBudget` | deferrable tasks (timer, frame, viewport, resize, theme, bridge) wait apart until the retry time, in order, frames collapsed into one, none dropped; boot, events and visibility run; `cpu-throttled` at most once a second. `cpuKillAfterMs` 0: throttling never stops a widget | `cpuQuotaMs`, `cpuQuotaWindowMs`, `cpuKillAfterMs` |
| Main-thread window | 100 ms per window (`mainThreadQuotaMs`) of the step's layout-query time plus 0.025 ms an operation and 0.002 ms a canvas command (`CpuBudget::opsCostMs`); our renderer's other flushes are charged to no window | `EventLoop::endStep` (`m_hostBudget`) | as the JS quota: deferrable tasks wait | `mainThreadQuotaMs`, upstream's `opsCostMs` |
| Layout queries | 100 ms of a task's layout-query flushes | `Runtime::queryBudgetSpent` (`kQueryBudgetMs`), `layoutForQuery` | a stop, `StopReason::LayoutQuery`: "Layout query limit exceeded: host queries blocked the renderer for more than 100 ms in one <kind> task (<where>)" | upstream's `queryBudgetMs` |
| Steps per core task | 256 | `MessageWidgetCore.maximumStepsPerTask`, `drain` | the rest runs at the next wake; a step the CPU windows defer ends the drain | a widget that keeps a task runnable cannot hold its thread: a drain (and the boot's loop) stops once a slice of CPU (`cpuLimitMs`) is spent, whatever its steps' kinds |
| Memory, stack | 8 MiB (compat 64 MiB), 1 MiB | `WRSession` from `Limits::memoryBytes` | a memory stop is fatal: the runtime goes, the last tree stays | widget-sandbox v0.3.0's `memoryLimitBytes` |
| Tap slop | 8 CSS px on either axis | `Taps.h` `kTapSlop` | the move is not delivered; once past it, no click | the old renderer's |
| Bridge calls | a method name of at most 64 characters; a link at most 4,096 UTF-8 bytes (the runtime's 256 is the real bound) | `MessageWidgetCore.bridge`, `MessageWidgetInstance.maximumLinkLength` | `bridge-ignored`, `bridge-refused` | the old core's policies |
| Diagnostics | 500 per core | `MessageWidgetCore` | dropped | the old core's |
| `data:` images | profile 1's types only (V4); a body of at most 24 MiB; PNG, JPEG, GIF or WebP as ImageIO sniffs it, at most 4,096 px a side and 16 Mpx; the placeholder's SVG through `LHCreateSVGImage` (the only SVG the host is handed) | `LHContainer.mm` (`kMaxDataImageBytes`, `TelegramImageSourceAllowed`), reached through `LHHostContainer::createImage` | refused: not drawn | `LHContainer`'s policy, unchanged |
| Tiles | 128 pt; one image each, at most 4,096 px a side; a size change redraws every tile | `WidgetFrame.swift`, `LayerTreePainter.mm` | — | as before |
| Effects a draw's tiles share | 32 MiB of filter and backdrop results kept for the draw | `LHEffectStore::kMaxBytes` (twidget edit 64) | made where it is drawn and not kept | the tiles made one copy each, nine at once; the cap bounds a draw of many distinct effects |
| Text value | 32,768 UTF-16 units (compat 65,536): a Text's data, a text attribute (`alt label placeholder title value`, `data-*`, `aria-*`), the strings of a `style` or a sheet, a canvas string, a Path2D's data | `Limits::textValueUnits`, `Builder.h` `renderTextFit`, `LimitStops.h` | strict: the widget stops ("Text limit exceeded: a text value of N characters (max 32768)"); compat: the Text renders nothing (`text-node`), the attribute or style is left out (`text-budget`) | widget-sandbox v0.3.0's `maxText` |
| Document text | 49,152 UTF-16 units (compat 262,144), of which 8,192 complex-script (>= U+0590) | `Limits::textBudgetUnits`, `kComplexTextBudgetUnits` | strict: a stop ("…the document's text is over 49152 characters"); compat, and complex script under both: what does not fit in tree order renders nothing (`text-budget`) | `textBudget`, `complexTextBudget` |
| Attribute value | 8,192 UTF-16 units, any attribute, an inline style included (compat: none) | `Limits::attributeUnits`, `Builder.cpp` `scanAttributes` | a stop ("Attribute limit exceeded: …") | `maxAttr` |
| Operations per batch | 10,000 (compat: none), counted as upstream's shim sends a flush's difference (capture.ts): a node's first insertion 2, a later insertion or removal 1, a move (removed and inserted in one batch) 1 in all, an attribute or a text changed in a batch 1 however often, a property of an inline style added before the batch set or removed through the CSSOM 1 per property (a style added in the batch, `cssText` and `setAttribute('style')` 1 in all), nothing for a node first inserted in the same batch, a removal from a tree outside the document (a fragment's, a detached element's) nothing, a sole text replaced by a new one (`textContent`, `replaceChildren` with a string) 1, each canvas drawn on 1; a batch is a task, a frame, or what a layout query flushes | `Runtime::addOps`, `Node::countsChange`, `m_announcedBatch`, `m_removedBatch`, `replaceAllChildren`, `CSSStyleDeclaration::countPropertyChange`, `EventLoop` | a stop ("Ops limit exceeded: N operations in one batch (max 10000)") | `maxOps` (upstream counts its wire batches; ours are the same points) |
| CSS rules, `@keyframes` | 400 and 32 over the applied sheets, as written (compat: none); judged by the boot's build, and after it by every patch whose sheets change, over all the applied sheets in tree order (`RenderTree::planSheets`) | `Render/CSSRuleCount.cpp` (a port of upstream's `countCssRules`), `Builder.cpp` | a stop | `maxCssRules`, `maxKeyframes` |
| Canvas commands | 10,000 to one canvas in one batch (compat 400,000) | `CanvasContext2D` `command` | `RangeError("Canvas limit exceeded: …")` (compat: dropped) | `maxCanvasCmds` |
| Canvas pixels | the connected canvases' width × height together, 2048² (compat: the bitmap allocator's own cap); judged by a walk of the whole document: the boot's build, and after it the cut walk, where a canvas in a new subtree or a canvas resized sends its patch (`Builder.cpp` refuses one outside the walk) | `Builder.cpp` `m_canvasPixels`, `RenderTree.cpp` ("a canvas's size changed") | a stop ("Canvas limit exceeded: canvases of N pixels together (max 4194304)") | `maxCanvasPixels` |
| A `data:` image's pixels | 1024² as its header claims (PNG, GIF, WebP, JPEG read from the decoded start), under both policies | `Host/DataImageSize.cpp`, `CSSPolicy` `imageSource` | the 48 px placeholder; unreadable bytes are a broken image | `MAX_IMAGE_PIXELS` (upstream's constant) |
| Nodes (V4) | 50,000: the document node, every element, Text and Comment, rendered or not, a `<script>`'s children aside | `kMaxRenderNodes` | the walk stops (`nodes`) | profile 1 `MAX_NODES` |
| A refused `<img src>` (V4) | the 48 × 48 placeholder, `twplaceholder:` | `WidgetContainer::kPlaceholderURL`, `placeholderSVG` | — | the reference's placeholder; the element loads at 48 × 48 |
| `matchMedia` query (V4) | 1,024 UTF-16 units as written | `MediaQueries.h` `kMaxMatchMediaUnits` | `matches` is false | the reference host's query length |
| A math function (fidelity) | a tree of at most 64 nodes; 32 arguments to `min()`, `max()` or `clamp()`; nesting to 16 | `calc_node::max_nodes` (twidget edit 48) | the declaration is invalid, so not applied | a cached declaration's one tree is evaluated for every element it styles at every layout, inside a flush that nothing interrupts, and a `var()` splice can make one declaration as large as the style budget |
| SVG `<use>` (fidelity) | instances nest 8 deep; the document's svgs draw 8,192 elements inside instances together (each its last paint's share plus what the others left), hit tests within the same share | `el_svg.cpp` `kMaxUseDepth`, `kMaxUseElements`, `el_svg::use_budget` (twidget edit 38) | not drawn | bounds a `<use>` chain's exponential fan-out across every svg: a budget per svg let a few KB of small svgs record gigabytes of paths |
| Intrinsic widths (fidelity) | nested `min-content`/`max-content`/`fit-content` boxes lay out in full 8 deep; the measuring passes lay them out as `auto` | `render_block.cpp` `kMaxIntrinsicDepth`, `document::intrinsic_measuring` (twidget edit 39) | laid out as `auto` | every pass laying out every nested keyword box doubled the work per level, inside a flush that nothing interrupts |

The resulting transient-heap bounds:
- **Script markup at its cap:** 119,144,832 B (about 114 MiB).
- **A 256 KiB boot document:** 88,473,984 B (about 84 MiB). A larger source is not refused since V1 (below).
- **Measured worst case:** an adversarial shape at the script cap peaks at 71 MB.
- **Selector parse at its cap:** stated bound 26.8 MB; the true bound is about 8.9 MB.

The render limits bound litehtml's heap and the layer tree, which are on the system heap and outside the widget's
memory limit. The estimates are written at `RenderTree.h`, and `testHostileSizesAreBounded` holds each
hostile single build under 160 MB and prints its growth:
- 10,000 styled elements: about 10.4 KB each, so about 104 MB published. The test's styled-elements shape measured
  95.5 MB;
- 10,000 text pieces: about 36 MB (measured 36.4 MB); 256 form controls: about 5 MB (measured 5.0 MB);
- all limits together: about 156 MB published and 200 MB at the boot's build's peak (estimates); a patch never holds two
  documents.

Not bounded by the limits: litehtml's process-global caches (master and author sheets, declarations) and its interned
names (below).

The boot bound was computed for a 256 KiB source, the cap `WRSession` enforced from M1d until V1 removed it (the
client adds no size check of its own). A larger source is now bounded only by the parse's count limits (nodes,
attributes, attribute bytes: the table above) and by what the server delivers (the parse's work ceiling went with the
work units, 2026-10-30); its transient heap is not measured (M5 measures the boot on a device). A known way to cut
the markup bound to about half: once an attribute limit is exceeded, `clone_node` copies no attributes. It waits for a
memory measurement on a device (M5 measures the boot there).

## The gumbo fork

Upstream gumbo is unmaintained, so gaps are fixed in our copy. Every change is numbered in
`third-party/gumbo/VENDOR.md` and has its own case in `tests/fork_test.cpp`.

Pristine gumbo was quadratic on eight input classes (256 KiB of nested `<li>` took 3 s). Its formatting-element
reconstruction made 5 M nodes from 64 KiB, and its error recording took 277 MB. Changes 1–8 make it linear and
bounded. The rest:
- **Change 9:** a dropped attribute name resets the tag buffer. Before it, `<p h h ref=x>` invented an `href`.
- **Change 10:** the formatting list is bounded.
- **Change 11:** a tag name read from source text ends at CR and at whitespace, for start and end tags, so CRLF
  markup gets correct SVG and custom-element names.
- **Changes 12–13:** total attribute count and attribute byte limits.

html5lib tree construction stays at 1747 pass, 31 pre-existing fails, 14 skipped (`:GumboHtml5libTests`; M1a's harness
counted 1746 and 32 because it misread the one case with an empty `#data`, fixed in M1b Task 15).
litehtml uses gumbo's defaults, which leave every new limit off.

## Measured (spec §6.2, 2026-10-16, loaded host)

The unit figures in this section (QuickJS work units, M1a to M1c) predate the CPU-clock limits of 2026-10-30, which
removed the counter: they are history, kept for the relative sizes they show, and nothing is held to them now. The
runners that printed them (`:WidgetRuntimeMeasurementTests`, `:WidgetRuntimeCorpusBootTests`) print thread CPU
milliseconds instead. The KB figures stand.

- **A context with the DOM and an empty document:** 49,693 units, 136 KB. The old runtime spent about 20M units on
  setup before a widget's own scripts ran.
- **One interface materialized** in a bare runtime: 513–14,700 units, 0.3–28.9 KB.
- **The corpus parsed natively:** 323 documents, 0.1 ms mean, 0.66 ms max. None reaches a parse limit.

After M1b (spec §6.2, 2026-10-17, loaded host):
- **The Window, host state and loop** on top of the DOM context: 9,370 units, 18.5 KB (83,457 units and 204.6 KB
  in all). The DOM context alone is now 74,087 units and 186.2 KB (49,693 units and 136 KB after M1a).
- **The corpus booted headless** (`:WidgetRuntimeCorpusBootTests`, 230 documents): median 61,456 units, max 653,076;
  all 230 within main's wait allowance of the time (1,000,000 units). 103 documents report failures; by hand against
  the corpus (not program output), 79 of them fail on `element.style` (M2).

After M1c (spec §6.2, 2026-10-18; the corpus booted with the render tree at a width of 360):
- **The first flush** (the build after the parse, inside `boot`): median 12,334 units, p90 34,103, max 188,729. A boot
  with the tree: median 78,596, p90 315,363, max 840,605; all 230 within the allowance of the time, none stopped.
- **The corpus gates** (`:WidgetRuntimeRenderCorpusTests`): the render input of 230 of 230 documents survives a
  re-parse (0 are skipped) and lays out as litehtml's own parse of it does, and the mirror equals the recorded tree on
  230 of 230; no document stops only because of the tree; the largest style charge is 585,504 bytes of 16 MiB; the 93
  attacks load nothing.

After M1d (spec §6.2, 2026-10-19; `MessageWidgetCorpusTests` in the iPhone 17 / 26.5 test simulator, a debug build,
wall time, printed and not asserted):
- **Boot latency**, the layout call that boots each of the 230 corpus widgets at a width of 360, tiles at 3×: what main
  waits for (the size and the state), median 2.6 ms, p95 8.9 ms, max 17.0 ms (`compat/sortable-table.html`); until the
  tiles land, 4.3, 13.7 and 20.4 ms. With the tiles drawn inside the task, before the draw task, main waited 5.8, 20.2
  and 49.5 ms.
- **Tap latency**, a 3 × 3 grid of taps (down and up) over each widget, 2,070 taps: what main waits for, median 1.5 ms,
  p95 8.4 ms, max 17.9 ms (`showcase/commerce/04-flash-sale.html`); until the tiles land, 2.2, 9.8 and 21.8 ms. A 5 s
  tap seen before was the process's first `CADisplayLink` (5,014 ms in a headless test simulator; the tap itself
  1.6 ms); `testThePollsTapsAreFast` warms it up and holds each of the poll's taps under 500 ms.
- **The corpus**: every file boots and none stops; the uncaught errors left are by design ("What the corpus still
  trips on", below). With every unit budget then lifted to 200,000,000, only the deliberate runaway stopped, and every
  other widget's boot and largest later task stayed under a quarter of their budgets. The corpus check now holds the
  same margin on the CPU clock ("Tests").

Pool contention (V6; the widget harness's Tier 1 process in the iPhone 17 / 26.5 test simulator, a debug build, wall
time read by sampling the widget's tiles on main, measured and not asserted):
- **`visual/06-css-animations` alone** shows its first tiles 42–66 ms after the chat is laid out, then a new frame
  every 17 ms (the longest gap 19 ms).
- **Beside `visual/05-transforms-effects-a` and `-b`**, all three on screen, its first tiles come at 213–519 ms: the
  pool's two threads take the widgets' tasks in the order they were queued, so they wait for the other two's first
  draws, which take about 200–500 ms with their blurs at 3×. From then on it keeps 60 fps (the longest gap 35 ms).

Per-frame publishes (2026-10-26; the 254 corpus documents and the client's 14 fixtures, each booted at a width of 360 on
the host's fake render host and run through 120 frames, thread CPU time, best of three, under a load of about 30):
- **What a frame publishes:** before the patch paths' refusals were narrowed (canvas repaints, `::before`/`::after`
  content, `textContent` swaps, paint-only and geometry-only styles, the style bound per subtree), 4,105 whole-document
  builds per 2 s over all documents; after, about 480. None now: every flush after the boot is a patch published as
  operations (`:WidgetRuntimeCorpusIncrementalTests`).
- **CPU:** 6,901 ms → 3,131 ms over all documents (JS included); the heaviest, `showcase/travel/01-boarding-pass`,
  357 ms → under 45 ms, `htmlbubbles-ported/09-code-review/01-leo-bare` 324 → 118 ms.

Paint cost per frame (2026-10-26; one widget, 360 × 260: a card floating by `translateY` and `rotate(±1deg)` under
three box shadows of 25–55 px, over a glow pulsing in `opacity` and `scale` with `filter: blur(45px)`, and a counter
with `backdrop-filter: blur(4px)`; in the widget harness's app process on the iPhone 17 / 26.5 simulator, a debug build,
tiles at 3×, frames from the real display link):
- **What a frame costs:** the `.draw` task 137 ms, 7 frames/s, at first; 81–87 ms (11 frames/s) once a draw's tiles
  shared their filter and backdrop results (twidget edit 64); 17.6–18.2 ms (45–49 frames/s) once a big box shadow
  was drawn from one low-resolution raster (edit 65). Now without the backdrop 11 ms, without the glow's filter
  8.3 ms, without both and the shadows 6 ms (60 frames/s). The frame task (script, animations, layout, publish) is
  0.6 ms (a test process). Timed on a loaded machine (load average 10–16).
- **What it was:** every tile, and each of the two 1×1 corner-colour samples `WidgetTileDrawer.draw` took, computed every
  filter (`LHContainer::draw_filtered`) and backdrop (`draw_backdrop`) in the tree whole, whether it showed them or
  not: a 128 pt tile cost 23.5 ms, a corner sample 10.5 ms. And a moving box shadow missed its raster cache, whose key
  carried the box's sub-pixel phase, while a rotated one was never cached (neither cached path took a rotated CTM), so
  every tile it reached painted a full-resolution Core Graphics blur every frame: one shadow of 55 px cost 44 ms a
  frame, of 25 px 14 ms, of 8 px 5 ms (a test process).
- **What is left:** the glow's filter and the backdrop are made once a frame, since the glow scales every frame and
  what is behind the backdrop changes with it; the backdrop's source paint makes the glow's filter again.
- **Where to measure paint cost:** in the widget harness's app process (a Tier 1 test). The hostless test processes
  (`MessageWidgetTests`, `MessageWidgetCorpusTests`, `WidgetRuntimeIOSTests`) have no Metal device, and there a CSS
  filter or backdrop paints nothing, so their timings leave filters out. The simulator's Core Image runs on the Mac's
  GPU; the cost on a device is unmeasured.

The corpus runs incrementally (`:WidgetRuntimeCorpusIncrementalTests`, every corpus document with the attacks and the
client's fixtures, 367 documents, in the corpus goldens' deterministic mode: the boot, 3 s, a 6 × 4 grid of taps, 120
frames): each builds once, at the boot, and none stops for an inconsistency. The randomized oracles fail on any flush
that builds or stops the widget:
`testRandomEditsMatchARebuild`, 6,105 flushes over 31 groups, 5,565 patched and the rest clean, and
`testOpsMatchAFreshMirror`, 4,085 flushes, every one published as operations (40 of them batches an animation frame
published twice). A predicate's refusal is named by its reason (twidget edit 76). Structure beside
`::before`/`::after` content patches (near a cap the commit replays the style pass in a build's order: twidget edit
84), and counters run again in a build's order at the commit (edit 78).

Churn (2026-10-30; the layers a flush re-creates though their element did not change, `Tests/LayerChurn.h`, a
`::before`'s, an `::after`'s or a form control part's layers counted with their element, on the corpus run above, 367
documents): 58,562 flushes removed 467,779 layers, 410,002 of them re-created as churn (6,986 elements). By the fork's
reason for replacing render subtrees, the layers of an element the runtime built again apart: `property: font-size`
110,836; none at all (the mirror's own re-placements) 78,424; `rule: animation` 44,128; `element: svg` 38,794;
`structure: remove: in an inline context` 25,119; `text: pieces not placeable` 17,703; `attribute: points` 16,579;
`attribute: stroke` 15,957; `pseudo-element children` 13,936 (a match that changes nothing keeps an element's `::before`
and `::after`, twidget edit 91, and a change of its own style makes them again, as every frame of an animation does);
the other structure refusals (`a float or an out-of-flow box` 11,362, `in an inline` 2,393); `rule: transition` 9,217;
the rest under 4,600 each. A kept node's own change beside structure is set in place (an element's attributes, an
animation frame's included, and a Text's pieces), so an element built again though unchanged (`(built again)`) is 372
layers; where that change restyles the element's box (`hidden`, `display`, `font-size`, `transition`), the attribute
path replaces the boundary above the element, as it does for the same change without structure. The most churned
documents: `htmlbubbles-ported/09-code-review/02-leo-bare.html` 135,662,
`htmlbubbles-ported/08-analytics/09-bot-bare.html` 40,342, `htmlbubbles-ported/06-trip-lisbon/10-ana-bare.html` 30,472.
The randomized oracles: `testRandomEditsMatchARebuild` 141,855 of 170,937 removed (`structure: …: renders nothing`
31,392, `attribute: hidden` 22,394, `rule: background-attachment` 17,042, `property: display` 9,408, `structure: remove:
in an inline context` 7,982, `(built again)` 7,042, nearly all the document element replaced, `RenderTree::flushRoot`),
`testOpsMatchAFreshMirror` 45,411 of 61,649 (`structure: …: renders nothing` 7,065, `(built again)` 6,922, `attribute:
hidden` 6,179). A flush's churn goes under the first reason its session gave.

KB are deterministic on one platform (the units were too, while they existed): the same on every run and, since
quickjs-ng change 12, in every build configuration (before it, a build without `NDEBUG` made every string larger).
Another platform's allocator can move them: QuickJS counts a block over 512 B at the allocator's usable size
(`js_arena_usable_size`), which the memory figures, the collector's thresholds and the in-place string concatenation
read. The host wall times were to be
re-measured on a quiet machine before an M1d gate, which the spec's amended D5 removed; M5 measures the boot on a
device.

## Divergences

Spec §10 lists every intended difference from the old runtime and from the specs, including the ones M1a to M1d added
(§10.1 and §10.3). There is no comparison harness (the amended D5): the list is the record, and WPT and the corpus are
the gates. M1c's were the ones the validator's removal made; since V4 profile 1 decides the renderer's copy again
(M1c's invariants), so what remains of them is that the validator's diagnostics are gone, a theme change re-themes
`style` attributes and SVG presentation colours, and a `<style>`'s sheet is its Text children only.

M1d's, from the old runtime (spec §10.1):
- **A frozen widget does not reflow.** It keeps its last tree, drawn at its own layout and clipped to a new width, and
  the theme it froze in; the old renderer reflowed and re-themed its kept document.
- **The badge is drawn, not injected.** `WidgetTreeRenderer` draws it in CoreGraphics over the bottom left of the
  last tiles (V1: the bottom right is where the widget bubble's date pill sits), with the old badge's look; the old renderer put it into the document as HTML, with a rule that set the
  body's opacity to 0.85, which is not drawn now.
- **`innerWidth` and `innerHeight` are the layout's** (V3: the layout width and the document's height, "Layout
  queries"). The old core sent the offered width and 300 by a `viewport` task; the core has no such task now.
- **No keyboard events.** There is no `KeyboardEvent` interface (iOS has no keyboard path into widgets), and
  `createEvent('KeyboardEvent')` throws `NotSupportedError`; the `onkey*` handler attributes stay and never fire.
- **A widget that published nothing is `.failedToStart`**, the unsupported pill, not frozen: a caught failure or a
  memory stop before the parse's flush published (a counted cap's stop there freezes with the badge alone, "Divergences
  from widget-sandbox v0.3.0" item 9).
- **A tap's events come in touch browsers' order**, `pointerdown`, `touchstart`; `pointerup`, `touchend`; then
  `mousedown`, `mouseup`, `click`, and a drag sends no `mousemove`.
- **Bridge arguments are strings**, always a JSON array of them: a link's URL as checked and normalised, a haptic's
  kind and style or type.
- **One press is one gesture.** The reference numbers gestures from the renderer's events, and on a touch's order
  (`pointerup` before `mousedown`) its counter starts a second gesture at `mousedown`; ours is one per press, as sdk-v1
  §2.5 says ("one press unlocks one call"). The reference's 5-second gesture lifetime is not ported: a press is only
  ever usable while its own events dispatch.
- **The haptic gate runs on the step's clock** (`EventLoop::currentTime`), not the live one the reference's host
  reads. A burst inside one task never sees a refill however long the task runs, and the touch's press and release
  are stamped with the times of the tasks that run them.
- **At the chat's bottom a top-anchored widget grows upward** (the user, 2026-10-28): the chat stays at its bottom
  until the widget's top reaches the screen's top inset, and only the rest of the growth goes downward. And while the
  chat holds a pinned message (a bot streaming its reply under the user's message, until a drag or a held jump to
  another message), a widget grows away
  from it whatever its anchor: a bottom-anchored one under it does not keep its bottom. sdk-v1 §5.6 keeps the anchored
  edge everywhere; the message widgets guide's "Which edge stays put" has the rules.
- **There is no source cap** (V1): M1d's 256 KiB cap is gone with the inline `tgwidget` blocks and `.tgw` files it
  covered. The old runtime booted an inline source of any size, and stopped it when its serialized document passed
  256 KiB.
- **The built-ins diverge in places** (V5a): `URL`'s setters re-parse instead of using the state override (WPT's URL
  data fails 7 cases, none of them IDNA: `Tests/url-data-expected-failures.txt`); `TextDecoder` knows UTF-8 only; `EvalError` and
  `URIError` clone as `Error`; a `DataView` is a `DataCloneError`; `[Clamp]` and `[EnforceRange]` are not applied
  (`Blob.slice`, `AbortSignal.timeout`); there is no `FileReader` and no `AbortSignal.any`.
- **Intl diverges in places** (V5b): `formatRange`, `formatRangeToParts`, `selectRange`, the `formatToParts` of
  `RelativeTimeFormat` and `ListFormat`, `Segmenter`, `DisplayNames`, `Locale`, `DurationFormat` and
  `supportedValuesOf` are absent. A tag's unicode extension reaches the glue reduced to the keywords its constructor
  reads, with supported values (above); the glue applies them on iOS 16 and later, while `resolvedOptions()` still
  reports `latn` and `gregory`, as upstream's glue answers it. The `numberingSystem` and `calendar` options do not
  override an extension's keyword (ECMA-402 drops the keyword then): the glue reads neither option, so
  `new Intl.NumberFormat('en-u-nu-thai', { numberingSystem: 'latn' })` formats in Thai digits. `hour12` and
  `hourCycle` do override (the glue rebuilds the hour cycle from them). What the glue
  formats is Foundation's, and it formats only what widget-sandbox's
  shim asks it for: no compact, scientific or unit notation, `roundingMode`, `roundingIncrement` or
  `trailingZeroDisplay` (accepted and reported, not applied); a `calendar` or `numberingSystem` is reported, the glue
  formats Gregorian in Latin digits; `caseFirst` and `ignorePunctuation` do not reach the comparison; quarters are
  English words, and months elsewhere; a unit list is a narrow conjunction (widget-sandbox's docs/changes.md, v0.1.1,
  lists the glue's own approximations). Locale tags are canonicalized in case only (no alias is replaced) and every
  valid tag is supported; a time zone the glue does not know formats in the device's, and only a name that cannot be
  one (`+01:00`, `../x`) is a `RangeError`. A string handed to `NumberFormat.format` goes through `ToNumber`, and a
  BigInt reaches the glue as a number.

Two things the M1d plan wrote otherwise keep the old runtime's behaviour, so they are not divergences: the host CSS
goes with litehtml's master sheet (an author's rules win over it, as with `LHDocument`'s `MasterWithCSS`), and a
snapshot's width is the layout width, not the content's natural width.

## Divergences from widget-sandbox v0.1.0 (for the maintainers)

What V4 does differently from the reference validator and sandbox at v0.1.0, on purpose. One line each:

1. **No text churn limit.** The reference's `text-churn` bucket refills by wall-clock time; this client has no such
   bucket (its only limits on time are the CPU limits, "Limits").
2. **Rendered elements are capped at 10,000** (Ruling E9), below the 50,000 nodes, which both count.
3. **`var()` is judged after substitution:** `--p: sticky; position: var(--p)` lays out as `relative`. The reference
   checks a value only as written, so `var()` bypasses its value rules.
4. **The CPU limits were work units, not milliseconds** (spec §4.3), until 2026-10-30. Since then they are the
   reference's, in milliseconds of the widget thread's CPU ("Limits"): no longer a divergence.
5. **Media and supports:** range syntax with units is in profile (`(width >= 400px)` matches; the reference reads `px`
   as a feature and drops the rule); `@supports` mixing `and` and `or` without parentheses is invalid, so false, as in
   browsers (the reference evaluates it left to right); `CSS.supports('content', 'attr(class)')` is false, the
   renderer's own verdict (the reference skips strict `attr()` there and answers true); `@keyframes` inside a kept
   `@media` apply whether or not the query matches now.
6. **Absent members throw:** `showPopover`, `hidePopover`, `togglePopover`, `scrollIntoView` and the textarea's
   `select()` are not defined, so a call throws `TypeError` where the reference does nothing; and **no diagnostics
   report what the profile dropped**: no `tag-dropped`, `attr-dropped`, `css-dropped`, `url-blocked` or `profile`.
7. **The text budgets count what renders, in tree order, on every build and patch:** text under a dropped element, a comment's
   data and a sheet that is not applied count nothing; a sheet's strings are read from its raw text (`"\5b57"` is five
   units, not one); and what fits is decided by tree order, where the reference decides by the order of operations
   over time.
8. **A refused text change renders nothing:** the build is stateless, where the reference keeps the last accepted text.
9. **`data-tg-link` and `data-tg-placeholder` never go stale:** a patch re-derives every attribute, so the markers follow
   the current `href` and `src`.
10. **`light-dark()`'s two branches are both checked.**
11. **Canvas fonts are not reduced to the profile's families** (the canvas default is `sans-serif`).
12. **WPT:** no row was lowered by V4 (focus included; `blur-event.window.js` still passes).
13. Smaller ones: `tabIndex` defaults to 0 for HTML's focusable kinds (the sandbox: -1); `activeElement` with no body is
    the document element (the sandbox: null); `drawImage` of a refused `<img>` draws the placeholder (the reference's
    behaviour there is not established); a `<style>` whose text or strings do not fit is not applied and counts
    nothing (the reference blanks the sheet and keeps its text charged).

## Divergences from widget-sandbox v0.4.0 (for the maintainers)

What this client does differently from v0.4.0's validator and renderers (`packages/core/src/host/validator.ts`), on
purpose. One line each:

1. **The CPU limits are upstream's** since 2026-10-30 (its numbers and messages, its quota policy as the vendored
   `CpuBudget`, its clock: "Limits"), but for three things:
   - **Our renderer's flushes are charged to no window.** The main-thread window holds what upstream's does, the layout
     queries' time and the modelled cost of the operations and canvas commands; our renderer runs on the widget's pool
     thread, and its other flushes (each step's render build and publish, the ResizeObserver rounds, a width, theme or
     reduced-motion change) are measured, kept out of the slice and the JS quota, and charged to no window, as
     upstream's renderer's work is not (the CPU-clock limits plan's Task 6 ruling: charging them throttled honest
     corpus widgets; `EventLoop::endStep` is the one line to revert). A flush-heavy CSS animation can hold a pool
     thread for its flushes at every frame.
   - **Our DOM and renderer are native code, which nothing interrupts.** As upstream's, the slice and the backstop are
     read only at QuickJS's polls, and QuickJS's own builtins do not poll (a `trim` of 4 MB, BigInt division, a
     generic `join` of `{length: 2**40}`), so the stop lands at the next poll after them. Upstream's DOM is its shim's
     JavaScript, which polls, and its renderer runs off the widget's thread; ours are C++ on that thread, so a long
     DOM walk or a render build also runs to its end. One hostile message can hold one of `MessageWidgetPool`'s two
     threads for as long as that call takes, delaying every widget queued there; main keeps its 20 ms cap (the user's
     call, exact parity over interrupt points of our own). No page of the attack corpus does (measured 2026-10-30,
     `InstanceTests.testAttackCorpusRequestsNothing`, over the boot, three frames and 0.2 s): the CPU of each task's
     runtime steps (their JS and render, on the thread's clock; not the boot's parse and first build, which are no
     step, nor the publish and the tile drawing) is largest for the tasks the slice stops, `timer-flood`'s boot at
     546 ms and `fallback-at-boot`'s at 500 ms, then `layout-query-loop`'s at 107 ms (its query limit), every other page
     under 60 ms. The test fails a task past two slices, which is the most a task may take by design (a drain stops
     after a slice, and the step that crosses it runs to its end), so it catches a runaway, not a native path a few
     hundred ms long. A task that stops its widget after its first publish has its CPU read before the stop drops the
     session (it read 0 before); a boot that stops before it publishes still reads 0.
   - **A follow-up is a task of its own, on a slice of its own.** Upstream settles a delivery's follow-ups inside that
     delivery's slice (at most 20 rounds); here each follow-up task inherits its root's kind and gets its own slice,
     so a chain rooted in a boot, event or visibility step is never deferred by the JS quota. A core drain, and the
     boot's loop, stop once a slice of CPU is spent, so such a chain shares its pool thread with the other widgets
     between drains.
2. **Operations are counted at our DOM's changes**, stamped per batch to come out as upstream's flush difference, not
   diffed against a mirror: a node made and never inserted costs nothing, and a node's attributes and text count nothing
   in the batch it is first inserted in (upstream sends them with the node); an attribute or a text written back to its
   old value in one batch still counts one (upstream: none), and a node made, inserted and removed in one batch counts
   three (upstream: none). A node counts its making at its first insertion anywhere, not when it reaches the document:
   a subtree built detached in an earlier batch, or detached and put back in a later one, counts its root only, one
   (upstream sends it whole, two per node), and writing a style attribute's text that predates the batch (`cssText`,
   `setAttribute('style')`) counts one (upstream: one per changed property). These are lenient only. A batch ends at a
   task, a frame, and after a layout query's flush.
3. **Text, attribute, rule and canvas-pixel caps are judged on the render build**, over what renders in tree order.
4. **A gradient's `addColorStop` and a Path2D's own steps are not canvas commands** (upstream counts them per canvas):
   our gradients and paths do not know their canvas.
5. **Animation frame callbacks keep a cap of their own**, 256 (upstream's shim caps none): our table needs a bound.
6. **The 1024² `data:` image cap holds under compat too** (upstream's `MAX_IMAGE_PIXELS` is a constant there as well).
7. **A broken `url()` in CSS drops its declaration** (upstream swaps in its `BROKEN_IMAGE`): it draws the same nothing.
8. **No network marker** (the user's decision, 2026-10-29; sdk-v1 §5.11 asks for one beside the date when the message
   has `can_query`).
9. **A stop before the widget first published freezes with the badge alone**, never the "please update" pill: the pill
   says the app cannot show the message, which a limit stop is not.
10. **CSS rules are counted over each applied sheet as written**, not after our policy (upstream counts its sanitized
    text), so a sheet with many out-of-profile rules stops a little earlier here.
11. **A style attribute keeps the `env()` its author wrote** (v0.4.0): the renderer gets the policy's rewrite, as for every
    rewrite here, so `el.style.paddingBottom` reads `env(safe-area-inset-bottom)` back where upstream's validator stored
    `var(--tg-content-safe-area-inset-bottom)`.
12. **The bubble's touches take the whole corner box the widget is told is covered** (v0.4.0), the date pill with its
    8 pt margins on both sides, where upstream's reference keeps the pill alone from the widget: the bubble's press
    shrinks it, and a long press's activation, the tap recognizer's own long tap and a tap's up all convert a held
    finger's down point through that shrink, several points toward the corner, so a touch begun on the pill's edge
    would otherwise reach the widget late (the message widgets guide, "The time over the widget").

## Divergences from widget-sandbox v0.5.0 (for the maintainers)

What this client does differently from v0.5.0's shim and glue, on purpose. One line each. Aligned with upstream on
2026-10-31 (the user): the promise errors' words, the messages read through their iterator, an incomplete emulation
shown in the window, and the top-up offered for a short balance (§5.13).

1. **No wallet for a user whose device cannot sign** (the user, 2026-10-30): `context.wallet` needs a wallet this device
   holds the key for, beside `wallet_available`, so a widget never makes the server create a wallet (§5.13 says whether
   the user has one is not part of it).
2. **A send whose server reply is lost reaches the bot only through the chain**: the transfer accepted with no message
   hash (`.submissionUnknown`) is `FAILED` to the widget, and no query reports it, though the wallet may resolve it
   later (§2.18's "may have been sent").
3. **A channel post a bot sent cannot pay or sign**: the client finds no bot for it (no via bot, the channel as the
   author, no bot id on the media), so its wallet calls are `FAILED` with no window; the bot's id on
   `messageMediaWidget` would close this.
4. **Messages whose iterator gives no value, or more than 255, while their `length` is 1–255, throw `TypeError`**: the
   shim posts what its `for…of` read and the glue drops the malformed call (`bridge-rejected`, the promise never
   settles); this runtime is the shim and the glue in one, so it refuses the call where it is made, reading at most 256
   values.

## What the corpus still trips on

`CorpusTests.testEveryCorpusWidgetStartsAndFetchesNothing` boots every corpus file but `attacks` with no crash and no
stop. The uncaught errors it allows (`CorpusTests.knownGaps`) are all by design: `Chart is not defined` and
`d3 is not defined` (profile 1 bundles no library and the app installs no script loader, so a library loaded by URL is
`script-skipped`) and `fetch is not defined` (a widget never fetches). The Hang and Buggy buttons are not honest widgets
(`throwsOnPurpose`).

## Tests

Host tests, from the repo root:

```sh
./build-input/bazel-9.2.0-darwin-arm64 test \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeTests \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeBindingTests \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeIntlCasesTests \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeBidiTests \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeNoWorkUnitsScanTests \
  //third-party/widget-sandbox:WidgetSandboxIntlTests //third-party/widget-sandbox:CpuBudgetTests \
  //build-system/WidgetIDL:WidgetIDLTests //third-party/quickjs-ng:QuickJSHostTests \
  //third-party/gumbo:GumboHtml5libTests --test_output=errors
./build-input/bazel-9.2.0-darwin-arm64 test //third-party/gumbo:GumboForkTests   # alone: its timing case is flaky under load
```

V4's profile suites are in `:WidgetRuntimeTests` (listed under "Profile enforcement (V4)"); the fork's hooks are
`//third-party/twidget:TwidgetProfileHooksTests`; `:WidgetRuntimeBuilderHtml5libTests` guards that the DOM's parse stays
unfiltered.

The CPU limits (2026-10-30): `CpuSliceTests` (a step stops past its slice with upstream's message and says when the
quota shrank it, render time is not the slice's, layout queries past 100 ms stop, the wall backstop, the thread clock
skips sleep, each boot script and the load have a slice of their own, the parse is not the widget's),
`CpuQuotaTests` (the quota defers timers but not events, deferred tasks keep their order and run at the retry, frames
collapse, a tap's follow-ups run with it, the main-thread window defers, the diagnostic once a second,
`cpuKillAfterMs`, a width lays out at once) and `StopGuardTests` (the memory limit, the uncatchable stop, the count
caps and the parse's limits still stop) are in `:WidgetRuntimeTests`, on the harness's fake clock;
`:WidgetRuntimeNoWorkUnitsScanTests` fails on any deleted work-unit name in the runtime, its iOS glue and quickjs-ng;
`//third-party/widget-sandbox:CpuBudgetTests` runs the vendored `CpuBudget` against upstream's `cpu-budget.json`; and
`MessageWidgetTests`' `LimitsTests` stops runaways through the app on the real clock with upstream's message. The
harness gives every runtime the product's slice (500 fake ms, a millisecond per interrupt-handler check) with both
windows lifted; the quota tests set the product's windows.

The WPT runner (vendored tests on a virtual clock; fails on any regression or unexpected change), and how to
record new results:

```sh
./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWPTTests
./build-input/bazel-9.2.0-darwin-arm64 run //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWPTTests -- --update
```

At the end of M1b it recorded 331 pages (304 with the harness OK) and 3,078 of 4,541 subtests passing, and skipped
139 pages (`wpt-skip.txt` gives each its reason). At the end of M1d it records 350 pages (318 with the harness OK, 16
ERROR, 9 TIMEOUT, 7 STOPPED) and 3,276 of 4,594 subtests passing, the `css/cssom/` subset included, and still skips 139.
Six `NodeList-static-length-getter-tampered*` pages are STOPPED (by the 500,000,000-unit page cap then; since
2026-10-30 by the harness's slice on its fake clock), and
`Event-timestamp-safe-resolution.html` loops waiting on a fixed clock. M1d recorded with `--allow-regressions` three
times. In Task 2, three pages that now run further and wait for what is absent by design: `Event-dispatch-click.html`
(TIMEOUT, on activation and `hashchange`), `Event-stopPropagation-cancel-bubbling.html` (ERROR: no `window.event`) and
`Event-timestamp-safe-resolution.html` (STOPPED). In Task 3, `Event-dispatch-single-activation-behavior.html`, whose
harness went from ERROR to OK and whose old FAIL rows are no longer reported under those names (122 rows newly pass).
With `element.style`, the animation cases of `EventListener-invoke-legacy.html`, which now sets `style.animation` and
waits for animation events (TIMEOUT: CSS animations run since V5f, but only over a render tree, which this runner
does not install).
V5e added `web-animations/` (71 pages run, 2 skipped on the virtual clock; 964 of 1,216 subtests pass). Its runner keeps
no render tree, so computed-style subtests there stay unverified; `AnimationRenderTests` covers the render path. V5f
added the CSS event interfaces' pages (`css/css-animations/animationevent-interface.html`,
`css/css-transitions/transitionevent-interface.html`, 42 of 42 each); the other pages of those directories need a CSS
animation to run, which needs the render tree, so `CSSAnimation{Rules,Object,Render,Event}Tests` and `CSSStyleStepTests`
replicate the conformance pages' numbers on the host render tree instead.

M1c's targets, from the repo root. The first two are the render layer's own gates; the twidget ones test the litehtml
fork on the host: `:TwidgetExternalTests` pins edits 12, 16–18, 20 and 21, and edits 13, 14, 15 and 19 have `:TwidgetSchemeTests`,
`:TwidgetCssNestingTests`, `:TwidgetCssListsTests` and `:TwidgetPseudoNestingTests`:

```sh
./build-input/bazel-9.2.0-darwin-arm64 test \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeRenderCorpusTests \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeNoIOScanTests \
  //third-party/twidget:TwidgetLitehtmlSmokeTests //third-party/twidget:TwidgetForkTests \
  //third-party/twidget:TwidgetExternalTests //third-party/twidget:TwidgetSchemeTests \
  //third-party/twidget:TwidgetCssNestingTests //third-party/twidget:TwidgetCssListsTests \
  //third-party/twidget:TwidgetPseudoNestingTests --test_output=errors
```

`:WidgetRuntimeTests` (454 cases at the end of M1c, 491 at the end of M1d) holds the render suites: `RenderBuildTests`,
`RenderJournalTests`, `RenderTextPatchTests`, `RenderAttributePatchTests`, `RenderStructurePatchTests` (with
`testRandomEditsMatchARebuild`), `RenderHitTestTests`, `WidgetContainerTests`, `LayerTreeTests` and `LayerMirrorTests`;
and M1d's `HostApiTests`, `TapTests`, `ActivationTests`, `FocusTests`, `BridgeTests` and `StyleDeclarationTests`.
It takes about a minute. `testSelectorParsingIsLinear` times itself and can flake under load: rerun it alone.

M1d's iOS targets are `ios_unit_test`s on a runner pinned to iPhone 17 / 26.5, run through `Make.py test` (root
`CLAUDE.md`, "Running tests"; `--testFilter Class` or `Class/testMethod` runs part of one, since M1d):
- `//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS:WidgetRuntimeIOSTests` (30 cases): the CoreText
  host against `LHContainer` and hostile images, the painter against `LHDocument` (16 fixtures; a CSS filter paints
  nothing in a test process, which has no Metal device), and the `WRSession` facade;
- `//submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests` (141 cases): the instance, pool,
  handshake, registry, view and the other kept suites on the native core, `NativeCoreTests`, and the 93 attack pages;
- `//submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetCorpusTests` (size large, about 7
  minutes): the corpus files through the whole pipeline on the product's CPU limits and the widget thread's clock (an
  honest widget's largest step under 125 ms, a quarter of the slice; its JS at most 75 ms a second while it runs on, a
  quarter of the quota; never throttled, but for the two files the message widgets guide names), and the latency
  measurement.

Two manual programs run with `-c opt`:
- `:WidgetRuntimeMeasurementTests`: the §6.2 numbers (KB, and times on the wall and thread CPU clocks), and a check
  that no corpus document reaches a parse limit.
- `:WidgetRuntimeCorpusBootTests`: every corpus document booted headless, with the render tree since M1c; the §6.2
  boot numbers, the first flush's, and the failures by missing global (M2's list).

The corpus goldens, `:WidgetRuntimeCorpusGoldenTests` (size large, seconds), hold every non-attack corpus document's
results, so that a change in the runtime or the renderer shows as a diff to fix or to accept: how the run ended, the
render limits, what the host was told (diagnostics, console, bridge calls, storage commits, refused loads), the DOM
without its scripts' and style sheets' text, the layout dump and the paint (`LayerTree::dump`, each font description
printed once), in `WidgetRuntime/Tests/CorpusGoldens/<path under corpus/>.txt`. Each document boots at width 360 to
idle, runs one virtual second and is flushed, in deterministic mode: the host's virtual clock (its wall clock at
2026-01-01T00:00:00Z), random seed 1, `FakeRenderHost`'s metrics (8 px a byte, breaking only between code points), Intl
answered by `echoIntl` (the request itself) and `TZ` pinned to Asia/Tokyo by the test (an offset, so a local-time and
UTC mix-up shows; no daylight saving). Each step runs in the harness's slice on its fake clock, which stops only a
runaway. Animations are kept; CPU times and memory are never recorded. Accepting a
change, or re-vendoring the corpus, records them again (and removes the goldens of documents the corpus no longer has):

```sh
WR_GOLDENS_UPDATE=1 ./build-input/bazel-9.2.0-darwin-arm64 run \
  //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeCorpusGoldenTests
```

The corpus incremental run, `:WidgetRuntimeCorpusIncrementalTests` (size large, about a minute), runs every corpus
document (the attacks included) and every client fixture in the goldens' deterministic mode (the boot, 3 s, a grid of
taps, 120 frames) and fails when one builds more than once or stops for an inconsistency (`RenderTree::stopInternally`).
It and both randomized oracles print the churn (`Tests/LayerChurn.h`, a `RenderTree::FlushProbe`): the layers their
flushes re-created though the element did not change, summed and by the fork's reason (`rebuild_reason`), the layers
of an element the runtime built again apart: `(moved)` for a moved node, `(built again)` for an unchanged one.

The randomized oracles (`testRandomEditsMatchARebuild`, `LayerMirrorTests.testOpsMatchAFreshMirror`) share
`Tests/IncrementalEdits` (one page, one `__edit` generator: structure, text, class, style, `hidden`, tables,
templates, any attribute, box-type styles, `<style>` edits, the document element) and run groups for each kind, the
environment (width, the theme's own declarations, reduced motion, taps, each with something on the page that renders
it; a tap is a task, run by draining the loop), animations with structure, and pages near each limit (the text pieces,
selector steps, form controls, litehtml's element cap, the render bytes, the text budget, the node cap and the style
bytes), whose filler goes first so that an insertion crosses the cut and a removal comes back; each patches across
its limit. After every flush, which must not build or stop the widget,
the render oracle compares the patched tree with a fresh one: the layout, the render input, the recorded paint, the
render limits, litehtml's own counts (`text_elements`, `build_elements`, `pseudo_elements`), and what the read APIs answer (`wr_test::readsDump`: boxes, client and visual rects, computed style, hit
tests, the selectable text, the filler aside); the mirror oracle, the operations replayed on the previous tree against
a fresh mirror, and the union of the batch's changed rects (`takeChangedRects`) against the diff of the published trees,
which share every node no operation names (`LayerDiff` matches them by identity first), for a batch that did not
build.

The corpus is `third-party/widget-sandbox/corpus` (`//third-party/widget-sandbox:CorpusFiles`).

## Open

- **V6, the release checks** (the client spec's §5). The pass by eye of the visual conformance set is done on the
  simulator (light, dark, incoming, the largest text size, every widget re-created by scrolling): every row matches
  its picture but `visual/02`'s tiled row and `visual/13`'s popover and button label, both the set's ("Rendering
  fidelity"). Open: what needs a device or real messages: rotation, right-to-left, the bot's real layer-233 messages
  end to end (forward, edit, delete), the SDK group's interactive rows (links, haptics, an app restart), the feed
  bench on a low-end device, an iPad trackpad, and a resize during a drag.
- **The wallet (v0.5.0, 2026-10-31).** Unverified: the real path (prepare, the window, the send or the signature, the
  bot's query with `msg_hash` or the signature) has not run end to end; it needs a wallet this device signs for, a
  bot's widget that can query, and the server's side of layer 233's wallet queries. The window itself was seen only
  through Debug Settings ▸ "Show widget wallet window (nothing is sent)". For the maintainer: the bot's id on
  `messageMediaWidget`, so a bot's channel post can pay (divergence 3); whether a send the wallet resolves later should
  reach the bot (divergence 2). The top-up offer (2026-10-31) is unit-tested as far as its outcome; the alert and its
  receive screen were not seen on a short balance. `userWallet#454d2737` is the maintainer's (their schema of 2026-10-31). Follow-ups,
  none blocking:
  - the window: a cancelled passcode closes it (a dApp's stays for a retry); after a failure past Confirm the sheet
    leaves in one frame instead of sliding out (`dismiss(completion:)` on a pushed sheet, and the screen has no public
    animated close that does not report `cancelled`); a window prepared after the chat closed is pushed over whatever
    the chat's navigation shows; the bot line has no accessibility label, and no unit test (the screen's module
    reaches AccountContext);
  - the bot line: a name of invisible characters that are not whitespace (U+3164, U+2060, U+FEFF) survives trimming
    and leaves `· @username` after an invisible name; a short name that would fit is dropped when less than
    `ceil(3 × font size)` points are left; a name with a newline inside could overflow by an ellipsis;
  - the wallet's side: a transient engine failure while preparing maps to `BAD_REQUEST`; a sent transaction's card
    carries no signing data (the server attaches the card); on a cold start a widget on screen may boot twice when the
    wallet's state loads; the availability's `set(false)` clears another owner's answer (by design, the latest answer
    wins);
  - the runtime: the argument converter reads every own value before `onlyKeys` refuses an extra key (a getter on an
    extra key runs here, not in the shim); its 65,536-unit string limit could be 8,192 (no check takes more);
  - Debug Settings' row hardcodes the shield's 0.8 s (`MessageWidgetWalletWindow.ignoresTouchesFor` is in another
    module).
- **After V6** (the spec's §5): WPT rendering (reftests and `check-layout-th.js` tests through litehtml, with their own
  ratcheting expectations); the boot measured against main's 20 ms wait on a device.

The host contract the app keeps (`MessageWidgetCore`, `WRProductionHost`, `CoreTextRenderHost`):
- the loop is stepped with `now`, `CACurrentMediaTime()` in milliseconds, which is also the clock `WRProductionHost`
  reports to the runtime;
- `MessageWidgetCore` reads `stopReason` and `failed` after every task (`publish`), so a stopped widget freezes
  instead of reading as idle;
- moves reach the runtime's tasks only when the widget listens for them, which `Taps.cpp` decides from
  `ListenedTypes` itself: the host does not call `takeIfChanged`;
- a width or theme change is `setWidth:` or `setDark:`, each followed by a flush; a stopped widget meets a new width
  by being clipped, not reflowed, and the view paints the canvas colour right of a narrower picture;
- `CoreTextRenderHost` never throws and never calls back into the runtime, and its fonts and images (`IOSHostFont`,
  `IOSHostImage`) outlive it;
- out-of-memory is fatal at the facade, and no source is refused for its size (V1 removed `WRSession`'s 256 KiB cap);
- a tile the renderer cannot draw keeps the last frame up and leaves a `tile-draw-failed` diagnostic;
- taps, the UI events and the activation behaviour are built, and `TapTests` and `ActivationTests` pin their order.
