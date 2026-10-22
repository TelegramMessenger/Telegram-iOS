// CSSOM View's geometry queries (V3 plan, Task 3): each flushes what is pending and reads the published layout
// (RenderTree::flushForQuery, then borderBox / clientRects / nodeAt / boxMetrics), in CSS px from the document's
// top-left (there is no scrolling viewport). The default layout is 300 px wide under the UA layer's body margin, the
// padding token (its reference default `8px 12px` here: widget-sandbox v0.1.1).
#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"
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

WR_TEST(testAQueryLoopStopsAtTheLayoutQueryLimit) {
    RenderEnv env("<!doctype html><div id=a style=\"height:20px\">x</div>"
                  "<script>window.a = document.getElementById('a');</script>");
    std::string result = env.env().eval("var i = 0; for (;;) { a.style.width = (i++ % 300) + 'px'; a.offsetHeight; }");
    CHECK(result == "ABORTED" || result == "STOPPED");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::LayoutQuery);
}

namespace {

/// The work units one evaluation of `code` cost, and what it added to the step's layout-query count.
std::pair<uint64_t, uint64_t> costOf(RenderEnv& env, const char* code) {
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const uint64_t units = JS_GetWorkUnits(rt), queries = env.env().runtime().layoutQueryUnits();
    env.env().eval(code);
    return {JS_GetWorkUnits(rt) - units, env.env().runtime().layoutQueryUnits() - queries};
}

std::string manyBlocks(int count) {
    std::string html = "<!doctype html><body>";
    for (int i = 0; i < count; i++) {
        html += "<div style=\"height:2px\"></div>";
    }
    return html + "<span id=s>x</span><script>window.s = document.getElementById('s');</script></body>";
}

} // namespace

/// The final review's I1: a query's read is charged by the work it does and counted against the query budget, so a
/// read-only loop (no style writes, so no flush to pay for) is bounded by its document's size, not only by the 100
/// units a query costs. elementFromPoint hit-tests the whole render tree; getClientRects walks the element's lines.
WR_TEST(testAReadIsChargedByTheDocumentItWalks) {
    RenderEnv small(manyBlocks(1));
    RenderEnv large(manyBlocks(2000));
    costOf(small, "document.elementFromPoint(1, 1)");
    costOf(large, "document.elementFromPoint(1, 1)");
    const auto [smallUnits, smallQueries] = costOf(small, "document.elementFromPoint(1, 1)");
    const auto [largeUnits, largeQueries] = costOf(large, "document.elementFromPoint(1, 1)");
    // The large document has 1999 more blocks.
    CHECK(largeUnits >= smallUnits + 1999 * wr::work::kLayoutBox);
    CHECK(largeQueries >= smallQueries + 1999 * wr::work::kLayoutBox);
}

WR_TEST(testClientRectsAreChargedByTheLinesTheyWalk) {
    const std::string oneLine = "<!doctype html><body><span id=s>x</span><script>window.s = document.getElementById('s');</script></body>";
    std::string manyLines = "<!doctype html><body style=\"width:20px\"><span id=s>";
    for (int i = 0; i < 400; i++) {
        manyLines += "word ";
    }
    manyLines += "</span><script>window.s = document.getElementById('s');</script></body>";
    RenderEnv one(oneLine);
    RenderEnv many(manyLines);
    costOf(one, "s.getClientRects().length");
    costOf(many, "s.getClientRects().length");
    CHECK_EQ(many.env().eval("s.getClientRects().length > 100"), std::string("true"));
    // Only the query count is load-bearing: the returned DOMRects' allocations are charged to the task anyway.
    const auto [oneUnits, oneQueries] = costOf(one, "s.getClientRects()");
    const auto [manyUnits, manyQueries] = costOf(many, "s.getClientRects()");
    (void)oneUnits;
    (void)manyUnits;
    CHECK(manyQueries >= oneQueries + 100 * wr::work::kLayoutBox);
}

namespace {

std::string nestedIn(int depth) {
    std::string html = "<!doctype html><body>";
    for (int i = 0; i < depth; i++) {
        html += "<div>";
    }
    html += "<span id=c>x</span>";
    for (int i = 0; i < depth; i++) {
        html += "</div>";
    }
    return html + "<script>window.c = document.getElementById('c');</script></body>";
}

std::string parentOf(int children) {
    std::string html = "<!doctype html><body><div id=p style=\"overflow:hidden;height:10px\">";
    for (int i = 0; i < children; i++) {
        html += "<div style=\"height:1px\"></div>";
    }
    return html + "</div><script>window.p = document.getElementById('p');</script></body>";
}

} // namespace

/// The walks behind offsetParent (the ancestors) and scrollWidth (the descendants) count against the query budget.
WR_TEST(testTheOffsetParentAndScrollWalksAreCharged) {
    RenderEnv shallow(nestedIn(1));
    // Under the render depth cap (256): deeper, the span has no box and offsetParent answers at once.
    RenderEnv deep(nestedIn(200));
    costOf(shallow, "c.offsetParent");
    costOf(deep, "c.offsetParent");
    const auto [shallowUnits, shallowQueries] = costOf(shallow, "c.offsetParent");
    const auto [deepUnits, deepQueries] = costOf(deep, "c.offsetParent");
    (void)shallowUnits;
    (void)deepUnits;
    CHECK(deepQueries >= shallowQueries + 199 * (wr::work::kNodeVisit + wr::work::kLayoutBox));
    RenderEnv few(parentOf(1));
    RenderEnv lots(parentOf(300));
    costOf(few, "p.scrollHeight");
    costOf(lots, "p.scrollHeight");
    const auto [fewUnits, fewQueries] = costOf(few, "p.scrollHeight");
    const auto [lotsUnits, lotsQueries] = costOf(lots, "p.scrollHeight");
    (void)fewUnits;
    (void)lotsUnits;
    CHECK(lotsQueries >= fewQueries + 299 * (wr::work::kNodeVisit + wr::work::kLayoutBox));
    CHECK_EQ(lots.env().eval("p.scrollHeight"), std::string("300"));
}
