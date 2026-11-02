# Widget harness — operating manual

A standalone, loginless iOS app that hosts message widgets in the **real** chat bubbles, so an agent can develop and
test the widget client (sizing, the fallback pill, taps, the long press, links, the conformance set) without the
logged-in app, and turn every defect into a regression test. The user asked for it on 2026-10-19 ("a separate UI
test target with a harness for easier development"); the widgets v0.1.0 design runs its conformance runner here later.

Modelled on [`Tests/ComposerHarness`](../ComposerHarness/CLAUDE.md), whose app context it shares. Everything that
manual says about the app context, the Bazel test simulators, stale installs, `--test_filter` taking a class, never
building `:all`, traps that print no failure and reading a build's own exit code applies here unchanged.

## What is real and what is synthetic

**Real, worth filing bugs against:** `ChatMessageItemImpl` → `ChatMessageBubbleItemNode` →
`ChatMessageWidgetBubbleContentNode` (and the caption's `ChatMessageTextBubbleContentNode`) → `MessageWidgetRegistry` /
`MessageWidgetInstance` → `WidgetRuntime`. Every line from the chat item down is the shipping code.

**Real too:** the list. `WidgetHarnessListHost` hosts the chat's own history backend
(`makeCoreListChatHistoryBackend`, CoreList), so its scroll pan, its gesture arbitration and its main-thread layout
are the chat's. Never put a widget under `ListViewImpl` here: the chat no longer uses it, and gestures that passed
there failed on CoreList (2026-10-22: a horizontal swipe on a widget opened the menu instead of replying).

**Real too:** the chat's lock while a widget control is held: the root carries the same `MessageWidgetChatLockRecognizer`
`ChatControllerNode` installs on the chat's view.

**Synthetic:** the app context (`Tests/ComposerHarness/AppContext`), the rotated wrapper around the list (the chat's
`ChatHistoryListNodeImpl`), the root's back swipe (an `InteractiveTransitionGestureRecognizer` to the right that
every pan below waits for, as `NavigationContainer` declares; it records `back`), the
`ChatControllerInteraction` closures (they record what the bubble asks for; `tapMessage` is nil, as `ChatController`
passes it: a non-nil one makes the bubble take every tap as a single tap, so no double tap reaches it), the context menu (a long press records
`contextMenu`, tells the bubble's content nodes the menu extracted them through both hooks, as the chat's context
source does, switches off the bubble's own recognizers above its content (in the chat the menu moves the content out
from under them), and ends 2 s later, or when `harness.endMenu` is tapped under `-harness-menu hold`), the text
selection's menu (`WidgetHarnessContextMenuController`, installed as the context menu controller provider: it never
shows itself, the root shows its actions as buttons, and the list host keeps it until it is dismissed, since
`TextSelectionNode` holds its menu weakly and only presenting keeps one alive in the chat), and the messages
(in-memory `Message`s in a 1:1 chat with "Harness Chat", outgoing unless `-harness-side incoming`). Findings about the chat's layout AROUND the bubble
are provisional until reproduced in the app.

## Build, test, run

From the worktree root:

```bash
BZL=./build-input/bazel-9.2.0-darwin-arm64
CACHE=--disk_cache=$HOME/telegram-bazel-cache
$BZL build $CACHE --ios_multi_cpus=sim_arm64 //Tests/WidgetHarness:WidgetHarness
$BZL test $CACHE //Tests/WidgetHarness:WidgetHarnessTests      # Tier 1, in the app process (iPhone 17 / 26.5)
$BZL test $CACHE //Tests/WidgetHarness:WidgetHarnessUITests    # Tier 2, XCUITest (iPhone 18 Pro / 27.0)
```

Both runners uninstall `org.telegram.WidgetHarness`, and the UI tests' runner app, from the booted Bazel test simulators
first (`Tools/uninstall_widget_harness_from_test_sims.sh`): installd keeps either across builds, and a run then executes
an earlier build's code. Drive it by hand on **K1**, never K3 (the user's logged-in
Telegram):

```bash
K1=$(xcrun simctl list devices available | grep " K1 " | grep -oE '[0-9A-F-]{36}')
STAGE=$(mktemp -d); unzip -q -o bazel-bin/Tests/WidgetHarness/WidgetHarness.ipa -d "$STAGE"
xcrun simctl uninstall "$K1" org.telegram.WidgetHarness 2>/dev/null
xcrun simctl install "$K1" "$STAGE/Payload/WidgetHarness.app"; rm -rf "$STAGE"
xcrun simctl launch "$K1" org.telegram.WidgetHarness -widget-post 17-size-hint
```

