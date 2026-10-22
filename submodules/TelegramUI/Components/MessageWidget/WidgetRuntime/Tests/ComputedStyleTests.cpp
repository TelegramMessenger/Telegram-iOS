// CSSOM's getComputedStyle (V3 plan, Task 4): a read-only CSSStyleDeclaration over what litehtml computed for the
// element after a flush (a layout query), serialized as CSSOM resolves it: colors as rgb()/rgba(), lengths in px,
// keywords as written. A property the renderer does not model reads "".
#include <string>

#include <litehtml/string_id.h>

#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Work.h"
#include "Tests/HostHarness.h"
#include "Tests/JSHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kStyled =
    "<!doctype html><html><head><style>"
    "#parent { font-size: 10px; } #a { width: 100px; height: 20px; margin-top: 1em; color: red; font-size: 2em; "
    "font-weight: bold; text-align: center; --c: 5px; } #b::before { content: \"x\"; } #h { display: none; }"
    "</style></head><body><div id=parent><div id=a>a</div><span id=s>s</span><p id=b>b</p><div id=h></div></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>";

} // namespace

WR_TEST(testComputedKeywords) {
    RenderEnv env(kStyled);
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).display", "block");
    CHECK_JS_EQ(env.env(), "getComputedStyle(s).display", "inline");
    CHECK_JS_EQ(env.env(), "getComputedStyle(h).display", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).textAlign", "center");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).getPropertyValue('text-align')", "center");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).fontWeight", "700");
    CHECK_JS_EQ(env.env(), "getComputedStyle(s).fontWeight", "400");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).position", "static");
}

WR_TEST(testComputedColorsAndLengths) {
    RenderEnv env(kStyled);
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).color", "rgb(255, 0, 0)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).backgroundColor", "rgba(0, 0, 0, 0)");
    // 2em of the parent's 10px; margin-top 1em of the element's own 20px; width resolved from the layout.
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).fontSize", "20px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).marginTop", "20px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).width", "100px");
}

WR_TEST(testComputedCustomPropertiesAndPseudoElements) {
    RenderEnv env(kStyled);
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).getPropertyValue('--c').trim()", "5px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(b, '::before').content", "\"x\"");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).getPropertyValue('no-such-property')", "");
}

WR_TEST(testTheComputedDeclarationIsReadOnlyAndLive) {
    RenderEnv env(kStyled);
    CHECK_THROWS(env.env(), "getComputedStyle(a).setProperty('color', 'blue')", "NoModificationAllowedError");
    CHECK_THROWS(env.env(), "getComputedStyle(a).removeProperty('color')", "NoModificationAllowedError");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).cssText", "");
    CHECK_JS(env.env(), "getComputedStyle(a).length > 0");
    CHECK_JS(env.env(), "getComputedStyle(a) instanceof CSSStyleDeclaration");
    CHECK_JS_EQ(env.env(), "(() => { const cs = getComputedStyle(a); a.style.color = 'blue'; return cs.color; })()", "rgb(0, 0, 255)");
    // Not in the document: nothing computed.
    CHECK_JS_EQ(env.env(), "getComputedStyle(document.createElement('div')).display", "");
}

/// A custom property a widget names is looked up without adding the name to litehtml's process-wide id table, which
/// never shrinks (twidget VENDOR.md edit 23): `getPropertyValue('--' + i)` in a loop must not grow it.
WR_TEST(testAnUnknownCustomPropertyDoesNotGrowTheIdTable) {
    RenderEnv env(kStyled);
    CHECK_JS_EQ(env.env(), "(() => { let s = ''; for (let i = 0; i < 100; i++) s += getComputedStyle(a).getPropertyValue('--never-declared-' + i); return s; })()", "");
    litehtml::string_id id;
    CHECK(!litehtml::_find_id("--never-declared-7", id));
}

/// The fix-wave review's I-3: a computed value's serialization counts against the query budget by its length, and
/// `cursor` drops the space litehtml puts before each comma in one pass (it was quadratic).
WR_TEST(testAComputedValueIsChargedByItsLength) {
    std::string longCursor = "a";
    for (int i = 0; i < 3000; i++) {
        longCursor += ",a";
    }
    RenderEnv shortEnv("<!doctype html><html><head><style>:root { cursor: a, b }</style></head><body></body></html>");
    RenderEnv longEnv("<!doctype html><html><head><style>:root { cursor: " + longCursor + " }</style></head><body></body></html>");
    CHECK_EQ(shortEnv.env().eval("getComputedStyle(document.documentElement).cursor"), std::string("a, b"));
    auto queries = [](RenderEnv& env) {
        const uint64_t before = env.env().runtime().layoutQueryUnits();
        env.env().eval("getComputedStyle(document.documentElement).cursor");
        return env.env().runtime().layoutQueryUnits() - before;
    };
    const uint64_t shortQueries = queries(shortEnv);
    const uint64_t longQueries = queries(longEnv);
    CHECK(longQueries >= shortQueries + uint64_t(longCursor.size()) / 8 * wr::work::kScanEightUnits);
    CHECK_EQ(longEnv.env().eval("(v => !v.includes(' ,') && v.split(',').length)(getComputedStyle(document.documentElement).cursor)"),
             std::string("3001"));
}

