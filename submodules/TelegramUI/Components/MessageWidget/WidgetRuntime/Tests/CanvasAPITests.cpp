// The Canvas 2D surface (V5d plan, Task 3; HTML "The canvas element" and the 2D context): HTMLCanvasElement,
// CanvasRenderingContext2D, its objects and DOMMatrix, over a FakeRenderHost whose canvases log their ops (8 px per
// byte, ascent 12, descent 4). Profile 1's out features are API-visible and draw nothing.
#include <cstdio>
#include <string>

#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeCanvas;
using wr_test::FakeRenderHost;
using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><html><head></head><body>"
    "<canvas id=probe width=40 height=20></canvas><canvas id=stage width=160 height=120></canvas>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } };</script></body></html>";

/// The log of the newest fake canvas, joined by " | ".
std::string lastLog() {
    if (FakeCanvas::live().empty()) {
        return "(no canvas)";
    }
    std::string out;
    for (const std::string& line : FakeCanvas::live().back()->log) {
        out += (out.empty() ? "" : " | ") + line;
    }
    return out;
}

} // namespace

/// auto/12-canvas-a's step, value by value.
WR_TEST(testTheConformanceValues) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("stage.width"), std::string("160"));
    CHECK_EQ(env.env().eval("var pc = probe.getContext('2d'); pc.font = '16px sans-serif'; var m = pc.measureText('Hello');"
                            "[m.width, m.actualBoundingBoxAscent, m.actualBoundingBoxDescent].join()"),
             std::string("40,12,4"));
    CHECK_EQ(env.env().eval("pc.beginPath(); pc.rect(5, 5, 10, 10); [pc.isPointInPath(10, 10), pc.isPointInPath(30, 10)].join()"),
             std::string("true,false"));
    CHECK_EQ(env.env().eval("pc.lineWidth = 4; pc.isPointInStroke(5, 10)"), std::string("true"));
    CHECK_EQ(env.env().eval("pc.fillStyle = 'rgb(200,10,20)'; pc.fillRect(0, 0, 4, 4); Array.from(pc.getImageData(1, 1, 1, 1).data).join()"),
             std::string("0,0,0,0"));
    CHECK_EQ(env.env().eval("probe.toDataURL()"), std::string("data:,"));
    CHECK_EQ(env.env().eval("[document.createElement('canvas').getContext('webgl'), typeof OffscreenCanvas,"
                            " err(() => new OffscreenCanvas(1, 1)), err(() => probe.transferControlToOffscreen())].join()"),
             std::string(",undefined,ReferenceError,NotSupportedError"));
    // The same context every time; the canvas back-reference.
    CHECK_EQ(env.env().eval("[probe.getContext('2d') === pc, pc.canvas === probe, pc instanceof CanvasRenderingContext2D,"
                            " probe instanceof HTMLCanvasElement, probe.getContext('2D')].join()"),
             std::string("true,true,true,true,"));
}

WR_TEST(testDrawingReachesTheBitmap) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); c.fillStyle = '#cc3333'; c.scale(2, 2); c.fillRect(8, 8, 40, 30); 1");
    CHECK_EQ(lastLog(), std::string("fill 16,16 80x60 #cc3333ff"));
    env.env().eval("c.globalAlpha = 0.5; c.fillRect(0, 0, 1, 1); c.clearRect(14, 14, 10, 10); 1");
    CHECK_EQ(lastLog(), std::string("fill 16,16 80x60 #cc3333ff | fill 0,0 2x2 #cc3333ff alpha=0.5 | clear 28,28 20x20 alpha=0.5"));
    CHECK_EQ(FakeCanvas::live().back()->width, 160);
    // Nothing is allocated before the first draw.
    env.env().eval("var lazy = document.createElement('canvas').getContext('2d'); 1");
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(1));
    env.env().eval("lazy.fillRect(0, 0, 1, 1); 1");
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(2));
    CHECK_EQ(FakeCanvas::live().back()->width, 300);
    CHECK_EQ(FakeCanvas::live().back()->height, 150);
}

WR_TEST(testPathsTextAndStyles) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); c.strokeStyle = 'blue'; c.lineWidth = 3; c.beginPath(); c.moveTo(40, 50);"
                   " c.bezierCurveTo(50, 10, 70, 10, 76, 50); c.stroke();"
                   " c.font = 'bold 22px sans-serif'; c.textBaseline = 'top'; c.fillText('Ag', 6, 6);"
                   " var g = c.createLinearGradient(0, 0, 80, 0); g.addColorStop(0, 'red'); g.addColorStop(1, 'blue');"
                   " c.fillStyle = g; c.fillRect(0, 0, 80, 28); 1");
    CHECK_EQ(lastLog(), std::string("stroke 40,10 36x40 #0000ffff w=3 | text \"Ag\" 6,18 | fill 0,0 80x28 linear"));
    CHECK_EQ(env.env().eval("[c.font, c.textBaseline, c.fillStyle === g, c.strokeStyle].join()"),
             std::string("bold 22px sans-serif,top,true,#0000ff"));
}

