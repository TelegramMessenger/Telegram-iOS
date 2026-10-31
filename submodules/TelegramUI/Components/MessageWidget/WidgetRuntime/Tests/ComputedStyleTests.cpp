// CSSOM's getComputedStyle (V3 plan, Task 4): a read-only CSSStyleDeclaration over what litehtml computed for the
// element after a flush (a layout query), serialized as CSSOM resolves it: colors as rgb()/rgba(), lengths in px,
// keywords as written. A property the renderer does not model reads "".
#include <string>

#include <litehtml.h>
#include <litehtml/string_id.h>

#include "Sources/Render/ComputedStyle.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"
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

/// Computed-style plan, Task 3: a positional shorthand is serialized from its longhands' computed values (CSSOM: a value
/// repeated across sides or axes is written once; `border` is "" when its sides differ), so a script that sets one
/// longhand reads it back in the shorthand.
WR_TEST(testPositionalShorthandsFollowTheirLonghands) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#d{display:flex;flex-flow:column wrap;gap:4px 8px;place-content:center space-between;"
                  "border:2px solid rgb(255, 0, 0);border-radius:1px 2px 3px 4px;outline:3px dashed rgb(0, 0, 255);"
                  "list-style:inside none square}"
                  "#c{flex:2 3 10px;position:relative;inset:1px 2px 3px 4px}"
                  "#u{border-top:1px solid rgb(255, 0, 0);border-bottom:2px solid rgb(255, 0, 0)}"
                  "#e{border-radius:10px / 5px}"
                  "#grid{display:grid;place-items:start end}#g{place-self:end start}"
                  "</style></head><body><div id=d><div id=c></div></div><div id=u></div><div id=e></div>"
                  "<div id=grid><div id=g>g</div></div><p id=p>p</p>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  " window.cs = e => getComputedStyle(e);</script></body></html>");
    CHECK_JS_EQ(env.env(), "cs(d).flexFlow", "column wrap");
    CHECK_JS_EQ(env.env(), "cs(d).gap", "4px 8px");
    CHECK_JS_EQ(env.env(), "cs(d).placeContent", "center space-between");
    // litehtml computes justify-items for grid containers (it does nothing to a flex one): a grid's place-items.
    CHECK_JS_EQ(env.env(), "cs(grid).placeItems", "start end");
    CHECK_JS_EQ(env.env(), "cs(d).borderWidth", "2px");
    CHECK_JS_EQ(env.env(), "cs(d).borderStyle", "solid");
    CHECK_JS_EQ(env.env(), "cs(d).borderColor", "rgb(255, 0, 0)");
    CHECK_JS_EQ(env.env(), "cs(d).borderTop", "2px solid rgb(255, 0, 0)");
    CHECK_JS_EQ(env.env(), "cs(d).border", "2px solid rgb(255, 0, 0)");
    CHECK_JS_EQ(env.env(), "cs(d).borderRadius", "1px 2px 3px 4px");
    CHECK_JS_EQ(env.env(), "cs(d).outline", "rgb(0, 0, 255) dashed 3px");
    CHECK_JS_EQ(env.env(), "cs(d).listStyle", "inside none square");
    CHECK_JS_EQ(env.env(), "cs(c).flex", "2 3 10px");
    CHECK_JS_EQ(env.env(), "cs(c).inset", "1px 2px 3px 4px");
    CHECK_JS_EQ(env.env(), "cs(u).border", "");
    CHECK_JS_EQ(env.env(), "cs(u).borderWidth", "1px 0px 2px");
    CHECK_JS_EQ(env.env(), "cs(u).borderStyle", "solid none");
    CHECK_JS_EQ(env.env(), "cs(e).borderRadius", "10px / 5px");
    CHECK_JS_EQ(env.env(), "cs(g).placeSelf", "end start");
    // Nothing declared: the initial values, the colour the current one.
    CHECK_JS_EQ(env.env(), "cs(p).flex", "0 1 auto");
    CHECK_JS_EQ(env.env(), "cs(p).flexFlow", "row nowrap");
    CHECK_JS_EQ(env.env(), "cs(p).gap", "normal");
    CHECK_JS_EQ(env.env(), "cs(p).inset", "auto");
    CHECK_JS_EQ(env.env(), "cs(p).placeContent", "normal");
    CHECK_JS_EQ(env.env(), "cs(p).borderRadius", "0px");
    CHECK_JS_EQ(env.env(), "cs(p).listStyle", "outside none disc");
    CHECK_JS_EQ(env.env(), "String(cs(p).border === '0px none ' + cs(p).color)", "true");
    CHECK_JS_EQ(env.env(), "String(cs(p).outline === cs(p).color + ' none 0px')", "true");
    // Review Focus 4: a longhand a script sets is read back in its shorthand.
    CHECK_JS_EQ(env.env(), "(p.style.flexGrow = '2', cs(p).flex)", "2 1 auto");
    CHECK_JS_EQ(env.env(), "(p.style.rowGap = '3px', cs(p).gap)", "3px normal");
    CHECK_JS_EQ(env.env(), "(d.style.borderLeftWidth = '5px', cs(d).borderWidth)", "2px 2px 2px 5px");
    CHECK_JS_EQ(env.env(), "cs(d).border", "");
}

