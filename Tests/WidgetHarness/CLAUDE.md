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
| `-widget-set` | `conformance` (widget-sandbox v0.1.1's `channel.json`, with the reference pictures), `corpus`, `fixture` (`Fixtures/*.html`) | `conformance` |
| `-widget-post` | a part of a widget path; only matching posts | all |
| `-widget-kill-switch` | `on` (the app config's `ios_killswitch_disable_message_widgets` engaged: every widget a pill) | `off` |
| `-widget-anchors` | `<W>x<H>`, overriding every post's anchors | the post's |
| `-widget-caption` | `off` (the widget alone in its bubble: its corners, the tail, the date over it) | on |
| `-harness-theme` | `dark` | light |
| `-harness-side` | `incoming` (the posts come from the other side of the chat) | outgoing |
| `-harness-menu` | `hold` (the stand-in context menu stays open until `harness.endMenu`; `harness.openMenu` opens it on the newest widget bubble without a long press) | ends after 2 s |
| `-harness-copy-protected` | `on` (the chat forbids copying: `isCopyProtectionEnabled`) | off |

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
- `+caption`: the bubble holds another content node (the caption's text); ` pressed`: its context gesture's press
  (the shrink while it waits for a long press) is on.
- `log <path> <value>`: a fixture widget's (`fixture/…`) `<html data-log>`, when it has one, read through
  `MessageWidgetView.documentElementAttribute` (each read waits for the widget's queue, so only the harness's own
  fixtures are read). `Fixtures/multitouch.html` logs each pointer event at its buttons as
  `<down|up|cancel>:<left|right>:<finger>:<P|S>`, the finger a letter by its pointer's first appearance, `P` the primary
  pointer.
- Events: `openLink <url>` (the bubble asked to open a link; the chat would show "Open link?" — ` (not concealed)` is
  appended if it would not have), `appStore` (the pill's button), `contextMenu <path>` / `contextMenuEnded <path>`,
  `reply <path>` (a completed swipe-to-reply), `reaction <path>` (the quick reaction: a double tap the bubble took),
  `back` (the root's back swipe began), `selectionMenu <titles>` (a text selection showed its menu, its actions' titles
  joined by `,`; each is a button `harness.menu.<title>` under the readout), `selectionMenuDismissed` (that menu went
  away), `copy <text>` (its Copy, a newline written `\n`) and `pressed <path> <seconds>` (a bubble's press ended after
  that long, as the readout's ticks saw it: a query does not return while synthesized fingers play).
- Changing the format means changing every test that parses it.

## The conformance set (widget-sandbox v0.1.1, `conformance/CLIENTS.md`)

The widget-sandbox author's rule: take the widgets from the tag (vendored in `third-party/widget-sandbox`), together
with `manifest.json`, never from the chat; run and report as CLIENTS.md says. `ConformanceSetTests.testTheAutomaticSet`
runs the automatic set: every `auto/` test of `manifest.json` in every theme it lists (41 runs), through
`MessageWidgetInstance` with the app's pool and wait policy at width 390, on the app's own theme for an incoming bubble
of the default chat theme (`ConformanceRunner.theme`, `messageWidgetTheme`: CLIENTS.md step 1, "as in production"),
then the visual set loaded only (41 more runs, ended once the widget has loaded, recorded as `load · loads`; CLIENTS.md:
"the report then shows whether each widget loads"), one at a time (`ConformanceRunner.runAll`:
widgets run together share the pool's two threads, and 10-css-animations' iteration check failed whenever the
filter-heavy 09 pages ran beside it), each view in the window so it gets its frames, a stand-in chat input focused
before loading. A run reads the widget's `<html data-conformance>` from the live DOM (`MessageWidgetInstance.documentElementAttribute`), waits at most 20 s for
`done` (or `awaiting` when it has actions), records what the host saw and crops the manifest's stages at 2×
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

## Which tier

Tier 1 (`Tests/`) for sizes, states and anything readable in process; Tier 2 (`UITests/`) when the touch path is the
thing under test (the long press against the widget's own recognizer, a tap reaching a widget button). Attach
screenshots (`XCTAttachment`) in Tier 2, so a run leaves frames to look at.

Several fingers at once, with independent timing (hold one, tap another), go through `performFingers`
(`UITests/MultiTouch.swift`): XCUIAutomation's private event synthesis (`XCSynthesizedEventRecord` of
`XCPointerEventPath`s, sent through `XCUIDevice`'s `eventSynthesizer`), which XCUITest's public API has no equivalent of.
Points are the readout's (window) coordinates, times seconds from the record's start; a class or selector a future Xcode
drops throws `MultiTouchError.missing` rather than crashing. `startFingers` starts them and returns, for a test that
waits itself; a readout query only returns once they have played. **In a record of several fingers, a finger that goes
down after offset 0 is pressed a second time at its point after its lift** (the app gets a new touch, began and ended;
a single late finger, or several starting at 0, get none): start fingers together where order does not matter, else
read the log up to the late finger's first lift.
