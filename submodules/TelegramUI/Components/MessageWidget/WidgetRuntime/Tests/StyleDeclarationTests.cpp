// CSSOM's inline style declaration block (`element.style`): the declarations are the style attribute's, every change
// writes the attribute back serialized, and the render tree restyles from it.
#include <algorithm>
#include <chrono>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string page(const std::string& body) {
    return "<!doctype html><html><head><style>body{margin:0;padding:0}</style></head><body>" + body +
           // The window's named properties wait for M2: the ids become globals here.
           "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;</script></body></html>";
}

} // namespace

WR_TEST(testStyleReadsTheAttribute) {
    RenderEnv env(page("<div id=t style='color: red; WIDTH:10px ! important;'></div>"));
    CHECK_EQ(env.env().eval("t.style === t.style"), std::string("true"));
    CHECK_EQ(env.env().eval("t.style.length"), std::string("2"));
    CHECK_EQ(env.env().eval("t.style.item(0) + ',' + t.style[1] + ',' + t.style.item(2) + ',' + t.style[2]"),
             std::string("color,width,,undefined"));
    CHECK_EQ(env.env().eval("t.style.getPropertyValue('width') + '|' + t.style.getPropertyPriority('width')"),
             std::string("10px|important"));
    CHECK_EQ(env.env().eval("t.style.color + '|' + t.style.width + '|' + t.style.backgroundColor"), std::string("red|10px|"));
    CHECK_EQ(env.env().eval("t.style.cssText"), std::string("color: red; width: 10px !important;"));
    CHECK_EQ(env.env().eval("[...t.style].join()"), std::string("color,width"));
    // The attribute changed by other means is what the block reads next.
    CHECK_EQ(env.env().eval("t.setAttribute('style', 'top: 1px'); t.style.cssText"), std::string("top: 1px;"));
}

WR_TEST(testAttributesWriteTheAttribute) {
    RenderEnv env(page("<div id=t></div>"));
    CHECK_EQ(env.env().eval("t.style.backgroundColor = 'blue'; t.getAttribute('style')"),
             std::string("background-color: blue;"));
    CHECK_EQ(env.env().eval("t.style['background-color']"), std::string("blue"));
    CHECK_EQ(env.env().eval("t.style['background-color'] = 'green'; t.style.backgroundColor"), std::string("green"));
    CHECK_EQ(env.env().eval("t.style.width = '5px'; t.style.width = '7px'; t.getAttribute('style')"),
             std::string("background-color: green; width: 7px;"));
    CHECK_EQ(env.env().eval("t.style.backgroundColor = ''; t.getAttribute('style')"), std::string("width: 7px;"));
    CHECK_EQ(env.env().eval("t.style.cssFloat = 'left'; t.style.getPropertyValue('float')"), std::string("left"));
    CHECK_EQ(env.env().eval("t.style.webkitLineClamp = '2'; t.style.WebkitLineClamp"), std::string("2"));
    CHECK_EQ(env.env().eval("t.style.width = null; t.style.width"), std::string(""));
    CHECK_EQ(env.env().eval("'width' in t.style && !('nonsense' in t.style) && !Object.keys(t.style).includes('width')"),
             std::string("true"));
}

WR_TEST(testSetPropertyAndRemoveProperty) {
    RenderEnv env(page("<div id=t></div>"));
    CHECK_EQ(env.env().eval("t.style.setProperty('--Accent', ' #f00 '); t.style.getPropertyValue('--Accent')"),
             std::string("#f00"));
    CHECK_EQ(env.env().eval("t.style.getPropertyValue('--accent')"), std::string(""));
    CHECK_EQ(env.env().eval("t.style.setProperty('COLOR', 'green', 'IMPORTANT'); t.style.getPropertyPriority('color')"),
             std::string("important"));
    // A priority other than "important", an unsupported property and an invalid value are ignored.
    CHECK_EQ(env.env().eval("t.style.setProperty('color', 'red', 'bogus'); t.style.color"), std::string("green"));
    CHECK_EQ(env.env().eval("t.style.setProperty('nonsense-property', '1'); t.style.length"), std::string("2"));
    CHECK_EQ(env.env().eval("t.style.setProperty('color', 'red; top: 0'); t.style.color"), std::string("green"));
    CHECK_EQ(env.env().eval("t.style.setProperty('color', 'red !important'); t.style.color"), std::string("green"));
    CHECK_EQ(env.env().eval("t.style.removeProperty('COLOR') + '|' + t.style.length"), std::string("green|1"));
    CHECK_EQ(env.env().eval("t.style.removeProperty('top') + '|' + t.style.length"), std::string("|1"));
    CHECK_EQ(env.env().eval("t.style.setProperty('--Accent', ''); t.getAttribute('style')"), std::string(""));
}

