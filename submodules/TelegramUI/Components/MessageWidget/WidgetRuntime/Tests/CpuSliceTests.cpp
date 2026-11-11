// widget-sandbox's runtime limits on the CPU clock (docs/decisions.md "CPU time, not wall-clock time", the CPU-clock
// limits plan, Task 2): a slice per task, read in QuickJS's interrupt handler; our renderer's time kept out of it; the
// layout queries' 100 ms per task; the wall-clock backstop. Upstream's messages, verbatim (sandbox_engine.cpp
// handleError).
#include <unistd.h>

#include <cstdio>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/Runtime/CpuLimits.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Host/HostState.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/JSHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::HostEnv;
using wr_test::JSEnv;
using wr_test::RenderEnv;
using wr_test::ScopedCpuLimits;
using wr_test::ScopedFakeClock;

namespace {

const char* const kSpin = "for (;;) {}";

std::string page(const std::string& body) {
    return "<!doctype html><html><head></head><body><p>Some text to measure</p><script>window.log = [];</script>" + body +
           "</body></html>";
}

std::string logOf(RenderEnv& env) {
    return env.env().eval("log.join()");
}

} // namespace

WR_TEST(testASliceStopsPastItsTime) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(1.0);
    JSEnv env(wr::idl::kTable);
    env.runtime().beginSlice("timer", 500);
    CHECK_EQ(env.eval(kSpin), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.runtime().stopDetail(), std::string("CPU limit exceeded: more than 500 ms of continuous execution (timer)"));
}

WR_TEST(testAShortSliceSaysWhy) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(1.0);
    JSEnv env(wr::idl::kTable);
    env.runtime().setQuotaLeft([] { return 12.0; });
    env.runtime().beginSlice("frame", 50);
    CHECK_EQ(env.eval(kSpin), std::string("ABORTED"));
    CHECK_EQ(env.runtime().stopDetail(), std::string("CPU limit exceeded: more than 50 ms of continuous execution (frame; CPU quota: 12 ms "
                                                     "of 300 ms per 1000 ms left, so this frame task got 50 ms)"));
}

WR_TEST(testRenderTimeIsNotTheSlices) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    JSEnv env(wr::idl::kTable);
    env.runtime().beginSlice("timer", 500);
    {
        wr::Runtime::RenderScope scope(env.runtime(), false);
        clock->advance(600);
    }
    CHECK_EQ(env.eval("let n = 0; for (let i = 0; i < 100000; i++) n += i; n"), std::string("4999950000"));
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
    const wr::Runtime::SliceUsage usage = env.runtime().endSlice();
    CHECK(usage.renderMs == 600);
    CHECK(usage.queryMs == 0);
}

WR_TEST(testQueriesPast100msStop) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    JSEnv env(wr::idl::kTable);
    env.runtime().beginSlice("timer", 500);
    {
        wr::Runtime::RenderScope scope(env.runtime(), true);
        clock->advance(60);
    }
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
    {
        wr::Runtime::RenderScope scope(env.runtime(), true);
        clock->advance(41);
    }
    clock->stepMs = 1.0;
    CHECK_EQ(env.eval(kSpin), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::LayoutQuery);
    CHECK_EQ(env.runtime().stopDetail(), std::string("Layout query limit exceeded: host queries blocked the renderer for more than 100 ms "
                                                     "in one timer task (timer)"));
}

WR_TEST(testTheWallBackstopStops) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    JSEnv env(wr::idl::kTable);
    env.runtime().beginSlice("timer", 500);
    clock->advanceWall(5001);
    CHECK_EQ(env.eval(kSpin), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.runtime().stopDetail(), std::string("CPU limit exceeded: more than 500 ms of continuous execution (timer)"));
}

WR_TEST(testTheThreadClockSkipsSleep) {
    const wr::CpuClock thread = wr::CpuClock::thread();
    const double before = thread.cpuMs();
    const double wallBefore = thread.wallMs();
    usleep(50000);
    CHECK(thread.cpuMs() - before < 5);
    CHECK(thread.wallMs() - wallBefore >= 45);
}

// Boot (the CPU-clock limits plan, Task 4; upstream's pumpScripts resets the deadline before every inline script, and its
// `loaded` is a task of its own): each script and the load have a full slice of their own, and the parse and our first
// flush are ours.

