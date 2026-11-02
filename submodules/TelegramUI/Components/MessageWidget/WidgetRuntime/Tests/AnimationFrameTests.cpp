// Animation frames and page visibility (M1b plan, Task 11).
#include <cstdint>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/AnimationFrames.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

namespace wr {

/// The tests' access to AnimationFrames' handle counter (AnimationFrames.h names it a friend): the wrap past UINT32_MAX
/// cannot be reached by requesting 2^32 frames.
struct AnimationFramesTestAccess {
    static void setNextHandle(AnimationFrames& frames, uint32_t handle) { frames.m_nextHandle = handle; }
};

} // namespace wr

namespace {

/// globalThis.setNextFrameHandle(h): the handle the next requestAnimationFrame tries first, from inside a callback.
JSValue setNextFrameHandle(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    uint32_t handle = 0;
    if (JS_ToUint32(ctx, &handle, argv[0]) < 0) {
        return JS_EXCEPTION;
    }
    wr::AnimationFramesTestAccess::setNextHandle(wr::EventLoop::of(ctx).animationFrames(), handle);
    return JS_UNDEFINED;
}

} // namespace

WR_TEST(testFrameRunsTheCallbacksPresentAtItsStart) {
    wr_test::HostEnv env;
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    CHECK(!loop.wantsAnimationFrame());
    env.eval("var log = []; var a = requestAnimationFrame(t => log.push('a' + t)); var b = requestAnimationFrame(t => log.push('b' + t));");
    CHECK_JS(env, "a > 0 && b === a + 1");
    CHECK(loop.wantsAnimationFrame());
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "a16,b16");
    CHECK(!loop.wantsAnimationFrame());
    CHECK(loop.runAnimationFrame(env.host().now) == wr::StepResult::Idle);
}

// Review Focus 2: a callback that requests a frame from inside its frame runs in the next frame, never in this one.
WR_TEST(testFrameRequestedInsideAFrameRunsNextFrame) {
    wr_test::HostEnv env;
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    env.eval("var times = []; function f(t) { times.push(t); if (times.length < 3) requestAnimationFrame(f); } requestAnimationFrame(f);");
    env.frame(16);
    CHECK_JS_EQ(env, "times.join()", "16");
    CHECK(loop.wantsAnimationFrame());
    env.frame(16);
    CHECK_JS_EQ(env, "times.join()", "16,32");
    env.frame(16);
    CHECK_JS_EQ(env, "times.join()", "16,32,48");
    CHECK(!loop.wantsAnimationFrame());
}

WR_TEST(testCancelInsideAFrame) {
    wr_test::HostEnv env;
    env.eval("var log = []; requestAnimationFrame(() => { log.push('a'); cancelAnimationFrame(b); }); var b = requestAnimationFrame(() => log.push('b'));"
             "var c = requestAnimationFrame(() => log.push('c')); cancelAnimationFrame(c); cancelAnimationFrame(999);");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "a");
    CHECK(!wr::EventLoop::of(env.ctx()).wantsAnimationFrame());
}

WR_TEST(testTimestampIsRelativeToTheTimeOrigin) {
    wr_test::HostEnv env;
    env.advance(250);
    env.eval("var same = null; requestAnimationFrame(t => { same = (t === performance.now()) + ':' + t; });");
    env.frame(10);
    CHECK_JS_EQ(env, "same", "true:260");
}

WR_TEST(testCheckpointAfterEachFrameCallback) {
    wr_test::HostEnv env;
    env.eval("var log = []; requestAnimationFrame(() => { log.push('a'); queueMicrotask(() => log.push('m')); }); requestAnimationFrame(() => log.push('b'));");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "a,m,b");
}

WR_TEST(testFrameCallbackErrorsAreReported) {
    wr_test::HostEnv env;
    env.eval("var log = []; addEventListener('error', e => log.push('error:' + e.error.message));"
             "requestAnimationFrame(() => { throw new Error('a'); }); requestAnimationFrame(() => log.push('b'));");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "error:a,b");
}

// widget-sandbox v0.3.0: the timer cap (64) is the timers' own; frame callbacks keep theirs, 256 (upstream's shim caps
// none: ours bounds the table).
WR_TEST(testAnimationFramesHaveALimitOfTheirOwn) {
    wr_test::HostEnv env;
    env.eval("for (let i = 0; i < 64; i++) setTimeout(() => {}, 1000); var frames = []; for (let i = 0; i < 256; i++) frames.push(requestAnimationFrame(() => {}));");
    CHECK_THROWS(env, "requestAnimationFrame(() => {})", "RangeError");
    CHECK_JS_EQ(env, "(() => { try { requestAnimationFrame(() => {}); } catch (e) { return e.message; } })()", "too many animation frame callbacks");
    CHECK_THROWS(env, "setTimeout(() => {}, 1000)", "RangeError");
    env.eval("cancelAnimationFrame(frames[0])");
    CHECK_JS(env, "requestAnimationFrame(() => {}) > 0");
}

WR_TEST(testStoppedRuntimeRunsNoFrames) {
    wr_test::HostEnv env;
    env.eval("var ran = false; requestAnimationFrame(() => { ran = true; });");
    wr_test::stopAfter(env.runtime());
    CHECK_EQ(env.eval("for (;;) {}"), std::string("ABORTED"));
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    CHECK(!loop.wantsAnimationFrame());
    CHECK(loop.runAnimationFrame(100) == wr::StepResult::Stopped);
}

