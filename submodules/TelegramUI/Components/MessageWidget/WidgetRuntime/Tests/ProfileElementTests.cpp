// Profile 1's elements in the renderer's copy (V4 plan, Task 4): one decision (renderTagFor) for every site a build and
// a patch read the element at, so an element is kept, rendered as a span or a div with data-tg-tag, or dropped with its
// subtree, alike in a rebuild, a patch and the render input; the widget's DOM keeps the element as it wrote it.
#include <cstdio>
#include <string>
#include <tuple>

#include <litehtml.h>

#include "Sources/Render/Builder.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/WidgetContainer.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

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
    return "<!doctype html><html><head><style>body{margin:0}" + css + "</style></head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.cs = (id, p) => getComputedStyle($(id)).getPropertyValue(p);"
           "window.box = id => { const r = $(id).getBoundingClientRect(); return [r.x, r.y, r.width, r.height].join(); };"
           "</script></body></html>";
}

/// The three dumps a flush published, each as a fresh rebuild of the same DOM makes them.
void expectMatchesRebuild(RenderEnv& env, const char* what) {
    auto [layout, input, tree] = wr_test::rebuildDump(env);
    const bool same = env.render().layoutDump() == layout && env.render().renderInput() == input &&
                      env.render().layerTree()->dump() == tree;
    if (!same) {
        std::printf("    %s: the flush differs from a rebuild\n", what);
    }
    CHECK(same);
}

/// The render input laid out through litehtml's own parser, as RenderBuildTests' build-path parity does.
std::string parsedLayout(RenderEnv& env) {
    wr::WidgetContainer container(env.host(), env.render().options());
    std::string out;
    {
        litehtml::document::ptr parsed = litehtml::document::createFromString(
            litehtml::estring(env.render().renderInput()), &container, wr::masterWithHostCSS(env.render().options().hostCSS));
        parsed->render(litehtml::pixel_t(float(env.render().options().width)));
        out = wr::dumpLayout(*parsed);
    }
    return out;
}

} // namespace

/// Decision 1, RB §9 html.el.forms and html.el.progress-meter: a dropped element has no box and no computed style; the
/// DOM keeps it.
WR_TEST(testDroppedElementsHaveNoBox) {
    RenderEnv env(page("", "<progress id=prog value=.5></progress><meter id=meter value=.5></meter><input id=i>"
                           "<select id=s><option>o</option></select><textarea id=t>a</textarea>"
                           "<fieldset id=f><legend>l</legend></fieldset><p id=p>p</p>"));
    for (const char* id : {"prog", "meter", "i", "s", "t", "f"}) {
        checkEval(env, std::string("box('") + id + "').split(',').slice(2).join()", "0,0");
    }
    checkEval(env, "cs('prog', 'color')", "");
    checkEval(env, "$('prog').tagName", "PROGRESS");
    checkEval(env, "String(document.querySelectorAll('input').length)", "1");
    checkEval(env, "box('p').split(',')[3] > 0", "true");
}

/// RB §9 html.el.legacy, html.el.unknown and html.el.dialog-popover: a renamed element is an inert span or div.
WR_TEST(testRenamedElementsLoseTheirUAStyle) {
    RenderEnv env(page(".conf{font:13px/16px sans-serif} my-widget{color:rgb(200,0,0);display:block}",
                       "<div class=conf><center id=center>c</center><font id=font color=red>f</font>"
                       "<big id=big>b</big><tt id=tt>t</tt><strike id=strike>s</strike>"
                       "<div style='width:30px'><nobr id=nobr>no break here</nobr></div><my-widget id=mw>m</my-widget>"
                       "<div id=h style='position:relative;height:30px'><dialog id=dlg>m</dialog></div></div>"));
    checkEval(env, "cs('center', 'text-align') !== 'center'", "true");
    checkEval(env, "cs('font', 'color') !== 'rgb(255, 0, 0)'", "true");
    checkEval(env, "cs('big', 'font-size')", "13px");
    checkEval(env, "cs('tt', 'font-family').includes('monospace')", "false");
    checkEval(env, "cs('strike', 'text-decoration-line')", "none");
    checkEval(env, "$('nobr').getBoundingClientRect().height > 20", "true");
    checkEval(env, "cs('mw', 'color') !== 'rgb(200, 0, 0)'", "true");
    checkEval(env, "cs('mw', 'display')", "inline");
    checkEval(env, "box('dlg').split(',')[1] === box('h').split(',')[1]", "true");
    checkEval(env, "$('font').tagName + ',' + $('mw').tagName", "FONT,MY-WIDGET");
}

