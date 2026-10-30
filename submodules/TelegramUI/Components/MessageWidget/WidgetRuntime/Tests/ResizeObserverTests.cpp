// Resize Observer (V3b plan, Task 2): after the flush that ends a task or a frame (HTML's "update the rendering"), every
// observation whose box size changed since it last reported is delivered to its observer's callback, then what the
// callbacks changed is laid out and gathered again, a bounded number of rounds.
#include <string>

#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// a: a 100×40 content box with 5 px padding and a 2 px border (114×54 border box). z: an empty box.
const char* const kBoxes =
    "<!doctype html><html><head></head><body>"
    "<div id=a style=\"width:100px;height:40px;padding:5px;border:2px solid black\"></div>"
    "<div id=z style=\"width:0;height:0\"></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e; window.log = [];"
    "window.entry = e => [e.target.id, e.contentRect.x, e.contentRect.y, e.contentRect.width, e.contentRect.height,"
    "  e.contentBoxSize[0].inlineSize, e.contentBoxSize[0].blockSize, e.borderBoxSize[0].inlineSize,"
    "  e.borderBoxSize[0].blockSize].join(':');</script>"
    "</body></html>";

/// Runs one task, whose end is a rendering update that delivers.
void settle(RenderEnv& env) {
    env.env().eval("setTimeout(() => {}, 0); 1");
    env.env().advance(1);
}

} // namespace

WR_TEST(testAnObservedBoxIsReportedOnce) {
    RenderEnv env(kBoxes);
    env.env().eval("window.ro = new ResizeObserver((es, o) => { for (const e of es) log.push(entry(e) + ':' + (o === ro)"
                   "  + ':' + (e instanceof ResizeObserverEntry) + ':' + (e.contentRect instanceof DOMRectReadOnly)"
                   "  + ':' + Object.isFrozen(e.borderBoxSize) + ':' + (e.borderBoxSize[0] instanceof ResizeObserverSize)); });"
                   "ro.observe(a); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("a:5:5:100:40:100:40:114:54:true:true:true:true:true"));
    // Nothing changed: nothing more.
    settle(env);
    CHECK_EQ(env.env().eval("log.length"), std::string("1"));
}

WR_TEST(testAZeroBoxIsNotReportedInitially) {
    RenderEnv env(kBoxes);
    env.env().eval("new ResizeObserver(es => { for (const e of es) log.push(entry(e)); }).observe(z); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.length"), std::string("0"));
    env.env().eval("z.style.width = '10px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("z:0:0:10:0:10:0:10:0"));
}

WR_TEST(testASizeChangeIsReported) {
    RenderEnv env(kBoxes);
    env.env().eval("new ResizeObserver(es => { for (const e of es) log.push(e.contentRect.width); }).observe(a); 1");
    settle(env);
    env.env().eval("a.style.width = '90px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("100,90"));
}

WR_TEST(testTheBorderBoxOption) {
    RenderEnv env(kBoxes);
    env.env().eval("window.c = []; window.b = [];"
                   "new ResizeObserver(es => c.push(es.length)).observe(a);"
                   "new ResizeObserver(es => b.push(es[0].borderBoxSize[0].inlineSize)).observe(a, { box: 'border-box' }); 1");
    settle(env);
    // The padding grows the border box only.
    env.env().eval("a.style.padding = '6px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("c.join() + ' ' + b.join()"), std::string("1 114,116"));
}

WR_TEST(testUnobserveAndDisconnectStopReports) {
    RenderEnv env(kBoxes);
    env.env().eval("window.u = new ResizeObserver(es => log.push('u')); u.observe(a); u.observe(z);"
                   "window.d = new ResizeObserver(es => log.push('d')); d.observe(a); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("u,d"));
    env.env().eval("u.unobserve(a); d.disconnect(); a.style.width = '50px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("u,d"));
    // u still observes z.
    env.env().eval("z.style.height = '3px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("u,d,u"));
}

WR_TEST(testASelfResizingCallbackIsBounded) {
    RenderEnv env(kBoxes);
    env.env().eval("window.n = 0; window.errors = []; addEventListener('error', e => errors.push(e.message));"
                   "new ResizeObserver(es => { n++; a.style.width = (100 + n) + 'px'; }).observe(a); 1");
    settle(env);
    CHECK_EQ(env.env().eval("n"), std::string("4"));
    CHECK_EQ(env.env().eval("errors.join()"), std::string("ResizeObserver loop completed with undelivered notifications."));
    // What was left is delivered at the next update.
    settle(env);
    CHECK(std::stoi(env.env().eval("n")) > 4);
}

WR_TEST(testADroppedObserverKeepsObserving) {
    RenderEnv env(kBoxes);
    env.env().eval("(() => { new ResizeObserver(es => log.push(es.length)).observe(a); })(); 1");
    JS_RunGC(env.env().runtime().jsRuntime());
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("1"));
}

WR_TEST(testAThrowingCallbackDoesNotStopTheOthers) {
    RenderEnv env(kBoxes);
    env.env().eval("window.errors = []; addEventListener('error', e => errors.push(e.message));"
                   "new ResizeObserver(() => { throw new Error('boom'); }).observe(a);"
                   "new ResizeObserver(es => log.push('second')).observe(a); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("second"));
    CHECK_EQ(env.env().eval("errors.length"), std::string("1"));
}

/// The final review's I4: a width change is a rendering update of its own: it queues a task, whose end reports media
/// changes and delivers resize observations, even to an idle widget.
WR_TEST(testAWidthChangeRunsTheRenderingUpdate) {
    RenderEnv env(kBoxes);
    env.env().eval("new ResizeObserver(es => log.push(es[0].contentRect.width)).observe(document.body);"
                   "matchMedia('(max-width: 200px)').onchange = e => log.push('mq:' + e.matches); 1");
    settle(env);
    wr::HostState::of(env.ctx()).setWidth(env.ctx(), 150);
    env.env().drain();
    // The body's content box: the width less the padding token's 12 px a side.
    CHECK_EQ(env.env().eval("log.join()"), std::string("276,mq:true,126"));
}

/// What a capped round left is asked for at the next frame, not left for a task that may never come.
WR_TEST(testLeftoversAskForAFrame) {
    RenderEnv env(kBoxes);
    env.env().eval("window.n = 0; new ResizeObserver(es => { n++; a.style.width = (100 + n) + 'px'; }).observe(a); 1");
    settle(env);
    CHECK(wr::HostState::of(env.ctx()).loop().wantsAnimationFrame());
    env.env().frame();
    CHECK(std::stoi(env.env().eval("n")) > 4);
}
