// CSSOM View's geometry queries (V3 plan, Task 3): each flushes what is pending and reads the published layout
// (RenderTree::flushForQuery, then borderBox / clientRects / nodeAt / boxMetrics), in CSS px from the document's
// top-left (there is no scrolling viewport). The default layout is 300 px wide under the UA layer's body margin, the
// padding token (its reference default `8px 12px` here: widget-sandbox v0.1.1).
#include <cstdio>
#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// a: 100×40 at (12, 8). p: below it, 20 px further in, a 2 px border and 3 px padding around 50×30, positioned;
// c: a 10 px block inside p's content box, 4 px down.
const char* const kBoxes =
    "<!doctype html><html><head></head><body><div id=a style=\"width:100px;height:40px\"></div>"
    "<div id=p style=\"position:relative;margin-left:20px;border:2px solid black;padding:3px;width:50px;height:30px\">"
    "<div id=c style=\"height:10px;margin-top:4px\"></div></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>";

} // namespace

WR_TEST(testTheBoundingRectIsTheBorderBox) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("var r = a.getBoundingClientRect(); [r.x, r.y, r.width, r.height, r.top, r.right, r.bottom, r.left].join(',')"),
             std::string("12,8,100,40,8,112,48,12"));
    CHECK_EQ(env.env().eval("a.getBoundingClientRect() instanceof DOMRect && a.getBoundingClientRect() instanceof DOMRectReadOnly"),
             std::string("true"));
    CHECK_EQ(env.env().eval("JSON.stringify(a.getBoundingClientRect())"),
             std::string("{\"x\":12,\"y\":8,\"width\":100,\"height\":40,\"top\":8,\"right\":112,\"bottom\":48,\"left\":12}"));
    // A new object per call.
    CHECK_EQ(env.env().eval("a.getBoundingClientRect() !== a.getBoundingClientRect()"), std::string("true"));
    // An element with no box: all zero.
    CHECK_EQ(env.env().eval("var r = document.createElement('div').getBoundingClientRect(); [r.x, r.y, r.width, r.height].join(',')"),
             std::string("0,0,0,0"));
}

WR_TEST(testTheClientRectsListTheBoxes) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("var l = a.getClientRects(); [l.length, l[0].width, l.item(0).height, l.item(5) === null, l instanceof DOMRectList].join(',')"),
             std::string("1,100,40,true,true"));
    CHECK_EQ(env.env().eval("document.createElement('div').getClientRects().length"), std::string("0"));
}

WR_TEST(testAQueryReadsTheLayoutAfterAChange) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("a.style.height = '70px'; a.getBoundingClientRect().height"), std::string("70"));
    CHECK_EQ(env.env().eval("p.getBoundingClientRect().y"), std::string("78"));
}

WR_TEST(testElementFromPoint) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("document.elementFromPoint(20, 20) === a"), std::string("true"));
    CHECK_EQ(env.env().eval("document.elementFromPoint(40, 66) === c"), std::string("true"));
    CHECK_EQ(env.env().eval("document.elementFromPoint(-1, 5)"), std::string("null"));
    CHECK_EQ(env.env().eval("document.elementFromPoint(301, 5)"), std::string("null"));
}

WR_TEST(testTheOffsetGeometry) {
    RenderEnv env(kBoxes);
    // p's border box starts at (32, 48); its padding edge at (34, 50); c sits at (37, 57), 50 wide (p's content box).
    CHECK_EQ(env.env().eval("c.offsetParent === p"), std::string("true"));
    CHECK_EQ(env.env().eval("[c.offsetLeft, c.offsetTop, c.offsetWidth, c.offsetHeight].join(',')"), std::string("3,7,50,10"));
    // Without a positioned ancestor the offset parent is the body, and the offsets are the document's.
    CHECK_EQ(env.env().eval("a.offsetParent === document.body"), std::string("true"));
    CHECK_EQ(env.env().eval("[a.offsetLeft, a.offsetTop, p.offsetLeft, p.offsetTop].join(',')"), std::string("12,8,32,48"));
    CHECK_EQ(env.env().eval("document.body.offsetParent"), std::string("null"));
    CHECK_EQ(env.env().eval("document.createElement('div').offsetParent"), std::string("null"));
}