WR_TEST(testWhatIsOutDrawsNothing) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); var other = document.createElement('canvas');"
                   " var conic = c.createConicGradient(0, 40, 30); conic.addColorStop(0, 'red'); c.fillStyle = conic; c.fillRect(0, 0, 10, 10);"
                   " c.fillStyle = c.createPattern(other, 'repeat'); c.fillRect(0, 0, 10, 10); 1");
    CHECK_EQ(lastLog(), std::string("fill 0,0 10x10 #00000000 | fill 0,0 10x10 #00000000"));
    CHECK_EQ(env.env().eval("c.globalCompositeOperation = 'multiply'; c.shadowBlur = 6; c.shadowColor = 'rgba(0,0,0,0.6)';"
                            " c.filter = 'blur(2px)'; c.globalCompositeOperation = 'bogus';"
                            " [c.globalCompositeOperation, c.shadowBlur, c.shadowColor, c.filter].join('|')"),
             std::string("multiply|6|rgba(0, 0, 0, 0.6)|blur(2px)"));
    env.env().eval("c.fillStyle = 'red'; c.fillRect(0, 0, 1, 1); c.putImageData(c.createImageData(4, 4), 0, 0); 1");
    CHECK_EQ(FakeCanvas::live().back()->log.back(), std::string("fill 0,0 1x1 #ff0000ff"));
    CHECK_EQ(env.env().eval("var pat = c.createPattern(other, 'repeat'); [pat instanceof CanvasPattern, typeof pat.setTransform,"
                            " err(() => c.createPattern(other, 'diagonal'))].join()"),
             std::string("true,function,SyntaxError"));
}

WR_TEST(testDefaultsAndReset) {
    RenderEnv env(kPage);
    const char* const kDefaults =
        "[c.fillStyle, c.strokeStyle, c.font, c.lineWidth, c.lineCap, c.lineJoin, c.miterLimit, c.lineDashOffset, c.textAlign,"
        " c.textBaseline, c.direction, c.globalAlpha, c.globalCompositeOperation, c.imageSmoothingEnabled, c.imageSmoothingQuality,"
        " c.shadowColor, c.shadowBlur, c.shadowOffsetX, c.filter, c.letterSpacing, c.fontKerning, c.getLineDash().length].join('|')";
    const std::string expected = "#000000|#000000|10px sans-serif|1|butt|miter|10|0|start|alphabetic|inherit|1|source-over|true|"
                                 "low|rgba(0, 0, 0, 0)|0|0|none|0px|auto|0";
    env.env().eval("var c = stage.getContext('2d'); 1");
    CHECK_EQ(env.env().eval(kDefaults), expected);
    env.env().eval("c.fillStyle = 'red'; c.lineWidth = 5; c.lineCap = 'round'; c.font = '20px serif'; c.setLineDash([1, 2]);"
                   " c.globalAlpha = 0.3; c.fillRect(0, 0, 1, 1); c.translate(5, 5); c.reset(); 1");
    CHECK_EQ(env.env().eval(kDefaults), expected);
    CHECK_EQ(lastLog(), std::string("fill 0,0 1x1 #ff0000ff alpha=0.3 | reset"));
    env.env().eval("c.fillStyle = 'red'; stage.width = stage.width; 1");
    CHECK_EQ(env.env().eval("[c.fillStyle, c.getTransform().e].join()"), std::string("#000000,0"));
    // save and restore cover the attributes the IDL reads back.
    CHECK_EQ(env.env().eval("c.fillStyle = 'red'; c.shadowBlur = 3; c.save(); c.fillStyle = 'blue'; c.shadowBlur = 9; c.restore();"
                            " [c.fillStyle, c.shadowBlur].join()"),
             std::string("#ff0000,3"));
}