## The arrange channel

One leading dash (`--widget-set` is ignored silently).

| Argument | Values | Default |
|---|---|---|
| `-widget-set` | `conformance` (widget-sandbox v0.5.0's `channel.json`, with the reference pictures), `corpus`, `fixture` (`Fixtures/*.html`; `Fixtures/resize/` only by `-widget-posts`) | `conformance` |
| `-widget-post` | a part of a widget path; only matching posts | all |
| `-widget-posts` | whole widget paths, comma-separated: only these posts, in this order (oldest first), e.g. `fixture/tall-box.html,fixture/resize/grow-top.html` | all |
| `-widget-kill-switch` | `on` (the app config's `ios_killswitch_disable_message_widgets` engaged: every widget a pill) | `off` |
| `-widget-anchors` | `<W>x<H>`, overriding every post's anchors | the post's |
| `-widget-caption` | `off` (the widget alone in its bubble: its corners, the tail, the date over it) | on |
| `-harness-theme` | `dark` | light |
| `-harness-side` | `incoming` (the posts come from the other side of the chat) | outgoing |
| `-harness-menu` | `hold` (the stand-in context menu stays open until `harness.endMenu`; `harness.openMenu` opens it on the newest widget bubble without a long press) | ends after 2 s |
| `-harness-copy-protected` | `on` (the chat forbids copying: `isCopyProtectionEnabled`) | off |
| `-harness-can-query` | `on` (every widget message has the server's `can_query`; no bubble shows a network marker since 2026-10-29) | off |
| `-harness-background-query` | `on` (every widget message also has `background_query`: requests without a tap, as in the private chat with the bot) | off |
| `-harness-chat` | `bot` (the chat is with a bot, "Harness Bot": with `-harness-side incoming`, a bot's media, which otherwise gets the share button) | a user |
| `-harness-text-size` | Settings ▸ Appearance ▸ Text Size as `PresentationFontSize`'s raw value (0 extra small … 4 extra large, 5 extra large ×2, 6 medium) | the context's |

A hosted (Tier 1) test calls `WidgetHarnessRootViewController.reload(options:)` instead.

## The readout — a test contract

`harness.readout`'s `accessibilityValue` (and `WidgetHarnessRootViewController.readoutLines()` in process) is one line
per laid-out widget bubble, top of the screen first, then a `log` line per fixture widget that keeps one, then the event
log:

```
bubble 0 visual/sdk/17-size-hint.html 370x240 @201,180 widget +caption
bubble 1 visual/sdk/17-size-hint.html 370x300 @201,470 widget +caption
openLink https://example.org/harness
contextMenu fixture/open-link.html
contextMenuEnded fixture/open-link.html
```

- The size is the widget area's (the clip view, or the pill); the `@x,y` is its centre in the window's coordinates,
  which a Tier 2 test taps (the root view sits about 10 pt off them inside the system's presentation views; aim for
  text needs the window's). A widget reports its height after its boot: wait for the readout to leave the 160 pt
  placeholder (`x160 `) before aiming inside a widget.
- The state is `widget` (a live `MessageWidgetView` is attached), `pill` (the unsupported pill) or `placeholder`.
- `+caption`: the bubble holds another content node (the caption's text); ` +share`: the chat's share button sits
  beside the bubble (never, for a widget); ` pressed`: its context gesture's press (the shrink while it waits for a long press) is on.
- `log <path> <value>`: a fixture widget's (`fixture/…`) `<html data-log>`, when it has one, read through
  `MessageWidgetView.documentElementAttribute` (each read waits for the widget's queue, so only the harness's own
  fixtures are read). `Fixtures/multitouch.html` logs each pointer event at its buttons (a finger's first move only) as
  `<down|move|up|cancel>:<left|right>:<finger>:<P|S>`, the finger a letter by its pointer's first appearance, `P` the
  primary pointer; `double-tap.html`, `touch-drag.html` and `hold-none.html` log `<event type>:<element id>` for the
  gesture events their tests read (`click`, `dblclick`, `pointercancel`, `contextmenu`).
- `conformance <path> <json>`: an automatic conformance test's (`auto/…`) `<html data-conformance>`, its harness's own
  result (status, checks, published targets), for a Tier 2 run of the test through the real bubble
  (`testAuto23aThroughTheRealBubble`, `testAuto23bThroughTheRealBubble`).
- Events: `openLink <url>` (the bubble asked to open a link; the chat would show "Open link?" — ` (not concealed)` is
  appended if it would not have), `appStore` (the pill's button), `contextMenu <path>` / `contextMenuEnded <path>`,
  `reply <path>` (a completed swipe-to-reply), `reaction <path>` (the quick reaction: a double tap the bubble took),
  `back` (the root's back swipe began), `listDrag` (the list's pan began: the chat scrolls, though one post only
  rubber-bands back), `scrollEnded <seconds>` (the list came to rest that long after the drag's lift: its momentum,
  0 without), `selectionMenu <titles>` (a text selection showed its menu, its actions' titles
  joined by `,`; each is a button `harness.menu.<title>` under the readout), `selectionMenuDismissed` (that menu went
  away), `copy <text>` (its Copy, a newline written `\n`), `toast <text>` (the chat's undo toast: a widget's
  `copyText`, or the copy-protection notice that replaces it), `tooltip <text>` (a message tooltip: the network
  marker's tap; ` (not shown)` is appended when the chat would show none, as it does without a source node, and
  `WidgetHarnessListHost.lastTooltipRect` is where a shown one points) and `pressed <path> <seconds>` (a bubble's press ended after
  that long, as the readout's ticks saw it: a query does not return while synthesized fingers play).
- Changing the format means changing every test that parses it.

## The conformance set (widget-sandbox v0.5.0, `conformance/CLIENTS.md`)

The widget-sandbox author's rule: take the widgets from the tag (vendored in `third-party/widget-sandbox`), together
with `manifest.json`, never from the chat; run and report as CLIENTS.md says. `ConformanceSetTests.testTheAutomaticSet`
runs the automatic set: every `auto/` test of `manifest.json` in every theme it lists (62 runs), through
`MessageWidgetInstance` with the app's pool and wait policy at width 390, on the app's own theme for an incoming bubble
of the default chat theme (`ConformanceRunner.theme`, `messageWidgetTheme`: CLIENTS.md step 1, "as in production"),
then the visual set loaded only (51 more runs, ended once the widget has loaded, recorded as `load · loads`; CLIENTS.md:
"the report then shows whether each widget loads"), one at a time (`ConformanceRunner.runAll`:
widgets run together share the pool's two threads, and 10-css-animations' iteration check failed whenever the
filter-heavy 09 pages ran beside it), each view in the window so it gets its frames, a stand-in chat input focused
before loading. A run reads the widget's `<html data-conformance>` from the live DOM (`MessageWidgetInstance.documentElementAttribute`), waits at most 20 s for
`done` (or `awaiting` when it has actions, which it then performs 350 ms apart through the widget's instance: taps,
double taps, presses and drags), records what the host saw and crops the manifest's stages at 2×
(`documentImage`). It writes into the test's undeclared outputs (`conformance/`): the run file
(`ios-telegram-native.json`, `run.schema.json`), `crops/` and `baseline.new.json`.

**The baseline is a ratchet.** `Conformance/baseline.json` (bundled into the app) holds every check's status per run,
the manifest's expected checks included (`missing` when the widget never published them). The test fails on a
regression (a check that passed and no longer does) and on an improvement not yet recorded. After a change that
passes more checks:

```bash
$BZL test $CACHE //Tests/WidgetHarness:WidgetHarnessTests --test_filter=ConformanceSetTests   # fails: improvements
Tests/WidgetHarness/Tools/conformance_report.sh --record    # report.mjs → Conformance/report/, and the new baseline
$BZL test $CACHE //Tests/WidgetHarness:WidgetHarnessTests --test_filter=ConformanceSetTests   # passes
```

A recorded check that the manifest no longer has (an upstream tag renamed or removed it: `statuses` lists every check
the manifest expects, so it is absent from the new run altogether) is **retired**: the test fails until it is recorded
away the same way, and never as a regression (`ConformanceBaseline.compare`). A run that is gone is still a regression.

`conformance_report.sh` (without `--record`) only judges the last run with the vendored `tools/report.mjs` into
`Conformance/report/` (`summary.md`, the per-renderer JSON; the pixel diffs are dropped). Never record over a
regression: fix it. Actions the runner cannot perform for real go into `skippedActions` and their checks (the action's
`ids`) are `skip` in the baseline, never passed; a tap, press or drag whose target the widget never published is an
error of the run instead, and its checks stay as the widget left them. The manifest's host checks are in the baseline
too, as `host · <id> · <name>`, judged from what the host saw exactly as `report.mjs` judges them (a bridge call's
count, the bubble's height, the chat input's focus).

**A test that must stop** (v0.3.0's `auto/31`–`35`: text, attribute, batch, CSS-rule and canvas-pixel caps) names
the reason's prefix in the manifest's `stops`: the runner waits for the widget's death instead of `done`, records it
as the run's `dead`, and the baseline keys it as `<id> · stopped with "<stops>…"`, `pass` when the dead reason starts
with it (`ConformanceManifest.stops`, `ConformanceBaseline`), as `report.mjs` judges it.

**Who gets a press is the bubble's, so Tier 1 cannot pass it all.** The runner injects below the bubble, so the checks
only the bubble can satisfy fail there and stay `fail` in the baseline, as CLIENTS.md says such a runner reports:
- `auto/23-gestures-a`: the hold on `auto` (the menu's `pointercancel`).
- `auto/23-gestures-b`: vertical drags on `none` and `pan-x` (the chat's scroll's), and the drag from the leading 20 px
  (the back swipe's).

`WidgetHarnessUITests.testAuto23aThroughTheRealBubble` and `testAuto23bThroughTheRealBubble` run those tests through the
real bubble and hold every check to `pass`. XCUITest presses at the targets the readout's `conformance` line publishes.
There is no caption, and an older post sits above, so the probes are below the status bar and the chat can scroll.

**The time over the widget** (widget-sandbox v0.4.0): a test whose header gives a `safeArea` (`auto/36-safe-area`,
`visual/17-time-corner`, the reference band of 24 px and a 64 px corner) runs with it as its content safe area, handed to
the instance before its first layout (`ConformanceTest.safeArea`); its checks compare with what the widget was told, so
they hold at the bubble's own numbers too. The channel posts such a widget twice, `withoutCaption` and `captionAbove`
(`MessageWidgetChannelPost.captionPlacement`): the harness's posts and the DEBUG insertion send the first without a
caption and the second with its caption above (`WidgetHarnessPost.captionAbove`, `InvertMediaMessageAttribute`), where
the real bubble draws its date over the widget and passes its own band. `WidgetHarnessListHost.replaceCaption(path:text:captionAbove:)`
edits a post's caption and where it shows as a message edit does (`testACaptionEditChangesTheBandOnce`).

**The message context and the bot** (widget-sandbox v0.2.1, CLIENTS.md "The message context"):
- **The context and state:** a test with `message` runs with its first spec's kind (`MessageWidgetMessageKind`, upstream's
  `WIDGET_MESSAGE_KINDS`) and the spec's `chat_data` / `public_data`, seen by `ConformanceRunner.viewer`. Every other
  test runs as the private chat's original with no state. An unknown kind runs as the private chat's and is a run
  error.
- **The bot:** the runner plays it (`ConformanceMockBot`), answering each request by its exact data from the test's
  `bot` table. Edits (`edit`, `editShared`) reach the widget through `setState` before the answer, `repeat`s are
  timed on the main queue, and `{n}` counts per data.
- **Tier 1's one gap:** `auto/26`'s "TelegramWidget exists" check is published only when the SDK is missing, so it
  stays `missing` here.
- **The bubble's own path** (`WidgetHarnessStateTests`, `Fixtures/widget-state.html`, which logs what it sees):
  the harness's messages carry the account as the chat's `accountPeer` (the widget's viewer), and
  `WidgetHarnessListHost.replaceWidgetState(path:canQuery:chatData:publicData:)` replaces a post's widget media and
  updates its bubble as a message edit does.
- **The network** (W2; `WidgetHarnessNetworkTests`): the harness has no server, so a test replaces the bubble's seam,
  `MessageWidgetNetwork` (`requestAnswer`, `pollPublicData`), and restores it in `tearDown`.
  `Fixtures/widget-request.html` asks `ping` on a tap of `#ask` and logs `ok:<result>` or `err:<code>`.
  `Fixtures/widget-watch.html` watches its shared state from the start (a tap on `#toggle` stops or starts) and logs
  `watching|<state>` or `not|<state>`; `replaceWidgetState(…, widgetId:)` gives a post the widget id a shared widget's
  message has, which polling needs.
- **The wallet** (widget-sandbox v0.5.0; `WidgetHarnessWalletTests`): the harness has no wallet context, so a test
  replaces the wallet's part, `MessageWidgetWallet.perform` (the window and the send: the mock answers with a sent
  transaction, a signature or a failure), and the bot, `MessageWidgetNetwork.requestAnswer` (which takes the query type),
  and passes the wallet in the context as the app does where this device can sign
  (`MessageWidgetWalletAvailability.set(_:accountId:)` with `WidgetHarnessListHost.accountPeerIdValue`, cleared in
  `tearDown`). The coordinator between them is the shipping one. `Fixtures/wallet/pay.html` (a folder fixture, loaded
  by its path) pays on `#pay` (y 20: a request with the wallet, then the answer's transaction on the grant) and signs on
  `#sign` (y 80), logging `wallet` or `no-wallet` at load, then `paid:<result>`, `signed:<result>` or `err:<code>`; its
  posts come from the chat's bot (`botChat`, `incoming`), the message's bot the window would name.
- **Inline previews** (W3; `WidgetHarnessPreviewTests`): a `MessageWidgetPreviewNode` in the root's view, with no list.
  `Fixtures/preview/widget-preview.html` asks a request at load and logs
  `isPreview|chatType|viewer.id|chatData|publicData|request outcome|pointer count`, each value written with `String(…)`
  so a null reads `null`. It is a folder fixture loaded by its path, so it stays out of the all-fixtures set. The no-input
  test drives the widget's own pointer path (`MessageWidgetInstance.pointer`), below the node, so it fails if the
  runtime's preview gate lets input through. `Fixtures/preview/slow-box.html` boots past the layout pass's 20 ms wait
  (3,000,000 loop iterations), for the late-snapshot tests: every other fixture boots inside the wait. The failed-start
  test makes the start fail with `MessageWidgetCore.startFailureForTesting` (`@testable import MessageWidget`) and
  resets it.
- **A reload does not free the previous chat.** After `reload(options:)` the old list host is freed, but its whole node
  tree, bubbles and running widgets, stays alive under a root that left the window (measured 2026-10-26). A test
  never waits for a bubble's deinit after a reload; what a bubble's teardown does is unit-tested in its own module.
  **The app does not leak this way** (measured 2026-10-27 on the "iPhone 18 Pro" sim with `heap <pid>`): a chat with
  four live widgets holds 4 `ChatMessageWidgetBubbleContentNode`, `MessageWidgetInstance`, `MessageWidgetCore` and
  `MessageWidgetView` while open, and none 5 s after it closes, in three open/close cycles. The reload's leftover is the
  harness's own. Count only once the pop has settled: right after the tap the old chat is still alive.

## The stress kit (`-widget-stress measure|production`)

widget-sandbox v0.3.0's `packages/stress` (vendored as `third-party/widget-sandbox/stress`, bundled as
`WidgetStress.bundle`) run by `MessageWidgetStress` instead of the chat: each of the manifest's 127 widgets boots in a
stand-in bubble at the kit's width, warms up, is measured (`CADisplayLink` frames, the widget's `data-stress`, ops,
the largest batch, layout queries, heap, nodes, the renderer's flush and tile-draw time, the widget's JS on its
thread's CPU clock), and the run file (`run.schema.json`) goes to the app's Documents as `stress-<pass>-<date>.json`,
its path to the log. `measure` runs under the compat policy (nothing stops) with the CPU quotas out of the way (10,000
ms per 1000 ms window; the 500 ms slice stays, as the kit's reference keeps it), `production` under strict and the
product's CPU limits (a level past a cap stops, as in the app). The run file's `config.applied` names the CPU limits
each pass ran under (`cpuLimitMs`, `cpuQuotaMs`, `cpuQuotaWindowMs`, `cpuKillAfterMs`, `mainThreadQuotaMs`). On the
simulator a pass takes about 35 minutes; drive it on K1:

```bash
xcrun simctl launch "$K1" org.telegram.WidgetHarness -widget-stress measure
# the file: "$(xcrun simctl get_app_container "$K1" org.telegram.WidgetHarness data)/Documents/stress-measure-*.json"
```

The maintainers want device runs (CLIENTS.md: no debugger, low power mode off, a cool device); DEBUG builds of the app
run the same kit from Debug Settings ▸ "Run widget stress kit (measure)" or "(production)". `WidgetHarnessStressTests`
(Tier 1) runs one short load of each pass.

## Resize anchors (`Fixtures/resize/`, `WidgetHarnessResizeTests`)

The fixtures under `Fixtures/resize/` set their resize anchor first, then change by 120 pt once: on their first click
(`grow-top`, `grow-bottom`, `shrink-top`; `grow-top-far` by 480 pt, so at the chat's bottom its top reaches the screen's
top inset; `grow-bottom-far` by 480 pt, past the room below a pinned post) or 2.5 s after loading (`timer-top`); `toggle-top` changes
every 50 ms from its first pointerdown, 60 times, logging the count (a swipe that starts on it flings past a resizing
widget, `testAFlingPastAResizingWidgetKeepsItsMomentum`). They are loaded only
by `-widget-posts` (`WidgetHarnessLaunchOptions.posts`), so their timers never run in the all-fixtures set the other
tests lay out. Tier 1 lays out a chat of exactly the posts a measurement needs, clicks a fixture through its widget's
own pointer path (`WidgetHarnessListHost.widgetView(path:)`, `MessageWidgetInstance.pointer`) and compares the readout's
frames once the list settles. **Give each chat older filler posts so it is taller than the screen**
(`fixture/tall-box.html`): a chat that fits the screen cannot scroll, so no edge can be kept there but the list's own.
The list host updates a message as the chat does (animated, with the bubble's `resizeAnchor`; `updateMessage(path:)`
asks for one as a bubble would), records the anchor each update carried (`updateAnchors`) and each transaction's size
(`updateTransactions`), and tells whether the list holds a jump (`isHoldingScrollTarget`, after
`scrollTo(messageIndex:hold:)`). `holdsUpdates` keeps the bubbles' requests until `flushUpdates()` sends them as one
transaction, so several widgets change height in one list pass (`heldUpdateCount`: a widget asks on the main-queue turn
after its new height is set); `holdOverscroll(distance:)` holds the newest edge open as an overscroll action does;
`pinToTop(path:)` pins a post to the screen's top as the chat does while a bot streams its reply under the user's message
(the item's `pinToTop`, then the `.top(0.0)` scroll to it, which engages CoreList's pinned-row latch until a drag or a
held jump to another post). A test releases the latch as a drag does by calling the backend's scroll engine's
`onWillBeginDragging` then `onDidEndDragging` (`@testable` CoreList and ChatHistoryListViewBackend, the host's internal
`listView`; `testAResizeDoesNotPinAReleasedPinnedPostAgain`): a began without its ended leaves the backend tracking, and
no resize target is made under a finger.
`load` leaves the chat at its newest end, where a top-anchored widget grows upward: a test of the anchor away from the
bottom puts newer filler below and scrolls (`scrollTo(messageIndex:)`), then checks it left the bottom
(`assertOffTheBottom`).

## Which tier

Tier 1 (`Tests/`) for sizes, states and anything readable in process; Tier 2 (`UITests/`) when the touch path is the
thing under test (the long press against the widget's own recognizer, a tap reaching a widget button). Attach
screenshots (`XCTAttachment`) in Tier 2, so a run leaves frames to look at. Every Tier 2 test launches the app, a few
seconds each: both suites are `size = "large"`, as the UI suite outgrew a medium test's 300 s.

Several fingers at once, with independent timing (hold one, tap another), go through `performFingers`
(`UITests/MultiTouch.swift`): XCUIAutomation's private event synthesis (`XCSynthesizedEventRecord` of
`XCPointerEventPath`s, sent through `XCUIDevice`'s `eventSynthesizer`), which XCUITest's public API has no equivalent of.
Points are the readout's (window) coordinates, times seconds from the record's start; a class or selector a future Xcode
drops throws `MultiTouchError.missing` rather than crashing. `startFingers` starts them and returns, for a test that
waits itself; a readout query only returns once they have played. **In a record of several fingers, a finger that goes
down after offset 0 is pressed a second time at its point after its lift** (the app gets a new touch, began and ended;
a single late finger, or several starting at 0, get none): start fingers together where order does not matter, else
read the log up to the late finger's first lift.
