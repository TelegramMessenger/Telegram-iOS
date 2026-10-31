# Message widgets: CPU-clock limits, as upstream's native clients have them

Status: design, approved in conversation 2026-10-29/30 (the user: "We would like to move closer to the upstream in that
regard"; the playback was answered "Looks good", the builder check's questions "I agree"). Revised 2026-10-30: the
work-unit accounting goes completely, its interrupt points included ("go for exact upstream parity here").

## Intent

Limit a widget's execution the way widget-sandbox's native clients do (upstream `docs/decisions.md`, "Runtime limits",
"CPU time, not wall-clock time", "Layout queries are bounded per task and charged to the quota", "Strict limits from the
start"), instead of with this client's own model, where every limit on a widget's JS is a deterministic budget of
QuickJS work units. A widget should be stopped, throttled or left alone here when it would be on upstream's iOS,
Android and desktop clients, by the same rules and the same numbers, on the same QuickJS behaviour: the work-unit
accounting (the counter, its rates, the charges in QuickJS and in our runtime, the budgets and the cost suites) is
removed, not kept beside the clock.

This reverses the user's earlier rules (`submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`, "A hostile message
must not crash, freeze or exhaust the app…"): "fully deterministic", "per-task limits only", "no rate limits", and
"every limit on its JS is a budget of work". Whether a widget is stopped will now depend on the device and its
conditions, as upstream's does. A hostile message must still not crash the app or freeze its main thread.

## What upstream's native glue does (the behaviour to match)

Read from `~/build/widget-sandbox` at tag `v0.3.0`: `packages/core/src/host/cpu-budget.ts` and its twins
(`packages/desktop/sandbox/{include/twidget/cpu_budget.h,src/cpu_budget.cpp}`, `packages/ios/.../CpuBudget.swift`,
`CpuBudget.kt`), all checked against `packages/core/tests/fixtures/cpu-budget.json`; the glue in
`packages/desktop/sandbox/src/{sandbox_engine.cpp,quickjs_context.cpp}` and
`packages/ios/Sources/WidgetSandbox/SandboxEngine.swift`; defaults in `packages/core/src/shared/protocol.ts`
`LIMIT_DEFAULTS`.

- **The clock** is the widget JS thread's own CPU time (`CLOCK_THREAD_CPUTIME_ID`), not wall-clock time: on a loaded
  machine wall-clock slices killed widgets that had used a fraction of their budget. A wall-clock backstop,
  `max(10 × slice, 5 s)`, catches a thread that is starved or stuck outside JS. Both are read in QuickJS's interrupt
  handler (`quickjs_context.cpp`), which stock quickjs-ng calls every `JS_INTERRUPT_COUNTER_INIT` = 10,000 polls.
- **A slice per task, which kills.** Each task (boot, an event, a timer, a frame, a viewport/resize/theme change, a
  bridge delivery) runs with a slice; past it the widget is killed: "CPU limit exceeded: more than N ms of continuous
  execution (where[; CPU quota: …])". `cpuLimitMs` = 500. Upstream's own bundle evaluation is excluded from boot ("our
  own cost is not the widget's").
- **A JS quota per window, which delays.** A sliding window of `cpuQuotaWindowMs` = 1000 ms in ten buckets; a widget may
  spend `cpuQuotaMs` = 300 ms of JS per window. Past it, deferrable tasks (timer, frame, viewport, resize, theme,
  bridge) wait until the oldest busy bucket leaves the window (never dropped; frames collapse into one; one fire per
  timer id; order kept). Events, visibility and boot always run. Every slice is `min(cpuLimitMs, max(remaining,
  50 ms))`, so a task that starts with the window nearly spent can be killed early, and says why.
  `cpuKillAfterMs` (default 0 = never) kills after sustained throttling.
- **A main-thread window, which delays.** A second budget, `mainThreadQuotaMs` = 100 ms per window: the host's own
  work for the widget, the wall time of its layout queries plus a modelled cost of what it sent (`opsCostMs`: 0.025 ms
  per DOM operation, 0.002 ms per canvas command). A deferrable task waits while either window is spent.
- **Layout queries per task, which kill.** The time a task's layout queries take is summed; past 100 ms
  (`queryBudgetMs`) the task is interrupted and the widget killed: "Layout query limit exceeded: host queries blocked
  the renderer for more than 100 ms in one <kind> task (where)".
- **Diagnostics:** a throttled widget reports it at most once a second, naming which window is spent.
- **Debug builds** there use a wider quota (1000 ms per window), because upstream's debug QuickJS is several times
  slower. Ours is not: QuickJS and `WidgetRuntime` build `-O2` in every configuration (`quickjs_copts`, `WR_COPTS`),
  so this client keeps the product numbers in every build (the user, 2026-10-30).

## Goals

1. The four limits above, with upstream's numbers and messages, measured with the widget thread's CPU clock, are the
   verdict on a widget's execution, replacing the boot budget (48,000,000 units), the step budget (28,000,000 units)
   and the per-step layout-query budget (`work::kLayoutQueryBudget`, 10,000,000 units).
2. The quota policy is upstream's own code: vendor the C++ twin (`cpu_budget.h/.cpp`) and its fixture into
   `third-party/widget-sandbox/` the way `sdk_policy` and `gesture_policy` are vendored (VENDOR.md's recipe gains them),
   and test our copy against `cpu-budget.json`.
3. Throttling: deferred tasks wait in the widget's own event loop and the core wakes the widget at `retryAt`; nothing
   is dropped. A throttled widget animates less often but keeps working.
4. Every build uses the product numbers (no wider DEBUG quota), so the stress kit's production pass and the corpus
   check, which run only in DEBUG builds, judge against the real quota.
5. **The work-unit accounting is removed** (see "Removing the work-unit accounting").
6. Tests stay repeatable through an injectable clock (see "Tests").

## Non-goals

- Wall-clock limits, beyond upstream's backstop.
- The count-based strict limits of v0.3.0 (text, attributes, operations per batch, CSS rules, canvas commands and
  pixels, timers, animations, storage, memory) and the parse's own count limits (`ParseLimits`: depth, nodes,
  attributes, attribute bytes): unchanged.
- Interrupt points of our own inside native code: none, as upstream has none (below).

## Anti-goals (failure even if it works)

- An honest corpus widget killed or throttled on a current iPhone (the corpus check must still pass on device-class
  hardware; see "Tests").
- Main waiting longer on a widget than today, or ever blocking on one past its 20 ms cap.
- A difference from upstream's QuickJS behaviour introduced to keep a unit-era protection.

## Removing the work-unit accounting

Everything that counts or charges work units goes:
- **quickjs-ng** (`third-party/quickjs-ng`, VENDOR.md): change 1 (the interrupt poll every 100 polls) is reverted to
  the stock `JS_INTERRUPT_COUNTER_INIT` = 10,000; change 2 (the work counter, `JS_ChargeWork`/`JS_GetWorkUnits`, and
  the charges inside builtins) and change 11 (the module walks' charges) are removed. Changes that are not accounting
  stay: the uncatchable stop (8, 10), the memory-limit hook (9), host time and randomness (7), and the rest.
- **WidgetRuntime:** `wr::charge`, `chargeScan`, `chargeQueryRead` and every call (about 357), `Support/Work.h`'s
  rates (its non-rate constants, such as `kResizeObserverRounds` and `kMaxMediaQueryBytes`, move to the code that uses
  them), the work limit (`Runtime::setWorkLimit`, `m_workLimit`, `StopReason::Budget`), the work observer, and
  `WRSession`'s unit API (`workUnits`, `setWorkLimitAfter:`, the `parseUnits:`/`bootUnits:` parameters, the `didWork:`
  delegate call).
- **The tests that measure units:** `QuickJSWorkTests`, `QuickJSWorkCostTests`, `:WidgetRuntimeWorkCostTests`, the
  native-path sweep (`QuickJSNativeSweep`), `LimitsTests`' and `WRSessionTests`' per-unit cost tests,
  `DeterminismTests`, and every assertion on a unit count.
- **The host's own uses of units**, each moved (my calls, as the closest to today's intent):
  - the parse ceiling (`parseWorkUnits`): removed; the parse's count limits (`ParseLimits`) bound it, and a source's
    size is the server's to bound, as for upstream;
  - main's wait allowance (1,000,000 units per run-loop turn): removed; the 20 ms cap per turn stays, and main still
    waits only within it;
  - demotion (a background drain past 1,000,000 units): a background drain past 10 ms of the widget thread's CPU
    demotes;
  - the text-selection export's budget (`selectionWorkUnits`): removed; the export is host work main never waits for,
    bounded by the rendered text's caps.

**The accepted cost** (the user, 2026-10-30, choosing exact parity over keeping our native interrupt points): stock
QuickJS checks for interruption only between bytecodes and inside its regex engine, and our runtime's native code
never does. A native path that runs long without returning to bytecode (a builtin over a huge array-like such as
`join` on `{length: 2**40}`, a long string or BigInt operation, a DOM walk, a layout) cannot be stopped: neither the
CPU deadline nor the wall-clock backstop fires until it returns. Such a widget holds one of `MessageWidgetPool`'s two
threads until it finishes, delaying every other widget queued there; the main thread stays protected by its 20 ms cap.
The memory limit bounds most of these, but not all. Upstream's clients carry the same gap.

## Mapping onto this client

- **What a task is.** Upstream's task is one delivery to the widget. Ours is a *step* (`HostState`'s event loop: an
  event, a timer, a frame, a width or theme rebuild, a bridge answer, `setState`), run inside a core task on a
  `MessageWidgetPool` thread; one core task drains up to `maximumStepsPerTask` steps. Each step gets its slice from the
  budget's decision; a deferrable step whose decision is "retry at T" is not run, the drain ends, and the core
  schedules the widget's next wake at T. Which of our steps are deferrable follows upstream's list (timer, frame,
  viewport/width, resize, theme, bridge); events (taps, pointer input), visibility and boot always run.
