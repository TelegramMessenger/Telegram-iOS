// CSSOM's getComputedStyle (V3 plan, Task 4): a read-only CSSStyleDeclaration over what litehtml computed for the
// element after a flush (a layout query), serialized as CSSOM resolves it: colors as rgb()/rgba(), lengths in px,
// keywords as written. A property the renderer does not model reads "".
#include <string>

#include <litehtml.h>
#include <litehtml/string_id.h>

#include "Sources/Render/ComputedStyle.h"
#include "Sources/Render/RenderTree.h"
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

namespace {

/// The laid-out element whose id attribute is `id`, found by walking the published litehtml document.
const litehtml::element* laidOutById(const litehtml::element& element, const char* id) {
    const char* attribute = element.get_attr("id");
    if (attribute && std::string(attribute) == id) {
        return &element;
    }
    for (const auto& child : element.children()) {
        if (const litehtml::element* found = laidOutById(*child, id)) {
            return found;
        }
    }
    return nullptr;
}

bool selects(RenderEnv& env, const char* id) {
    env.flush();
    const litehtml::element* element = laidOutById(*env.render().document()->root(), id);
    CHECK(element != nullptr);
    return element && wr::selectsText(*element);
}

} // namespace

/// Text selection (sdk-v1 §2.4, §5.10): profile 1 keeps a var() value for user-select, and it resolves like any other.
WR_TEST(testUserSelectResolvesVar) {
    RenderEnv env("<!doctype html><html><head><style>:root{--s:text} #v{user-select:var(--s)}</style></head><body>"
                  "<p id=v>x</p><script>window.v = document.getElementById('v');</script></body></html>");
    CHECK_JS_EQ(env.env(), "getComputedStyle(v).userSelect", "text");
    CHECK(selects(env, "v"));
}

/// The effective value: the nearest ancestor-or-self whose own value is not auto decides; the UA layer's `none` on the
/// root ends the walk.
WR_TEST(testSelectsTextWalksToTheNearestDecidingAncestor) {
    RenderEnv env("<!doctype html><html><body><div id=t style=\"user-select:text\"><b id=b>w</b>"
                  "<span id=n style=\"user-select:none\"><i id=i>x</i></span></div><p id=p>y</p></body></html>");
    CHECK(selects(env, "t"));
    CHECK(selects(env, "b"));
    CHECK(!selects(env, "n"));
    CHECK(!selects(env, "i"));
    CHECK(!selects(env, "p"));
}

/// `-webkit-user-select` is the same property: alone it selects, and of the two the later declaration wins.
WR_TEST(testWebkitUserSelectIsTheSameProperty) {
    RenderEnv env("<!doctype html><html><body><p id=w style=\"-webkit-user-select:text\">w</p>"
                  "<p id=o style=\"user-select:text;-webkit-user-select:none\">o</p></body></html>");
    CHECK(selects(env, "w"));
    CHECK(!selects(env, "o"));
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

/// Profile 1's properties the renderer keeps no value of (2026-10-22): the element's own declaration as written (var()
/// substituted), an inherited one from the nearest ancestor that declares it, else the initial value; the CSS-wide
/// keywords cascade as they do for the others.
WR_TEST(testUnmodeledPropertiesAnswerTheirDeclarations) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#p { pointer-events: none; color-scheme: dark; --d: 3s; } "
                  "#a { animation-name: spin; animation-duration: var(--d); counter-reset: item; unicode-bidi: isolate; } "
                  "#b { pointer-events: inherit; animation-name: initial; }"
                  "</style></head><body><div id=p><div id=a>a</div><div id=b>b</div><div id=c>c</div></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).animationName", "spin");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).animationDuration", "3s");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).counterReset", "item");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).unicodeBidi", "isolate");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).animationName", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).pointerEvents", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).colorScheme", "dark");
    CHECK_JS_EQ(env.env(), "getComputedStyle(b).pointerEvents", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(b).animationName", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).getPropertyValue('unicode-bidi')", "isolate");
}

