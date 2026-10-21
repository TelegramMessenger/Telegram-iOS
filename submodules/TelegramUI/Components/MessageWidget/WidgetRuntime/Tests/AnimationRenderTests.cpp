// Animated values are rendered (V5e plan, Tasks 6 and 7): an animated element's sampled declarations reach litehtml as
// the animations origin (twidget VENDOR.md edit 27), getComputedStyle and the layout queries see them in the same task
// as a seek, a paused animation costs no relayout per frame, commitStyles writes them into the style attribute, and a
// frame that changes only paint-only properties keeps litehtml's render tree.
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "quickjs.h"
#include "Sources/Render/LayerMirror.h"
#include "Sources/Render/LayerTree.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><html><head><style>body { margin: 0 } .box { position: absolute; left: 10px; top: 20px; width: 20px;"
    " height: 20px } .faded { opacity: 0.4 }</style></head><body>"
    "<div id=a class=box></div><div id=s class=box></div><div id=o class=box></div>"
    "<div id=p2 style='width: 20px; height: 4px'></div><div id=x class='box faded' style='opacity: 0.3'></div>"
    "<div id=y class=box style='opacity: 0.3 !important'></div><div id=v style='width: var(--x); height: 4px'></div>"
    "<script>window.$ = id => document.getElementById(id);"
    " window.tx = id => { const m = /matrix\\(([^)]*)\\)/.exec(getComputedStyle($(id)).transform); return m ? +m[1].split(',')[4] : getComputedStyle($(id)).transform; };"
    " window.err = f => { try { f(); return 'ok' } catch (e) { return (e instanceof DOMException ? 'DOMException:' : '') + e.name } };"
    "</script></body></html>";