/// Computed-style plan, Task 3: the complex shorthands answer a canonical form built from their longhands, not claimed
/// Chrome-exact: background per layer (Chrome's order, the colour in the last layer), font without its initial parts,
/// the grid placements without trailing autos, and animation and transition from their longhands' lists (cycled), or
/// the shorthand as declared.
WR_TEST(testComplexShorthandsAnswerCanonicalForms) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#b{background:rgb(255, 0, 0)}"
                  "#l{background-image:linear-gradient(rgb(255, 0, 0), rgb(0, 0, 255)), none;background-color:rgb(0, 0, 255)}"
                  "#f{font:italic bold 20px/30px serif}#h{font:12px monospace}"
                  "#grid{display:grid}#g{grid-row:1 / 3;grid-column:2 / 4}#s{grid-column:span 2}"
                  "#a{animation-name:spin;animation-duration:2s}#t{transition-property:opacity, transform;transition-duration:1s}"
                  "#as{animation:spin 2s linear 1s infinite alternate both paused}#ts{transition:opacity 0.3s ease-in 0.1s}"
                  "</style></head><body><div id=b></div><div id=l></div><p id=f>f</p><p id=h>h</p>"
                  "<div id=grid><div id=g>g</div><div id=s>s</div></div><div id=a></div><div id=t></div>"
                  "<div id=as></div><div id=ts></div><p id=p>p</p>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  " window.cs = e => getComputedStyle(e);</script></body></html>");
    CHECK_JS_EQ(env.env(), "cs(b).background", "rgb(255, 0, 0) none repeat scroll 0% 0% / auto padding-box border-box");
    CHECK_JS_EQ(env.env(), "cs(l).background",
                "none repeat scroll 0% 0% / auto padding-box border-box, rgb(0, 0, 255) none repeat scroll 0% 0% / auto padding-box border-box");
    CHECK_JS_EQ(env.env(), "cs(f).font", "italic 700 20px / 30px serif");
    CHECK_JS_EQ(env.env(), "cs(h).font", "12px monospace");
    CHECK_JS_EQ(env.env(), "cs(g).gridRow", "1 / 3");
    CHECK_JS_EQ(env.env(), "cs(g).gridColumn", "2 / 4");
    CHECK_JS_EQ(env.env(), "cs(g).gridArea", "1 / 2 / 3 / 4");
    CHECK_JS_EQ(env.env(), "cs(s).gridColumn", "span 2");
    CHECK_JS_EQ(env.env(), "cs(s).gridRow", "auto");
    CHECK_JS_EQ(env.env(), "cs(s).gridArea", "auto / span 2");
    CHECK_JS_EQ(env.env(), "cs(p).gridArea", "auto");
    CHECK_JS_EQ(env.env(), "cs(p).animation", "none 0s ease 0s 1 normal none running");
    CHECK_JS_EQ(env.env(), "cs(p).transition", "all 0s ease 0s");
    CHECK_JS_EQ(env.env(), "cs(a).animation", "spin 2s ease 0s 1 normal none running");
    CHECK_JS_EQ(env.env(), "cs(t).transition", "opacity 1s ease 0s, transform 1s ease 0s");
    CHECK_JS_EQ(env.env(), "cs(as).animation", "spin 2s linear 1s infinite alternate both paused");
    CHECK_JS_EQ(env.env(), "cs(ts).transition", "opacity 0.3s ease-in 0.1s");
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
                  "<div id=bg style='width:20px;height:20px;background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==) 1px 2px/10px 12px no-repeat'>"
                  "</div><div id=cv style='background:#00f'></div><div id=two style='background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==) 0 0/cover,"
                  "url(data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==) 50% 100%/auto repeat-x'></div>"
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
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundImage", "url(\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==\")");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundSize", "10px 12px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundPosition", "1px 2px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bg).backgroundRepeat", "no-repeat");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundImage", "none");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundSize", "auto");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundPosition", "0% 0%");
    CHECK_JS_EQ(env.env(), "getComputedStyle(cv).backgroundRepeat", "repeat");
    CHECK_JS_EQ(env.env(), "getComputedStyle(two).backgroundImage",
                "url(\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==\"), url(\"data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==\")");
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

