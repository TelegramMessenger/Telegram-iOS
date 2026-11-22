// widget-sandbox's CPU quota and main-thread window (twidget::CpuBudget; docs/decisions.md "CPU time, not wall-clock
// time"; sandbox_engine.cpp `dispatch`) in the event loop (the CPU-clock limits plan, Task 3): every step has a kind,
// and a deferrable one past either window waits apart from the FIFO until the retry time, in order, frames collapsed,
// while an event still runs with the 50 ms floor; one throttle diagnostic a second; cpuKillAfterMs; a width change lays
// out at the call. The fake clock only moves when a test's natives move it (burn, render), so each step's time is exact.
#include <string>

#include "Sources/Events/Taps.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/CpuLimits.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr::StepResult;
using wr_test::HostEnv;
using wr_test::RenderEnv;
using wr_test::ScopedCpuLimits;
using wr_test::ScopedFakeClock;

namespace {

void installNatives(HostEnv& env) {
    wr_test::installClockNatives(env);
}

/// `#t` covers (0, 0)–(100, 50), so a press at (50, 25) hits it.
std::string page(const std::string& script) {
    return "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:0;top:0;width:100px;"
           "height:50px}</style></head><body><div id=t></div><script>window.log = [];" +
           script + "</script></body></html>";
}

std::string logOf(RenderEnv& env) {
    return env.env().eval("log.join()");
}

size_t throttleReports(HostEnv& env) {
    size_t n = 0;
    for (const auto& [kind, detail] : env.host().diagnostics) {
        n += kind == "cpu-throttled";
    }
    return n;
}

} // namespace

WR_TEST(testTheQuotaDefersTimersNotEvents) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => { burn(300); log.push('a') }, 0); setTimeout(() => log.push('b'), 0);"
                       "addEventListener('pointerdown', () => { log.push('down'); for (;;) {} });"),
                  {}, true, installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    // The first timer spent the window's 300 ms; the second waits for the oldest busy bucket to leave the window.
    CHECK_EQ(logOf(env), std::string("a"));
    CHECK(!loop.hasRunnableTask(0));
    CHECK(loop.nextTimerDeadline() == std::optional<double>(1000));
    CHECK_EQ(loop.throttledSteps(), uint64_t(1));
    // A press runs at once, ahead of the deferred timer, with the 50 ms floor.
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true);
    clock->stepMs = 1.0;
    CHECK(env.env().step() == StepResult::Stopped);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CPU limit exceeded: more than 50 ms of continuous execution (event; CPU "
                                                           "quota: 0 ms of 300 ms per 1000 ms left, so this event task got 50 ms)"));
}

WR_TEST(testDeferredTasksKeepOrderAndRunAtRetry) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => burn(300), 0); for (const n of [1, 2, 3]) setTimeout(() => log.push(n), 0);"), {}, true,
                  installNatives);
    CHECK_EQ(logOf(env), std::string(""));
    CHECK(wr::EventLoop::of(env.ctx()).nextTimerDeadline() == std::optional<double>(1000));
    env.env().advance(999);
    CHECK_EQ(logOf(env), std::string(""));
    env.env().advance(1);
    CHECK_EQ(logOf(env), std::string("1,2,3"));
    CHECK(!wr::EventLoop::of(env.ctx()).nextTimerDeadline());
}

WR_TEST(testFramesCollapse) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => { burn(300); requestAnimationFrame(() => log.push('f')) }, 0);"), {}, true, installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    CHECK(loop.wantsAnimationFrame());
    CHECK(loop.runAnimationFrame(16) == StepResult::Deferred);
    // The deferred frame waits for the retry: the host asks for none meanwhile, and wakes at the retry.
    CHECK(!loop.wantsAnimationFrame());
    CHECK(loop.runAnimationFrame(33) == StepResult::Deferred);
    CHECK(loop.nextTimerDeadline() == std::optional<double>(1000));
    CHECK_EQ(logOf(env), std::string(""));
    env.env().advance(1000);
    CHECK(loop.wantsAnimationFrame());
    CHECK(loop.runAnimationFrame(1000) == StepResult::Ran);
    CHECK_EQ(logOf(env), std::string("f"));
    CHECK(!loop.wantsAnimationFrame());
}