WR_TEST(testCssTextAndPutForwards) {
    RenderEnv env(page("<div id=t style='color: red'></div>"));
    // Assigning `style` assigns cssText ([PutForwards=cssText]). Unsupported names, empty values and stray semicolons
    // are dropped; of two declarations of one property, the later wins, at its place.
    CHECK_EQ(env.env().eval("t.style = 'margin: 0; bogus: 1; ; width:5px; top: ; margin: 2px'; t.style.cssText"),
             std::string("width: 5px; margin: 2px;"));
    CHECK_EQ(env.env().eval("t.getAttribute('style')"), std::string("width: 5px; margin: 2px;"));
    CHECK_EQ(env.env().eval("t.style.cssText = ''; t.getAttribute('style')"), std::string(""));
    // Strings and comments do not end a declaration.
    CHECK_EQ(env.env().eval("t.setAttribute('style', \"content: 'a;b'; /* x; y */ color: red\");"
                            "t.style.length + '|' + t.style.content + '|' + t.style.color"),
             std::string("2|'a;b'|red"));
    CHECK_EQ(env.env().eval("t.style.cssText = 'background: url(\"x;y.png\") ; color : blue'; t.style.background"),
             std::string("url(\"x;y.png\")"));
}

WR_TEST(testAStyleChangeRestylesTheLayout) {
    RenderEnv env(page("<div id=t style='width: 100px; height: 10px'></div>"));
    wr::Node* t = wr::DOMState::of(env.ctx()).document().getElementById(env.ctx(), wr::String::fromUTF8(env.ctx(), "t"));
    CHECK(t != nullptr);
    env.flush();
    CHECK(env.render().borderBox(*t).has_value() && env.render().borderBox(*t)->width == 100);
    CHECK_EQ(env.env().eval("t.style.width = '200px'; 1"), std::string("1"));
    env.flush();
    CHECK(env.render().borderBox(*t).has_value() && env.render().borderBox(*t)->width == 200);
}

WR_TEST(testSVGElementsHaveStyle) {
    RenderEnv env(page("<svg><circle id=c r=5></circle></svg>"));
    CHECK_EQ(env.env().eval("c.style.strokeDasharray = '4 2'; c.getAttribute('style')"),
             std::string("stroke-dasharray: 4 2;"));
}

/// The best of three runs of three `style` reads of `t`, whose style attribute holds `n` distinct custom properties.
static double secondsToReadStyle(RenderEnv& env, int n) {
    env.env().eval("t.setAttribute('style', Array.from({length: " + std::to_string(n) + "}, (_, i) => '--p' + i + ': 0').join(';')); 1");
    double best = 1e9;
    for (int run = 0; run < 3; run++) {
        auto start = std::chrono::steady_clock::now();
        CHECK_EQ(env.env().eval("t.style.length + t.style.length + t.style.length"), std::to_string(3 * n));
        best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
    }
    return best;
}

// Every access parses the attribute, and a widget can read it in a loop: the parse is linear in the declarations
// (final review I2: deduplicating them by a scan of the kept ones was quadratic and charged as linear). 4x the
// declarations in at most 8x the time.
WR_TEST(testStyleParsingIsLinear) {
    RenderEnv env(page("<div id=t></div>"));
    const double smallTime = secondsToReadStyle(env, 5000);
    const double largeTime = secondsToReadStyle(env, 20000);
    CHECK(largeTime <= 8 * smallTime + 0.01);
}