/// Final review C1: an animation or transition shorthand is its longhands' lists joined entry by entry, at most 64
/// entries (kMaxCSSListEntries, as many as the runtime runs) and "" past kMaxJoinedBytes, so a long list cycled against
/// a long item cannot build gigabytes before the read is charged.
WR_TEST(testAJoinedTransitionIsBounded) {
    std::string properties;
    for (int i = 0; i < 2000; i++) {
        properties += i ? ",a" : "a";
    }
    const std::string item(4000, 'x');
    RenderEnv env("<!doctype html><html><head><style>#x{transition-property:" + properties + ";transition-timing-function:" +
                  item + "}#y{transition-property:" + properties + "}</style></head><body><div id=x>x</div><div id=y>y</div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    // The long item survives the policy: the join is what has to bound it.
    CHECK_JS_EQ(env.env(), "String(getComputedStyle(x).transitionTimingFunction.length)", "4000");
    CHECK_JS_EQ(env.env(), "getComputedStyle(x).transition", "");
    CHECK_JS_EQ(env.env(), "String(getComputedStyle(y).transition.split(', ').length)", "64");
}

/// Final review I1: an absolutely positioned element's offsets run from its margin edge to its containing block's padding
/// edge, and transform-origin and a transform's percentages resolve against the border box, as litehtml draws them.
WR_TEST(testOffsetsAndOriginsUseTheirBoxes) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0} div{margin:0}"
                  "#cb{position:relative;width:200px;height:100px;padding:10px;border:2px solid}"
                  "#a{position:absolute;left:0;top:0;padding:5px;border:1px solid;width:20px;height:10px}"
                  "#pc{position:absolute;left:10%;top:50%;width:20px;height:10px}"
                  "#o{width:100px;height:40px;padding:10px}"
                  "#bb{box-sizing:border-box;width:100px;height:40px;padding:10px}"
                  "#t{width:100px;height:40px;padding:10px;transform:translate(-50%,-50%)}"
                  "#tc{width:100px;height:40px;padding:10px;transform:translate(calc(50% + 4px),calc(-1 * (50% + 1px)))}"
                  "#rc{position:relative;left:calc(10% + 5px);top:calc(50% - 2px);width:10px;height:10px}"
                  "#oc{width:100px;height:40px;padding:10px;transform-origin:calc(50% + 4px) calc(100% - 10px)}"
                  "</style></head><body><div id=cb><div id=a>a</div><div id=pc>p</div><div id=rc>r</div></div>"
                  "<div id=o>o</div><div id=bb>b</div><div id=t>t</div><div id=tc>c</div><div id=oc>c</div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    // The containing block's padding box is 220 x 120; #a's margin box 32 x 22.
    CHECK_JS_EQ(env.env(), "all(a, ['left', 'top', 'right', 'bottom'])", "0px|0px|188px|98px");
    CHECK_JS_EQ(env.env(), "all(pc, ['left', 'top', 'right', 'bottom'])", "22px|60px|178px|50px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(o).transformOrigin", "60px 30px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(bb).transformOrigin", "50px 20px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(t).transform", "matrix(1, 0, 0, 1, -60, -30)");
    // A translation's calc() mixing a percentage with a length (twidget edit 56): the share of the border box plus it.
    CHECK_JS_EQ(env.env(), "getComputedStyle(tc).transform", "matrix(1, 0, 0, 1, 64, -31)");
    // A calc() mixing a percentage with a length, in a relative offset (the containing block's 200 x 100 content box)
    // and in transform-origin (the border box): its share plus the length.
    CHECK_JS_EQ(env.env(), "all(rc, ['left', 'top'])", "25px|48px");
    CHECK_JS_EQ(env.env(), "getComputedStyle(oc).transformOrigin", "64px 50px");
}

