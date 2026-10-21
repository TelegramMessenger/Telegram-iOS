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