WR_TEST(testATapsFollowUpsRunWithIt) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("var a = new Image(); a.onerror = () => log.push('event');"
                       "var b = new Image(); b.onerror = () => log.push('timer');"
                       "setTimeout(() => { burn(300); b.src = 'data:image/png;base64,AAAA' }, 0);"
                       "addEventListener('pointerdown', () => { a.src = 'data:image/png;base64,AAAA' });"),
                  {}, true, installNatives);
    // The timer's image error is a timer's follow-up: deferred with it.
    CHECK_EQ(logOf(env), std::string(""));
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true);
    env.env().drain();
    CHECK_EQ(logOf(env), std::string("event"));
    env.env().advance(1000);
    CHECK_EQ(logOf(env), std::string("event,timer"));
}

/// The main-thread window holds what upstream's does (sandbox_engine.cpp: taskQueryMs_ + taskOpsCostMs_): the layout
/// queries' time and the modelled cost of the operations; our renderer's other flushes are measured but charged to no
/// window (the corpus check: an honest widget's taps and CSS animations filled it).
WR_TEST(testTheHostWindowDefers) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    {
        // 120 ms of layout queries over two steps, each under the per-task 100 ms.
        RenderEnv env(page("setTimeout(() => query(60), 0); setTimeout(() => query(60), 0); setTimeout(() => log.push('next'), 0);"), {},
                      true, installNatives);
        CHECK_EQ(logOf(env), std::string(""));
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK(wr::EventLoop::of(env.ctx()).nextTimerDeadline() == std::optional<double>(1000));
        env.env().advance(1000);
        CHECK_EQ(logOf(env), std::string("next"));
    }
    {
        // 500 ms of our renderer's other work (a flush, a CSS animation's frames) defers nothing.
        RenderEnv env(page("setTimeout(() => render(500), 0); setTimeout(() => log.push('next'), 0);"), {}, true, installNatives);
        CHECK_EQ(logOf(env), std::string("next"));
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    }
    {
        // 4,001 operations: 100.025 ms by opsCostMs.
        RenderEnv env(page(""), {}, true, installNatives);
        const uint64_t ops = env.env().runtime().totalOps();
        env.env().eval("const t = document.getElementById('t');"
                       "setTimeout(() => { for (let i = 0; i < 4001; i++) t.setAttribute('data-a' + i, '1') }, 0);"
                       "setTimeout(() => log.push('next'), 0); 1");
        env.env().drain();
        CHECK_EQ(env.env().runtime().totalOps() - ops, uint64_t(4001));
        CHECK_EQ(logOf(env), std::string(""));
        CHECK(wr::EventLoop::of(env.ctx()).nextTimerDeadline() == std::optional<double>(1000));
        env.env().advance(1000);
        CHECK_EQ(logOf(env), std::string("next"));
    }
}

WR_TEST(testThrottlingReportsOnceASecond) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    // Every tick spends the window: the next is deferred each second (at 200, 1200 and 2200).
    RenderEnv env(page("setInterval(() => burn(300), 100);"), {}, true, installNatives);
    env.env().advance(2500);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(throttleReports(env.env()), size_t(3));
    CHECK_EQ(wr::EventLoop::of(env.ctx()).throttledSteps(), uint64_t(3));
    CHECK(env.env().host().diagnostics.size() >= 1);
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        if (kind == "cpu-throttled") {
            CHECK_EQ(detail, std::string("deferred 1 timer: 300 ms of the 300 ms per 1000 ms budget used"));
        }
    }
}

WR_TEST(testKillAfterThrottling) {
    wr::CpuLimits cpu;
    cpu.cpuKillAfterMs = 2000;
    ScopedCpuLimits limits(cpu);
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setInterval(() => burn(300), 100);"), {}, true, installNatives);
    env.env().advance(2500);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CPU quota: throttled for 2.0 s (300 ms per 1000 ms, cpuKillAfterMs=2000)"));
    // At the third deferral (2200): throttled since the first (200), each one window after the last.
    CHECK_EQ(env.env().host().now, 2200.0);
}