WR_TEST(testVisibilityChange) {
    wr_test::HostEnv env;
    CHECK_JS(env, "document.hidden === false && document.visibilityState === 'visible'");
    env.eval("var events = []; addEventListener('visibilitychange', e => events.push(e.bubbles + ':' + document.visibilityState));");
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    CHECK_JS(env, "document.hidden === false");
    env.drain();
    CHECK_JS(env, "document.hidden === true && document.visibilityState === 'hidden'");
    CHECK_JS_EQ(env, "events.join()", "true:hidden");
    // An unchanged state fires nothing.
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    env.drain();
    CHECK_JS_EQ(env, "events.length", "1");
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), true);
    env.drain();
    CHECK_JS_EQ(env, "events.join()", "true:hidden,true:visible");
    // A document that is not the window's is hidden.
    CHECK_JS(env, "new Document().hidden === true");
}

// Ruling R4: a canceled callback, one that ran and one canceled by an earlier callback of its frame release what they
// captured; a callback that waits holds it.
WR_TEST(testFrameCallbacksReleaseWhatTheyHold) {
    wr_test::HostEnv env;
    JSRuntime* rt = env.runtime().jsRuntime();
    JS_RunGC(rt);
    size_t before = env.runtime().liveObjects();
    const char* tree = "const keep = document.createElement('div'); for (let i = 0; i < 100; i++) keep.appendChild(document.createElement('p'));";
    env.eval(std::string("(() => { ") + tree + " cancelAnimationFrame(requestAnimationFrame(() => keep.remove())); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
    env.eval(std::string("(() => { ") + tree + " requestAnimationFrame(() => { keep.id = 'x'; }); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() > before + 100);
    env.frame(16);
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
    env.eval(std::string("(() => { ") + tree + " let b; requestAnimationFrame(() => cancelAnimationFrame(b)); b = requestAnimationFrame(() => { keep.id = 'y'; }); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() > before + 100);
    env.frame(16);
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
    CHECK_EQ(wr::EventLoop::of(env.ctx()).liveCallbackCount(), size_t(0));
}

// Ruling R6: the handle counter wraps from UINT32_MAX to 1 and skips the handles still in the list (HTML: a handle
// greater than zero), so a handle is never zero or shared. Callbacks still run in the order they were requested.
WR_TEST(testHandlesWrapPastUint32MaxAndSkipThoseInUse) {
    wr_test::HostEnv env;
    env.eval("var log = []; var first = requestAnimationFrame(() => log.push('first'));");
    CHECK_JS(env, "first === 1");
    wr::AnimationFramesTestAccess::setNextHandle(wr::EventLoop::of(env.ctx()).animationFrames(), UINT32_MAX - 1);
    env.eval("var a = requestAnimationFrame(() => log.push('a')), b = requestAnimationFrame(() => log.push('b'));"
             "var c = requestAnimationFrame(() => log.push('c')), d = requestAnimationFrame(() => log.push('d'));");
    CHECK_JS_EQ(env, "[a, b, c, d].join()", "4294967294,4294967295,2,3");
    // Canceling the largest handle and a wrapped one cancels those callbacks only.
    env.eval("cancelAnimationFrame(b); cancelAnimationFrame(c);");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "first,a,d");
    CHECK_EQ(wr::EventLoop::of(env.ctx()).liveCallbackCount(), size_t(0));
}

// Ruling R6: once handles are reused, one canceled during a frame can be handed to a callback requested later in that
// frame. The frame runs the callbacks present when it started, so the new callback still waits for the next frame.
WR_TEST(testAReusedHandleRequestedInsideAFrameRunsNextFrame) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.runtime().setGlobal("setNextFrameHandle", JS_NewCFunction(ctx, setNextFrameHandle, "setNextFrameHandle", 1));
    env.eval("var log = [], b, c; setNextFrameHandle(10);"
             "var a = requestAnimationFrame(() => { log.push('a'); cancelAnimationFrame(b); setNextFrameHandle(b); c = requestAnimationFrame(() => log.push('c')); });"
             "b = requestAnimationFrame(() => log.push('b'));");
    CHECK_JS_EQ(env, "[a, b].join()", "10,11");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join() + ':' + c", "a:11");
    env.frame(16);
    CHECK_JS_EQ(env, "log.join()", "a,c");
}

/// A host call on a stopped runtime (here setVisible, which queues a task) neither throws to the host nor runs anything.
WR_TEST(testSetVisibleNeverThrowsToTheHost) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    wr_test::stopAfter(env.runtime());
    CHECK_EQ(env.eval("for (;;) {}"), std::string("ABORTED"));
    bool threw = false;
    try {
        for (int i = 0; i < 1000; i++) {
            wr::HostState::of(ctx).setVisible(ctx, i % 2 == 1);
        }
    } catch (...) {
        threw = true;
    }
    CHECK(!threw);
    CHECK(!JS_HasException(ctx));
    CHECK(env.step() == wr::StepResult::Stopped);
    CHECK(!wr::DOMState::of(ctx).document().isHidden());
}