/// Profile 1's longhands the renderer keeps (computed-style plan, Task 2), each at its default and declared, resolved as
/// CSSOM says: a positioned element's offsets are its used px, transform-origin is in px of its box, the rest their
/// computed values.
WR_TEST(testExactLonghands) {
    RenderEnv env("<!doctype html><html><head><style>body { margin: 0; } div { margin: 0; } "
                  "#box { position: relative; width: 200px; height: 100px; } "
                  "#rel10 { position: relative; left: 10px; top: 5px; } "
                  "#abs { position: absolute; left: 10%; top: 0; width: 100px; height: 40px; } "
                  "#fl { display: flex; flex-direction: column; flex-wrap: wrap; justify-content: center; "
                  "align-items: center; align-content: space-between; row-gap: 4px; column-gap: 6px; } "
                  "#it { flex-grow: 2; flex-shrink: 0; flex-basis: 10px; order: 3; align-self: flex-end; z-index: 2; "
                  "position: relative; } "
                  "#mm { min-width: 10px; max-width: 50%; min-height: 5px; max-height: 30px; } "
                  "#tx { letter-spacing: 2px; text-transform: uppercase; text-indent: 12px; text-overflow: ellipsis; "
                  "overflow: hidden; overflow-wrap: anywhere; clear: both; } "
                  "#li { list-style-position: inside; } #of { object-fit: cover; object-position: left top; } "
                  "#ar { aspect-ratio: 2 / 1; width: 40px; } #to { width: 100px; height: 40px; } "
                  "#to2 { width: 100px; height: 40px; transform-origin: left top; } "
                  "#oo { outline: 2px solid red; outline-offset: 3px; } #bs { box-shadow: 1px 2px 3px red; } "
                  "#td { text-decoration: underline; text-decoration-thickness: 2px; } "
                  "#bo { background-origin: content-box; } "
                  "#br { border-top-left-radius: 4px; border-bottom-right-radius: 4px 2px; } "
                  "#wb { -webkit-backdrop-filter: blur(2px); } "
                  "</style></head><body><div id=box><div id=st>s</div><div id=rel style='position:relative'>r</div>"
                  "<div id=rel10>r</div><div id=abs>a</div></div>"
                  "<div id=fl><div id=it>i</div></div><div id=mm>m</div><div id=tx>t</div><ul><li id=li>l</li></ul>"
                  "<div id=of>o</div><div id=ar>a</div><div id=to>t</div><div id=to2>t</div><div id=oo>o</div>"
                  "<div id=bs>b</div><div id=td>t</div><div id=bo>b</div><div id=br>b</div><div id=wb>w</div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.cs = (e, p) => getComputedStyle(e).getPropertyValue(p);"
                  "window.all = (e, ps) => ps.map(p => cs(e, p)).join('|');</script></body></html>");
    // Offsets: static computed (auto), relative used (0px, or the opposite's negation), absolute used from the layout.
    CHECK_JS_EQ(env.env(), "all(st, ['left', 'top', 'right', 'bottom', 'z-index'])", "auto|auto|auto|auto|auto");
    CHECK_JS_EQ(env.env(), "all(rel, ['left', 'top', 'right', 'bottom'])", "0px|0px|0px|0px");
    CHECK_JS_EQ(env.env(), "all(rel10, ['left', 'top', 'right', 'bottom'])", "10px|5px|-10px|-5px");
    CHECK_JS_EQ(env.env(), "all(abs, ['left', 'top', 'right', 'bottom'])", "20px|0px|80px|60px");
    // Flex and alignment.
    CHECK_JS_EQ(env.env(), "all(fl, ['flex-direction', 'flex-wrap', 'justify-content', 'align-items', 'align-content', "
                           "'row-gap', 'column-gap'])",
                "column|wrap|center|center|space-between|4px|6px");
    CHECK_JS_EQ(env.env(), "all(it, ['flex-grow', 'flex-shrink', 'flex-basis', 'order', 'align-self', 'z-index'])",
                "2|0|10px|3|flex-end|2");
    CHECK_JS_EQ(env.env(), "all(st, ['flex-direction', 'flex-wrap', 'flex-grow', 'flex-shrink', 'flex-basis', 'order', "
                           "'align-self', 'align-items', 'justify-content', 'row-gap'])",
                "row|nowrap|0|1|auto|0|auto|normal|normal|normal");
    // Sizes.
    CHECK_JS_EQ(env.env(), "all(mm, ['min-width', 'max-width', 'min-height', 'max-height'])", "10px|50%|5px|30px");
    CHECK_JS_EQ(env.env(), "all(st, ['min-width', 'max-width', 'min-height', 'max-height'])", "auto|none|auto|none");
    // Text.
    CHECK_JS_EQ(env.env(), "all(tx, ['letter-spacing', 'text-transform', 'text-indent', 'text-overflow', "
                           "'overflow-wrap', 'word-wrap', 'clear'])",
                "2px|uppercase|12px|ellipsis|anywhere|anywhere|both");
    // overflow-wrap inherits the UA layer's break-word (widget-sandbox v0.1.1's root rule).
    CHECK_JS_EQ(env.env(), "all(st, ['letter-spacing', 'text-transform', 'text-indent', 'text-overflow', "
                           "'overflow-wrap', 'clear'])",
                "normal|none|0px|clip|break-word|none");
    CHECK_JS_EQ(env.env(), "cs(li, 'list-style-position') + '|' + cs(st, 'list-style-position')", "inside|outside");
    // Replaced content, boxes, decoration.
    CHECK_JS_EQ(env.env(), "all(of, ['object-fit', 'object-position']) + '|' + all(st, ['object-fit', 'object-position'])",
                "cover|0% 0%|fill|50% 50%");
    CHECK_JS_EQ(env.env(), "cs(ar, 'aspect-ratio') + '|' + cs(st, 'aspect-ratio')", "2 / 1|auto");
    CHECK_JS_EQ(env.env(), "cs(to, 'transform-origin') + '|' + cs(to2, 'transform-origin')", "50px 20px|0px 0px");
    CHECK_JS_EQ(env.env(), "cs(oo, 'outline-offset') + '|' + cs(st, 'outline-offset')", "3px|0px");
    CHECK_JS_EQ(env.env(), "cs(bs, 'box-shadow') + '|' + cs(st, 'box-shadow')", "rgb(255, 0, 0) 1px 2px 3px 0px|none");
    CHECK_JS_EQ(env.env(), "cs(td, 'text-decoration-thickness') + '|' + cs(st, 'text-decoration-thickness')", "2px|auto");
    CHECK_JS_EQ(env.env(), "cs(bo, 'background-origin') + '|' + cs(st, 'background-origin')", "content-box|padding-box");
    CHECK_JS_EQ(env.env(), "all(br, ['border-top-left-radius', 'border-bottom-right-radius', 'border-top-right-radius'])",
                "4px|4px 2px|0px");
    CHECK_JS_EQ(env.env(), "cs(wb, '-webkit-backdrop-filter') + '|' + cs(wb, 'backdrop-filter')", "blur(2px)|blur(2px)");
}