/// Final review I2: an animation or transition longhand reads what the runtime runs (animationSpecs, transitionSpecs):
/// its own declaration, else the shorthand's entries, times in seconds as CSSOM writes them; a box container's
/// justify-content and align-content read what lays it out, so a later place-content wins over an earlier longhand.
WR_TEST(testLonghandsSeeTheirShorthands) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#t{transition:opacity .3s}#a{animation:spin 1s infinite}"
                  "#m{transition:opacity 1s, transform 2s linear 50ms;transition-duration:300ms}"
                  ".bar{display:flex;justify-content:space-between;align-content:space-around}.bar.c{place-content:center}"
                  "#fs{display:flex;justify-content:flex-start;align-content:stretch}#fl{display:flex}"
                  "</style></head><body><div id=t></div><div id=a></div><div id=m></div><div id=c class='bar c'></div>"
                  "<div id=fs></div><div id=fl></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "all(t, ['transition-property', 'transition-duration', 'transition-timing-function', 'transition-delay'])",
                "opacity|0.3s|ease|0s");
    CHECK_JS_EQ(env.env(), "all(a, ['animation-name', 'animation-duration', 'animation-iteration-count', 'animation-direction'])",
                "spin|1s|infinite|normal");
    CHECK_JS_EQ(env.env(), "all(m, ['transition-property', 'transition-duration', 'transition-timing-function', 'transition-delay'])",
                "opacity, transform|0.3s|ease, linear|0s, 0.05s");
    CHECK_JS_EQ(env.env(), "getComputedStyle(m).transition", "opacity 0.3s ease 0s, transform 0.3s linear 0.05s");
    CHECK_JS_EQ(env.env(), "all(c, ['justify-content', 'align-content'])", "center|center");
    CHECK_JS_EQ(env.env(), "all(fs, ['justify-content', 'align-content'])", "flex-start|stretch");
    CHECK_JS_EQ(env.env(), "all(fl, ['justify-content', 'align-content'])", "normal|normal");
}

/// Final review I3: every profile 1 property answered from what the element declares reads a declared value back, never
/// its initial value (an SVG dash from its presentation attribute too). transition-behavior is outside profile 1's
/// property table, so the policy drops its declaration and it reads its initial value.
WR_TEST(testDeclaredValuesReadBack) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#g{display:grid;grid-template-columns:10px 1fr;grid-template-rows:20px;grid-auto-rows:30px;"
                  "grid-auto-columns:40px;grid-auto-flow:column;grid-template-areas:\"a b\"}"
                  "#d{transition-behavior:allow-discrete;counter-increment:c 2;counter-reset:c 1;unicode-bidi:isolate;"
                  "color-scheme:dark;font-feature-settings:\"liga\" 0;font-variant-numeric:tabular-nums;position:relative;"
                  "z-index:3;pointer-events:none;translate:10px;rotate:45deg;scale:2}"
                  "#r{stroke-dasharray:5 3;stroke-dashoffset:2}"
                  "</style></head><body><div id=g></div><div id=d></div><svg width=40 height=40>"
                  "<rect id=r width=10 height=10></rect><rect id=pa stroke-dasharray=4 stroke-dashoffset=3 width=4 height=4></rect></svg>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "all(g, ['grid-template-columns', 'grid-template-rows', 'grid-auto-rows', 'grid-auto-columns', "
                           "'grid-auto-flow', 'grid-template-areas'])",
                "10px 1fr|20px|30px|40px|column|\"a b\"");
    CHECK_JS_EQ(env.env(), "all(d, ['counter-increment', 'counter-reset', 'unicode-bidi', 'color-scheme', "
                           "'font-feature-settings', 'font-variant-numeric', 'z-index', 'pointer-events', 'translate', 'rotate', "
                           "'scale'])",
                "c 2|c 1|isolate|dark|\"liga\" 0|tabular-nums|3|none|10px|45deg|2");
    CHECK_JS_EQ(env.env(), "getComputedStyle(d).transitionBehavior", "normal");
    CHECK_JS_EQ(env.env(), "all(r, ['stroke-dasharray', 'stroke-dashoffset'])", "5px, 3px|2px");
    CHECK_JS_EQ(env.env(), "all(pa, ['stroke-dasharray', 'stroke-dashoffset'])", "4px|3px");
}

