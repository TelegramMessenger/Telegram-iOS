# Message widgets: HTML widgets in chat bubbles

Date: 2026-10-13. Status: approved, then amended with the implementation plan
(`docs/superpowers/plans/2026-10-13-message-widgets.md`, "Deviations from the spec"). The
amendments are written into the sections below.

## Goal

An AI bot (bot → Claude API → `show_widget(html)`) sends a self-contained HTML
widget, and Telegram iOS shows it live and interactive inside the message
bubble.

- **Hard requirement:** a widget can never cause a network request from the
  device, so it cannot reveal the user's IP. Requests to Telegram's servers are fine.
- **Success for this version:** examples 01–05 in `docs/widget-messages/examples/`, posted
  as rich messages, render at the correct bubble height and respond to taps, and
  widget-sandbox's attack corpus requests nothing.

The sandbox comes from `~/build/widget-sandbox` (`docs/overview.md`,
`docs/decisions.md`, `docs/protocol.md` there). This design keeps its
JavaScript side (QuickJS, the DOM shim, the validator) and replaces its iOS
host: there is no WKWebView. Everything runs synchronously on the main thread,
and a renderer of our own is built on litehtml.

## Decisions

| Topic | Decision |
|---|---|
| Wire format | The final format is a new `PageBlock` (schema work later). For now, a code block with the language `tgwidget` whose text is the whole widget. |
| Messages | Rich messages only (`RichTextMessageAttribute`). A plain message with a `pre` entity stays text. |
| Authors | Users never author widgets. Bots do; for testing, examples are posted by hand. |
| Platforms | iOS only, iOS 15.0 and later. |
| Threading | The widget's JS and its layout run on the main thread, synchronously, so the bubble's height is known in the layout pass. |
| Renderer | A renderer of our own on litehtml, like React Native: litehtml lays out, and the result is drawn as a native layer tree. No WKWebView, no Blitz. |
| Hosting | An InstantPage V2 item inside `ChatMessageRichDataBubbleContentNode`. |
| State lifetime | A widget's runtime lives exactly as long as its message bubble. |
| Scope of this version | Examples 01–05: cards, taps, height changes after a tap, timers, the bridge. No grid, SVG or canvas; transitions jump to their final state. |
| `sendMessage` | Sends immediately as the user, but only from a task started by a real tap, and once per tap. |
| Code | Everything vendored. Third-party code goes to `third-party/` (it may become git submodules later). Our code goes to `submodules/`. |
| QuickJS stack limit | 2 MB for both runtimes (see "Stack" below). |
| Performance | Deferred. Correctness first; the cost of booting a widget on the main thread is accepted for now. |

Defaults set during brainstorming, not raised as questions:
- widgets keep their own CSS px and ignore Text Size;
- a long press opens the message menu;
- the feature is off unless a Debug Settings toggle is on and no server killswitch is set.

## Out of scope

- The `PageBlock` schema and server work.
- Plain-message widgets.
- Users authoring widgets.
- Android, desktop, web.
- Grid, SVG, canvas, Chart.js and D3 (examples 06–09).
- Native form inputs.
- `:hover`/`:active` styling.
- Animated transitions and `@keyframes`.
- Scrolling or dragging inside a widget.
- Persistent `localStorage`.
- Pools, prewarming, snapshot-and-drop, and any other performance work.

## 1. Code layout and ownership

`third-party/`. These are vendored copies, edited in place where the design needs it:

| Path | Target | Contents | Source |
|---|---|---|---|
| `third-party/quickjs-ng/` | `cc_library`, `-O2` in **every** configuration | quickjs-ng v0.17.0 plus `qjs_shim.c` | widget-sandbox `packages/ios/Sources/CQuickJS` |
| `third-party/litehtml/` | `cc_library` | litehtml master `4a651c52` plus its gumbo, **our fork** (§3) | widget-sandbox `apps/renderer-litehtml/third_party/litehtml` |
| `third-party/widget-sandbox/` | `apple_resource_bundle` for the JS; a `filegroup` for the fixtures | only built artifacts and fixtures. The app bundle gets `sandbox-bundle.js`/`.qbc`, `validator-bundle.js`/`.qbc`, and `libraries.json` with `libs/`. The `corpus/attacks` files are test fixtures, attached only to the test target's resources and never to the app. A `VENDOR.md` names the widget-sandbox commit (`862eec8` as of this writing). | widget-sandbox `packages/ios/Sources/WidgetSandbox/WidgetJS`, `corpus/attacks` |