/// Review Focus 4: values HTML ignores, and the TypeErrors the IDL gives.
WR_TEST(testIgnoredValues) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); 1");
    CHECK_EQ(env.env().eval("c.lineWidth = -1; c.lineWidth = NaN; c.globalAlpha = 2; c.globalAlpha = -0.1; c.fillStyle = {};"
                            " c.fillStyle = 'notacolor'; c.lineCap = 'bogus'; c.miterLimit = 0; c.shadowBlur = -1;"
                            " [c.lineWidth, c.globalAlpha, c.fillStyle, c.lineCap, c.miterLimit, c.shadowBlur].join()"),
             std::string("1,1,#000000,butt,10,0"));
    CHECK_EQ(env.env().eval("c.fillRect(NaN, 0, 1, 1); c.moveTo(Infinity, 0); c.arc(0, 0, NaN, 0, 1); c.translate(NaN, 1);"
                            " c.font = 'nonsense'; c.font"),
             std::string("10px sans-serif"));
    CHECK_EQ(lastLog(), std::string("(no canvas)"));
    CHECK_EQ(env.env().eval("[err(() => c.drawImage({}, 0, 0)), err(() => c.fill({})), err(() => c.drawImage(stage, 0)),"
                            " err(() => c.drawImage(stage, 0, 0, 1)), err(() => c.arc(0, 0, -1, 0, 1)),"
                            " err(() => c.createRadialGradient(0, 0, -1, 0, 0, 1)), err(() => c.createLinearGradient(0, 0, NaN, 0)),"
                            " err(() => c.createLinearGradient(0, 0, 1, 0).addColorStop(2, 'red')),"
                            " err(() => c.createLinearGradient(0, 0, 1, 0).addColorStop(0, 'nope')),"
                            " err(() => c.roundRect(0, 0, 10, 10, [1, 2, 3, 4, 5])), err(() => c.roundRect(0, 0, 10, 10, -1)),"
                            " err(() => c.setTransform(1, 2)), err(() => c.getImageData(0, 0, 0, 1))].join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,IndexSizeError,IndexSizeError,TypeError,IndexSizeError,"
                         "SyntaxError,RangeError,RangeError,TypeError,IndexSizeError"));
}

WR_TEST(testFillStyleSerializes) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); var out = [];"
                            " for (const v of ['red', 'rgba(51,170,51,0.8)', '#ABC', 'rgba(0,0,0,0.5)', 'transparent', 'currentcolor'])"
                            " { c.fillStyle = v; out.push(c.fillStyle); } out.join('|')"),
             std::string("#ff0000|rgba(51, 170, 51, 0.8)|#aabbcc|rgba(0, 0, 0, 0.5)|rgba(0, 0, 0, 0)|#000000"));
}

WR_TEST(testPath2D) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); var p = new Path2D('M10 50 L40 8 L70 50 Z'); c.fillStyle = 'blue'; c.fill(p);"
                   " var q = new Path2D(); q.arc(40, 36, 8, 0, Math.PI * 2); c.fill(q, 'evenodd'); c.stroke(p);"
                   " var copy = new Path2D(p); copy.addPath(q, {e: 100}); c.fill(copy); 1");
    CHECK_EQ(lastLog(), std::string("fill 10,8 60x42 #0000ffff | fill 32,28 16x16 #0000ffff | stroke 10,8 60x42 #000000ff w=1 |"
                                    " fill 10,8 138x42 #0000ffff"));
    CHECK_EQ(env.env().eval("[c.isPointInPath(p, 40, 30), c.isPointInPath(p, 5, 5), c.isPointInStroke(p, 10, 50),"
                            " new Path2D() instanceof Path2D, err(() => Path2D())].join()"),
             std::string("true,false,true,true,TypeError"));
}

WR_TEST(testDrawImageFromACanvas) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); var t = document.createElement('canvas'); t.width = 20; t.height = 20;"
                   " var tc = t.getContext('2d'); tc.fillStyle = 'red'; tc.fillRect(0, 0, 20, 20); c.drawImage(t, 44, 26, 30, 30);"
                   " c.drawImage(t, 0, 0, 10, 10, 0, 0, 5, 5); c.drawImage(stage, 1, 1); 1");
    CHECK_EQ(lastLog(), std::string("image 20x20 -> 44,26 30x30 | image 20x20 -> 0,0 5x5 from 0,0 10x10 | image 160x120 -> 1,1 160x120"));
    CHECK_EQ(env.env().eval("var z = document.createElement('canvas'); z.width = 0; err(() => c.drawImage(z, 0, 0))"),
             std::string("InvalidStateError"));
    // A canvas that never drew is transparent: nothing to draw.
    env.env().eval("c.drawImage(document.createElement('canvas'), 0, 0); 1");
    CHECK_EQ(FakeCanvas::live().back()->log.size(), size_t(3));
}