/// A declaration litehtml rejects never reads back: z-index reads what litehtml keeps (an integer, else auto), and a
/// non-container's justify-content and align-content read only a keyword of litehtml's tables, else normal.
WR_TEST(testInvalidDeclarationsDoNotReadBack) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#a{position:relative;z-index:abc}#b{position:relative;z-index:1.5}"
                  "#c{position:relative;z-index:2}#c.c{z-index:abc}#z{position:relative;z-index:0}#z.z{z-index:abc}"
                  "#d{justify-content:centre;align-content:middle}#e{justify-content:space-evenly;align-content:space-between}"
                  "</style></head><body><div id=a></div><div id=b></div><div id=c class=c></div><div id=z class=z></div>"
                  "<div id=d></div><div id=e></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "[a, b, c, z].map(e => getComputedStyle(e).zIndex).join('|')", "auto|auto|2|0");
    CHECK_JS_EQ(env.env(), "all(d, ['justify-content', 'align-content'])", "normal|normal");
    CHECK_JS_EQ(env.env(), "all(e, ['justify-content', 'align-content'])", "space-evenly|space-between");
}

/// A computed declaration lists longhands only (CSSOM), so a script copying every listed property one by one never
/// clears what an earlier copy set; the shorthands and the legacy alias stay readable by name.
WR_TEST(testTheListHoldsLonghandsOnly) {
    RenderEnv env("<!doctype html><html><body><div id=a style='border:1px solid red'>a</div>"
                  "<script>window.a = document.getElementById('a');</script></body></html>");
    CHECK_JS_EQ(env.env(), "(() => { const names = [...getComputedStyle(a)]; return [names.includes('border-top-width'),"
                           " ['animation', 'background', 'border', 'border-bottom', 'border-color', 'border-left', 'border-radius',"
                           " 'border-right', 'border-style', 'border-top', 'border-width', 'flex', 'flex-flow', 'font', 'gap',"
                           " 'grid-area', 'grid-column', 'grid-row', 'inset', 'list-style', 'outline', 'place-content',"
                           " 'place-items', 'place-self', 'transition', 'word-wrap'].filter(n => names.includes(n)).join(' ')].join('|'); })()",
                "true|");
    CHECK_JS_EQ(env.env(), "getComputedStyle(a).border", "1px solid rgb(255, 0, 0)");
}

/// A declaration whose var() never resolved is invalid at computed-value time: a non-inherited property reads its
/// initial value, an inherited one its parent's, never the var() as written.
WR_TEST(testAnUnresolvedVarIsInvalidAtComputedTime) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#u{unicode-bidi:var(--nope)}#p{font-feature-settings:\"liga\" 0}#c{font-feature-settings:var(--nope)}"
                  "#g{grid-auto-flow:var(--nope)}"
                  "#f{display:flex}#s{flex-grow:3;flex:var(--nope)}#m{margin-left:10px;margin:var(--nope)}"
                  "</style></head><body><div id=u>u</div><div id=p><div id=c>c</div></div><div id=g>g</div>"
                  "<div id=f><div id=s>s</div></div><div id=m>m</div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "getComputedStyle(u).unicodeBidi", "normal");
    CHECK_JS_EQ(env.env(), "getComputedStyle(c).fontFeatureSettings", "\"liga\" 0");
    CHECK_JS_EQ(env.env(), "getComputedStyle(g).gridAutoFlow", "row");
    // A shorthand's too (twidget edit 57): its longhands are unset, over the earlier flex-grow and margin-left.
    CHECK_JS_EQ(env.env(), "getComputedStyle(s).flexGrow", "0");
    CHECK_JS_EQ(env.env(), "getComputedStyle(m).marginLeft", "0px");
}