WR_TEST(testTheClientAndScrollSizes) {
    RenderEnv env(kBoxes);
    // p's padding box: 56×36, inside its 2 px border.
    CHECK_EQ(env.env().eval("[p.clientTop, p.clientLeft, p.clientWidth, p.clientHeight].join(',')"), std::string("2,2,56,36"));
    CHECK_EQ(env.env().eval("[p.scrollWidth, p.scrollHeight, p.scrollTop, p.scrollLeft].join(',')"), std::string("56,36,0,0"));
    // Nothing scrolls: setting a scroll offset keeps 0.
    CHECK_EQ(env.env().eval("p.scrollTop = 10; p.scrollTop"), std::string("0"));
    CHECK_EQ(env.env().eval("document.createElement('div').clientWidth"), std::string("0"));
}

/// CSS Overflow: the scrollable overflow counts the end padding after the content (auto/14-dom-layout-api-b's box: 60 px
/// of content below 5 px of padding scroll to 70, not 65).
WR_TEST(testTheScrollSizeCountsTheEndPadding) {
    RenderEnv env("<!doctype html><body><div id=b style=\"width:100px;height:20px;padding:5px;border:3px solid black;"
                  "overflow:hidden\"><div style=\"height:60px\"></div></div>"
                  "<script>window.b = document.getElementById('b');</script></body>");
    CHECK_EQ(env.env().eval("[b.scrollHeight, b.scrollWidth, b.clientHeight].join()"), std::string("70,110,30"));
}

WR_TEST(testTheWindowSizes) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("innerWidth"), std::string("300"));
    // No viewport: the document's height. 8 + 40 + 40 + 8.
    CHECK_EQ(env.env().eval("innerHeight"), std::string("96"));
}

/// devicePixelRatio (CSSOM View; profile 1's canvas.hidpi) is the scale the widget is drawn at, the render options'
/// pixelSnapScale (the screen's), and a bare global as in a browser: a game sizes its canvas's backing store by it, and
/// four of the user's games (2026-10-22, Fixtures 11-14) stopped at their first line without it.
WR_TEST(testDevicePixelRatioIsTheDrawingScale) {
    RenderEnv one(kBoxes);
    CHECK_EQ(one.env().eval("[typeof devicePixelRatio, devicePixelRatio, window.devicePixelRatio].join()"),
             std::string("number,1,1"));
    wr::RenderOptions threeTimes;
    threeTimes.pixelSnapScale = 3;
    RenderEnv three(kBoxes, threeTimes);
    CHECK_EQ(three.env().eval("devicePixelRatio"), std::string("3"));
}

/// widget-sandbox's layout queries per task: a loop of style writes and queries in one task stops once its queries took
/// 100 ms (each flush 1 ms on the fake clock), with upstream's message.
WR_TEST(testAQueryLoopStopsAtTheLayoutQueryLimit) {
    // Each query's flush takes 1 ms; the loop's own JS nothing.
    wr_test::ScopedFakeClock clock(0.0);
    clock->renderStepMs = 1.0;
    RenderEnv env("<!doctype html><div id=a style=\"height:20px\">x</div>"
                  "<script>window.a = document.getElementById('a');</script>");
    env.env().runtime().beginSlice("timer", 500);
    std::string result = env.env().eval("var i = 0; for (;;) { a.style.width = (i++ % 300) + 'px'; a.offsetHeight; }");
    CHECK(result == "ABORTED" || result == "STOPPED");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::LayoutQuery);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("Layout query limit exceeded: host queries blocked the renderer for more than "
                                                           "100 ms in one timer task (timer)"));
}