/// widget-sandbox v0.1.1 (D18, css.text.selection; auto/06-text-fonts-c): the UA layer makes the root `none`; an
/// element's own `user-select: text` (or `-webkit-user-select: text`, the same property) computes to text; one without
/// a declaration of its own computes to auto (not inherited); `all` is outside the profile and dropped; the later of
/// the two names wins.
WR_TEST(testUserSelectComputes) {
    RenderEnv env("<!doctype html><html><head><style>#t{user-select:text} #w{-webkit-user-select:text} #a{user-select:all}"
                  " #o{-webkit-user-select:none;user-select:text} #n{user-select:text;-webkit-user-select:none}</style></head><body>"
                  "<span id=t>t<b id=c>c</b></span><span id=w>w</span><span id=a>a</span><span id=o>o</span><span id=n>n</span>"
                  "<script>window.us = id => (s => s.userSelect + '/' + s.webkitUserSelect)("
                  "getComputedStyle(id ? document.getElementById(id) : document.documentElement));</script></body></html>");
    CHECK_JS_EQ(env.env(), "['', 't', 'c', 'w', 'a', 'o', 'n'].map(us).join()",
                "none/none,text/text,auto/auto,text/text,auto/auto,text/text,none/none");
}

/// v0.1.1 plan, Task 3 (auto/22-ua-defaults): vertical-align and border-collapse read back as keywords; the UA layer
/// sets sup on the baseline and tables collapsed, and border-collapse is inherited.
WR_TEST(testVerticalAlignAndBorderCollapse) {
    RenderEnv env("<!doctype html><html><head><style>#m{vertical-align:middle} #s{border-collapse:separate}</style></head>"
                  "<body><sup id=sup>2</sup><span id=m>m</span><span id=n>n</span><table id=t><tr><td id=td>c</td></tr>"
                  "</table><table id=s><tr><td id=std>c</td></tr></table>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "getComputedStyle(sup).verticalAlign", "baseline");
    CHECK_JS_EQ(env.env(), "getComputedStyle(m).verticalAlign", "middle");
    CHECK_JS_EQ(env.env(), "getComputedStyle(n).verticalAlign", "baseline");
    CHECK_JS_EQ(env.env(), "getComputedStyle(t).borderCollapse", "collapse");
    CHECK_JS_EQ(env.env(), "getComputedStyle(td).borderCollapse", "collapse");
    CHECK_JS_EQ(env.env(), "getComputedStyle(s).borderCollapse", "separate");
    CHECK_JS_EQ(env.env(), "getComputedStyle(std).borderCollapse", "separate");
    CHECK_JS_EQ(env.env(), "[...getComputedStyle(n)].includes('vertical-align') && [...getComputedStyle(n)].includes('border-collapse')",
                "true");
}

/// Fidelity plan, Task 1 (conformance 09-transforms-effects-a, 09-transforms-effects-b, 13-svg-a, 05-colour-backgrounds-b):
/// filter, touch-action, an SVG paint from a stylesheet and the background layers read back as Chromium serializes them.
WR_TEST(testTheFidelityProperties) {
    RenderEnv env("<!doctype html><html><head><style>.sv{fill:#c33;stroke:#36c;stroke-width:3} #ta{touch-action:none}"
                  " #pan{touch-action:pan-x pan-y}</style></head><body>"
                  "<div id=f style='width:10px;height:10px;filter:blur(2px) brightness(1.5) drop-shadow(1px 1px 0 red)'></div>"
                  "<div id=n>n</div><div id=ta>t</div><div id=pan>p</div><div id=in><span id=ch>c</span></div>"
                  "<div id=bg style='width:20px;height:20px;background:url(data:image/png;base64,AAAA) 1px 2px/10px 12px no-repeat'>"
                  "</div><div id=cv style='background:#00f'></div><div id=two style='background:url(data:image/png;base64,AA) 0 0/cover,"
                  "url(data:image/gif;base64,BB) 50% 100%/auto repeat-x'></div>"
                  "<svg width=40 height=40><rect id=r class=sv width=10 height=10></rect><circle id=c r=4></circle>"
                  "<g fill=#0f0><rect id=gr width=4 height=4></rect></g><rect id=cur style='color:#f00;fill:currentcolor'"
                  " width=4 height=4></rect><rect id=none fill=none width=4 height=4></rect></svg>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "getComputedStyle(f).filter", "blur(2px) brightness(1.5) drop-shadow(rgb(255, 0, 0) 1px 1px 0px)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(n).filter", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(ta).touchAction", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(pan).touchAction", "pan-x pan-y");
    CHECK_JS_EQ(env.env(), "getComputedStyle(n).touchAction", "auto");
    // touch-action is not inherited.
    CHECK_JS_EQ(env.env(), "getComputedStyle(ch).touchAction", "auto");
    CHECK_JS_EQ(env.env(), "getComputedStyle(r).fill", "rgb(204, 51, 51)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(r).stroke", "rgb(51, 102, 204)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(r).strokeWidth", "3px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).fill", "rgb(0, 0, 0)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).stroke", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(gr).fill", "rgb(0, 255, 0)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cur).fill", "rgb(255, 0, 0)");
    CHECK_JS_EQ(env.env(), "getComputedStyle(none).fill", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundImage", "url(\"data:image/png;base64,AAAA\")");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundSize", "10px 12px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundPosition", "1px 2px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundRepeat", "no-repeat");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundImage", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundSize", "auto");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundPosition", "0% 0%");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundRepeat", "repeat");
    CHECK_JS_EQ(env.env(), "getComputedStyle(two).backgroundImage",
                "url(\"data:image/png;base64,AA\"), url(\"data:image/gif;base64,BB\")");
    CHECK_JS_EQ(env.env(), "getComputedStyle(two).backgroundSize", "cover, auto");
    CHECK_JS_EQ(env.env(), "getComputedStyle(two).backgroundPosition", "0px 0px, 50% 100%");
    CHECK_JS_EQ(env.env(), "getComputedStyle(two).backgroundRepeat", "repeat, repeat-x");
}
