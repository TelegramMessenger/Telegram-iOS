// Timers (M1b plan, Task 10): HTML's timer initialization steps on the host-driven loop.
#include <cstdint>
#include <cstdio>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/Timers.h"
#include "Tests/HostHarness.h"

namespace wr {

/// The tests' access to Timers' id counter (Timers.h names it a friend): the wrap past INT32_MAX cannot be reached by
/// making 2^31 timers, and a call that failed on a stopped runtime cannot be asked which id it took.
struct TimersTestAccess {
    static void setNextId(Timers& timers, int32_t id) { timers.m_nextId = id; }
    static int32_t nextId(const Timers& timers) { return timers.m_nextId; }
};

} // namespace wr

namespace {

double globalNumber(JSContext* ctx, const char* name) {
    wr::Value global = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    wr::Value v = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, global.get(), name));
    double d = -1;
    JS_ToFloat64(ctx, &d, v.get());
    return d;
}

/// globalThis.squeezeMemory(): from here every allocation fails (QuickJS refuses malloc_size + size > limit - 1).
JSValue squeezeMemory(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, size_t(usage.malloc_size));
    return JS_UNDEFINED;
}

/// globalThis.restoreMemory(): the runtime's default limit again.
JSValue restoreMemory(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    JS_SetMemoryLimit(JS_GetRuntime(ctx), wr::Runtime::Options().memoryLimitBytes);
    return JS_UNDEFINED;
}

} // namespace

WR_TEST(testTimeoutRunsAtItsDeadline) {
    wr_test::HostEnv env;
    env.eval("var times = []; setTimeout(() => times.push(performance.now()), 10);");
    env.advance(9);
    CHECK_JS_EQ(env, "times.length", "0");
    env.advance(1);
    CHECK_JS_EQ(env, "times.join()", "10");
    CHECK(!wr::EventLoop::of(env.ctx()).nextTimerDeadline());
}

WR_TEST(testEqualDeadlinesRunInCreationOrder) {
    wr_test::HostEnv env;
    env.eval("var log = []; setTimeout(() => log.push('b'), 5); setTimeout(() => log.push('a'), 0);"
             "setTimeout(() => log.push('c'), 5); setTimeout(() => log.push('a2'), 0);");
    env.advance(10);
    CHECK_JS_EQ(env, "log.join()", "a,a2,b,c");
    // A 10 ms timer started at 0 and a 5 ms timer started at 5 are due together: the earlier one runs first.
    env.eval("log = []; setTimeout(() => log.push('first'), 10);");
    env.advance(5);
    env.eval("setTimeout(() => log.push('second'), 5);");
    env.advance(5);
    CHECK_JS_EQ(env, "log.join()", "first,second");
}

// Review Focus 2: a chain of zero-delay timers is clamped to 4 ms past nesting level 5 and keeps its order. A chain that
// never ends runs at the clamp and is not stopped: each timer is a task with a slice of its own, as upstream's (the JS
// quota throttles a chain whose callbacks spend CPU).
WR_TEST(testZeroDelayChainsAreOrderedAndClamped) {
    {
        wr_test::HostEnv env;
        env.eval("var times = []; function f() { times.push(performance.now()); if (times.length < 10) setTimeout(f, 0); } setTimeout(f, 0);");
        env.advance(100);
        CHECK_JS_EQ(env, "times.join()", "0,0,0,0,0,0,4,8,12,16");
    }
    {
        wr_test::HostEnv env;
        env.eval("var n = 0; (function f() { n++; setTimeout(f, 0); })();");
        env.advance(1000);
        // Five unclamped runs at 0, then one every 4 ms: 250 in the second.
        CHECK(env.runtime().stopReason() == wr::StopReason::None);
        const double n = globalNumber(env.ctx(), "n");
        if (n < 250 || n > 260) {
            std::printf("  %g runs in a second\n", n);
        }
        CHECK(n >= 250 && n <= 260);
    }
}

