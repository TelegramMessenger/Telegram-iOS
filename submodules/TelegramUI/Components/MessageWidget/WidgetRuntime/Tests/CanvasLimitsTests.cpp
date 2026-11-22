// widget-sandbox v0.3.0, limit.canvas-commands and limit.canvas-pixels (strict). Commands: at most 10,000 to one canvas
// in one task, as upstream's shim counts them (a drawing or path method, a state change, a gradient or pattern made;
// never a query), the next a RangeError. Pixels: the canvases a build sees hold at most 2048² together, each its width ×
// height (300 × 150 by default), past which the widget stops ("Canvas limit exceeded: canvases of …").
#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage = "<!doctype html><html><head></head><body><p id=p>t</p><script>"
                          "window.cx = document.createElement('canvas').getContext('2d');"
                          "window.$ = id => document.getElementById(id);</script></body></html>";

/// Draws `count` fillRects in a task of its own; the commands drawn and the error's name and message.
std::string drawInATask(RenderEnv& env, int count) {
    env.env().eval("window.result = ''; setTimeout(() => { let drawn = 0, error = null; try { for (let i = 0; i < " + std::to_string(count) +
                   "; i++) { cx.fillRect(i, 0, 1, 1); drawn++; } } catch (e) { error = e; }"
                   " result = drawn + (error ? ' ' + error.name + ': ' + error.message : ''); }); 1");
    env.env().drain();
    return env.env().eval("result");
}

bool flushStops(RenderEnv& env) {
    try {
        env.flush();
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

} // namespace

/// auto/19: the 10,001st command for one canvas in one task throws RangeError, after 10,000 drawn.
WR_TEST(testTheTenThousandFirstCommandThrows) {
    RenderEnv env(kPage);
    CHECK_EQ(drawInATask(env, 10001),
             std::string("10000 RangeError: Canvas limit exceeded: more than 10000 commands for one canvas in one task (max 10000)"));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// Each task starts the count again, and each canvas has its own.
WR_TEST(testTheCommandCountIsPerTaskAndCanvas) {
    RenderEnv env(kPage);
    CHECK_EQ(drawInATask(env, 10000), std::string("10000"));
    CHECK_EQ(drawInATask(env, 10000), std::string("10000"));
    env.env().eval("window.result = ''; setTimeout(() => { const other = document.createElement('canvas').getContext('2d');"
                   " for (let i = 0; i < 10000; i++) { cx.fillRect(0, 0, 1, 1); other.fillRect(0, 0, 1, 1); } result = 'ok'; }); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("result"), std::string("ok"));
}

/// A state change and a path step are commands; a query is not.
WR_TEST(testStateChangesAndPathsCountQueriesDoNot) {
    RenderEnv env(kPage);
    env.env().eval("window.result = ''; setTimeout(() => { try { for (let i = 0; i < 5000; i++) { cx.fillStyle = '#123456'; cx.lineTo(i, 1); }"
                   " cx.save(); } catch (e) { result = e.name; } }); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("result"), std::string("RangeError"));
    env.env().eval("window.result = ''; setTimeout(() => { for (let i = 0; i < 20000; i++) { cx.measureText('a'); cx.isPointInPath(0, 0);"
                   " cx.getTransform(); cx.getImageData(0, 0, 1, 1); } result = 'ok'; }); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("result"), std::string("ok"));
}

/// auto/35: a 2048² canvas beside a 1024² one stops the widget at the flush, and the tree from before stays.
WR_TEST(testCanvasesPastThePixelCapStop) {
    RenderEnv env("<!doctype html><html><head></head><body><canvas id=c width=1024 height=1024 style=\"width:20px;height:20px\">"
                  "</canvas></body></html>");
    const std::string before = env.render().layerTree()->dump();
    env.env().eval("const c = document.createElement('canvas'); c.width = 2048; c.height = 2048; document.body.append(c); 1");
    CHECK(flushStops(env));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Limit);
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("Canvas limit exceeded: canvases of 5242880 pixels together (max 4194304)"));
    CHECK_EQ(env.render().layerTree()->dump(), before);
}

/// A connected canvas resized past the cap stops the widget too; at the cap exactly it does not.
WR_TEST(testAResizePastThePixelCapStops) {
    RenderEnv env("<!doctype html><html><head></head><body><canvas id=c></canvas><script>"
                  "window.$ = id => document.getElementById(id);</script></body></html>");
    env.env().eval("$('c').width = 2048; $('c').height = 2048; 1");
    CHECK(!flushStops(env));
    env.env().eval("$('c').width = 2049; 1");
    CHECK(flushStops(env));
    CHECK_EQ(env.env().runtime().stopDetail(), std::string("Canvas limit exceeded: canvases of 4196352 pixels together (max 4194304)"));
}

/// A canvas taken out of the document gives its pixels back.
WR_TEST(testARemovedCanvasRefunds) {
    RenderEnv env("<!doctype html><html><head></head><body><canvas id=a width=2048 height=1024></canvas>"
                  "<canvas id=b width=2048 height=1024></canvas><script>window.$ = id => document.getElementById(id);</script>"
                  "</body></html>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    env.env().eval("$('b').remove(); const c = document.createElement('canvas'); c.width = 2048; c.height = 1024;"
                   " document.body.append(c); 1");
    CHECK(!flushStops(env));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// Compat keeps the old caps: 10,001 commands draw, and the pixel cap does not stop.
WR_TEST(testCompatKeepsTheOldCanvasCaps) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    CHECK_EQ(drawInATask(env, 10001), std::string("10001"));
    env.env().eval("for (const s of [1024, 2048]) { const c = document.createElement('canvas'); c.width = s; c.height = s;"
                   " document.body.append(c); } 1");
    CHECK(!flushStops(env));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}