/// Spellings as CSSOM writes them: aspect-ratio as declared (16 / 9, not its float over 1), a flex shorthand's omitted
/// basis as 0%, and grid lines side by side as declared, a span on the side it was written on.
WR_TEST(testDeclaredSpellingsReadBack) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#r{aspect-ratio:16/9;width:32px}#q{aspect-ratio:2;width:20px}"
                  "#f{display:flex}#i{flex:1}#j{flex:2 3}#k{flex:1 1 10px}"
                  "#g{display:grid}#a{grid-column:span 2 / 5}#b{grid-row-start:2;grid-row-end:span 3}"
                  "</style></head><body><div id=r></div><div id=q></div><div id=f><div id=i>i</div><div id=j>j</div>"
                  "<div id=k>k</div></div><div id=g><div id=a>a</div><div id=b>b</div></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.cs = e => getComputedStyle(e);</script></body></html>");
    CHECK_JS_EQ(env.env(), "cs(r).aspectRatio + '|' + cs(q).aspectRatio", "16 / 9|2 / 1");
    CHECK_JS_EQ(env.env(), "[i, j, k].map(e => cs(e).flexBasis).join('|')", "0%|0%|10px");
    CHECK_JS_EQ(env.env(), "cs(i).flex", "1 1 0%");
    CHECK_JS_EQ(env.env(), "cs(a).gridColumn + '|' + cs(a).gridArea", "span 2 / 5|auto / span 2 / auto / 5");
    CHECK_JS_EQ(env.env(), "cs(b).gridRow + '|' + cs(b).gridArea", "2 / span 3|2 / auto / span 3");
}

/// Outside the containers and items litehtml computes them for, a flex, gap or place longhand reads litehtml's own parse
/// of the element's declarations, a shorthand's part included, as CSS expands it; the parent's value for inherit; else
/// its initial value. A gap reads normal wherever none is declared, a container included.
WR_TEST(testLonghandsOutsideContainersSeeTheirShorthands) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#n{flex:2}#ni{flex-grow:inherit}#m{flex:none}#k{flex:3 10px}#x{flex-direction:diagonal}"
                  "#g{gap:3px 4px}#h{gap:5px}#o{gap:3px;row-gap:9px}#r{row-gap:9px;gap:3px}#em{font-size:10px;gap:1em 50%}"
                  "#fl{display:flex}#w{flex-flow:column wrap}#p{place-content:center space-between}"
                  "#pn{place-content:normal}#ps{place-content:stretch}#q{place-items:end}#s{place-self:start end}"
                  "</style></head><body><div id=n><div id=ni></div></div><div id=m></div><div id=k></div><div id=x></div>"
                  "<div id=g></div><div id=h></div><div id=o></div><div id=r></div><div id=em></div><div id=fl></div>"
                  "<div id=w></div><div id=p></div><div id=pn></div><div id=ps></div><div id=q></div><div id=s></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "[n, ni, m, k].map(e => all(e, ['flex-grow', 'flex-shrink', 'flex-basis'])).join(' ')",
                "2|1|0% 2|1|auto 0|0|auto 3|1|10px");
    CHECK_JS_EQ(env.env(), "all(x, ['flex-direction'])", "row");
    CHECK_JS_EQ(env.env(), "[g, h, o, r, em, fl].map(e => all(e, ['row-gap', 'column-gap'])).join(' ')",
                "3px|4px 5px|5px 9px|3px 3px|3px 10px|50% normal|normal");
    CHECK_JS_EQ(env.env(), "all(w, ['flex-direction', 'flex-wrap', 'flex-flow'])", "column|wrap|column wrap");
    CHECK_JS_EQ(env.env(), "[p, pn, ps].map(e => all(e, ['align-content', 'justify-content'])).join(' ')",
                "center|space-between normal|normal stretch|stretch");
    CHECK_JS_EQ(env.env(), "all(q, ['align-items', 'justify-items', 'place-items'])", "end|end|end");
    CHECK_JS_EQ(env.env(), "all(s, ['align-self', 'place-self'])", "start|start end");
}