WR_TEST(testEachScriptHasItsOwnBootSlice) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    {
        RenderEnv env(page("<script>burn(300); log.push(1)</script><script>burn(300); log.push(2)</script>"
                           "<script>burn(300); log.push(3)</script>"),
                      {}, true, wr_test::installClockNatives);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK_EQ(logOf(env), std::string("1,2,3"));
    }
    {
        RenderEnv env(page("<script>burn(501); for (;;) {}</script>"), {}, true, wr_test::installClockNatives);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
        CHECK_EQ(env.env().runtime().stopDetail(), std::string("CPU limit exceeded: more than 500 ms of continuous execution (script)"));
    }
}

WR_TEST(testTheLoadHasItsOwnSlice) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("<script>burn(400); addEventListener('load', () => { burn(400); log.push('load') })</script>"), {}, true,
                  wr_test::installClockNatives);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(logOf(env), std::string("load"));
}

WR_TEST(testTheParseIsNotTheWidgets) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    // The boot's first flush, before any script, takes 900 ms: neither the first script's slice nor either window sees
    // it, so the timer that script sets runs at once (a window spent would defer it).
    bool measured = false;
    RenderEnv env(page("<script>burn(200); setTimeout(() => log.push('timer'), 0)</script>"), {}, true, [&](HostEnv& host) {
        wr_test::installClockNatives(host);
        auto& render = static_cast<wr_test::FakeRenderHost&>(wr::HostState::of(host.ctx()).render()->host());
        render.onTextWidth = [&] {
            if (!measured) {
                measured = true;
                wr_test::testClock().advance(900);
            }
        };
    });
    CHECK(measured);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(logOf(env), std::string("timer"));
}

// MARK: The final review's C1: script our renderer runs is the widget's

namespace {

/// A CSS animation on #e from `rule`, and a `then` getter on Animation.prototype that never ends: the style-change step
/// reads it when it settles the animation's ready promise.
std::string styleStepPage(const std::string& rule) {
    return page("<style>@keyframes k{to{opacity:.5}} " + rule + "</style><div id=e></div><script>"
                "Object.defineProperty(Animation.prototype, 'then', {configurable: true, get() { for (;;) {} }});</script>");
}

bool startsWith(const std::string& text, const std::string& prefix) {
    return text.compare(0, prefix.size(), prefix) == 0;
}

} // namespace

/// A class change in a timer starts a CSS animation, whose ready promise the style-change step of a later flush settles:
/// the `then` getter that never ends stops at the slice of the step that flushes, with upstream's message, as the step's
/// own script would. The step's render time stays out of the slice: only the getter's runs against it.
WR_TEST(testScriptInsideTheStyleStepStopsAtTheSlice) {
    wr_test::ScopedProductSlices slices;
    RenderEnv env(styleStepPage(".a{animation:k 1s}"));
    const double wallBefore = slices.clock->wall;
    env.env().eval("setTimeout(() => { document.getElementById('e').className = 'a'; }, 0); 1");
    env.env().advance(1);
    for (int i = 0; i < 4 && env.env().runtime().stopReason() == wr::StopReason::None; i++) {
        env.env().frame(16);
    }
    // The timer task flushes: its slice, the 300 ms the quota leaves a timer.
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    const std::string detail = env.env().runtime().stopDetail();
    const std::string want = "CPU limit exceeded: more than 300 ms of continuous execution (timer; CPU quota: 300 ms of 300 ms "
                             "per 1000 ms left, so this timer task got 300 ms)";
    if (detail != want) {
        std::printf("  %s\n", detail.c_str());
    }
    CHECK_EQ(detail, want);
    // At the slice, not at the wall backstop (5 s): the step's ScriptScope, not the net under it.
    CHECK(slices.clock->wall - wallBefore < 2000);
}