/// Review Focus 1: the side and total allowances.
WR_TEST(testTheAllowance) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var big = document.createElement('canvas'); big.width = 1e9; big.getContext('2d').fillRect(0, 0, 1, 1);"
                            " var wide = document.createElement('canvas'); wide.width = 16385; wide.getContext('2d').fillRect(0, 0, 1, 1);"
                            " var huge = document.createElement('canvas'); huge.width = 4294967295; [big.width, wide.width, huge.width].join()"),
             std::string("1000000000,16385,300"));
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(0));
    // Four 1024 × 1024 canvases are the whole allowance (4,194,304 pixels): the fifth gets no bitmap.
    env.env().eval("var cs = []; for (let i = 0; i < 5; i++) { const k = document.createElement('canvas'); k.width = 1024; k.height = 1024;"
                   " k.getContext('2d').fillRect(0, 0, 1, 1); cs.push(k); } 1");
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(4));
    // A resize frees a bitmap; the fifth canvas draws on its next call.
    env.env().eval("cs[0].width = 0; cs[4].getContext('2d').fillRect(0, 0, 2, 2); 1");
    CHECK_EQ(FakeRenderHost::liveCanvases(), size_t(4));
    CHECK_EQ(lastLog(), std::string("fill 0,0 2x2 #000000ff"));
    bool limited = false;
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        limited = limited || (kind == "render-limit" && detail.find("canvas-pixels") != std::string::npos);
    }
    CHECK(limited);
}

WR_TEST(testDOMMatrix) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); c.scale(2, 3); var m = c.getTransform();"
                            " [m.a, m.d, m.m11, m.m22, m.is2D, m.isIdentity, m instanceof DOMMatrix, m !== c.getTransform()].join()"),
             std::string("2,3,2,3,true,false,true,true"));
    CHECK_EQ(env.env().eval("c.setTransform({a: 1, d: 1, e: 5}); c.getTransform().e"), std::string("5"));
    CHECK_EQ(env.env().eval("c.setTransform(); c.getTransform().isIdentity"), std::string("true"));
    CHECK_EQ(env.env().eval("var d = new DOMMatrix([1, 0, 0, 1, 7, 8]); [d.f, d.m42, new DOMMatrix().isIdentity,"
                            " err(() => new DOMMatrix([1, 2, 3]))].join()"),
             std::string("8,8,true,TypeError"));
    CHECK_EQ(env.env().eval("c.setTransform(new DOMMatrix([2, 0, 0, 2, 1, 1])); c.getTransform().a"), std::string("2"));
}

/// Review Focus 2: unbounded state growth.
WR_TEST(testUnboundedGrowth) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); for (let i = 0; i < 100000; i++) c.save(); c.translate(5, 0);"
                            " for (let i = 0; i < 100000; i++) c.restore(); c.getTransform().e"),
             std::string("0"));
    CHECK_EQ(env.env().eval("c.setLineDash([3, 1]); c.setLineDash(new Array(1000000).fill(1)); c.getLineDash().join()"),
             std::string("3,1"));
    CHECK_EQ(env.env().eval("c.setLineDash([1, 2, 3]); c.getLineDash().join()"), std::string("1,2,3,1,2,3"));
}

WR_TEST(testTheOtherMembers) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); var a = c.getContextAttributes();"
                            " [a.alpha, a.colorSpace, a.desynchronized, a.willReadFrequently, c.isContextLost()].join()"),
             std::string("true,srgb,false,false,false"));
    CHECK_EQ(env.env().eval("var d = c.createImageData(3, 2); [d.width, d.height, d.data.length, d.colorSpace, d instanceof ImageData,"
                            " c.createImageData(d).width, new ImageData(2, 2).data.length, c.getImageData(0, 0, -3, 2).width].join()"),
             std::string("3,2,24,srgb,true,3,16,3"));
    CHECK_EQ(env.env().eval("err(() => c.createImageData(4000, 4000))"), std::string("RangeError"));
    env.env().eval("var called = 'no'; stage.toBlob(b => { called = String(b) }); 1");
    CHECK_EQ(env.env().eval("called"), std::string("no"));
    env.env().drain();
    CHECK_EQ(env.env().eval("called"), std::string("null"));
    CHECK_EQ(env.env().eval("[c.fillRect.length, c.drawImage.length, c.isPointInPath.length, c.setTransform.length,"
                            " c.arc.length, c.roundRect.length, c.putImageData.length].join()"),
             std::string("4,3,2,0,5,4,3"));
}