- **Boot** (my call, following upstream: `pumpScripts` resets the deadline before every inline script, and `loaded` is
  a second boot task): each inline script and the `load` dispatch get a full `cpuLimitMs` of their own; the time
  recorded against the quota is their sum. Other steps that fall due inside our boot loop are ordinary steps with
  their own kinds. The parse and our first flush before any script are our own cost and are excluded, as upstream
  excludes its bundle evaluation.
- **Steps our runtime queues itself** (my call). Upstream runs what a delivery causes (image `load`/`error`, promise
  rejection events, observer deliveries, `toBlob` callbacks, script tasks) inside that delivery, on its slice and its
  recording. Ours are separate `EventLoop` tasks, so each takes the kind of the step that queued it: queued while a
  timer or frame ran, it is deferrable; while an event ran, it runs as the event did. A deferred step leaves the FIFO
  and waits apart, so an event queued behind it still runs at once, as upstream's events overtake its deferred queue.
- **Our renderer's work.** Upstream's renderer runs outside the JS thread and reaches the quota only through the
  main-thread window. Ours runs on the same pool thread (the user, 2026-10-30):
  - every flush (the end-of-step render build and publish, a layout query's flush, the ResizeObserver relayout rounds,
    a width or theme rebuild) is measured on the CPU clock and kept out of the JS slice and the JS quota;
  - a layout query's time (its flush and its read) is the query time: summed per step for the 100 ms kill, and charged
    to the main-thread window, as upstream charges query time;
  - ~~every other flush's measured time is charged to the main-thread window too~~ **Revised in implementation (the
    plan's Task 6 ruling, 2026-10-30, surfaced to the user):** every other flush is measured (it reaches the core's
    demotion and the largest-step statistic) but charged to no window, since charging it throttled about sixty honest
    corpus widgets that upstream, whose renderer is the browser's, never throttles; the anti-goal outranks this
    bullet. Only the queries' time and each step's operations (v0.3.0's count) and canvas commands, through
    `opsCostMs`, reach the main-thread window, as upstream charges them (`EventLoop::endStep` is the one line to
    revert);
  - no ceiling of its own on a single flush (the earlier per-flush unit ceiling goes with the units): the count caps
    (rendered elements, nodes, text, form controls, litehtml's own) bound it.
- **The clock.** `clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)` on the pool thread running the step (a step runs on
  one thread from start to end); the backstop on the monotonic clock. Both are read in our QuickJS interrupt handler
  at every call, as upstream's, and around each flush.
- **Where the stop lands.** At the next interrupt QuickJS makes (bytecode or regex), or at a flush's end for the query
  rule: the stop latches (`StopReason`), nothing is catchable by script, and the last published tree stays (a frozen
  widget is a picture). The dead reason carries upstream's message text.
- **Configuration** (`LIMIT_DEFAULTS`): `cpuLimitMs` 500, `cpuQuotaMs` 300, `cpuQuotaWindowMs` 1000, `cpuKillAfterMs` 0,
  `mainThreadQuotaMs` 100, in every build. The values are part of the session's configuration (`WRSession`), like the
  limit policy, so the stress kit's measure pass can lift them as CLIENTS.md asks (its run file already reports
  `requested` and `applied` values for them) and tests can set their own. Both limit policies (strict and compat) use
  the same CPU limits, as upstream's do.
- **Hidden widgets** keep today's behaviour (no frames, 1 Hz timers); the quota applies on top.

## Tests

- **An injectable clock.** The runtime reads its CPU clock and the backstop's wall clock through the session's
  configuration; production passes the thread clocks, tests a fake. With no units left, the workhorse fake advances
  by a fixed step at every call of the interrupt handler (QuickJS's own bytecode count paces it), plus explicit
  advances a test makes (around a flush, for instance), which keeps the runtime and core tests repeatable. Today's
  budget tests (`LimitsTests`, the core's wait and demotion tests) are restated in milliseconds against it.
- **The quota policy** against upstream's fixture (`cpu-budget.json`), as the SDK and gesture policies are.
- **New behaviour:** a step past its slice stops with upstream's message; a widget past 300 ms in a window has its
  timers and frames deferred and resumed (none dropped, one frame for many, order kept) while a tap still runs; a
  task's layout queries past 100 ms stop it; the main-thread window defers on flush time and modelled op cost; the
  backstop stops a starved task; boot excludes the parse; the production clock is the thread's (time asleep does not
  count).
- **The corpus check** (`MessageWidgetCorpusTests`) measures milliseconds of CPU on the real clock (my call on the
  thresholds): no honest widget's step may pass a quarter of its slice, its steady state a quarter of the JS quota, nor
  may it be throttled by either window, on the test host. Upstream records an honest corpus widget
  (`htmlbubbles-ported/06-trip-lisbon/10-ana-bare`) at 82 ms per second of the 100 ms main-thread window, mostly the
  op model, so a quarter of that window cannot be the bar.
- **The attacks** (`corpus/attacks`): each still crashes nothing and requests nothing; one that now runs a native
  path to its end is recorded, with how long it held its thread on the test host.
- **Conformance:** upstream's conformance set has no timing tests that change; the ratchet must stay green.
- **Device:** a pass of the stress kit on a device (the user's), which now reports throttling where upstream's would.

## Docs

The message widgets guide's "A hostile message must not crash…" bullet and everything else that describes work units,
budgets or the cost suites, the runtime record (its "Limits" table, "Measured", the "Divergences" items on work units
and time limits, "Tests"), quickjs-ng's VENDOR.md (changes 1, 2 and 11 gone), the harness guide (stress mode's applied
config), widget-sandbox's VENDOR.md (the vendored CPU budget), the root CLAUDE.md where it names the cost suites, and
the memory notes.

## Left to the builder

- How a deferred step is kept and replayed in `HostState`'s event loop (upstream: frames collapse, one fire per timer
  id, order kept), and how the core's wake is scheduled at `retryAt`.
- How the flushes are measured and excluded from the JS slice.
- The fake clock's step per interrupt in tests, and which existing tests are restated versus removed.
- The order in which the accounting comes out, so that every commit builds and its tests pass.