/// A width change lays out at the call, outside any step: the flush runs in a slice of its own (resize), so the same
/// getter, reached when the new width starts the animation, stops there.
WR_TEST(testScriptInAWidthChangesFlushStopsAtTheSlice) {
    wr_test::ScopedProductSlices slices;
    RenderEnv env(styleStepPage("@media (min-width: 400px) { #e { animation: k 1s } }"));
    const double wallBefore = slices.clock->wall;
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 500);
    for (int i = 0; i < 4 && env.env().runtime().stopReason() == wr::StopReason::None; i++) {
        env.env().frame(16);
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    const std::string detail = env.env().runtime().stopDetail();
    if (!startsWith(detail, "CPU limit exceeded: more than 500 ms of continuous execution (")) {
        std::printf("  %s\n", detail.c_str());
    }
    CHECK(startsWith(detail, "CPU limit exceeded: more than 500 ms of continuous execution ("));
    // At the slice, not at the wall backstop (5 s): the step's ScriptScope, not the net under it.
    CHECK(slices.clock->wall - wallBefore < 2000);
}

/// The same reached from a theme change.
WR_TEST(testScriptInAThemeChangesFlushStopsAtTheSlice) {
    wr_test::ScopedProductSlices slices;
    RenderEnv env(styleStepPage("@media (prefers-color-scheme: dark) { #e { animation: k 1s } }"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    const double wallBefore = slices.clock->wall;
    host.themeChanged(env.ctx(), wr::Theme::Dark);
    for (int i = 0; i < 4 && env.env().runtime().stopReason() == wr::StopReason::None; i++) {
        env.env().frame(16);
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    const std::string detail = env.env().runtime().stopDetail();
    if (!startsWith(detail, "CPU limit exceeded: more than 500 ms of continuous execution (")) {
        std::printf("  %s\n", detail.c_str());
    }
    CHECK(startsWith(detail, "CPU limit exceeded: more than 500 ms of continuous execution ("));
    // At the slice, not at the wall backstop (5 s): the step's ScriptScope, not the net under it.
    CHECK(slices.clock->wall - wallBefore < 2000);
}

/// Script our renderer calls in a ScriptScope is the widget's: its time is JS and runs against the slice, while the
/// render time around it stays out of both; a runaway there stops at the slice.
WR_TEST(testScriptInARenderScopeIsJS) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    HostEnv env;
    wr_test::installClockNatives(env);
    env.runtime().beginSlice("event", 500);
    CHECK_EQ(env.eval("renderAround(1000, () => burn(100), true); 1"), std::string("1"));
    const wr::Runtime::SliceUsage usage = env.runtime().endSlice();
    CHECK_EQ(usage.renderMs, 2000.0);
    CHECK_EQ(usage.jsMs, 100.0);
    env.runtime().beginSlice("event", 500);
    clock->stepMs = 1.0;
    CHECK_EQ(env.eval("renderAround(1000, () => { for (;;) {} }, true); 1"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.runtime().stopDetail(), std::string("CPU limit exceeded: more than 500 ms of continuous execution (event)"));
}

/// Script that reaches a poll inside a render scope with no ScriptScope around it still ends: the wall-clock backstop,
/// max(10 x slice, 5 s), counted from the scope's start.
WR_TEST(testScriptOutsideAScriptScopeMeetsTheBackstop) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(1.0);
    HostEnv env;
    wr_test::installClockNatives(env);
    env.runtime().beginSlice("event", 500);
    CHECK_EQ(env.eval("renderAround(0, () => { for (;;) {} }, false); 1"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.runtime().stopDetail(), std::string("CPU limit exceeded: more than 500 ms of continuous execution (event)"));
    CHECK(clock->wall >= 5000 && clock->wall < 5100);
}

/// The fix wave's review: getAnimations() flushes the styles as a layout query does, so its flush is the query's time.
/// A loop that changes a class and asks for the animations stops at the 100 ms of queries; its flushes' time would
/// otherwise move the slice's deadline on at every call, and nothing would end it.
WR_TEST(testGetAnimationsFlushesAsAQuery) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    clock->renderStepMs = 1.0;
    RenderEnv env(page("<div id=e></div>"));
    env.env().runtime().beginSlice("timer", 500);
    CHECK_EQ(env.env().eval("const e = document.getElementById('e'); for (;;) { e.className = e.className ? '' : 'a'; e.getAnimations(); }"),
             std::string("ABORTED"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::LayoutQuery);
    // At the flush that passes the 100 ms, as a geometry query stops: not at the next interrupt poll, thousands of
    // flushes on.
    if (clock->cpu >= 150) {
        std::printf("  stopped after %g ms of flushes\n", clock->cpu);
    }
    CHECK(clock->cpu < 150);
}