/// V5d final review, C1: canvas text is measured without the layout's cached measure (the iOS host keeps every text it
/// measures in a process-wide cache), and measureText reads at most 65,536 bytes.
WR_TEST(testCanvasTextIsMeasuredUncachedAndCapped) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); c.measureText('x'.repeat(100000)).width"), std::string("524288"));
    const size_t before = env.host().textWidthCalls;
    env.env().eval("c.measureText('abc'); c.fillText('abc', 1, 10); c.strokeText('abc', 1, 10); 1");
    CHECK_EQ(env.host().textWidthCalls, before);
    CHECK_EQ(env.env().eval("c.measureText('abc').width"), std::string("24"));
}

/// V5d final review, I2: Path2D data is read only up to the reference's 64 K; a longer string makes an empty path.
WR_TEST(testPathDataIsCapped) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("var c = stage.getContext('2d'); var q = new Path2D('M0 0 L100 0 L100 100 L0 100 Z' + ' '.repeat(70000));"
                            " [c.isPointInPath(q, 50, 50), c.isPointInPath(new Path2D('M0 0 L100 0 L100 100 L0 100 Z'), 50, 50)].join()"),
             std::string("false,true"));
}

/// V5d fix-wave review, C-B: a dash pattern multiplies a stroke into its dashes, which CoreGraphics builds as one outline
/// each: a stroke of more than kMaxDashSegments is drawn solid with a render-limit.
WR_TEST(testDashesAreCapped) {
    RenderEnv env(kPage);
    env.env().eval("var c = stage.getContext('2d'); c.setLineDash([1e-6, 1e-6]); c.beginPath(); c.moveTo(0, 60); c.lineTo(160, 60); c.stroke(); 1");
    CHECK(!FakeCanvas::live().empty() && FakeCanvas::live().back()->log.back() == "stroke 0,60 160x0 #000000ff w=1");
    bool limited = false;
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        limited = limited || (kind == "render-limit" && detail == "canvas-dashes");
    }
    CHECK(limited);
    // 160 px of dashes 0.01 px long and 0.01 px apart: 16,000 dashes and gaps, under the cap.
    env.env().eval("c.setLineDash([0.01, 0.01]); c.stroke(); 1");
    CHECK(FakeCanvas::live().back()->log.back() == "stroke 0,60 160x0 #000000ff w=1 dash=2");
    // A pattern of zeros strokes solid.
    env.env().eval("c.setLineDash([0, 0]); c.stroke(); 1");
    CHECK(FakeCanvas::live().back()->log.back() == "stroke 0,60 160x0 #000000ff w=1");
}

/// V5d fix-wave 2 review, C-1: the dashes are counted in the space the backend dashes in (the device path through the
/// inverse of the op's float matrix) and per subpath, as the pattern restarts at each; a length that is not finite
/// drops the dash. Each input makes far more than kMaxDashSegments, so each strokes solid with canvas-dashes.
WR_TEST(testTheDashCountCannotBeWalkedAround) {
    const char* const inputs[] = {
        // An anisotropic transform: a device length of 1 is 1e6 in user space.
        "c.scale(1, 1e-6); c.setLineDash([0.02, 0.02]); c.beginPath(); c.moveTo(0, 0); c.lineTo(0, 1e6); c.stroke();",
        // Singular in double, invertible once rounded to float.
        "c.beginPath(); c.moveTo(0, 75); c.lineTo(150, 75); c.setTransform(1 + 2**-25, 1 + 2**-24 + 2**-50, 1, 1 + 2**-25, 0, 0);"
        " c.setLineDash([1, 1]); c.stroke();",
        // 288,000 short subpaths, each reaching all 64 entries before the long gap (data under the strict text cap).
        "const p = new Path2D('M0 0h7 '.repeat(4500)); for (let i = 0; i < 6; i++) p.addPath(p);"
        " c.setLineDash(Array(63).fill(0.1).concat([1e9])); c.stroke(p);",
        // A point past float's range: the length is not a number.
        "c.beginPath(); c.moveTo(1e39, 0); c.lineTo(1e39, 1); c.moveTo(0, 60); c.lineTo(100, 60); c.setLineDash([1, 1]); c.stroke();",
    };
    for (const char* input : inputs) {
        RenderEnv env(kPage);
        CHECK_EQ(env.env().eval(std::string("var c = stage.getContext('2d'); ") + input + " 1"), std::string("1"));
        const std::string last = FakeCanvas::live().empty() ? "" : FakeCanvas::live().back()->log.back();
        bool limited = false;
        for (const auto& [kind, detail] : env.env().host().diagnostics) {
            limited = limited || (kind == "render-limit" && detail == "canvas-dashes");
        }
        CHECK(last.rfind("stroke ", 0) == 0 && last.find(" dash=") == std::string::npos);
        CHECK(limited);
        if (!limited) {
            std::printf("  dashed: %s -> %s\n", input, last.c_str());
        }
    }
}