/// justify-content and align-content at litehtml's default read the keyword litehtml applied: `!important` decides
/// between the longhand and place-content as the cascade does, and an animation's value stands over a declaration's
/// (final review I1).
WR_TEST(testContentAtTheDefaultReadsWhatWasApplied) {
    RenderEnv env("<!doctype html><html><head><style>"
                  "#f{display:flex;justify-content:flex-start!important}#f.x{place-content:center}"
                  ".y{place-content:stretch!important}#y{display:flex;justify-content:flex-start}"
                  "#b{justify-content:flex-start!important}#b.x{place-content:normal}#an{display:flex;justify-content:center}"
                  "</style></head><body><div id=f class=x></div><div id=y class=y></div><div id=b class=x></div><div id=an></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "all(f, ['justify-content', 'align-content'])", "flex-start|center");
    CHECK_JS_EQ(env.env(), "all(y, ['justify-content', 'align-content'])", "stretch|stretch");
    CHECK_JS_EQ(env.env(), "all(b, ['justify-content', 'align-content'])", "flex-start|normal");
    CHECK_JS_EQ(env.env(), "(() => { const k = an.animate({justifyContent: ['flex-start', 'flex-start']}, 1000); k.pause();"
                           " k.currentTime = 500; return getComputedStyle(an).justifyContent; })()",
                "flex-start");
}

/// A flex shorthand's omitted basis reads 0% only when that `flex` wrote the basis litehtml applied: a later one wins
/// over an earlier flex-basis, an invalid later one and a refused one (`!important`) do not (final review M1).
WR_TEST(testAnOmittedFlexBasisIsTheAppliedFlexs) {
    RenderEnv env("<!doctype html><html><head><style>#f{display:flex}"
                  "#k{flex-basis:10px}#k.k{flex:1}#j{flex:1 1 0px}#j.j{flex:-1}#i{flex:1!important;flex-basis:5px}"
                  "</style></head><body><div id=f><div id=k class=k></div><div id=j class=j></div><div id=i></div></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "[k, j, i].map(e => getComputedStyle(e).flexBasis).join('|')", "0%|0px|0%");
}

/// gap and place-* are shorthands litehtml expands: a CSS-wide keyword reaches their longhands, and a longhand written
/// after one holding a var() stands once the var() is substituted (final review M2).
WR_TEST(testGapAndPlaceKeywordsReachTheirLonghands) {
    RenderEnv env("<!doctype html><html><head><style>.p{row-gap:7px;column-gap:6px}.c{row-gap:9px}.c.d{gap:inherit}"
                  "#v{--g:3px;gap:var(--g);row-gap:9px}#pc{display:flex;--pc:end;place-content:var(--pc);justify-content:center}"
                  "#pi{display:flex;justify-content:center}#pi.x{place-content:initial}"
                  "</style></head><body><div class=p><div id=c class='c d'></div></div><div id=v></div><div id=pc></div>"
                  "<div id=pi class=x></div><script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "all(c, ['row-gap', 'column-gap'])", "7px|6px");
    CHECK_JS_EQ(env.env(), "all(v, ['row-gap', 'column-gap'])", "9px|3px");
    CHECK_JS_EQ(env.env(), "all(pc, ['align-content', 'justify-content'])", "end|center");
    CHECK_JS_EQ(env.env(), "all(pi, ['align-content', 'justify-content'])", "normal|normal");
}

/// A length litehtml keeps as a calc() (a percentage it cannot resolve yet) reads as CSS writes its computed value,
/// font-relative terms in px (final review M3).
WR_TEST(testACalcLengthReadsAsACalc) {
    RenderEnv env("<!doctype html><html><head><style>#n{font-size:10px;gap:calc(10% + 2em) calc(5px + 50%)}"
                  "#m{gap:min(10%, 30px)}#x{display:flex;gap:calc(10% - 2px)}"
                  "</style></head><body><div id=n></div><div id=m></div><div id=x></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
                  "window.all = (e, ps) => ps.map(p => getComputedStyle(e).getPropertyValue(p)).join('|');</script></body></html>");
    CHECK_JS_EQ(env.env(), "all(n, ['row-gap', 'column-gap'])", "calc(10% + 20px)|calc(50% + 5px)");
    CHECK_JS_EQ(env.env(), "all(m, ['row-gap'])", "min(10%, 30px)");
    CHECK_JS_EQ(env.env(), "all(x, ['row-gap'])", "calc(10% - 2px)");
}

/// A grid line declaration litehtml cannot lay out (an unresolved var(), a name) reads as if absent, as layout treats
/// it (final review M5).
WR_TEST(testAnInvalidGridLineReadsAsAbsent) {
    RenderEnv env("<!doctype html><html><head><style>#g{display:grid}#a{grid-row:var(--nope)}#b{grid-column-start:foo bar}"
                  "#c{grid-column:2 / 4;grid-column-start:foo}"
                  "</style></head><body><div id=g><div id=a></div><div id=b></div><div id=c></div></div>"
                  "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>");
    CHECK_JS_EQ(env.env(), "[getComputedStyle(a).gridRow, getComputedStyle(b).gridColumn, getComputedStyle(c).gridColumn].join('|')",
                "auto|auto|2 / 4");
}