// HTML: the nesting level is the running task's, and a microtask is not a timer task.
WR_TEST(testNestingLevelIsNotInheritedByMicrotasks) {
    wr_test::HostEnv env;
    env.eval("var times = []; var depth = 0;"
             "function f() { depth++; if (depth === 7) { queueMicrotask(() => setTimeout(() => times.push(performance.now()), 0)); return; } setTimeout(f, 0); }"
             "setTimeout(f, 0);");
    env.advance(100);
    // The seventh callback runs at 4 (the sixth's call was clamped); the microtask's timer is not clamped again.
    CHECK_JS_EQ(env, "times.join()", "4");
}

WR_TEST(testIntervalRearmsAfterItsCallback) {
    wr_test::HostEnv env;
    env.eval("var times = []; var id = setInterval(() => { times.push(performance.now()); if (times.length === 3) clearInterval(id); }, 10);");
    env.advance(100);
    CHECK_JS_EQ(env, "times.join()", "10,20,30");
    // An interval whose callback throws is reported and goes on.
    env.eval("var n = 0, errors = 0; addEventListener('error', () => errors++); var j = setInterval(() => { n++; throw new Error('x'); }, 10);");
    env.advance(35);
    env.eval("clearInterval(j)");
    CHECK_JS_EQ(env, "n + ',' + errors", "3,3");
}

WR_TEST(testClearingFromACallback) {
    wr_test::HostEnv env;
    // Both are due at 0 and promoted together; the first clears the second before its task runs.
    env.eval("var log = []; var t2; setTimeout(() => { log.push('t1'); clearTimeout(t2); }, 0); t2 = setTimeout(() => log.push('t2'), 0);");
    env.advance(0);
    CHECK_JS_EQ(env, "log.join()", "t1");
    // Ids are shared: clearTimeout clears an interval. Unknown ids and no argument are no-ops.
    env.eval("var ran = false; var iv = setInterval(() => { ran = true; }, 5); clearTimeout(iv); clearTimeout(123456); clearTimeout(); clearInterval('nope');");
    env.advance(20);
    CHECK_JS(env, "!ran");
    CHECK_JS(env, "(() => { const a = setTimeout(() => {}); const b = setInterval(() => {}, 1000); clearInterval(b); return a > 0 && b === a + 1; })()");
}

WR_TEST(testHandlerArgumentsAndThis) {
    wr_test::HostEnv env;
    env.eval("var r = []; setTimeout(function (a, b) { 'use strict'; r.push(this === window, a + b); }, 0, 2, 3);"
             "setTimeout('r.push(this === window); var fromString = 42;', 0);");
    env.advance(0);
    CHECK_JS_EQ(env, "r.join()", "true,5,true");
    CHECK_JS_EQ(env, "fromString", "42");
}

WR_TEST(testTimeoutConversion) {
    wr_test::HostEnv env;
    // long conversion wraps 2^31 to a negative value, which HTML makes 0; NaN is 0; a string is converted.
    env.eval("var r = []; setTimeout(() => r.push('neg'), -5); setTimeout(() => r.push('wrap'), 2 ** 31);"
             "setTimeout(() => r.push('nan'), NaN); setTimeout(() => r.push('str'), '3');");
    env.advance(0);
    CHECK_JS_EQ(env, "r.join()", "neg,wrap,nan");
    env.advance(3);
    CHECK_JS_EQ(env, "r.join()", "neg,wrap,nan,str");
}

// widget-sandbox v0.3.0 (strict): at most 64 live timers (compat: 256).
WR_TEST(testTooManyTimers) {
    wr_test::HostEnv env;
    env.eval("var ids = []; for (let i = 0; i < 64; i++) ids.push(setTimeout(() => {}, 1000));");
    CHECK_THROWS(env, "setTimeout(() => {}, 1000)", "RangeError");
    CHECK_JS_EQ(env, "(() => { try { setInterval(() => {}, 1000); } catch (e) { return e.message; } })()", "too many timers");
    env.eval("clearTimeout(ids[0])");
    CHECK_JS(env, "setTimeout(() => {}, 1000) > 0");
    // A timer that ran gives its slot back.
    env.advance(1000);
    CHECK_JS(env, "setTimeout(() => {}, 1000) > 0");
}

