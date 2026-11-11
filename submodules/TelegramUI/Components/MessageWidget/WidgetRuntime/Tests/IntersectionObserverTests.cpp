// Intersection Observer (V3b plan, Task 3): after the flush that ends a task or a frame, every observation's
// intersection with its root (the widget's whole area by default: a widget has no viewport) is computed, and when its
// threshold index or isIntersecting changed (always, the first time) an entry is queued and delivered in a task.
#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// v: 20 px tall in the flow. n: not rendered. root: a 100×40 clipping box holding `half`, 40 px tall at top 20 (half of
// it inside), and `below`, 40 px tall at top 50 (all of it outside).
const char* const kPage =
    "<!doctype html><html><head></head><body>"
    "<div id=v style=\"height:20px\"></div>"
    "<div id=n style=\"display:none\"></div>"
    "<div id=root style=\"position:relative;overflow:hidden;width:100px;height:40px\">"
    "<div id=half style=\"position:absolute;top:20px;width:100px;height:40px\"></div>"
    "<div id=below style=\"position:absolute;top:50px;width:100px;height:40px\"></div></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e; window.log = [];</script>"
    "</body></html>";

/// Runs one task, whose end computes the intersections, and the delivery task it queues.
void settle(RenderEnv& env) {
    env.env().eval("setTimeout(() => {}, 0); 1");
    env.env().advance(1);
}

} // namespace

WR_TEST(testAVisibleElementIsReportedIntersecting) {
    RenderEnv env(kPage);
    env.env().eval("window.io = new IntersectionObserver((es, o) => es.forEach(e => log.push([e.target.id, e.isIntersecting,"
                   "  e.intersectionRatio, e.boundingClientRect.height, e.intersectionRect.height, e.rootBounds.width,"
                   "  typeof e.time, o === io, e instanceof IntersectionObserverEntry].join(':'))));"
                   "io.observe(v); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("v:true:1:20:20:300:number:true:true"));
    // Nothing changed: no new entry.
    settle(env);
    CHECK_EQ(env.env().eval("log.length"), std::string("1"));
}

/// Fidelity plan, Task 7: the target's rect is its transformed box, as getBoundingClientRect reports it.
WR_TEST(testATransformedTargetIntersectsWhereItIsDrawn) {
    RenderEnv env("<!doctype html><html><head></head><body style='margin:0'>"
                  "<div id=root style='position:relative;overflow:hidden;width:100px;height:40px'>"
                  "<div id=t style='width:100px;height:20px;transform:translateY(30px)'></div></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e; window.log = [];</script>"
                  "</body></html>");
    env.env().eval("new IntersectionObserver(es => es.forEach(e => log.push(e.intersectionRatio + ':' +"
                   " Math.round(e.boundingClientRect.y) + ':' + Math.round(t.getBoundingClientRect().y))), { root }).observe(t); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("0.5:30:30"));
}

WR_TEST(testANotRenderedElementIsNotIntersecting) {
    RenderEnv env(kPage);
    env.env().eval("new IntersectionObserver(es => es.forEach(e => log.push(e.isIntersecting + ':' + e.intersectionRatio))).observe(n); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("false:0"));
}

WR_TEST(testAThresholdCrossingIsReported) {
    RenderEnv env(kPage);
    env.env().eval("new IntersectionObserver(es => es.forEach(e => log.push(e.intersectionRatio)), { root, threshold: [0.25, 0.75] })"
                   ".observe(half); 1");
    settle(env);
    // All of it inside: the index moves past 0.75.
    env.env().eval("half.style.top = '0px'; 1");
    settle(env);
    // Three quarters inside: the same index (a ratio at a threshold is past it).
    env.env().eval("half.style.top = '10px'; 1");
    settle(env);
    // A quarter inside.
    env.env().eval("half.style.top = '30px'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("0.5,1,0.25"));
}

WR_TEST(testRootMarginGrowsTheRoot) {
    RenderEnv env(kPage);
    env.env().eval("window.plain = new IntersectionObserver(es => es.forEach(e => log.push('plain:' + e.isIntersecting)), { root });"
                   "window.grown = new IntersectionObserver(es => es.forEach(e => log.push('grown:' + e.isIntersecting)),"
                   "  { root, rootMargin: '0px 0px 20px' });"
                   "plain.observe(below); grown.observe(below); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("plain:false,grown:true"));
    CHECK_EQ(env.env().eval("[plain.rootMargin, grown.rootMargin, plain.thresholds.join(), plain.root === root].join(' ')"),
             std::string("0px 0px 0px 0px 0px 0px 20px 0px 0 true"));
}

WR_TEST(testTakeRecordsAndDisconnect) {
    RenderEnv env(kPage);
    env.env().eval("window.io = new IntersectionObserver(es => log.push(es.length)); io.observe(v); setTimeout(() => {}, 0); 1");
    // The timer's task: its end queues the entry and the task that would deliver it.
    env.env().step();
    CHECK_EQ(env.env().eval("io.takeRecords().map(e => e.target.id).join()"), std::string("v"));
    env.env().drain();
    CHECK_EQ(env.env().eval("log.length"), std::string("0"));
    env.env().eval("io.disconnect(); v.style.height = '0px'; v.style.display = 'none'; 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.length"), std::string("0"));
}

WR_TEST(testATargetOutsideItsRootIsNotIntersecting) {
    RenderEnv env(kPage);
    env.env().eval("new IntersectionObserver(es => es.forEach(e => log.push(e.target.id + ':' + e.isIntersecting)), { root })"
                   ".observe(v); 1");
    settle(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("v:false"));
}

WR_TEST(testInvalidOptionsThrow) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { threshold: 2 }); 'no' } catch (e) { e.name }"),
             std::string("RangeError"));
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { rootMargin: 'x' }); 'no' } catch (e) { e.name }"),
             std::string("SyntaxError"));
}

/// The final review's C1: an options member of interface type keeps the object it was converted from. A root made by
/// a getter has no other reference, and the conversions after it run more script before the constructor takes it.
WR_TEST(testARootMadeByAGetterStaysAlive) {
    RenderEnv env(kPage);
    env.env().eval("window.io = new IntersectionObserver(() => {}, { get root() { const d = document.createElement('div');"
                   "  d.id = 'made'; return d; }, get rootMargin() { for (let i = 0; i < 1000; i++) ({ i }); return '1px'; } }); 1");
    JS_RunGC(env.env().runtime().jsRuntime());
    CHECK_EQ(env.env().eval("io.root.id"), std::string("made"));
}

/// The final review's I1: an option that cannot be valid is refused before it is copied into native memory: a
/// rootMargin past its longest form, a threshold that is not a finite number (WebIDL's restricted double: TypeError).
WR_TEST(testAHugeRootMarginOrThresholdIsRefusedEarly) {
    RenderEnv env(kPage);
    env.env().eval("window.margin = '0 '.repeat(100000); window.holes = []; holes.length = 1000000; 1");
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { rootMargin: margin }); 'no' } catch (e) { e.name }"),
             std::string("SyntaxError"));
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { threshold: holes }); 'no' } catch (e) { e.name }"),
             std::string("TypeError"));
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { threshold: NaN }); 'no' } catch (e) { e.name }"),
             std::string("TypeError"));
    CHECK_EQ(env.env().eval("try { new IntersectionObserver(() => {}, { threshold: [0.5, 2] }); 'no' } catch (e) { e.name }"),
             std::string("RangeError"));
}