WR_TEST(testWidthLaysOutAtOnce) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("new ResizeObserver(() => log.push('ro ' + document.body.clientWidth)).observe(document.body);"
                       "setTimeout(() => burn(300), 0);"),
                  {}, true, installNatives);
    CHECK_EQ(logOf(env), std::string("ro 300"));
    env.env().eval("log.length = 0; 1");
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 200);
    CHECK(env.render().layoutWidth() == 200);
    // Only the step that tells the widget (its ResizeObserver delivery) waits for the window.
    CHECK(env.env().step() == StepResult::Deferred);
    CHECK_EQ(logOf(env), std::string(""));
    env.env().advance(1000);
    CHECK_EQ(logOf(env), std::string("ro 200"));
}

/// Upstream records a task's CPU at its end (sandbox_engine.cpp `task`: `budget_.record(kind, cpuMs, nowMs())`): a
/// timer that ran 300 ms from 0 to 300 fills the bucket at 300, which a timer due at 1100 still finds in the window.
WR_TEST(testTheQuotaRecordsATaskAtItsEnd) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => { burn(300); elapse(300) }, 0); setTimeout(() => log.push('b'), 1100);"), {}, true,
                  installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    CHECK_EQ(env.env().host().now, 300.0);
    env.env().advance(800);
    CHECK_EQ(logOf(env), std::string(""));
    CHECK(loop.nextTimerDeadline() == std::optional<double>(1300));
    env.env().advance(200);
    CHECK_EQ(logOf(env), std::string("b"));
}

/// Upstream decides at dispatch on its clock (`dispatch`: `budget_.decide(kind, nowMs())`), not at the drain's start:
/// a step of a drain begun at 950 that the host reaches at 1150 finds the bucket at 0 gone, and its slice is the 290 ms
/// the window leaves, not the 50 ms floor it would get at 950. The step before it ends past 1100, so its record lands in
/// the next bucket and leaves the one at 0 in place for a decision at 950 to see.
WR_TEST(testALaterStepOfADrainIsAdmittedAtTheHostsTime) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => burn(250), 0); setTimeout(() => { burn(10); elapse(200) }, 950);"
                       "setTimeout(() => { for (;;) {} }, 950);"),
                  {}, true, installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    env.env().host().now = 950;
    CHECK(loop.runNextTask(950) == StepResult::Ran);
    CHECK_EQ(env.env().host().now, 1150.0);
    clock->stepMs = 1.0;
    CHECK(loop.runNextTask(950) == StepResult::Stopped);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CPU limit exceeded: more than 290 ms of continuous execution (timer; CPU "
                                                           "quota: 290 ms of 300 ms per 1000 ms left, so this timer task got 290 ms)"));
}

/// Upstream's message recomputes the quota left at the kill (`handleError`: `cpuQuotaMs - budget_.used(nowMs())`): a
/// timer given 50 ms at 990 that the host reaches past 1000 says the window has its 300 ms again.
WR_TEST(testTheCpuStopSaysTheQuotaLeftAtTheKill) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => burn(250), 0); setTimeout(() => { elapse(20); for (;;) {} }, 990);"), {}, true,
                  installNatives);
    clock->stepMs = 1.0;
    env.env().advance(990);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("CPU limit exceeded: more than 50 ms of continuous execution (timer; CPU "
                                                           "quota: 300 ms of 300 ms per 1000 ms left, so this timer task got 50 ms)"));
}

// MARK: A width or theme change's flush is a step of its own kind (the fix waves' M-2)

namespace {

/// A width of 400 or more starts a CSS animation on #e; settling its ready promise reads Animation.prototype.then, a
/// getter that runs `work` once, inside the width change's flush (EventLoop::flushForHostChange).
std::string widthChangePage(const std::string& work, const std::string& script = "") {
    return "<!doctype html><html><head><style>@keyframes k{to{opacity:.5}} @media (min-width: 400px) { #e { animation: "
           "k 1s } }</style></head><body><div id=e></div><div id=box style=\"display:none\"></div><script>window.log = [];"
           "window.box = document.getElementById('box');"
           "Object.defineProperty(Animation.prototype, 'then', {configurable: true, get() { delete Animation.prototype.then; " +
           work + " }});" + script + "</script></body></html>";
}

} // namespace