WR_TEST(testCompatKeepsTwoHundredFiftySixTimers) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    wr_test::HostEnv env;
    env.eval("var ids = []; for (let i = 0; i < 256; i++) ids.push(setTimeout(() => {}, 1000));");
    CHECK_THROWS(env, "setTimeout(() => {}, 1000)", "RangeError");
}

// Review Focus 4: a cleared timer, a timer that ran once and an interval cleared from its own callback release what
// their callbacks captured.
WR_TEST(testClearedTimersReleaseTheirCallbacks) {
    wr_test::HostEnv env;
    JSRuntime* rt = env.runtime().jsRuntime();
    JS_RunGC(rt);
    size_t before = env.runtime().liveObjects();
    const char* tree = "const keep = document.createElement('div'); for (let i = 0; i < 100; i++) keep.appendChild(document.createElement('p'));";
    env.eval(std::string("(() => { ") + tree + " const id = setTimeout(() => keep.remove(), 1000); clearTimeout(id); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
    env.eval(std::string("(() => { ") + tree + " setTimeout(() => { keep.id = 'x'; }, 0); })()");
    // While the timer waits, its callback holds the tree: the div and its 100 children.
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() > before + 100);
    env.advance(0);
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
    env.eval(std::string("(() => { ") + tree + " const id = setInterval(() => { keep.id = 'y'; clearInterval(id); }, 5); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() > before + 100);
    env.advance(10);
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
}

// A timer whose task could not be made is not kept. The refused allocation stops the widget (quickjs-ng change 9), and
// from then on no exception can be caught (change 10): the script's catch does not run.
WR_TEST(testATimerThatCouldNotBeScheduledIsNotKept) {
    // 255 live timers at once: past the strict cap (64), which this is not about.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.runtime().setGlobal("squeezeMemory", JS_NewCFunction(ctx, squeezeMemory, "squeezeMemory", 0));
    env.runtime().setGlobal("restoreMemory", JS_NewCFunction(ctx, restoreMemory, "restoreMemory", 0));
    // 255 timers made and cleared leave the table and the loop's heap room to spare, so the one allocation setTimeout
    // makes below is its task's.
    env.eval("var f = () => {}; var ids = []; for (let i = 0; i < 255; i++) ids.push(setTimeout(f, 1000)); for (const id of ids) clearTimeout(id);");
    CHECK_EQ(wr::EventLoop::of(ctx).liveCallbackCount(), size_t(0));
    CHECK_EQ(wr::TimersTestAccess::nextId(wr::EventLoop::of(ctx).timers()), 256);
    CHECK(env.eval("var caught = false; squeezeMemory(); try { setTimeout(f, 0); } catch (e) { caught = true; } restoreMemory();") == "ABORTED");
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
    CHECK_EQ(globalNumber(ctx, "caught"), 0.0);
    // It failed inside start, after the entry was made (the call took id 256, and takeId comes just before the entry):
    // the entry is gone, and its callback released.
    CHECK_EQ(wr::TimersTestAccess::nextId(wr::EventLoop::of(ctx).timers()), 257);
    CHECK_EQ(wr::EventLoop::of(ctx).liveCallbackCount(), size_t(0));
}

// Fix round 1, I1: the id counter wraps from INT32_MAX to 1 and skips the ids still in use (HTML: an id greater than
// zero, not already in the map), so an id is never negative, zero or shared.
WR_TEST(testIdsWrapPastInt32MaxAndSkipThoseInUse) {
    wr_test::HostEnv env;
    env.eval("var log = []; var first = setInterval(() => log.push('first'), 100);");
    CHECK_JS(env, "first === 1");
    wr::TimersTestAccess::setNextId(wr::EventLoop::of(env.ctx()).timers(), INT32_MAX - 1);
    env.eval("var a = setTimeout(() => log.push('a'), 50), b = setTimeout(() => log.push('b'), 50);"
             "var c = setTimeout(() => log.push('c'), 50), d = setTimeout(() => log.push('d'), 50);");
    CHECK_JS_EQ(env, "[a, b, c, d].join()", "2147483646,2147483647,2,3");
    // Clearing a wrapped id clears that timer only; clearing id 1 clears the interval.
    env.eval("clearTimeout(c)");
    env.advance(100);
    CHECK_JS_EQ(env, "log.join()", "a,b,d,first");
    env.eval("clearInterval(first)");
    env.advance(100);
    CHECK_JS_EQ(env, "log.join()", "a,b,d,first");
    CHECK_EQ(wr::EventLoop::of(env.ctx()).liveCallbackCount(), size_t(0));
}

// Fix round 1, M3: a string handler's exception is reported (an ErrorEvent at the window) and the loop goes on.
WR_TEST(testAStringHandlerExceptionIsReported) {
    wr_test::HostEnv env;
    env.eval("var errors = [], after = false; addEventListener('error', e => errors.push(e.message));"
             "setTimeout('throw 1', 0); setTimeout(() => { after = true; }, 0);");
    env.advance(0);
    CHECK_JS_EQ(env, "errors.join()", "Uncaught 1");
    CHECK_JS(env, "after");
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}

// Fix round 1, M3: a string handler that never ends stops the widget at its CPU slice. The stop leaves the task
// (Aborted) with the nesting level restored, and nothing runs after it.
WR_TEST(testAStringHandlerThatNeverEndsStopsTheWidget) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var ran = 0; setTimeout('for (;;);', 0); setTimeout(() => { ran = 1; }, 0);");
    wr_test::stopAfter(env.runtime());
    CHECK(env.step() == wr::StepResult::Stopped);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(wr::EventLoop::of(ctx).timerNestingLevel(), 0);
    CHECK(env.step() == wr::StepResult::Stopped);
    CHECK_EQ(globalNumber(ctx, "ran"), 0.0);
}

