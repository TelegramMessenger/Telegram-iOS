// The renderer's CSS follows profile 1 (V4 plan, Task 3b): WidgetContainer answers twidget edit 29's hooks with the
// policy of CSSPolicy.h, so a declaration, a selector, an at-rule, an @media query and an @supports condition reach
// litehtml as the profile keeps them, while the widget's own DOM keeps what it wrote. The master sheet (litehtml's,
// the profile's UA sheet and the host's) is trusted and passes whole.
#include <cstdio>
#include <string>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::RenderEnv;

namespace {

void checkEval(RenderEnv& env, const std::string& code, const std::string& want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("    %s\n    got  %s\n    want %s\n", code.c_str(), got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

std::string page(const std::string& css, const std::string& body) {
    return "<!doctype html><html><head><style>" + css + "</style></head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.cs = (id, p, pseudo) => getComputedStyle($(id), pseudo || null).getPropertyValue(p);</script>"
           "</body></html>";
}

} // namespace

WR_TEST(testTheDeclarationRulesReachTheRenderer) {
    RenderEnv env(page("#s{position:sticky} #o{overflow:auto} #m{background:color-mix(in srgb,red,blue)}"
                       " #u{background-image:url(https://x/a.png)} #n{font-family:\"Times New Roman\",sans-serif}"
                       " #c{font-family:\"Courier New\"} #ui{font-family:ui-monospace} #v{--p:sticky;position:var(--p)}"
                       " #k::before{content:attr(class)} #d::before{content:attr(data-x)}",
                       "<div id=s>s</div><div id=o>o</div><div id=m>m</div><div id=u>u</div><div id=n>n</div>"
                       "<div id=c>c</div><div id=ui>ui</div><div id=v>v</div><div id=k class=kk>k</div>"
                       "<div id=d data-x=ok>d</div>"));
    checkEval(env, "cs('s', 'position')", "relative");
    checkEval(env, "cs('o', 'overflow-y')", "hidden");
    checkEval(env, "cs('m', 'background-color')", "rgba(0, 0, 0, 0)");
    checkEval(env, "cs('u', 'background-image')", "none");
    checkEval(env, "cs('n', 'font-family')", "sans-serif");
    checkEval(env, "cs('c', 'font-family')", "system-ui");
    checkEval(env, "/,\\s*monospace/.test(cs('ui', 'font-family'))", "true");
    // The reference's var() bypass is closed (plan decision 4): the value is judged once substituted.
    checkEval(env, "cs('v', 'position')", "relative");
    checkEval(env, "cs('k', 'content', '::before')", "none");
    checkEval(env, "cs('d', 'content', '::before') !== 'none'", "true");
    // The widget's DOM keeps what it wrote.
    checkEval(env, "document.querySelector('style').textContent.includes('position:sticky')", "true");
}

/// Review Focus 1: the master sheet is parsed once per process per scheme and cached; a hook that did not pass it
/// through would strip `a:link { cursor: pointer }` (`:link` is out of profile) from every later widget's master.
WR_TEST(testTheMasterSheetIsTrustedInEveryDocument) {
    wr::RenderOptions options;
    // A master text new to the process, so the first build parses it.
    options.hostCSS += " /* V4 master poisoning */";
    {
        RenderEnv first(page("p{color:red}", "<p>a</p>"), options);
        checkEval(first, "document.querySelector('p') !== null", "true");
    }
    RenderEnv second(page("#b{position:absolute;left:0;top:50px;width:80px;height:30px}",
                          "<a id=l href=#x>l</a><button id=b>b</button>"),
                     options);
    checkEval(second, "cs('l', 'cursor')", "pointer");
    wr::HostState::of(second.ctx()).pointer(second.ctx(), PointerPhase::Down, 40, 65, 1, true);
    second.env().drain();
    checkEval(second, "cs('b', 'opacity')", "0.7");
    wr::HostState::of(second.ctx()).pointer(second.ctx(), PointerPhase::Up, 40, 65, 1, true);
    second.env().drain();
}

WR_TEST(testAtLayerIsDroppedWithItsRules) {
    RenderEnv env(page("#ly{color:rgb(1,1,1)} @layer base{#ly{color:rgb(40,0,0)}} @layer{#ly{color:rgb(41,0,0)}}",
                       "<div id=ly>l</div>"));
    checkEval(env, "cs('ly', 'color')", "rgb(1, 1, 1)");
}

WR_TEST(testAtSupportsFollowsTheProfile) {
    RenderEnv env(page("@supports (display:flex){#sf{color:rgb(20,0,0)}}"
                       " @supports (transform:rotateY(1deg)){#s3d{color:rgb(21,0,0)}}"
                       " @supports (display:flex) and (not (position:sticky)){#scomb{color:rgb(22,0,0)}}"
                       " @supports (gap:1px){#sgap{color:rgb(23,0,0)}}",
                       "<div id=sf>a</div><div id=s3d>b</div><div id=scomb>c</div><div id=sgap>d</div>"));
    checkEval(env, "cs('sf', 'color')", "rgb(20, 0, 0)");
    checkEval(env, "cs('s3d', 'color') !== 'rgb(21, 0, 0)'", "true");
    checkEval(env, "cs('scomb', 'color')", "rgb(22, 0, 0)");
    checkEval(env, "cs('sgap', 'color')", "rgb(23, 0, 0)");
}

WR_TEST(testOutOfProfileMediaIsDropped) {
    const std::string html = page("@media (hover:hover){#h{color:rgb(1,0,0)}} @media print{#p{color:rgb(2,0,0)}}"
                                  " @media (max-height:400px){#t{color:rgb(3,0,0)}} @media (max-width:9999px){#w{color:rgb(4,0,0)}}"
                                  " @media (prefers-reduced-motion: reduce){#r{color:rgb(5,0,0)}}",
                                  "<div id=h>h</div><div id=p>p</div><div id=t>t</div><div id=w>w</div><div id=r>r</div>");
    RenderEnv env(html);
    checkEval(env, "cs('h', 'color') !== 'rgb(1, 0, 0)'", "true");
    checkEval(env, "cs('p', 'color') !== 'rgb(2, 0, 0)'", "true");
    checkEval(env, "cs('t', 'color') !== 'rgb(3, 0, 0)'", "true");
    checkEval(env, "cs('w', 'color')", "rgb(4, 0, 0)");
    checkEval(env, "cs('r', 'color') !== 'rgb(5, 0, 0)'", "true");
    wr::RenderOptions reduced;
    reduced.reducedMotion = true;
    RenderEnv motion(html, reduced);
    checkEval(motion, "cs('r', 'color')", "rgb(5, 0, 0)");
}

/// Review Focus 4: one out-of-profile selector leaves its list; a malformed one still drops the whole rule.
WR_TEST(testSelectorGroups) {
    // A bare :disabled is [disabled], which matches any element with the attribute (RB §5).
    RenderEnv env(page(".a:has(.b), .c{color:rgb(1,0,0)} .c2, .d:{color:rgb(2,0,0)} :disabled{color:rgb(3,0,0)}"
                       " a:enabled{color:rgb(4,0,0)} #f:focus{color:rgb(5,0,0)}",
                       "<div class=c id=c>c</div><div class=c2 id=c2>c2</div><button id=bd disabled>b</button>"
                       "<span id=sd disabled>s</span><a id=ae>a</a><button id=f>f</button>"));
    checkEval(env, "cs('c', 'color')", "rgb(1, 0, 0)");
    checkEval(env, "cs('c2', 'color') !== 'rgb(2, 0, 0)'", "true");
    checkEval(env, "cs('bd', 'color')", "rgb(3, 0, 0)");
    checkEval(env, "cs('sd', 'color')", "rgb(3, 0, 0)");
    checkEval(env, "cs('ae', 'color')", "rgb(4, 0, 0)");
    env.env().eval("$('f').focus(); 1");
    env.flush();
    checkEval(env, "cs('f', 'color') !== 'rgb(5, 0, 0)'", "true");
}

WR_TEST(testOtherAtRulesAreDropped) {
    RenderEnv env(page("@import url(x.css); @font-face{font-family:x} @container (min-width:1px){#c{color:rgb(6,0,0)}}"
                       " @namespace x url(y);",
                       "<div id=c>c</div>"));
    checkEval(env, "cs('c', 'color') !== 'rgb(6, 0, 0)'", "true");
    CHECK_EQ(env.render().refusedLoads(), uint64_t(0));
}

/// Review Focus 3: @keyframes inside a dropped @layer is no rule the widget's animations can name.
WR_TEST(testKeyframesInsideADroppedLayerDoNotAnimate) {
    RenderEnv dropped(page("@layer x{@keyframes k{from{opacity:0}to{opacity:1}}} #e{animation:k 1s}", "<div id=e>e</div>"));
    checkEval(dropped, "String($('e').getAnimations().length)", "0");
    RenderEnv kept(page("@keyframes k{from{opacity:0}to{opacity:1}} #e{animation:k 1s}", "<div id=e>e</div>"));
    checkEval(kept, "String($('e').getAnimations().length)", "1");
}

/// The font backstop (WidgetContainer::create_font): a family no declaration hook saw (an SVG font attribute) is
/// reduced before the host resolves it.
WR_TEST(testTheFontBackstop) {
    RenderEnv env("<!doctype html><svg width=40 height=20><text x=0 y=15 font-family=\"Courier New\">x</text></svg>");
    for (const auto& created : env.host().createdFonts) {
        CHECK(created.description.family.find("Courier") == std::string::npos);
    }
    CHECK(!env.host().createdFonts.empty());
}