void checkEval(RenderEnv& env, std::string_view code, std::string_view want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("  %.*s\n    → %s\n    want %.*s\n", int(code.size()), code.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

// The three dumps of the flushed tree equal a fresh rebuild's.
void expectMatchesRebuild(RenderEnv& env, const std::string& what) {
    auto [layout, input, layer] = wr_test::rebuildDump(env);
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string dump = tree ? tree->dump() : std::string();
    if (env.render().layoutDump() != layout || env.render().renderInput() != input || dump != layer) {
        std::printf("  differs from a rebuild after: %s\n", what.c_str());
    }
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK_EQ(env.render().renderInput(), input);
    CHECK_EQ(dump, layer);
}

bool publishedReset(RenderEnv& env) {
    for (const wr::LayerOp& op : env.render().layerOps()) {
        if (op.kind == wr::LayerOp::Reset) {
            return true;
        }
    }
    return false;
}

} // namespace

WR_TEST(testTheConformanceFrames) {
    RenderEnv env(kPage);
    checkEval(env,
              "const a1 = $('a').animate([{transform: 'translateX(0)'}, {transform: 'translateX(40px)'}], {duration: 1000, fill: 'both'});"
              " a1.pause(); a1.currentTime = 500;"
              " const e = $('s').animate([{transform: 'translateX(0)'}, {transform: 'translateX(40px)'}],"
              "   {duration: 1000, easing: 'steps(2, end)', fill: 'both'}); e.pause(); e.currentTime = 600;"
              " const f = $('o').animate([{background: '#3a3'}, {background: '#c33', offset: 0.25}, {background: '#3a3'}],"
              "   {duration: 1000, fill: 'both'}); f.pause(); f.currentTime = 250;"
              " [tx('a'), tx('s'), getComputedStyle($('o')).backgroundColor].join()",
              "20,20,rgb(204, 51, 51)");
}

WR_TEST(testASeekIsVisibleInTheSameTask) {
    RenderEnv env(kPage);
    checkEval(env,
              "window.p2 = $('p2').animate([{width: '20px'}, {width: '120px'}], {duration: 1000, fill: 'forwards'});"
              " p2.pause(); p2.currentTime = 250; $('p2').getBoundingClientRect().width",
              "45");
    env.env().advance(1);
    checkEval(env, "$('p2').getBoundingClientRect().width", "45");
}

WR_TEST(testARunningAnimationMoves) {
    RenderEnv env(kPage);
    env.env().eval("window.r = $('a').animate({opacity: [1, 0]}, 1000); 1");
    env.env().frame(16);
    checkEval(env, "getComputedStyle($('a')).opacity", "1");
    env.env().frame(250);
    checkEval(env, "getComputedStyle($('a')).opacity", "0.75");
    env.env().frame(250);
    checkEval(env, "getComputedStyle($('a')).opacity", "0.5");
    env.env().frame(600);
    checkEval(env, "[r.playState, getComputedStyle($('a')).opacity].join()", "finished,1");
}

WR_TEST(testCascadeOrder) {
    RenderEnv env(kPage);
    checkEval(env,
              "const i = $('x').animate({opacity: [0.9, 0.9]}, 1000); i.pause(); i.currentTime = 1;"
              " const j = $('y').animate({opacity: [0.9, 0.9]}, 1000); j.pause(); j.currentTime = 1;"
              " [getComputedStyle($('x')).opacity, getComputedStyle($('y')).opacity].join()",
              "0.9,0.3");
    // One keyframe: the implicit one at 0 is the element's inline value (with the 0.9 animation gone; over it, the
    // underlying value would be its 0.9).
    checkEval(env,
              "$('x').getAnimations().forEach(a => a.cancel());"
              " const k = $('x').animate({opacity: 0}, 1000); k.pause(); k.currentTime = 500; getComputedStyle($('x')).opacity",
              "0.15");
}

WR_TEST(testNoRelayoutWhilePaused) {
    RenderEnv env(kPage);
    env.env().eval("const m = $('p2').animate([{width: '20px'}, {width: '120px'}], {duration: 1000, fill: 'forwards'});"
                   " m.pause(); m.currentTime = 500; window.widths = [];"
                   " const loop = () => { widths.push($('p2').getBoundingClientRect().width); requestAnimationFrame(loop); };"
                   " requestAnimationFrame(loop); 1");
    env.env().frame(16);
    env.env().frame(16);
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    for (int i = 0; i < 60; i++) {
        env.env().frame(16);
    }
    CHECK_EQ(env.render().patchCount(), patches);
    CHECK_EQ(env.render().buildCount(), builds);
    checkEval(env, "widths.slice(-1)[0] + ' ' + widths.length", "70 62");
}

WR_TEST(testCommitStyles) {
    RenderEnv env(kPage);
    checkEval(env,
              "const c = $('a').animate([{transform: 'translateX(0px)'}, {transform: 'translateX(40px)'}], {duration: 1000, fill: 'both'});"
              " c.pause(); c.currentTime = 500; c.commitStyles(); $('a').getAttribute('style')",
              "transform: translateX(20px);");
    checkEval(env,
              "const d = $('s').animate({opacity: [0, 1]}, {duration: 1000, fill: 'both'}); d.pause(); $('s').remove(); err(() => d.commitStyles())",
              "DOMException:InvalidStateError");
}

WR_TEST(testCustomPropertyRebuilds) {
    RenderEnv env(kPage);
    const uint64_t builds = env.render().buildCount();
    checkEval(env, "const v = $('v').animate({'--x': ['0px', '100px']}, 1000); v.pause(); v.currentTime = 500; $('v').getBoundingClientRect().width",
              "50");
    CHECK(env.render().buildCount() > builds);
}

WR_TEST(testValuesThatWouldEscapeTheirDeclaration) {
    RenderEnv env(kPage);
    checkEval(env,
              "const w = $('a').animate({opacity: ['0.5; width: 99px', '0.5; width: 99px'], width: ['30px', '30px']}, 1000);"
              " w.pause(); w.currentTime = 1; const b = $('a').getBoundingClientRect(); [b.width, getComputedStyle($('a')).opacity].join()",
              "30,1");
}

WR_TEST(testTheAnimationLimit) {
    RenderEnv env(kPage);
    env.env().eval("window.boxes = []; for (let i = 0; i < 1100; i++) { const d = document.createElement('div'); document.body.append(d);"
                   " boxes.push(d); d.animate({opacity: [0.5, 0.5]}, 100000); } 1");
    env.env().frame(16);
    env.env().frame(16);
    checkEval(env, "[getComputedStyle(boxes[0]).opacity, getComputedStyle(boxes[1023]).opacity, getComputedStyle(boxes[1024]).opacity].join()",
              "0.5,0.5,1");
    int limits = 0;
    for (const auto& [kind, detail] : env.env().host().diagnostics) {
        limits += kind == "animation-limit" && detail == "more than 1024 live script animations; further ones are not rendered";
    }
    CHECK_EQ(limits, 1);
}

WR_TEST(testOverrideSize) {
    RenderEnv env(kPage);
    checkEval(env,
              "const big = 'x'.repeat(4096); const k = {}; for (let i = 0; i < 64; i++) k['--p' + i] = [big, big];"
              " const z = $('a').animate(k, 1000); z.pause(); z.currentTime = 1; const cs = getComputedStyle($('a'));"
              " [cs.getPropertyValue('--p0').length, cs.getPropertyValue('--p63').length].join()",
              "4096,0");
}

/// A running transform animation's frames are patches that keep litehtml's render tree: on an in-flow block no Reset is
/// published at all, from the frame its declarations appear to the one they go, and what each publishes is a rebuild's.
/// On a positioned element the tree is kept too; the frames where it becomes and stops being a paint group publish the
/// mirror's own Reset (LayerMirror's placement rule places a new group only for an in-flow block: unplaceableResets).
WR_TEST(testAPaintOnlyFrameKeepsTheTree) {
    RenderEnv env(kPage);
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    const uint64_t resets = env.render().treeRebuildResets();
    const auto run = [&](const char* id, bool inFlow) {
        env.env().eval(std::string("window.t = $('") + id +
                       "').animate({transform: ['translateX(0px)', 'translateX(100px)'], opacity: [1, 0.5]}, 500); 1");
        // The first frame starts it at 0; the next five move it, the last of them to its end, where its values go.
        for (int i = 0; i < 7; i++) {
            env.env().frame(100);
            const std::string what = std::string(id) + ", frame " + std::to_string(i) + " (" +
                                     env.env().eval("[t.playState, t.currentTime].join()") + ")";
            if (env.render().treeRebuildResets() != resets || (inFlow && publishedReset(env))) {
                std::printf("  the render tree was rebuilt or a Reset published: %s\n", what.c_str());
            }
            CHECK_EQ(env.render().treeRebuildResets(), resets);
            CHECK(!inFlow || !publishedReset(env));
            CHECK_EQ(env.render().buildCount(), builds);
            expectMatchesRebuild(env, what);
        }
        checkEval(env, std::string("[t.playState, tx('") + id + "'), getComputedStyle($('" + id + "')).opacity].join()",
                  "finished,none,1");
    };
    run("p2", true);
    CHECK(env.render().patchCount() >= patches + 6);
    run("a", false);
}

/// A running width animation still lays out: the box follows it, as a rebuild's does.
WR_TEST(testALayoutFrameStillLaysOut) {
    RenderEnv env(kPage);
    env.env().eval("window.w = $('p2').animate({width: ['20px', '120px']}, 1000); 1");
    env.env().frame(16);
    for (int i = 0; i < 3; i++) {
        env.env().frame(250);
        const std::string at = env.env().eval("w.currentTime");
        checkEval(env, "$('p2').getBoundingClientRect().width", std::to_string(20 + std::stoi(at) / 10));
        expectMatchesRebuild(env, "width at " + at);
    }
}

/// One frame of a running transform animation on a 200-element page is cheap (Review Focus 3).
WR_TEST(testAFrameIsCheap) {
    std::string page = "<!doctype html><html><head><style>body { margin: 0 } .row { height: 10px; color: #333 }"
                       " #mover { width: 20px; height: 20px; background: #3a3 }</style></head><body><div id=mover></div>";
    for (int i = 0; i < 200; i++) {
        page += "<div class=row>row " + std::to_string(i) + "</div>";
    }
    page += "</body></html>";
    RenderEnv env(page);
    env.env().eval("document.getElementById('mover').animate({transform: ['translateX(0px)', 'translateX(100px)']}, 100000); 1");
    env.env().frame(16);
    env.env().frame(16);
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const uint64_t before = JS_GetWorkUnits(rt);
    env.env().frame(16);
    const uint64_t cost = JS_GetWorkUnits(rt) - before;
    if (cost >= 250000) {
        std::printf("  a frame cost %llu units\n", (unsigned long long)cost);
    }
    CHECK(cost < 250000);
}

/// A frame's changed rects are in the document's coordinates, wherever the animated element sits: the host redraws
/// what they cover and nothing else (the conformance page's ball sits in a positioned stage below a heading).
WR_TEST(testAFramesRectsCoverTheElement) {
    RenderEnv env("<!doctype html><style>html,body{margin:0} .stage{position:relative;overflow:hidden;width:150px;height:90px;"
                  "margin:100px 0 0 30px} .ball{position:absolute;left:55px;top:4px;width:40px;height:40px;background:#e83}"
                  " .flow{width:40px;height:40px;margin-left:20px;background:#36c}</style><body><div class=stage>"
                  "<div class=ball id=ball></div></div><div class=flow id=flow></div></body>");
    env.env().eval("window.a = document.getElementById('ball').animate({transform: ['translateY(0px)', 'translateY(42px)']}, 1000);"
                   " window.b = document.getElementById('flow').animate({transform: ['translateX(0px)', 'translateX(50px)']}, 1000); 1");
    env.env().frame(16);
    env.env().frame(16);
    env.render().takeChangedRects();
    for (int i = 0; i < 3; i++) {
        env.env().frame(100);
        const std::optional<std::vector<litehtml::position>> rects = env.render().takeChangedRects();
        // Each element's rect now: the box where layout put it, moved by its transform.
        const auto covered = [&](const char* what, double x, double y) {
            bool found = !rects;
            for (const litehtml::position& r : rects ? *rects : std::vector<litehtml::position>{}) {
                found = found || (double(r.x) <= x + 0.5 && double(r.y) <= y + 0.5 && double(r.x + r.width) >= x + 39.5 &&
                                  double(r.y + r.height) >= y + 39.5);
            }
            if (!found) {
                std::printf("  frame %d: no changed rect covers %s at %g,%g; rects:", i, what, x, y);
                for (const litehtml::position& r : *rects) {
                    std::printf(" (%g,%g %gx%g)", double(r.x), double(r.y), double(r.width), double(r.height));
                }
                std::printf("\n");
            }
            CHECK(found);
        };
        const double t = std::stod(env.env().eval("a.currentTime")) / 1000;
        covered("the positioned ball", 30 + 55, 100 + 4 + 42 * t);
        covered("the in-flow box", 20 + 50 * t, 190);
    }
}

/// Final review I2: a filling or paused animation's rendered values follow a change of its effect made other than
/// through `effect.target`: the effect cleared or replaced, its composite, its pseudo-element.
WR_TEST(testAnEffectChangeIsRendered) {
    RenderEnv env(kPage);
    const char* const opacities = "['a', 's', 'o', 'x'].map(id => getComputedStyle($(id)).opacity).join()";
    checkEval(env,
              "window.e1 = $('a').animate({opacity: [0.2, 0.2]}, {duration: 10, fill: 'forwards'}); e1.finish();"
              " window.e2 = $('s').animate({opacity: [0.3, 0.3]}, {duration: 10, fill: 'forwards'}); e2.finish();"
              " window.e3 = $('x').animate({opacity: [0.5, 0.5]}, {duration: 1000, fill: 'forwards'}); e3.pause(); e3.currentTime = 1;"
              " ['a', 's', 'o', 'x'].map(id => getComputedStyle($(id)).opacity).join()",
              "0.2,0.3,1,0.5");
    checkEval(env, std::string("e1.effect = null; ") + opacities, "1,0.3,1,0.5");
    checkEval(env,
              std::string("e2.effect = new KeyframeEffect($('o'), {opacity: [0.4, 0.4]}, {duration: 10, fill: 'forwards'}); ") + opacities,
              "1,1,0.4,0.5");
    // Added to the inline 0.3.
    checkEval(env, std::string("e3.effect.composite = 'add'; ") + opacities, "1,1,0.4,0.8");
    // A pseudo-element's animation renders nothing: the element is back at its inline value.
    checkEval(env, std::string("e3.effect.pseudoElement = '::before'; ") + opacities, "1,1,0.4,0.3");
}

/// Final review I3: commitStyles writes the animation's own properties, computed over the stack up to it: not the
/// properties only an animation below it animates, and a removed animation's own values too (Level 1 §4.4.20).
WR_TEST(testCommitStylesWritesItsOwnProperties) {
    RenderEnv env(kPage);
    checkEval(env,
              "const a = $('a').animate({opacity: [0.2, 0.2]}, {duration: 1, fill: 'forwards'}); a.finish();"
              " const b = $('a').animate({transform: ['translateX(10px)', 'translateX(10px)']}, {duration: 1, fill: 'forwards'}); b.finish();"
              " b.commitStyles(); $('a').getAttribute('style')",
              "transform: translateX(10px);");
    env.env().eval("window.c = $('s').animate({opacity: [0.3, 0.3]}, {duration: 1, fill: 'forwards'}); c.finish();"
                   " window.d = $('s').animate({opacity: [0.6, 0.6]}, {duration: 1, fill: 'forwards'}); d.finish(); 1");
    env.env().frame(16);
    checkEval(env, "c.replaceState + ' ' + (c.commitStyles(), $('s').getAttribute('style'))", "removed opacity: 0.3;");
}

/// Final review I9: sampling an effect is linear in its keyframes' values. 64 keyframes of 64 distinct properties each
/// (4,033 properties, one of them in every keyframe with a long value of words that are not colours) sample in a few
/// milliseconds (56 ms when every property lookup was a scan, at -O2). The best of three samples, each forced by a seek,
/// so a loaded host does not fail it.
WR_TEST(testSamplingIsLinear) {
    RenderEnv env(kPage);
    env.env().eval("const words = 'abc '.repeat(1000); const frames = [];"
                   " for (let k = 0; k < 64; k++) { const f = {'--w': words + k}; for (let v = 0; v < 63; v++) f['--p' + k + '_' + v] = 'x'; frames.push(f); }"
                   " window.big = $('a').animate(frames, 100000); big.pause(); big.currentTime = 50000; 1");
    env.flush();
    double best = 1e9;
    for (int i = 1; i <= 3; i++) {
        env.env().eval("big.currentTime = " + std::to_string(50000 + i) + "; 1");
        const auto start = std::chrono::steady_clock::now();
        env.flush();
        best = std::min(best, std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count());
    }
    if (best >= 20) {
        std::printf("  sampling took %.1f ms at best\n", best);
    }
    CHECK(best < 20);
    checkEval(env, "getComputedStyle($('a')).getPropertyValue('--w').length > 3000", "true");
}

/// Final review M8 (regraded): a paused animation whose value starts from the inline style (one keyframe, so the other
/// end is the underlying value) follows a change of that style.
WR_TEST(testAnInlineStyleChangeIsSampledAgain) {
    RenderEnv env(kPage);
    checkEval(env,
              "window.k = $('x').animate({opacity: 0}, 1000); k.pause(); k.currentTime = 500; getComputedStyle($('x')).opacity",
              "0.15");
    checkEval(env, "$('x').style.opacity = '0.8'; getComputedStyle($('x')).opacity", "0.4");
}