/// The render input names what the build made, so litehtml's own parser of it lays out the same document.
WR_TEST(testTheRenderInputCarriesTheRenderedTag) {
    RenderEnv env(page("", "<font id=f>x</font><center>c</center><progress></progress>"
                           "<svg width=20 height=20><defs><linearGradient id=g><stop offset=0 stop-color=red></stop>"
                           "</linearGradient></defs><rect width=10 height=10 fill='url(#g)'></rect></svg>"));
    const std::string input = env.render().renderInput();
    CHECK(input.find("<span data-tg-tag=\"font\"") != std::string::npos);
    CHECK(input.find("<div data-tg-tag=\"center\"") != std::string::npos);
    CHECK(input.find("<linearGradient") != std::string::npos);
    CHECK(input.find("<progress") == std::string::npos);
    expectMatchesRebuild(env, "markup");
    CHECK_EQ(env.render().layoutDump(), parsedLayout(env));
}

/// Review Focus 2: a presentational attribute on a renamed element is inert through a patch as through a rebuild.
WR_TEST(testAPresentationalAttributeChangeOnARenamedElementMatchesARebuild) {
    RenderEnv env(page("", "<font id=f color=red>x</font>"));
    env.env().eval("$('f').setAttribute('color', 'blue'); 1");
    env.flush();
    expectMatchesRebuild(env, "color changed");
    checkEval(env, "cs('f', 'color') !== 'rgb(255, 0, 0)' && cs('f', 'color') !== 'rgb(0, 0, 255)'", "true");
}

/// Plan OP8: an SVG <title> is kept, and draws nothing.
WR_TEST(testAnSVGTitleIsKeptAndDrawsNothing) {
    RenderEnv env(page("", "<svg width=40 height=40><title>tip</title><rect width=40 height=40 fill='#00f'></rect></svg>"));
    CHECK(wr_test::findText(*env.render().layerTree(), "tip") == nullptr);
}

/// RB §1.5: "dropped with its subtree" is positional; a node moved out of the dropped element renders.
WR_TEST(testAnElementMovedOutOfADroppedOneRenders) {
    RenderEnv env(page("", "<video><span id=s>x</span></video>"));
    checkEval(env, "box('s').split(',')[3]", "0");
    env.env().eval("document.body.append($('s')); 1");
    env.flush();
    checkEval(env, "box('s').split(',')[3] > 0", "true");
    expectMatchesRebuild(env, "moved out");
}

/// RB §1.4: only the document's own html, head and body are themselves; another body renders as a div. Appended to the
/// document element, it patches through the root's replacement (twidget edit 82).
WR_TEST(testASecondBodyIsADiv) {
    RenderEnv env(page("", "<p>x</p>"));
    const uint64_t builds = env.render().buildCount();
    env.env().eval("document.documentElement.append(document.createElement('body')); 1");
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().renderInput().find("<div data-tg-tag=\"body\"") != std::string::npos);
    expectMatchesRebuild(env, "a second body appended to the document element");
}

/// Ruling E6's cap counts what litehtml makes a control of, by the rendered tag: only <button> is left.
WR_TEST(testFormControlsCountByTheRenderedTag) {
    std::string inputs;
    std::string buttons;
    for (int i = 0; i < 300; i++) {
        inputs += "<input>";
        buttons += "<button>b</button>";
    }
    RenderEnv many(page("", inputs));
    for (const std::string& limit : many.render().renderLimits()) {
        CHECK(limit != "form-controls");
    }
    RenderEnv pressed(page("", buttons));
    bool noted = false;
    for (const std::string& limit : pressed.render().renderLimits()) {
        noted = noted || limit == "form-controls";
    }
    CHECK(noted);
}
