# MessageWidget provenance

This module is ours: edit it here. It hosts a message widget in a chat bubble on top of the native runtime,
`WidgetRuntime` (`../WidgetRuntime`), which Swift reaches only through `WRSession` (`../WidgetRuntimeIOS`). The record
of the runtime, the app's contract with it included, is `docs/message-widgets-native-runtime.md`.

What it holds:
- `MessageWidgetPool` (two 8 MB threads, a serial queue per widget) and `WidgetHandshake` (main's waits within a turn's
  cap; results applied in task order, its drain never re-entered).
- `MessageWidgetCore`: the widget's `WRSession`, its `WidgetTreeRenderer` (`../MessageWidgetRendering`) and its
  `WidgetTileDrawer`, used only inside the widget's tasks. It holds the CPU limits, the tap's bridge permission and the
  freeze, and ends every task with a `WidgetSnapshot`.
- `MessageWidgetInstance` (main): applies snapshots, answers the bubble's layout, queues the `.draw` task a snapshot
  asks for, and runs timers, frames and visibility; `MessageWidgetTimers`, `MessageWidgetView`, `MessageWidgetRegistry`,
  `MessageWidgetApplicationState`, `MessageWidgetKillSwitch` and `MessageWidgetCorpusListing`.

History: the module started as a port of widget-sandbox `packages/ios/Sources/WidgetSandbox` (commit 862eec8):
a JS sandbox (`QuickJSContext`, `MessageWidgetEngine`, `IntlBridge`, `MessageWidgetResources`) behind a validator
(`TrustedValidator`), drawn by `MessageWidgetRenderer` over twidget's LHDocument. M1d deleted all of it
(`a85f21a602`) when the app switched to `WidgetRuntime`; the commit before it still has them.

Visibility (2026-10-14): a widget is visible (frames, timers at full rate, `document.hidden`) only while its bubble is
(`setVisible`), its view is in a window (the view's `didMoveToWindow`; a view never put in a window does not hide it)
and the app is active (`MessageWidgetApplicationState`, fed by the host app's `applicationIsActive` signal through one
subscription in `ChatMessageRichDataWidgetHost.swift`). A chat covered by a pushed screen leaves the window while its
list visibility stays, and an app in the background stays alive during a call or audio playback.

## Drawing

Only the size is on the critical path. A task's snapshot carries the size and state; applying one whose tree changed
queues an unwaited, keyed `.draw` task, whose `WidgetTileDrawer` draws the changed 128 pt tiles in parallel, each the
renderer's `image(rect:scale:)` at the scale the widget was created with; main merges them and `MessageWidgetView`
shows each as a `CALayer`'s `contents`. A frozen widget keeps its last tree and draws the "stopped" badge over it. The
view's own layer carries a transparent 1x1 `contents`, because iOS 26/27 deliver no real touches to a view whose layer
renders nothing (`docs/ios27-windows-and-touches.md`).

## Tests

`Tests/TestSupport.swift`'s `MessageWidgetTestCase` holds the helpers every suite shares (`make`, `render`, `pixel`,
`booted`, `settle`, `borderBox`). Every test runs its widgets on a pool of its own with `.unbounded` (each wait ends
with its task); the background path's tests pass a capped policy and hold a task with `gateNextTaskForTesting()`.
Helpers settle pending draws before they read pixels. Under Bazel's test runner the test process has no display, so a
case that needs a frame calls `MessageWidgetInstance.deliverFrameForTesting()`; the first `CADisplayLink` of a headless
test simulator takes ~5 s, so timing tests warm one up first.

`AcceptanceTests` holds the fixtures `01`–`05` to WebKit's heights (macOS 27 `WKWebView`, measured 2026-10-13,
rounded up as the renderer rounds) within 4 pt at 360 and 240 pt.

`InstanceTests.testAttackCorpusRequestsNothing` is the network boundary: over the 93 pages of
`third-party/widget-sandbox/corpus/attacks`, each laid out, given three animation frames and drawn, no URL is requested
(`RecordingURLProtocol`), and the pages that name URLs have them refused by the runtime's container (`refusedLoads`).
`cpu-raf-burn` is stopped at its first frame by its work limit.

A tap makes no `click` on a disabled `button`, `input`, `select` or `textarea`, or on anything inside one (W's
`Taps.cpp`; a disabled fieldset's contents wait for M2's forms); the pointer, mouse and touch events still go out.
`InstanceTests.testDisabledSendTakesNoClick` pins it. A script's own `element.click()` is unchanged.
