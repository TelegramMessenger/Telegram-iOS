// Profile 1's attributes in the renderer's copy (V4 plan, Task 5): every attribute rule is applied inside scanAttributes,
// the one reading the build and the attribute patch share, so a patch and a rebuild carry the same attributes; the
// widget's DOM keeps what it wrote.
#include <cstdio>
#include <string>
#include <tuple>

#include "Sources/Render/RenderTree.h"
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
           "window.cs = (id, p) => getComputedStyle($(id)).getPropertyValue(p);</script></body></html>";
}

void expectMatchesRebuild(RenderEnv& env, const char* what) {
    auto [layout, input, tree] = wr_test::rebuildDump(env);
    const bool same = env.render().layoutDump() == layout && env.render().renderInput() == input &&
                      env.render().layerTree()->dump() == tree;
    if (!same) {
        std::printf("    %s: the flush differs from a rebuild\n", what);
    }
    CHECK(same);
}

} // namespace

/// RB §9 (02-attributes-images-a): attributes outside the profile never reach the renderer; the DOM keeps them.
WR_TEST(testOutOfProfileAttributesDoNotReachTheRenderer) {
    RenderEnv env(page("[contenteditable]{color:rgb(1,1,1)} [draggable]{color:rgb(2,2,2)} [tabindex]{color:rgb(3,3,3)}",
                       "<div id=ce contenteditable=true>c</div><div id=dg draggable=true>d</div><div id=ti tabindex=0>t</div>"
                       "<div id=al align=center style='width:200px'>a</div>"
                       "<table id=lt border=4 cellpadding=9><tr><td id=lt-td bgcolor=red>x</td></tr></table>"));
    checkEval(env, "cs('ce', 'color') !== 'rgb(1, 1, 1)'", "true");
    checkEval(env, "cs('dg', 'color') !== 'rgb(2, 2, 2)'", "true");
    checkEval(env, "cs('ti', 'color') !== 'rgb(3, 3, 3)'", "true");
    checkEval(env, "$('ce').getAttribute('contenteditable')", "true");
    checkEval(env, "cs('al', 'text-align') !== 'center'", "true");
    checkEval(env, "cs('lt-td', 'background-color') !== 'rgb(255, 0, 0)'", "true");
    checkEval(env, "cs('lt', 'border-top-width')", "0px");
}

/// RB §9 html.el.a-external: an external href never reaches the renderer; the DOM keeps it, and a tap reads it there.
WR_TEST(testAnExternalLinkRendersAsAFragment) {
    RenderEnv env(page("a.ext[href^=\"https\"]{color:rgb(1,2,3)}",
                       "<a id=aext class=ext href=\"https://example.org/\">x</a>"));
    checkEval(env, "cs('aext', 'color') !== 'rgb(1, 2, 3)'", "true");
    CHECK(env.render().renderInput().find("href=\"#\" data-tg-link=\"\"") != std::string::npos);
    checkEval(env, "$('aext').getAttribute('href')", "https://example.org/");
}

/// RB §1.7: `media` is no profile attribute, so a <style media> sheet applies whatever its media.
WR_TEST(testStyleMediaApplies) {
    RenderEnv env(page("", "<style media=print>p{color:rgb(5,5,5)}</style><p id=p>p</p>"));
    checkEval(env, "cs('p', 'color')", "rgb(5, 5, 5)");
}

/// data-tg-* is the host's: a widget's own never reaches the renderer.
WR_TEST(testAWidgetCannotWriteHostMarkers) {
    RenderEnv env(page("", "<span id=s data-tg-link=\"\" data-tg-tag=x data-ok=1>s</span>"));
    const std::string input = env.render().renderInput();
    CHECK(input.find("data-tg-link") == std::string::npos);
    CHECK(input.find("data-tg-tag") == std::string::npos);
    CHECK(input.find("data-ok=\"1\"") != std::string::npos);
}

/// An href changed through the attribute patch: the link marker comes and goes with the external href, as a rebuild
/// makes it (stateless, where the reference leaves a stale marker: RB §2.5).
WR_TEST(testHrefPatchesMatchARebuild) {
    RenderEnv env(page("", "<a id=a href=\"https://x\">a</a>"));
    for (const char* script : {"$('a').setAttribute('href', '#top')", "$('a').setAttribute('href', 'https://y')",
                               "$('a').removeAttribute('href')"}) {
        env.env().eval(std::string(script) + "; 1");
        env.flush();
        expectMatchesRebuild(env, script);
    }
    CHECK(env.render().renderInput().find("data-tg-link") == std::string::npos);
}
