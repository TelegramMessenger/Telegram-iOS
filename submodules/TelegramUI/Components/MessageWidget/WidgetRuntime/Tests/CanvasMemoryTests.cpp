// Canvas memory (V5d final review, C2–C4): what a canvas keeps between calls (paths, Path2D copies, clips, gradient
// stops, saved states) lives in the JS heap, so the widget's memory limit bounds it; clips are a chain each save()
// shares, at most kMaxClipDepth deep; the readback strings are capped.
#include <cstdio>
#include <string>

#include <malloc/malloc.h>

#include "Sources/Runtime/Runtime.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeCanvas;
using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><html><head></head><body><canvas id=stage width=160 height=120></canvas>"
    "<script>window.stage = document.getElementById('stage'); window.ctx = stage.getContext('2d');"
    // A Path2D of 524,288 points: doubled until the path cap refuses the next doubling.
    "window.bigPath = (n) => { const p = new Path2D(); p.moveTo(0, 0); p.lineTo(1, 1); for (let i = 0; i < n; i++) p.addPath(p); return p; };"
    "</script></body></html>";

/// Limits the JS heap to what it holds now plus `extra` bytes.
void limitTo(RenderEnv& env, size_t extra) {
    JSRuntime* rt = env.env().runtime().jsRuntime();
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, size_t(usage.malloc_size) + extra);
}

} // namespace

/// C3: Path2D copies are JS heap.
WR_TEST(testPathCopiesCountTowardTheLimit) {
    RenderEnv env(kPage);
    env.env().eval("var p = bigPath(19); var keep = []; 1");
    limitTo(env, 16 << 20);
    // 50 copies of about 4.7 MB each.
    CHECK_EQ(env.env().eval("for (let i = 0; i < 50; i++) keep.push(new Path2D(p)); keep.length"), std::string("ABORTED"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Memory);
}

/// C3: the current path is JS heap too.
WR_TEST(testTheCurrentPathCountsTowardTheLimit) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    limitTo(env, 4 << 20);
    CHECK_EQ(env.env().eval("ctx.moveTo(0, 0); for (let i = 0; i < 900000; i++) ctx.lineTo(i % 7, 1); 1"), std::string("ABORTED"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Memory);
}

/// C2: a clip is one link of a chain each save() shares, counted, and at most kMaxClipDepth deep.
WR_TEST(testClipsAreAChainCountedAndCapped) {
    RenderEnv env(kPage);
    env.env().eval("for (let i = 0; i < 100; i++) { ctx.save(); ctx.beginPath(); ctx.rect(0, 0, 100 - i, 100); ctx.clip(); }"
                   " ctx.fillRect(0, 0, 10, 10); 1");
    CHECK(!FakeCanvas::live().empty() && FakeCanvas::live().back()->log.back() == "fill 0,0 10x10 #000000ff clips=64");
    bool limited = false;
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        limited = limited || (kind == "render-limit" && detail == "canvas-clips");
    }
    CHECK(limited);
    RenderEnv big(kPage);
    big.env().eval("var p = bigPath(18); 1");
    limitTo(big, 8 << 20);
    // Ten clips of about 2.4 MB each, kept by ten saved states.
    CHECK_EQ(big.env().eval("for (let i = 0; i < 10; i++) { ctx.save(); ctx.clip(p); } 1"), std::string("ABORTED"));
    CHECK(big.env().runtime().stopReason() == wr::StopReason::Memory);
}

/// C3: gradient stops are JS heap.
WR_TEST(testGradientStopsCountTowardTheLimit) {
    RenderEnv env(kPage);
    limitTo(env, 1 << 20);
    CHECK_EQ(env.env().eval("var gs = []; for (let i = 0; i < 1000; i++) { const g = ctx.createLinearGradient(0, 0, 1, 0);"
                            " for (let s = 0; s < 256; s++) g.addColorStop(s / 255, 'red'); gs.push(g); } gs.length"),
             std::string("ABORTED"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Memory);
}

/// C4: the readback strings are capped, so a saved state stays small.
WR_TEST(testReadbackStringsAreCapped) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("ctx.lang = 'x'.repeat(1000000); ctx.lang.length"), std::string("256"));
    CHECK_EQ(env.env().eval("ctx.font = '12px ' + 'a'.repeat(5000) + ', sans-serif'; ctx.font"), std::string("10px sans-serif"));
    CHECK_EQ(env.env().eval("ctx.filter = 'x'.repeat(5000); ctx.filter.length"), std::string("1024"));
}

/// V5d fix-wave review, M-A: a save() refused at the memory limit leaks no reference (a gradient style dup'd into a
/// state the stack could not take): the runtime still frees every object at teardown.
WR_TEST(testASaveAtTheLimitLeaksNothing) {
    {
        RenderEnv env(kPage);
        env.env().eval("ctx.fillStyle = ctx.createLinearGradient(0, 0, 1, 0); 1");
        limitTo(env, 64 << 10);
        CHECK_EQ(env.env().eval("for (let i = 0; i < 100000; i++) ctx.save(); 1"), std::string("ABORTED"));
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Memory);
    }
    // Reaching here: JS_FreeRuntime found every object freed (it asserts otherwise).
    CHECK(true);
}

/// V5d fix-wave review, I-C: a saved state shares its strings (font, filter, lang) and its dash with the state it was
/// saved from, so a save costs only counted bytes: the heap outside the JS heap does not grow with the saves.
WR_TEST(testSavedStatesShareTheirStrings) {
    RenderEnv env(kPage);
    JSRuntime* rt = env.env().runtime().jsRuntime();
    // malloc's bytes in use that the JS heap does not count.
    auto uncounted = [&] {
        malloc_statistics_t stats;
        malloc_zone_statistics(nullptr, &stats);
        JSMemoryUsage usage;
        JS_ComputeMemoryUsage(rt, &usage);
        return int64_t(stats.size_in_use) - int64_t(usage.malloc_size);
    };
    const int64_t before = uncounted();
    CHECK_EQ(env.env().eval("var keep = []; for (let k = 0; k < 20; k++) { const c = document.createElement('canvas').getContext('2d');"
                            " c.font = '10px ' + 'a'.repeat(1000) + ', sans-serif'; c.filter = 'x'.repeat(1024);"
                            " c.lang = 'x'.repeat(256); c.setLineDash(Array(63).fill(1));"
                            " for (let i = 0; i < 512; i++) c.save(); keep.push(c); } [keep.length, keep[0].font.length].join()"),
             std::string("20,1017"));
    const int64_t grown = uncounted() - before;
    // 10,240 saved states: 40 MB if each copied its strings.
    CHECK(grown < (int64_t(2) << 20));
    if (grown >= (int64_t(2) << 20)) {
        std::printf("  uncounted heap grew %lld bytes\n", (long long)grown);
    }
}