The TypeScript sources of the two bundles stay in widget-sandbox. A change to
the DOM shim or the validator is made there and re-vendored as a unit.

Our code lives in `submodules/TelegramUI/Components/MessageWidget/`. It is
derived from widget-sandbox and rewritten for the main thread:

| Module | Target | Contents | Derived from |
|---|---|---|---|
| `MessageWidgetCore` | `objc_library` (C++) | ops → shadow tree → litehtml document; the container with no network access; the layout walker; hit testing; a C API for Swift | `apps/renderer-litehtml/src` (`renderer.cpp`, `apple/coregraphics.cpp`, `include/twidget_litehtml.h`) |
| `MessageWidget` | `swift_library` | the engine and validator glue on the main thread, `CpuBudget`, the native layer tree, the `MessageWidgetInstance` facade, and `MessageWidgetRegistry` (a bubble's runtimes, unit-tested here) | `packages/ios/Sources/WidgetSandbox` (`SandboxEngine`, `TrustedValidator`, `QuickJS`, `CpuBudget`) |

`MessageWidget/PROVENANCE.md` records the widget-sandbox commit each file was
taken from and how it was changed.

Not taken over: `RendererWebView`, `RendererEnvironment`, the renderer bundle,
`Pools`, `JSThread`, `WidgetHost`.

**Dependencies.** InstantPageUI does not depend on `MessageWidget`. It declares
`InstantPageV2WidgetHost`, and `ChatMessageRichDataBubbleContentNode` (which
depends on `MessageWidget`) implements it with an adapter over
`MessageWidgetRegistry`. TelegramCore is unchanged: the block is the existing
`.preformatted(text, language:)`.

**Test fixtures.** Byte-identical copies of examples 01–05 and 10 are committed
under `submodules/TelegramUI/Components/MessageWidget/Fixtures/` as test inputs,
together with their boot ops (`*.ops.json`). The docs examples themselves stay
uncommitted.

**Gate.** Widgets render only when both of these hold:
- `ExperimentalUISettings.messageWidgets` is on (a Debug Settings toggle);
- the app config has no `ios_killswitch_disable_message_widgets` (same pattern
  as `ios_killswitch_disable_corelist_chat_backend`, `ChatHistoryListNode.swift:1022`).

Otherwise the block draws as the code block it is today.

**iOS 15.** The C and C++ parts have no OS floor. The widget-sandbox Swift
package declares iOS 16, so the ported glue must be checked for iOS 16-only APIs.

## 2. The engine on the main thread

A widget is **two QuickJS runtimes on the main thread**:
- the widget's own runtime, with its scripts and the DOM shim;
- a trusted validator runtime running `validator-bundle`.

`JSThread` is replaced by a main-thread executor: `sync` runs inline and
`async` posts to the main run loop. Both runtimes are entered only on the
main thread.

**Stack.** `JS_SetMaxStackSize` is 2 MB for both runtimes. QuickJS counts the
limit from the point where JS is entered (`JS_UpdateStackTop` runs on every
entry), so the main thread's real stack must exceed the depth at entry
(UIKit plus the layout pass) plus 2 MB. If it doesn't, deep recursion crashes
the app instead of throwing a catchable `RangeError`. The app does not set a
main-thread stack size today, and the iOS default is usually 1 MB. The plan's
first step:
1. Measure the main thread's stack size on a device (`pthread_get_stacksize_np`).
2. If it is too small, raise it with the linker's `-stack_size` on the Telegram
   executable, after verifying that iOS honours it on a device.
3. If iOS doesn't, run each JS entry synchronously on a dedicated thread with an
   8 MB stack while the main thread waits. This is still synchronous for the
   layout pass, and it cannot deadlock because the JS side never waits on the
   main thread.

quickjs-ng is built `-O2` even in debug builds: a debug build spends about
10 KB of C stack per JS call, and css-tree in the validator recurses deeply.

**Boot happens inside layout.** The first measure of a widget block
(`MessageWidgetInstance.layout(width:)`) does all of this before returning a size:
1. Create both runtimes and evaluate the bundles from bytecode.
2. Run the shim's `boot`: parse the HTML, run inline scripts in order, fire
   `DOMContentLoaded` and `load`.
3. Validate the resulting ops inline and apply them to the core.
4. Have litehtml lay out at the given width.

Script-built content (03's FAQ list) is therefore part of the first height.

**After boot, every input is a task on the main run loop.** That covers
events, timers and animation frames. Each task:
1. runs JS;
2. lets the shim flush its ops at the end of the task;
3. validates them inline;
4. has the core apply them and lay out again;
5. if the height changed, queues a height-change notice for the host (§4);
6. updates the native tree.

**Timers, frames and queries:**
- **Timers** are `RunLoop.main` timers in `.common` mode, so they keep firing
  during a scroll. The 256-timer cap, the 24 h clamp and the 1 Hz rate while
  hidden are kept.
- **`requestAnimationFrame`** is driven by a `CADisplayLink`, active only while
  the shim has asked for a frame and the widget is visible.
- **Synchronous queries** are answered inline by the core: `rect`, `rects`,
  `box`, `cs`, `measureText`, `matchMedia`, `viewport`, `elementFromPoint`.
  The shim flushes its ops before every query, so the core is always current.
  The widget-sandbox semaphore and its 3 s timeout are gone; with the engine on
  the main thread they would deadlock, because the answer was posted to the
  main queue.

**Width changes.** `layout(width:)` with a new width re-lays out in litehtml
without running JS and returns at once. The `resize` and viewport update then
goes to JS as an ordinary task; any DOM change it makes is an ordinary height
change. So a widget whose script reacts to width (rotation, for example) shows
its litehtml-only height for one frame and then relayouts. That first height
is provisional by design. Running JS inside the width relayout itself is left
for later.

**No re-entrancy, enforced in both directions:**
- While a JS task runs, the engine never calls the host synchronously. Bridge
  calls and height-change notices are queued and delivered (via
  `DispatchQueue.main.async`) after the task ends.
- The host never enters an instance that is mid-task. This is asserted in debug
  builds and dropped in release.

Without this rule, a `sendMessage` that triggers a synchronous list update
could ask the same widget for its height from inside its own task.

**Kept from widget-sandbox:**
- the per-task CPU limit (`cpuLimitMs` 500, enforced by the interrupt handler)
  and the quota of 300 ms per 1000 ms (`CpuBudget`, deferring rather than killing);
- the memory limit, 64 MB;
- the `Intl` provider;
- `document.hidden` and `visibilitychange`.

Visibility comes from V2's `instantPageUpdateIsVisible` combined with window
attachment. The chat theme (light or dark) goes to the validator, which
re-resolves `light-dark()` and `prefers-color-scheme`, and to the shim (`onTheme`).

## 3. litehtml and the native layer tree

**Pipeline in `MessageWidgetCore`.** This is renderer-litehtml's core with
its threading made explicit:
1. Apply the validated ops to a shadow tree keyed by node id.
2. Serialise it to HTML, stamping each element with `data-twid="<id>"`.
3. Have litehtml parse it (`document::createFromString`) with our container.
4. Lay out with `render(width)`, converging over the viewport height as renderer-litehtml does.

The height is litehtml's document height, clamped to 24–900 pt; content beyond
900 is clipped in this version.

**The container is the no-network boundary.** litehtml fetches only through
`document_container` callbacks, so this is where the guarantee lives:
- `load_image` and `get_image_size` accept only `data:` PNG, JPEG, GIF or WebP,
  decoded synchronously with ImageIO, and refuse everything else;
- `import_css` returns nothing;
- `link`, `set_base_url` and `on_anchor_click` are no-ops (links go through
  the shim's `openLink`);
- `create_font` resolves only to installed CoreText fonts and never loads one.
  `system-ui`, `-apple-system` and `sans-serif` map to the system UI font, as in
  `coregraphics.cpp`.

The validator remains a second line of defence: allowlists, the CSS
sanitizer, the URL policy and size limits.

**Attributing drawing to elements.** litehtml's drawing callbacks don't say
which element they draw. The fork changes the 8 places litehtml enters an
element's `draw` (`document.cpp:570`, five in `render_item.cpp`, two in
`render_table.cpp`) to pass the render item being drawn as the opaque `hdc`.
Every drawing callback (`draw_solid_fill`, the gradients, `draw_borders`,
`draw_image`, `draw_list_marker`, `draw_text`) is reached only through those
sites, so each one now knows its render item. The container records it under
the nearest element with a node id. litehtml's own `document::draw` pass
records it, which keeps litehtml's paint order, positioning and table handling.

**Layout nodes.** After each rebuild, the core walks the DOM and emits one
`mwc_layout_node` per element with a node id that has a render item. The key is
the node id: an inline element that wraps across lines is one node, whose
fragments all draw in its layer. Each node carries:
- **frame:** the border box, in document coordinates;
- **clipping:** `overflow` not visible, together with border radii (radii via `calc_percents`);
- `opacity`, `transform` and `box-shadow`, parsed by the core from the fork's raw tokens;
- `z-index` for positioned elements;
- its parent, the nearest ancestor that is a node.

Anonymous boxes, `::before`/`::after` and text belong to the nearest ancestor
with a node id, so an element's text draws in that element's layer.

**The native tree in `MessageWidget`:**
- One `CALayer` per node. It draws its element's own commands (backgrounds,
  gradients, borders, list markers, images, text) through the core's
  CoreGraphics painter (`mwc_draw_node`), translated to the layer's origin.
- Clipping (corner radius plus `masksToBounds`, or a mask for unequal radii),
  shadow, opacity, transform (an affine transform around the box centre) and
  z-order are layer properties.
- Text is drawn with the same CTFont used for measurement, so drawn widths
  match laid-out widths.
- Updates diff the new tree against the old by node id: layers are reused and
  updated, missing ones are removed.
- Implicit animations are disabled, so transitions jump to their final state.
- Hit testing stays in C++; layers never hit-test.

**Fork changes in `third-party/litehtml` for 01–05.** Besides the draw token above, each
property adds a `string_id`, a case in `style::add_property`, and a computed field in
`css_properties`. The three paint-only properties are stored as raw token lists, and the core
parses them:

| Property | Kind | Examples | Extra work |
|---|---|---|---|
| `gap`, `row-gap`, `column-gap` (flex) | layout | 02–05 | `render_flex.cpp` `get_lines` (wrapping), `flex_line.cpp` `init` (free space minus (n−1)·gap) and `calculate_items_position`, row gap in the cross axis |
| `letter-spacing` | text width | 02, 05 | carried into `font_description` and the CoreText font (kerning) |
| `font-variant-numeric: tabular-nums` | text width | 05 | carried into `font_description`; a CoreText font feature |
| `opacity` | paint only | 04 | stored as tokens; parsed by the core |
| `transform` (2D: translate, rotate, scale, skew, matrix) | paint only | 03 | stored as tokens; parsed by the core |
| `box-shadow` (first outer shadow) | paint only | 01 | stored as tokens; parsed by the core |

Buttons draw as boxes from the core's existing user-agent CSS; 01–05 style
their own.

## 4. Integration with InstantPage V2

Paths below are under `submodules/`.

**Detection.** In `InstantPageUI/Sources/InstantPageV2Layout.swift`,
`layoutBlock` (around :999) sends a `.preformatted(text, language)` whose
language, trimmed and lowercased, is `tgwidget` to a new `layoutWidgetBlock`
instead of `layoutCodeBlock` (:2780), provided the gate is open and a widget
host is present. The widget's source is the block's plain text. Such blocks
are excluded from syntax highlighting
(`TextFormat/Sources/InstantPageSyntaxHighlightSpecs.swift`; the highlight
request in `ChatMessageRichDataBubbleContentNode.swift` around :828). The
bubble still sends only rich messages to that node
(`ChatMessageBubbleItemNode.swift:415` is unchanged).

**The item.** A new `InstantPageV2LaidOutItem.widget(InstantPageV2WidgetItem)`
carries a frame and the block's structural path. It goes through the same
checklist as every other kind:
- the enum (`InstantPageV2Layout.swift:81`) and its `frame`/`offsetBy` switches;
- `InstantPageV2ItemKind`;
- `stableId`, which is **`.widget(path)`, not positional**, so the view survives
  relayouts (`InstantPageRenderer.swift:1049`);
- `reuse` (:931) and `makeItemView` (:1113).

**Who owns the runtime.** `layoutInstantPageV2` (`InstantPageV2Layout.swift:496`)
gains `widgetHost: InstantPageV2WidgetHost?`. This protocol answers the laid-out
size for (path, source, width) and later provides the instance's view.
- `ChatMessageRichDataBubbleContentNode` passes one only when it is laying out
  on the main thread.
- The other four call sites pass nil, and so do lists that lay out off the main
  thread (`ListViewImpl` without `useMainQueueTransactions`). With nil the block
  draws as a code block.

The node owns a `MessageWidgetRegistry` (in `MessageWidget`), which keys each
`MessageWidgetInstance` by the block's path plus its source. A measure pass creates and boots
the instance it needs. This is a deliberate side effect in an otherwise pure
measure closure, allowed only because that closure is on the main thread. An
instance whose layout is never applied stays in the registry, so nothing leaks.

**Lifetime: the bubble.** All instances are destroyed when:
- the node is recycled for a different message (`ensurePageView`'s rebuild
  path, around `ChatMessageRichDataBubbleContentNode.swift:413`);
- the node is deallocated.

Editing the source gives a new key, and the widget starts fresh. The old
instance is destroyed at the end of the layout pass that stopped using it. Its
view keeps its last drawn frame, so the outgoing page view still shows it during
the crossfade. When some other part of the
message triggers a crossfade, the live widget view moves into the new page
view, and the outgoing page view shows a static snapshot for the fade.

**Height changes** follow the collapsible-quote path
(`currentExpandedQuotePaths`, `ChatMessageRichDataBubbleContentNode.swift` around :1950):
1. Each instance has a layout version, bumped when its laid-out height changes.
2. The node adds the versions to the `currentPageLayout` cache key (around :847–863).
3. On an instance's height-change notice, which arrives after its task (§2),
   the node calls `controllerInteraction.requestMessageUpdate(id, false, nil)`.
4. The relayout gets the instance's cached size for that width; no JS runs.

**Width, theme and Text Size:**
- The widget is laid out at the page's block width, without the stretching
  that code bands get (`instantPageV2StretchCodeBands`).
- Text Size (`contentScale`) is ignored.
- A chat theme change calls `setTheme`. That may change the height, which bumps the version.

**The view.** `InstantPageV2WidgetView` (an `InstantPageItemView`) hosts the
instance's native root view.
- `update(item:)` is idempotent, because V2 calls it on every apply: attach the
  view if it isn't attached, then set its frame.
- Visibility is driven per bubble: the node's `visibility` maps to the registry's `setVisible`.

## 5. Touches and the bridge

**Taps go to the widget; a long press opens the message menu.**
- `ChatMessageRichDataBubbleContentNode.tapActionAtPoint` (around :1789) returns
  `ChatMessageBubbleContentTapAction(content: .ignore, hasLongTapAction: false)`
  inside a live widget's frame.
- `.ignore` makes the bubble's `TapLongTapOrDoubleTapGestureRecognizer` fail at
  touch-down (`ChatMessageBubbleItemNode.swift` :1382–1390), so taps never turn
  into a message tap or a double-tap reaction.
- Today `.ignore` also stops the context gesture: the arm at
  `ChatMessageBubbleItemNode.swift` around :6094 builds an action with
  `contextMenuOnLongPress: false`, and :909 then refuses the gesture. The change
  is to set it to `!tapAction.hasLongTapAction`.
- `hasLongTapAction` defaults to `true`
  (`ChatMessageBubbleContentNode.swift:178`), so every existing `.ignore` caller
  behaves as before. The widget's `false` lets a long press open the menu.

**Touches inside the widget.** The widget's root view handles raw touches and
hit-tests in the core, finding the nearest element with a node id
(renderer-litehtml's `Renderer::touch` logic):
- touch-down → `pointerdown`/`mousedown`/`touchstart`;
- touch-up → `pointerup`/`mouseup`/`touchend`, plus `click` when the finger
  lifted within 8 pt over the same element;
- a cancelled touch → `pointercancel`/`touchcancel` and no click. This covers a
  long press opening the menu, a scroll, and a swipe to reply.

Each event is one task (§2). `preventDefault` needs no special handling,
because this renderer has no default actions to cancel.

**The bridge (`window.TelegramWidget`):**
- **`sendMessage(text)`** sends immediately as the user through
  `controllerInteraction.sendMessage(text, messageId)`, the path of bot
  keyboard text buttons (`TelegramUI/Sources/ChatController.swift:2348`).
  - That path already refuses chats the user can't post in and scheduled-message mode.
  - Inherited side effects: it collapses the input and clears a pending reply.
  - **Tap gate:** allowed only during a task started by a real tap (the
    `pointerup`/`click` task and its microtasks), at most once per tap.
    Otherwise it is dropped, with a diagnostic. The vendored shim's bridge call
    has no return value to make `false`.
  - Text is capped at the message length limit (`UserLimitsConfiguration.maxMessageLength`).
  - The call is delivered after the task ends.
- **`openLink(url)`**, and a tap on `<a href>`, go through
  `controllerInteraction.openUrl` with the usual "Open link?" confirmation,
  under the same tap gate.
- **`onTheme(cb)`** and **`theme`** follow the chat theme; **`ready()`** is accepted.
- `alert`, `confirm` and `prompt` remain no-ops, as in widget-sandbox.

## 6. Failure handling

**At boot (inside layout):**
- **Engine creation fails** (a missing resource, or the runtime can't be
  created): the block draws as a code block and the failure is logged.
- **Refused bytecode:** the engine evaluates the source instead, reports a
  `bytecode` diagnostic, and the widget still runs.
- **An uncaught JS error** doesn't stop the widget. What the scripts built
  before the error is shown, and the error is kept in the instance's diagnostics.
- **A CPU or memory overrun:**
  - the main thread is blocked for up to `cpuLimitMs`, then the runtime is killed;
  - the document was fully parsed before any script ran, so its markup is shown, frozen.

**After boot:**
- If the runtime dies (CPU, memory, or a C++ exception caught at the C API
  boundary), the native tree keeps its last frame and shows a localised "Widget stopped" badge.
- `tapActionAtPoint` stops returning `.ignore` for the dead widget, and the
  widget's root view disables user interaction, so it stops consuming touches
  and the bubble behaves normally again.
- It isn't restarted until its bubble is rebuilt.

**Guards:**
- Re-entrancy violations assert in debug and are dropped in release.
- The validator's size limits (50,000 nodes; 200,000 ops per batch) drop the
  excess with a diagnostic.
- Height is clamped to 24–900 pt.
- When the gate closes mid-session, the next relayout draws code blocks and
  the node destroys its instances.

## 7. Testing

**Host C++ tests** (`cc_test` for `MessageWidgetCore`): macOS, no codesigning,
run like the tgcalls host tests with `./build-input/bazel-9.2.0-darwin-arm64 test …`.
- Heights of 01–05 at two widths, from validated-op fixtures. The fixtures come
  from widget-sandbox's `sandbox-node.ts --ops-file` and are vendored next to the test.
- The fork: widths with `gap` and `letter-spacing`, tabular figures, and the
  computed `opacity`, `transform` and `box-shadow`.
- The walker: every drawing callback is attributed, text is merged per line,
  and keys are stable across a rebuild.
- The container refuses non-`data:` URLs given to it directly (`load_image`,
  `get_image_size`, `import_css`).

**`ios_unit_test` `MessageWidgetTests`**: run with `Make.py test --target`, on a
pinned `ios_test_runner` device. The engine runs on the main thread.
- 01–05 boot synchronously and return a height.
- 02's taps change its text without changing its height.
- 03's tap bumps the layout version.
- 05's interval fires on the main run loop.
- The bytecode is used: no `bytecode` fallback diagnostic.
- The tap gate: `sendMessage` outside a tap is refused; inside a tap it is allowed once.
- 10's Hang ends frozen without a crash.
- Deep recursion throws `RangeError` rather than overflowing the stack.
- **The leak scan:** every file in the vendored `corpus/attacks` runs through
  the full pipeline (engine, validator, core) with a counting container, which
  must record **zero** requests for anything but `data:`. The attacks need the
  shim to execute their JS, which is why the scan lives here and not in the
  host test. This is a port of widget-sandbox's desktop `twidget-run --attacks`
  scan.

**InstantPage V2 layout test:**
- with a stub widget host, a `tgwidget` block lays out as `.widget` at the stub's height;
- with a nil host, it lays out as `.codeBlock`.

**Manual check on a device or simulator**, by the user (I build, the user
installs). Post all ten examples as rich messages, using the recipe in the
examples README:
- 01–05 render at the right height and respond.
- 06–09 show what's still missing.
- 10: every network row says blocked, Open link asks first, and Hang stops the
  widget while the app keeps running.

## Open items to verify early

1. The main thread's stack size on a device, whether `-stack_size` is honoured
   on iOS, and the fallback in §2 if it isn't.
2. That `ChatMessageBubbleItemNode`'s tap recognizer and context gesture behave
   as described in §5 once the `.ignore` arm honours `hasLongTapAction`
   (long press opens the menu; a tap reaches the widget).
3. The Swift glue against the iOS 15 floor.
4. That a `# Heading` line above the fence really makes the iOS composer send a
   rich message whose code block keeps the language `tgwidget` (the examples
   README recipe).
5. That the `ios_unit_test` process pumps the main run loop while a test waits
   on an expectation. Otherwise the attacks that need timers or frames to fire
   (`timer-flood`, `cpu-raf-burn`, `fallback-after-kill`, …) only exercise their
   boot in the leak scan, and §7 must pump the run loop explicitly.
