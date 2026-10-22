// CSS animations and transitions from style (V5f plan, Tasks 4, 5 and 7): replicas of the conformance set's own numbers
// (auto/10-css-animations, auto/11-web-animations' css-control) on the host render tree, and the objects' identity,
// script control, cancellation and composite order; and what they cost in the steady state and at a mass start.
#include <cstdio>
#include <memory>
#include <string>

#include "Sources/Animation/AnimationState.h"
#include "Sources/Support/Work.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kHead =
    "<!doctype html><html><head><style>"
    "@keyframes slide{from{transform:translateX(0)}to{transform:translateX(40px)}}"
    "@keyframes grow{from{width:10px}to{width:70px}}"
    "@keyframes tint{from{background:#c33}to{background:#36c}}"
    "@keyframes short{from{opacity:1}to{opacity:.5}}"
    "body{margin:0} .box{position:absolute;left:10px;width:20px;height:20px;background:#c33}"
    "</style></head><body>";

const char* const kHelpers =
    "<script>window.$ = id => document.getElementById(id);"
    " window.tx = id => { const m = /matrix\\(([^)]*)\\)/.exec(getComputedStyle($(id)).transform); return m ? +m[1].split(',')[4] : getComputedStyle($(id)).transform; };"
    " window.w = id => $(id).getBoundingClientRect().width;</script>";

std::string page(const std::string& body, const std::string& style = "") {
    return std::string(kHead) + (style.empty() ? "" : "<style>" + style + "</style>") + body + kHelpers + "</body></html>";
}