// Fix round 1, M3: an interval's re-arm is a timer initialization like any other: from the one where the nesting
// level passes 5, a zero delay is clamped to 4 ms.
WR_TEST(testAZeroDelayIntervalIsClampedPastNestingLevel5) {
    wr_test::HostEnv env;
    env.eval("var times = []; var id = setInterval(() => { times.push(performance.now()); if (times.length === 10) clearInterval(id); }, 0);");
    env.advance(100);
    CHECK_JS_EQ(env, "times.join()", "0,0,0,0,0,0,4,8,12,16");
}

// Fix round 1, M1: an interval that cannot be re-armed is dropped, releasing what its callback holds. Here the re-arm's
// allocation is refused at the memory limit, which stops the widget (quickjs-ng change 9) whatever QuickJS throws then
// (null: it cannot even make its out-of-memory error). Nothing is reported, and no interval is left behind.
WR_TEST(testAnIntervalThatCannotBeRearmedIsDropped) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.runtime().setGlobal("squeezeMemory", JS_NewCFunction(ctx, squeezeMemory, "squeezeMemory", 0));
    env.eval("(() => { const big = new Array(100000).fill(0); setInterval(() => { big.length; squeezeMemory(); }, 10); })()");
    env.advance(10);
    JS_SetMemoryLimit(env.runtime().jsRuntime(), wr::Runtime::Options().memoryLimitBytes);
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
    CHECK_EQ(wr::EventLoop::of(ctx).liveCallbackCount(), size_t(0));
    CHECK(env.host().diagnostics.empty());
}
