// widget-sandbox v0.2.3 (its canvas-args.test.ts): a canvas call's arguments are converted as a browser's context
// converts them (WebIDL): text through String(), coordinates through Number(), the anticlockwise flag through Boolean();
// a call with a coordinate that is not finite does nothing, in Path2D too; setTransform takes a DOMMatrix or a plain
// {a…f} / {m11…m42}; isPointInPath and isPointInStroke answer false for a point that is not finite. Upstream fixed its
// shim, which forwarded arguments as the widget passed them; these pin what our WebIDL bindings and the context do.
#include <string>

#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeCanvas;
using wr_test::RenderEnv;

namespace {

/// What the canvas drew for `script`, run with `x` a 300 × 200 canvas's 2D context: its ops joined with " | ".
std::string drawn(const std::string& script, std::string* result = nullptr) {
    RenderEnv env("<!doctype html><html><head></head><body><canvas id=c width=300 height=200></canvas>"
                  "<script>var x = document.getElementById('c').getContext('2d');"
                  " window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } };</script></body></html>");
    const std::string value = env.env().eval(script);
    if (result) {
        *result = value;
    }
    std::string log;
    for (const FakeCanvas* canvas : FakeCanvas::live()) {
        for (const std::string& line : canvas->log) {
            if (line != "reset") {
                log += (log.empty() ? "" : " | ") + line;
            }
        }
    }
    return log;
}

} // namespace

WR_TEST(testCanvasTextIsAString) {
    CHECK_EQ(drawn("x.fillText(4, 10, 20); x.strokeText(true, '5', 6); x.fillText(undefined, 1, 2); x.fillText({}, 1, 2);"
                   " x.fillText(null, 1, 2, '30'); 1"),
             std::string("text \"4\" 10,20 | text \"true\" 5,6 | text \"undefined\" 1,2 | text \"[object Object]\" 1,2 | text \"null\" 1,2"));
}

WR_TEST(testCanvasCoordinatesAreNumbersAndANonFiniteOneDrawsNothing) {
    CHECK_EQ(drawn("x.fillRect('1', '2', 3, 4); x.fillRect(NaN, 1, 2, 3); x.clearRect(0, Infinity, 1, 1); x.fillText('a', NaN, 0);"
                   " x.drawImage(x.canvas, 0, Infinity); 1"),
             std::string("fill 1,2 3x4 #000000ff"));
    // A point that is not finite is skipped, the path keeps the others; a valueOf counts as the number it gives.
    CHECK_EQ(drawn("x.beginPath(); x.moveTo({ valueOf() { return 7; } }, 8); x.lineTo(1, NaN); x.lineTo(9, 8); x.lineTo(9, 10);"
                   " x.fill(); 1"),
             std::string("fill 7,8 2x2 #000000ff"));
    CHECK_EQ(drawn("x.translate('250', '60'); x.fillRect(0, 0, 1, 1); 1"), std::string("fill 250,60 1x1 #000000ff"));
    // Path2D alike.
    CHECK_EQ(drawn("var p = new Path2D(); p.moveTo(0, 0); p.lineTo(NaN, 5); p.lineTo(4, 4); p.lineTo(0, 4); x.fill(p); 1"),
             std::string("fill 0,0 4x4 #000000ff"));
}

WR_TEST(testCanvasAnticlockwiseIsABooleanAndSetTransformTakesAMatrix) {
    // 1 is anticlockwise: from 0 to π/2 the long way round, three quarters of the circle.
    CHECK_EQ(drawn("x.beginPath(); x.arc(50, 50, 10, 0, Math.PI / 2, 1); x.fill(); 1"), std::string("fill 40,40 20x20 #000000ff"));
    CHECK_EQ(drawn("x.setTransform({ a: 2, b: 0, c: 0, d: 2, e: 5, f: 6 }); x.fillRect(0, 0, 1, 1); 1"), std::string("fill 5,6 2x2 #000000ff"));
    CHECK_EQ(drawn("x.scale(3, 3); x.setTransform(); x.fillRect(0, 0, 1, 1); 1"), std::string("fill 0,0 1x1 #000000ff"));
    CHECK_EQ(drawn("x.setTransform(new DOMMatrix([1, 0, 0, 1, 7, 8])); x.fillRect(0, 0, 1, 1); 1"), std::string("fill 7,8 1x1 #000000ff"));
    CHECK_EQ(drawn("x.setTransform({ m11: 3, m22: 3, m41: 1, m42: 2 }); x.fillRect(0, 0, 1, 1); 1"), std::string("fill 1,2 3x3 #000000ff"));
    // roundRect keeps its radii list.
    std::string result;
    CHECK_EQ(drawn("var p = new Path2D(); var r = [err(() => p.roundRect(0, 0, 10, 10, [2, 4])), err(() => x.roundRect(0, 0, 10, 10, [2, 4]))];"
                   " x.fill(p); r.join()", &result),
             std::string("fill 0,0 10x10 #000000ff"));
    CHECK_EQ(result, std::string("ok,ok"));
}

WR_TEST(testCanvasPointQueriesConvertTheirPoint) {
    std::string result;
    drawn("x.beginPath(); x.rect(0, 0, 10, 10); [x.isPointInPath('5', '5'), x.isPointInPath(NaN, 5), x.isPointInPath(5, Infinity),"
          " x.isPointInStroke(NaN, 0), x.isPointInStroke('0', '5')].join()", &result);
    CHECK_EQ(result, std::string("true,false,false,false,true"));
}