void checkEval(RenderEnv& env, std::string_view code, std::string_view want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("  %.*s\n    → %s\n    want %.*s\n", int(code.size()), code.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

} // namespace

/// Fidelity plan, Task 7: an animation of the translate property moves the box (the animated layer keeps no raw
/// declarations, so the property must be litehtml's own).
WR_TEST(testAnAnimatedTranslateMovesTheBox) {
    RenderEnv env(page("<div id=t class=box style='animation:nudge 10s linear -5s paused'></div>",
                       "@keyframes nudge{from{translate:0 0}to{translate:40px 0}}"));
    checkEval(env, "Math.round($('t').getBoundingClientRect().x)", "30");
}

/// auto/10 `#p-kf`: a paused animation at -2.5s of 10s is at 25%, and stays there.
WR_TEST(testAPausedAnimationWithANegativeDelay) {
    RenderEnv env(page("<div id=p class=box style='animation:slide 10s linear -2.5s paused'></div>"));
    checkEval(env, "tx('p')", "10");
    env.env().frame(16);
    env.env().frame(500);
    checkEval(env, "tx('p')", "10");
}

/// auto/10 `.s-alt`: -13s of 10s, 2 iterations, alternate: the second iteration at 30%, reversed (left 38 in the ref).
WR_TEST(testAlternate) {
    RenderEnv env(page("<div id=a class=box style='animation:slide 10s linear -13s 2 alternate paused'></div>"));
    checkEval(env, "tx('a')", "28");
}

/// auto/10 `#p-steps` and `#p-ease`: steps(4, end) at 37.5% is the first step; ease-in at 50% lags behind linear.
WR_TEST(testStepsAndEaseIn) {
    RenderEnv env(page("<div id=s style='animation:grow 8s steps(4,end) -3s paused;height:4px'></div>"
                       "<div id=e style='animation:grow 10s ease-in -5s paused;height:4px'></div>"));
    checkEval(env, "w('s')", "25");
    checkEval(env, "const x = w('e'); x > 10 && x < 36", "true");
}

/// auto/10 `.s-tint`: a colour animation at 50% is midway between #c33 and #36c.
WR_TEST(testColour) {
    RenderEnv env(page("<div id=c class=box style='animation:tint 10s linear -5s paused'></div>"));
    checkEval(env, "const [r, g, b] = getComputedStyle($('c')).backgroundColor.match(/\\d+/g).map(Number);"
                   " Math.abs(r - 128) <= 1 && Math.abs(g - 77) <= 1 && Math.abs(b - 128) <= 1",
              "true");
}

/// auto/10 `.s-fill`: a 0.1s animation with forwards fill keeps its end value (left 50 in the ref).
WR_TEST(testFillForwards) {
    RenderEnv env(page("<div id=f class=box style='animation:slide .1s linear forwards'></div>"));
    env.env().frame(16);
    env.env().frame(200);
    env.env().frame(16);
    checkEval(env, "tx('f')", "40");
}

/// auto/11 css-control: a CSS animation is in getAnimations(), and script pauses and seeks it; a later restyle of the
/// element leaves it where script put it.
WR_TEST(testScriptControl) {
    RenderEnv env(page("<div id=c class=box style='background:#36c;animation:slide 10s linear infinite'></div>"));
    checkEval(env, "const list = $('c').getAnimations(); [list.length, list[0] instanceof CSSAnimation, list[0].animationName].join()",
              "1,true,slide");
    checkEval(env, "window.css = $('c').getAnimations()[0]; css.pause(); css.currentTime = 2500; [css.playState, tx('c')].join()",
              "paused,10");
    env.env().frame(16);
    env.env().frame(300);
    checkEval(env, "$('c').className = 'box other'; [css.playState, tx('c'), $('c').getAnimations()[0] === css].join()", "paused,10,true");
}

/// CSS Animations 2: an animation keeps its object while its name stays listed; a changed spec updates it; a name no
/// longer listed cancels it.
WR_TEST(testIdentity) {
    RenderEnv env(page("<div id=i class=box style='animation:slide 1s, grow 1s'></div>"));
    checkEval(env, "const l0 = $('i').getAnimations(); window.a = l0[0]; window.b = l0[1]; [a.animationName, b.animationName].join()", "slide,grow");
    checkEval(env, "$('i').style.animation = 'grow 1s, slide 1s'; const l = $('i').getAnimations(); [l.includes(a), l.includes(b), l.length].join()",
              "true,true,2");
    checkEval(env, "$('i').style.animation = 'slide 2s'; const m = $('i').getAnimations(); [m.length, m[0] === a, a.effect.getTiming().duration, b.playState].join()",
              "1,true,2000,idle");
}

/// An element leaving the document cancels its CSS animations; a name with no @keyframes makes none.
WR_TEST(testRemovalAndUnknownNames) {
    RenderEnv env(page("<div id=r class=box style='animation:slide 1s infinite'></div><div id=u class=box style='animation:nosuch 1s'></div>"));
    checkEval(env, "window.r = $('r').getAnimations()[0]; [r.playState, $('u').getAnimations().length].join()", "running,0");
    checkEval(env, "$('r').remove(); document.getAnimations().includes(r) + ' ' + r.playState", "false idle");
}

/// Composite order: CSS animations before script animations, whatever their creation order.
WR_TEST(testCompositeOrder) {
    RenderEnv env(page("<div id=o class=box></div>"));
    checkEval(env,
              "window.s = $('o').animate({opacity: [0, 1]}, 1000); $('o').style.animation = 'slide 1s';"
              " const l = document.getAnimations(); [l.length, l[0] instanceof CSSAnimation, l[1] === s].join()",
              "2,true,true");
}

// MARK: transitions (Task 5)

/// auto/10 `#p-tr`: a transition with a negative delay starts part-way (35 ±1).
WR_TEST(testANegativeDelayStartsPartWay) {
    RenderEnv env(page("<div id=p class=t style='height:4px'></div>",
                       ".t{transition:width 10000s linear -2500s;width:10px} .t.go{width:110px}"));
    env.env().frame(16);
    checkEval(env, "$('p').classList.add('go'); const x = w('p'); Math.abs(x - 35) <= 1", "true");
    checkEval(env, "const l = $('p').getAnimations(); [l.length, l[0] instanceof CSSTransition, l[0].transitionProperty].join()",
              "1,true,width");
}

/// auto/10 `.s-tr`: a transform transition halfway through its negative delay (left 40 in the ref).
WR_TEST(testTransformTransition) {
    RenderEnv env(page("<div id=s class='box tr'></div>",
                       ".tr{background:#a3a;transition:transform 10000s linear -5000s} .tr.go{transform:translateX(60px)}"));
    env.env().frame(16);
    checkEval(env, "$('s').classList.add('go'); tx('s')", "30");
}

/// An element's first style starts no transition: there is no before-change style.
WR_TEST(testNoTransitionOnTheFirstStyle) {
    RenderEnv env(page("", ".t{transition:width 1s linear;width:10px;height:4px} .t.go{width:110px}"));
    checkEval(env, "const d = document.createElement('div'); d.id = 'n'; d.className = 't go'; document.body.append(d);"
                   " [w('n'), d.getAnimations().length].join()",
              "110,0");
}

/// A change made while a transition runs starts the next one from where the running one is.
WR_TEST(testInterrupt) {
    RenderEnv env(page("<div id=i class=t style='height:4px'></div>", ".t{transition:width 1000ms linear;width:10px} .t.go{width:110px}"));
    env.env().frame(16);
    env.env().eval("$('i').classList.add('go'); window.first = $('i').getAnimations()[0]; 1");
    env.env().frame(16);
    env.env().frame(500);
    checkEval(env, "const x = w('i'); Math.abs(x - 60) <= 1", "true");
    checkEval(env, "$('i').classList.remove('go'); const l = $('i').getAnimations(); const x2 = w('i');"
                   " [l.length, l[0] !== first, first.playState, Math.abs(x2 - 60) <= 1].join()",
              "1,true,idle,true");
}

/// `all` covers every watched property; a property no longer covered cancels its running transition.
WR_TEST(testAllAndUncovering) {
    RenderEnv env(page("<div id=a class=box style='transition:all 1s linear'></div>"));
    env.env().frame(16);
    checkEval(env, "$('a').style.opacity = '0'; const l = $('a').getAnimations(); [l.length, l[0].transitionProperty].join()", "1,opacity");
    checkEval(env, "window.t = $('a').getAnimations()[0]; $('a').style.transition = 'none'; const n = $('a').getAnimations().length; [t.playState, n].join()",
              "idle,0");
}

/// Only the properties litehtml keeps declarations of are watched (Ruling): padding does not transition.
WR_TEST(testOnlyWatchedProperties) {
    RenderEnv env(page("<div id=p class=box style='transition:padding-left 1s linear'></div>"));
    env.env().frame(16);
    checkEval(env, "$('p').style.paddingLeft = '20px'; $('p').getAnimations().length", "0");
}

/// A transition declared in the same task as the change it covers still runs: the before-change value is the one the
/// element had before the task's changes.
WR_TEST(testTransitionDeclaredWithTheChange) {
    RenderEnv env(page("<div id=d class=box></div>"));
    env.env().frame(16);
    checkEval(env, "const d = $('d'); d.style.transition = 'opacity 1s linear'; d.style.opacity = '0';"
                   " const l = d.getAnimations(); [l.length, l.length && l[0].transitionProperty, getComputedStyle(d).opacity].join()",
              "1,opacity,1");
}

// MARK: Task 7: cost and the steady state

namespace {

/// A page of `rows` rows below one element `#mover` styled by `moverStyle`.
std::string rowsPage(int rows, const std::string& moverStyle, const std::string& style = "") {
    std::string body = "<div id=mover style='" + moverStyle + "'></div>";
    for (int i = 0; i < rows; i++) {
        body += "<div class=row>row " + std::to_string(i) + "</div>";
    }
    return page(body, ".row{height:10px;color:#333}" + style);
}

} // namespace

/// A paused CSS animation changes nothing frame after frame: no patch, no build.
WR_TEST(testAPausedCSSAnimationCostsNoRelayout) {
    RenderEnv env(page("<div id=p class=box style='animation:grow 10s linear -5s paused'></div>"));
    env.env().frame(16);
    env.env().frame(16);
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    for (int i = 0; i < 60; i++) {
        env.env().frame(16);
    }
    CHECK_EQ(env.render().patchCount(), patches);
    CHECK_EQ(env.render().buildCount(), builds);
    checkEval(env, "w('p')", "40");
}

/// One frame of a running CSS transform animation on a 200-element page is cheap, and the style-change step does not
/// run for it (Review Focus 3).
WR_TEST(testARunningCSSAnimationFrameIsCheap) {
    int steps = 0;
    RenderEnv env(rowsPage(200, "animation:slide 100s linear;width:20px;height:20px"), {}, true, [&](wr_test::HostEnv& host) {
        wr::animation::AnimationState::of(host.ctx()).setStyleObserverForTesting([&](const wr::animation::StyleChange&) { steps++; });
    });
    env.env().frame(16);
    env.env().frame(16);
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const int stepsBefore = steps;
    const uint64_t before = JS_GetWorkUnits(rt);
    env.env().frame(16);
    const uint64_t cost = JS_GetWorkUnits(rt) - before;
    if (cost >= 250000) {
        std::printf("  a frame cost %llu units\n", (unsigned long long)cost);
    }
    CHECK(cost < 250000);
    CHECK_EQ(steps, stepsBefore);
    CHECK(std::stod(env.env().eval("tx('mover')")) > 0);
}

/// A flush whose style-change step starts animations publishes their values in a second pass, and stops there: at
/// most two patches, whatever the step did.
WR_TEST(testTheSecondPassIsBounded) {
    RenderEnv env(page("<div id=a class=box></div><div id=b class=box style='top:30px'></div>",
                       ".go{animation:grow 1s linear;transition:opacity 1s} .go.on{opacity:.2}"));
    env.env().frame(16);
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    env.env().eval("$('a').className = 'box go'; $('b').className = 'box go on'; 1");
    env.flush();
    CHECK(env.render().patchCount() + env.render().buildCount() - patches - builds <= 2);
    // #a's animation, #b's, and #b's opacity transition (declared and changed in the same change, as browsers start it).
    checkEval(env, "document.getAnimations().length", "3");
    checkEval(env, "w('a')", "10");
}

/// 10,000 elements with `transition: all 1s` whose ancestor's class flips at once: starting their transitions is
/// charged (the flip costs more than the same flip without the declarations), so a widget either runs them to the end
/// or stops on its budget. The render build keeps 10,000 elements (Builder's kMaxElements): the page's first five are
/// html, head, its two style elements and body, so the last five `.t` are not rendered, have no style, and start none.
WR_TEST(testManyTransitionsAreCharged) {
    std::string body;
    for (int i = 0; i < 10000; i++) {
        body += "<i class=t></i>";
    }
    // The cost of the flip on a fresh page; `env` keeps the page.
    const auto flipCost = [&](const std::string& transition, std::unique_ptr<RenderEnv>& env) {
        env = std::make_unique<RenderEnv>(
            page(body, ".t{display:block;width:1px;height:1px;opacity:1;" + transition + "} body.go .t{opacity:.5}"));
        env->env().frame(16);
        JSRuntime* rt = env->env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env->env().eval("document.body.className = 'go'; 1");
        env->flush();
        return JS_GetWorkUnits(rt) - before;
    };
    std::unique_ptr<RenderEnv> env;
    const uint64_t plain = flipCost("", env);
    const uint64_t transitioning = flipCost("transition:all 1s linear", env);
    std::printf("  flip %llu units, %llu with the transitions\n", (unsigned long long)plain, (unsigned long long)transitioning);
    CHECK(transitioning >= plain + 9995 * wr::work::kNodeVisit);
    checkEval(*env, "document.getAnimations().length", "9995");
    for (int i = 0; i < 70; i++) {
        env->env().frame(16);
    }
    checkEval(*env, "[document.getAnimations().length, getComputedStyle(document.querySelector('.t')).opacity].join()", "0,0.5");
}

/// A class change on an element restyles its descendants: their transitions start as the element's own would (the patch
/// refuses a change other elements' selectors depend on, and the rebuild's step sees every element).
WR_TEST(testAnAncestorsClassStartsTransitions) {
    RenderEnv env(page("<div id=wrap><div id=c class=box></div></div>",
                       "#c{transition:opacity 1s linear;opacity:1} #wrap.open #c{opacity:.2}"));
    env.env().frame(16);
    env.env().eval("$('wrap').className = 'open'; 1");
    env.env().frame(16);
    checkEval(env, "$('c').getAnimations().map(a => a.transitionProperty).join()", "opacity");
}

/// A value that stops being declared transitions back to the initial value (`.hide{opacity:0}` removed fades the
/// element in), as browsers do; a property without an initial value in the table does not transition back.
WR_TEST(testATransitionBackToAnUndeclaredValue) {
    RenderEnv env(page("<div id=t class='box hide'></div><div id=u class='box tall' style='top:30px'></div>",
                       ".box{transition:opacity 1s linear,max-height 1s linear} .hide{opacity:0} .tall{max-height:60px}"));
    env.env().frame(16);
    checkEval(env, "getComputedStyle($('t')).opacity", "0");
    env.env().eval("$('t').classList.remove('hide'); $('u').classList.remove('tall'); 1");
    // The frame that restyles starts the transition; the next one gives it its start time.
    env.env().frame(16);
    env.env().frame(16);
    env.env().frame(500);
    const double opacity = std::stod(env.env().eval("getComputedStyle($('t')).opacity"));
    CHECK(opacity > 0.4 && opacity < 0.6);
    checkEval(env, "$('t').getAnimations().map(a => a.transitionProperty).join()", "opacity");
    checkEval(env, "$('u').getAnimations().length", "0");
    env.env().frame(600);
    checkEval(env, "[getComputedStyle($('t')).opacity, $('t').getAnimations().length].join()", "1,0");
}

/// visual/06's tap box: a colour declared through the `background` shorthand transitions as `background-color`, as
/// browsers expand it, under `transition: background-color` and under `transition: background` alike.
WR_TEST(testABackgroundShorthandColourTransitions) {
    RenderEnv env(page("<div id=a class=box></div><div id=b class=box style='top:30px'></div>",
                       "#a{background:#e83;transition:transform .6s,background-color 1s linear} #a.go{background:#36c}"
                       " #b{background:#e83;transition:background 1s linear} #b.go{background:#36c}"));
    env.env().frame(16);
    env.env().eval("$('a').classList.add('go'); $('b').classList.add('go'); 1");
    env.env().frame(16);
    env.env().frame(16);
    env.env().frame(500);
    checkEval(env, "$('a').getAnimations().map(a => a.transitionProperty).join()", "background-color");
    checkEval(env, "$('b').getAnimations().map(a => a.transitionProperty).join()", "background-color");
    for (const char* id : {"a", "b"}) {
        // Half-way from rgb(238, 136, 51) to rgb(51, 102, 204): red near 145.
        const std::string red = env.env().eval(std::string("+/rgba?\\((\\d+)/.exec(getComputedStyle($('") + id + "')).backgroundColor)[1]");
        CHECK(std::stoi(red) > 110 && std::stoi(red) < 180);
    }
    env.env().frame(600);
    checkEval(env, "getComputedStyle($('a')).backgroundColor + ' ' + $('a').getAnimations().length", "rgb(51, 102, 204) 0");
}

// MARK: Final review fixes

/// C1: script that runs inside the style-change step (a `then` getter, read while a CSS animation's ready promise is
/// resolved) frees nothing the step holds: it removes the element being updated and flushes (getAnimations), and it
/// empties the body while a rebuild's walk is under way. Run under ASan to see a regression.
WR_TEST(testScriptInsideTheStyleStepFreesNothingItHolds) {
    RenderEnv env(page("<div id=e class=box></div><div id=f class=box></div><!-- c --><p>p</p>",
                       "@keyframes k{to{opacity:.5}} .a{animation:k 1s} .x .box{animation:k 2s}"));
    env.env().frame(16);
    env.env().eval("Object.defineProperty(Animation.prototype, 'then', {configurable: true, get() {"
                   " if (this instanceof CSSAnimation && !window.once) { window.once = true; $('e').remove(); document.getAnimations(); } }});"
                   " $('e').className = 'box a'; 1");
    env.env().frame(16);
    env.env().frame(16);
    checkEval(env, "[window.once, $('e'), document.getAnimations().length].join()", "true,,0");
    env.env().eval("window.twice = false; Object.defineProperty(Animation.prototype, 'then', {configurable: true, get() {"
                   " if (this instanceof CSSAnimation && !window.twice) { window.twice = true; document.body.replaceChildren(); } }});"
                   " document.body.className = 'x'; 1");
    env.env().frame(16);
    env.env().frame(16);
    checkEval(env, "[window.twice, document.body.childNodes.length, document.getAnimations().length].join()", "true,0,0");
}

/// I1: script's changes to a CSS animation's effect survive a rebuild that leaves the style sheets as they were (a
/// class change other elements' selectors depend on rebuilds).
WR_TEST(testScriptsEffectChangesSurviveARebuild) {
    RenderEnv env(page("<div id=c class=box style='animation:slide 10s linear infinite'></div><div id=o></div>",
                       ".x #o{color:red}"));
    env.env().frame(16);
    env.env().eval("window.a = $('c').getAnimations()[0]; a.effect.updateTiming({duration: 20000}); 1");
    const uint64_t builds = env.render().buildCount();
    env.env().eval("document.body.className = 'x'; 1");
    env.env().frame(16);
    CHECK(env.render().buildCount() > builds);
    checkEval(env, "[a.effect.getTiming().duration, $('c').getAnimations()[0] === a].join()", "20000,true");
}

/// I1: on a page whose patches litehtml refuses (generated content), every animated frame is a rebuild; the style-change
/// step still runs only when the frame changed something it reads.
WR_TEST(testARebuildFromAnAnimatedFrameRunsNoStyleStep) {
    int steps = 0;
    RenderEnv env(page("<div id=m class=box style='animation:grow 10s linear'></div><p id=p>x</p>", "#p::before{content:'>'}"), {}, true,
                  [&](wr_test::HostEnv& host) {
                      wr::animation::AnimationState::of(host.ctx()).setStyleObserverForTesting([&](const wr::animation::StyleChange&) { steps++; });
                  });
    env.env().frame(16);
    env.env().frame(16);
    const int stepsBefore = steps;
    const uint64_t builds = env.render().buildCount();
    for (int i = 0; i < 5; i++) {
        env.env().frame(100);
    }
    CHECK(env.render().buildCount() > builds);
    CHECK_EQ(steps, stepsBefore);
}

/// I2: play and pause driven by style never throw out of a flush: a reversed infinite animation that style resumes or
/// pauses keeps the widget running; a finished one that style pauses and resumes stays finished (no auto-rewind).
WR_TEST(testPlayStateFromStyleNeverThrows) {
    RenderEnv env(page("<div id=s class=box></div><div id=f class=box style='top:30px;animation:short .1s forwards'></div>",
                       "@keyframes spin{to{transform:rotate(360deg)}} #s{animation:spin 1s infinite paused}"
                       " #s.run{animation-play-state:running} #f.hold{animation-play-state:paused}"));
    env.env().frame(16);
    env.env().eval("window.r = $('s').getAnimations()[0]; r.playbackRate = -1; $('s').className = 'box run'; 1");
    env.env().frame(16);
    // Resumed without auto-rewind, a reversed animation at its start is finished there (as in Gecko), not an error.
    checkEval(env, "[r.playState, r.playbackRate].join()", "finished,-1");
    env.env().eval("$('s').className = 'box'; 1");
    env.env().frame(16);
    checkEval(env, "1", "1");
    for (int i = 0; i < 12; i++) {
        env.env().frame(16);
    }
    env.env().eval("window.g = $('f').getAnimations()[0]; 1");
    checkEval(env, "g.playState", "finished");
    env.env().eval("$('f').classList.add('hold'); 1");
    env.env().frame(16);
    env.env().eval("$('f').classList.remove('hold'); 1");
    env.env().frame(16);
    env.env().frame(16);
    checkEval(env, "[g.playState, Math.round(g.currentTime)].join()", "finished,100");
}
