// What stops a widget besides its CPU limits, held through the removal of the work-unit accounting (the CPU-clock limits
// plan, Task 7; its Review Focus 5): the memory limit, the uncatchable stop, a widget-sandbox v0.3.0 count cap and the
// parse's count limits still stop what they stopped.
#include <string>

#include "Sources/Host/Boot.h"
#include "Sources/Runtime/CpuLimits.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::HostEnv;
using wr_test::RenderEnv;
using wr_test::ScopedCpuLimits;
using wr_test::ScopedFakeClock;

namespace {

/// A global's int32 value (-1 when it is not a number), read without running script.
int32_t globalInt(wr::Runtime& runtime, const char* name) {
    JSContext* ctx = runtime.context();
    JS_SetMemoryLimit(runtime.jsRuntime(), wr::Runtime::Options().memoryLimitBytes);
    wr::Value global = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    wr::Value value = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, global.get(), name));
    int32_t n = -1;
    if (JS_IsNumber(value.get())) {
        JS_ToInt32(ctx, &n, value.get());
    }
    return n;
}

} // namespace

WR_TEST(testTheMemoryLimitStillStops) {
    HostEnv env;
    JSRuntime* rt = env.runtime().jsRuntime();
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, size_t(usage.malloc_size) + (8 << 20));
    CHECK_EQ(env.eval("const a = []; for (;;) a.push(new Float64Array(1 << 16)); 1"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
}

WR_TEST(testTheStopStaysUncatchable) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(1.0);
    HostEnv env;
    env.runtime().beginSlice("timer", 500);
    // A try/catch around the runaway, in a bounded outer loop: a stop the catch could take would be counted and the loop
    // would go on.
    CHECK_EQ(env.eval("var caught = 0; for (let i = 0; i < 1000; i++) { try { for (;;) {} } catch (e) { caught++ } } 1"),
             std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(globalInt(env.runtime(), "caught"), 0);
}

/// limit.text-node, judged on the render build: markup already past it stops the boot's flush.
WR_TEST(testTheCountCapsStillStop) {
    RenderEnv env("<!doctype html><div>" + std::string(40000, 'b') + "</div>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Limit);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("Text limit exceeded: a text value of 40000 characters (max 32768)"));
}

WR_TEST(testTheParseLimitsStillHold) {
    wr::ParseLimits limits;
    limits.maxNodes = 50;
    std::string html = "<!doctype html>";
    for (int i = 0; i < 200; i++) {
        html += "<p>x</p>";
    }
    HostEnv env(wr_test::BootTag{}, html, "about:srcdoc", 1, limits);
    CHECK(env.bootOutcome().stoppedAtNodeLimit);
    env.drain();
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}