/// The flush's script time reaches the JS quota at the host's time, not at the last step's: 300 ms at 2000, long after
/// the boot's turn at 0, still defers a timer at 2100.
WR_TEST(testAHostChangeRecordsItsScriptAtItsTime) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(widthChangePage("burn(300);", "setTimeout(() => log.push('b'), 2100);"), {}, true, installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    env.env().host().now = 2000;
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 500);
    env.env().advance(100);
    CHECK_EQ(logOf(env), std::string(""));
    CHECK(loop.nextTimerDeadline() == std::optional<double>(3000));
    env.env().advance(900);
    CHECK_EQ(logOf(env), std::string("b"));
}

/// The flush's operations are a batch of their own (limit.batch), as a task's are: 6,000 right after a step's 6,000 run
/// (the step alone, as the core's drain ends at its last step; the harness's drain asks once more, which starts a batch).
WR_TEST(testAHostChangesOperationsAreABatchOfTheirOwn) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(widthChangePage("for (let i = 0; i < 3000; i++) box.appendChild(document.createElement('i'));",
                                  "setTimeout(() => { for (let i = 0; i < 3000; i++) box.appendChild(document.createElement('i')) }, 10);"),
                  {}, true, installNatives);
    env.env().host().now = 10;
    CHECK(wr::EventLoop::of(env.ctx()).runNextTask(10) == StepResult::Ran);
    // No eval in between: the harness's starts a batch, as a task's start does.
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 500);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(env.env().eval("String(box.childNodes.length)"), std::string("6000"));
}

/// A task the flush's script queues is of the change's kind, as a step's follow-up is: deferred while the quota is spent.
WR_TEST(testAHostChangesFollowUpIsOfItsKind) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(widthChangePage("img.src = 'data:image/png;base64,AAAA';",
                                  "var img = new Image(); img.onerror = () => log.push('error'); setTimeout(() => burn(300), 0);"),
                  {}, true, installNatives);
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 500);
    env.env().drain();
    CHECK_EQ(logOf(env), std::string(""));
    env.env().advance(1000);
    CHECK_EQ(logOf(env), std::string("error"));
}

/// What the flush costs the host reaches the main-thread window, as a step's does (its queries' time and its operations'
/// modelled cost: 5 ms and 4,002 × 0.025 ms), and the loop's totals: a timer waits for the window.
WR_TEST(testAHostChangesCostIsCountedAsAStepsIs) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(widthChangePage("for (let i = 0; i < 2001; i++) box.appendChild(document.createElement('i')); query(5); burn(200);",
                                  "setTimeout(() => log.push('t'), 10);"),
                  {}, true, installNatives);
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 500);
    CHECK(loop.queryMsTotal() >= 5);
    CHECK(loop.largestStepMs() >= 205);
    env.env().advance(10);
    CHECK_EQ(logOf(env), std::string(""));
    CHECK(loop.nextTimerDeadline() == std::optional<double>(1000));
    env.env().advance(990);
    CHECK_EQ(logOf(env), std::string("t"));
}

// MARK: The boot's links, which demotion exempts (EventLoop::bootLinkCpuMsTotal)

/// The parse's async scripts run as the boot's, as its other scripts do: their execution is a link. A script the widget
/// inserts is its own, async or not.
WR_TEST(testTheParsesAsyncScriptsAreBootLinks) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env("<!doctype html><html><head></head><body><script>const s = document.createElement('script'); s.type = 'module';"
                  "s.textContent = 'burn(50); window.inserted = 1'; document.body.append(s);</script>"
                  "<script type=module async>burn(100); window.parsed = 1</script></body></html>",
                  {}, true, installNatives);
    CHECK_EQ(env.env().eval("[window.inserted, window.parsed].join()"), std::string("1,1"));
    CHECK_EQ(wr::EventLoop::of(env.ctx()).bootLinkCpuMsTotal(), 100.0);
}

/// A link marks its own step only: the timer its script sets, which runs before the next link, is the widget's.
WR_TEST(testALinksMarkStaysOnItsStep) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env("<!doctype html><html><head></head><body><script>burn(50); setTimeout(() => { burn(100); window.timer = 1 }, 0)"
                  "</script></body></html>",
                  {}, true, installNatives);
    CHECK_EQ(env.env().eval("String(window.timer)"), std::string("1"));
    CHECK_EQ(wr::EventLoop::of(env.ctx()).cpuMsTotal(), 150.0);
    CHECK_EQ(wr::EventLoop::of(env.ctx()).bootLinkCpuMsTotal(), 50.0);
}
