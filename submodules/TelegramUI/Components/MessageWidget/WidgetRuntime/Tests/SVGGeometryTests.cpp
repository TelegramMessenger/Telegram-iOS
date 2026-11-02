// SVG geometry (V3b plan, Task 4): SVGGraphicsElement.getBBox, SVGGeometryElement.getTotalLength/getPointAtLength and
// SVGTextContentElement.getComputedTextLength, each a layout query, in the shape's user units (litehtml::svg_geometry).
#include <string>

#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// auto/13-svg-a's shapes: a viewBox at twice the user units, a rect, a horizontal path, a text.
const char* const kShapes =
    "<!doctype html><html><head></head><body>"
    "<svg id=geo width=120 height=40 viewBox=\"0 0 60 20\">"
    "<rect id=r x=5 y=2 width=10 height=8 fill=\"#c33\"/>"
    "<path id=p d=\"M0 15 H40\" stroke=\"#36c\"/>"
    "<circle id=c cx=30 cy=10 r=10 />"
    "<g id=g><rect x=1 y=1 width=4 height=4 /><rect x=10 y=6 width=2 height=2 /></g>"
    "<text id=t x=20 y=10 font-size=8 font-family=sans-serif>Hello</text>"
    "<text id=big x=20 y=10 font-size=16 font-family=sans-serif>Hello</text>"
    "</svg>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "window.box = b => [b.x, b.y, b.width, b.height].join(',');</script>"
    "</body></html>";

} // namespace

WR_TEST(testTheBBoxOfARectIsExact) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("(b => b.x === 5 && b.y === 2 && b.width === 10 && b.height === 8)(r.getBBox())"), std::string("true"));
    CHECK_EQ(env.env().eval("r.getBBox() instanceof DOMRect"), std::string("true"));
}

WR_TEST(testTheBBoxOfAPathAGroupAndACircle) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("box(p.getBBox())"), std::string("0,15,40,0"));
    // A group's box is the union of its children's.
    CHECK_EQ(env.env().eval("box(g.getBBox())"), std::string("1,1,11,7"));
    // A curve's extrema, not its control points.
    CHECK_EQ(env.env().eval("box(c.getBBox()).split(',').map(v => Math.round(v * 100) / 100).join()"), std::string("20,0,20,20"));
}

WR_TEST(testTotalLengthOfALineAndACircle) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("Math.abs(p.getTotalLength() - 40) < 0.1"), std::string("true"));
    CHECK_EQ(env.env().eval("Math.abs(c.getTotalLength() - 2 * Math.PI * 10) < 0.1"), std::string("true"));
}

WR_TEST(testPointAtLengthIsClamped) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("[p.getPointAtLength(10), p.getPointAtLength(-5), p.getPointAtLength(100)].map(q => q.x + ':' + q.y).join()"),
             std::string("10:15,0:15,40:15"));
    CHECK_EQ(env.env().eval("p.getPointAtLength(1) instanceof DOMPoint && p.getPointAtLength(1) instanceof DOMPointReadOnly"),
             std::string("true"));
}

/// The container's measurement of the text in the element's font (litehtml takes font-size and font-family from the
/// attributes as from CSS). FakeRenderHost measures 8 px per byte whatever the font, so "Hello" is 40 here; CoreText
/// scales with the font on the device.
WR_TEST(testComputedTextLengthIsTheTextsAdvance) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("t.getComputedTextLength()"), std::string("40"));
    CHECK_EQ(env.env().eval("[getComputedStyle(t).fontSize, getComputedStyle(big).fontSize].join()"), std::string("8px,16px"));
    CHECK_EQ(env.env().eval("t.getNumberOfChars()"), std::string("5"));
}

WR_TEST(testADetachedShapeAnswersZero) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("(s => [box(s.getBBox()), s.getTotalLength()].join(' '))"
                            "(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))"),
             std::string("0,0,0,0 0"));
}

WR_TEST(testTheInterfaces) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("[p instanceof SVGGeometryElement, p instanceof SVGGraphicsElement, g instanceof SVGGraphicsElement,"
                            " g instanceof SVGGeometryElement, t instanceof SVGTextContentElement, geo instanceof SVGGraphicsElement,"
                            " r instanceof SVGElement].join()"),
             std::string("true,true,true,false,true,true,true"));
}

/// A shape has no CSS box: its client rect is its user-unit box mapped into the <svg>'s content box through the viewBox
/// (preserveAspectRatio's default, xMidYMid meet). geo is 120×40 at (12, 8) over 60×20 user units: twice the size.
WR_TEST(testAShapesRectIsMappedThroughTheViewBox) {
    RenderEnv env(kShapes);
    CHECK_EQ(env.env().eval("box(r.getBoundingClientRect())"), std::string("22,12,20,16"));
    CHECK_EQ(env.env().eval("r.getClientRects().length"), std::string("1"));
    CHECK_EQ(env.env().eval("box(g.getBoundingClientRect())"), std::string("14,10,22,14"));
}

/// The final review's I2: what the SVG painter does not draw has no geometry (display none by CSS or attribute, under a
/// hidden group, <defs> and the other never-rendered elements): no client rects, a zero bounding rect and bbox, and no
/// part of a container's bbox.
WR_TEST(testANotRenderedShapeHasNoGeometry) {
    RenderEnv env("<!doctype html><html><head></head><body><svg id=s width=100 height=100>"
                  "<rect id=h style=\"display:none\" x=5 y=2 width=10 height=8 />"
                  "<rect id=a display=none x=5 y=2 width=10 height=8 />"
                  "<g id=g><rect x=1 y=1 width=4 height=4 /><rect style=\"display:none\" x=50 y=50 width=4 height=4 /></g>"
                  "<g style=\"display:none\"><rect id=under x=5 y=5 width=5 height=5 /></g>"
                  "<defs><rect width=500 height=500 /></defs>"
                  "</svg><script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.box = b => [b.x, b.y, b.width, b.height].join(',');</script></body></html>");
    CHECK_EQ(env.env().eval("[h, a, under].map(e => box(e.getBoundingClientRect()) + '/' + e.getClientRects().length).join(' ')"),
             std::string("0,0,0,0/0 0,0,0,0/0 0,0,0,0/0"));
    CHECK_EQ(env.env().eval("box(g.getBBox())"), std::string("1,1,4,4"));
    CHECK_EQ(env.env().eval("box(s.getBBox())"), std::string("1,1,4,4"));
    CHECK_EQ(env.env().eval("box(h.getBBox()) + ' ' + box(under.getBBox())"), std::string("0,0,0,0 0,0,0,0"));
}
