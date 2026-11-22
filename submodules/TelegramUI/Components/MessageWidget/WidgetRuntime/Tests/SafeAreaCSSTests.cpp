// widget-sandbox v0.4.0, the content safe area's CSS (sdk-v1 §2.17; conformance auto/36-safe-area): env(safe-area-inset-*)
// is the root variable the renderer sets, as the validator rewrites it; another env() name is its fallback, or the
// declaration is dropped; the six --tg-content-safe-area-* variables are always on the root (0px until the host says);
// the UA layer pads the body by the band; CSS.supports and @supports say yes for the safe-area insets only.
#include <cmath>
#include <cstdio>
#include <functional>
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

void checkEval(RenderEnv& env, const std::string& code, const std::string& want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("    %s\n    got  %s\n    want %s\n", code.c_str(), got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

/// auto/36's probes: each #eN a bar whose width is the value under test, and #bar between the two corners.
std::string page(const std::string& css = "") {
    return "<!doctype html><html><head><style>"
           ".p{position:relative;height:6px} .p>div{height:6px}"
           "#e1{width:env(safe-area-inset-bottom)} #e2{width:env(safe-area-inset-bottom,77px)}"
           "#e3{width:env(safe-area-inset-top,77px)} #e4{width:calc(10px + env(safe-area-inset-bottom, 0px))}"
           "#e5{width:env(keyboard-inset-height,13px)} #e6{width:40px;width:env(keyboard-inset-height)}"
           "#e7{width:var(--tg-content-safe-area-inset-bottom)}"
           "#bar{position:absolute;top:0;left:var(--tg-content-safe-area-corner-left);right:var(--tg-content-safe-area-corner-right)}" +
           css +
           "</style></head><body>"
           "<div class=p><div id=e1></div></div><div class=p><div id=e2></div></div><div class=p><div id=e3></div></div>"
           "<div class=p><div id=e4></div></div><div class=p><div id=e5></div></div><div class=p><div id=e6></div></div>"
           "<div class=p><div id=e7></div></div><div class=p id=row><div id=bar></div></div><div id=w></div>"
           "<script>window.$ = id => document.getElementById(id);"
           "window.W = id => $(id).getBoundingClientRect().width;"
           "window.root = n => getComputedStyle(document.documentElement).getPropertyValue('--tg-content-safe-area-' + n).trim();"
           "window.vars = () => ['inset-top', 'inset-right', 'inset-bottom', 'inset-left', 'corner-left', 'corner-right'].map(root).join();"
           "</script></body></html>";
}

/// `text` with `from` (once) replaced by `to`.
std::string replaced(std::string text, const std::string& from, const std::string& to) {
    const size_t at = text.find(from);
    return at == std::string::npos ? text : text.replace(at, from.size(), to);
}

std::function<void(HostEnv&)> passing(wr::ContentSafeArea area) {
    return [area](HostEnv& env) { wr::HostState::of(env.ctx()).setInitialContentSafeArea(env.ctx(), area); };
}

wr::ContentSafeArea band(double bottom, double cornerLeft, double cornerRight) {
    wr::ContentSafeArea area;
    area.bottom = bottom;
    area.cornerLeft = cornerLeft;
    area.cornerRight = cornerRight;
    return area;
}

} // namespace

/// auto/36's CSS checks at its header's safe area (a 24 px band, a 64 px corner on the left).
WR_TEST(testEnvIsTheClientsSafeArea) {
    RenderEnv env(page(), {}, true, passing(band(24, 64, 0)));
    checkEval(env, "vars()", "0px,0px,24px,0px,64px,0px");
    checkEval(env, "[W('e1'), W('e2'), W('e3'), W('e4'), W('e5'), W('e6'), W('e7')].join()", "24,24,0,34,13,40,24");
    checkEval(env, "(r => [Math.round($('bar').getBoundingClientRect().left - r.left), Math.round(r.right - $('bar').getBoundingClientRect().right)].join())($('row').getBoundingClientRect())", "64,0");
    // The UA layer: an unstyled body is padded by the band.
    checkEval(env, "getComputedStyle(document.body).paddingBottom", "24px");
}

/// Nothing passed: every variable is 0px (set, so a fallback never applies to a safe-area inset), the body unpadded.
WR_TEST(testWithoutASafeAreaEveryVariableIsZero) {
    RenderEnv env(page());
    checkEval(env, "vars()", "0px,0px,0px,0px,0px,0px");
    checkEval(env, "[W('e1'), W('e2'), W('e3'), W('e4'), W('e5'), W('e6'), W('e7')].join()", "0,0,0,10,13,40,0");
    checkEval(env, "getComputedStyle(document.body).paddingBottom", "0px");
}

/// The UA layer's padding ranks below any author rule: a widget that pads for the band itself sets the body's padding.
WR_TEST(testTheBodysOwnPaddingWins) {
    RenderEnv env(page("body{padding:0}"), {}, true, passing(band(24, 0, 64)));
    checkEval(env, "getComputedStyle(document.body).paddingBottom", "0px");
    checkEval(env, "(r => Math.round(r.right - $('bar').getBoundingClientRect().right))($('row').getBoundingClientRect())", "64");
}

/// A reset of every padding (`* { padding: 0 }`) wins over the UA layer's band too, whatever its specificity: the layer
/// is an origin below the author's, so such a widget handles the band itself.
WR_TEST(testAPaddingResetWinsOverTheBand) {
    RenderEnv env(page("* { padding: 0 }"), {}, true, passing(band(24, 0, 64)));
    checkEval(env, "getComputedStyle(document.body).paddingBottom", "0px");
    checkEval(env, "W('e1')", "24");
}

/// CSS.supports and @supports: true for the safe-area insets, false for another env() name.
WR_TEST(testOnlyTheSafeAreaInsetsAreSupported) {
    RenderEnv env(replaced(page("#s1,#s2{height:1px} @supports (padding: env(safe-area-inset-top)) { #s1 { height: 5px } }"
                                " @supports (padding: env(keyboard-inset-height, 1px)) { #s2 { height: 5px } }"),
                           "<div id=w></div>", "<div id=s1></div><div id=s2></div>"),
                  {}, true, passing(band(24, 0, 64)));
    checkEval(env, "[CSS.supports('padding-bottom', 'env(safe-area-inset-bottom)'), "
                   "CSS.supports('padding-bottom: max(8px, env(safe-area-inset-bottom, 4px))'), "
                   "CSS.supports('padding', 'env(keyboard-inset-height, 4px)'), CSS.supports('padding', 'env(keyboard-inset-height)')].join()",
              "true,true,false,false");
    checkEval(env, "[$('s1').getBoundingClientRect().height, $('s2').getBoundingClientRect().height].join()", "5,1");
}

/// A style attribute and a CSSOM write meet the same rewrite; env() inside url() stays out, as var() does.
WR_TEST(testInlineStyleAndCSSOMAreRewritten) {
    RenderEnv env(replaced(page(), "<div id=w></div>", "<div id=w style=\"width:env(safe-area-inset-bottom, 5px)\"></div><div id=u></div>"),
                  {}, true, passing(band(24, 0, 64)));
    checkEval(env, "W('w')", "24");
    checkEval(env, "$('u').style.width = 'calc(1px + env(safe-area-inset-bottom))'; W('u')", "25");
    checkEval(env, "CSS.supports('background-image', 'url(env(safe-area-inset-bottom))')", "false");
}

/// An SVG attribute whose value is CSS (profile 1's table: paint, colours, urls) meets the same rewrite, so a fallback
/// never applies to a safe-area inset there either; another attribute is no CSS value (upstream's validator leaves it as
/// written), so env() in it is the renderer's own: 0, or its fallback.
WR_TEST(testAnSVGAttributeIsRewrittenWhenItsValueIsCSS) {
    RenderEnv env(replaced(page(), "<div id=w></div>",
                           "<svg width=\"40\" height=\"40\"><rect id=\"sf\" width=\"10\" height=\"10\" fill=\"env(safe-area-inset-bottom, red)\"/>"
                           "<rect id=\"sk\" width=\"10\" height=\"10\" fill=\"env(keyboard-inset-height, red)\"/>"
                           "<rect id=\"sw\" width=\"10\" height=\"10\" stroke=\"black\" stroke-width=\"env(safe-area-inset-bottom, 2px)\"/></svg>"),
                  {}, true, passing(band(24, 0, 64)));
    checkEval(env, "[getComputedStyle($('sf')).fill != 'rgb(255, 0, 0)', getComputedStyle($('sk')).fill, getComputedStyle($('sw')).strokeWidth].join()",
              "true,rgb(255, 0, 0),2px");
}

/// The values as upstream's checkContentSafeArea keeps them: an inset 0–64 and a corner 0–200, then rounded to two
/// decimals (199.996 is 200; 200.004 is past the range, 0); anything else (negative, not finite) is 0.
WR_TEST(testTheValuesAreCheckedAsUpstreamChecksThem) {
    wr::ContentSafeArea area;
    area.top = -1;
    area.right = 64;
    area.bottom = 24.456;
    area.left = std::nan("");
    area.cornerLeft = 199.996;
    area.cornerRight = 200.004;
    RenderEnv env(page(), {}, true, passing(area));
    checkEval(env, "vars()", "0px,64px,24.46px,0px,200px,0px");
}
