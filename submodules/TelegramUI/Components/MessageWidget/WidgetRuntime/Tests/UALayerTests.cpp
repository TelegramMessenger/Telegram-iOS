// widget-sandbox v0.1.1's UA layer (`tables.uaStylesheet`, generated into the master sheet as a layer above litehtml's
// own rules, twidget edit 41): what a widget with no CSS gets, and that every author rule beats it, a later longhand
// over one of the layer's var() shorthands included (v0.1.1 plan, Task 2; Review Focus 2).
#include <cstdio>
#include <string>

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
    return "<!doctype html><html><head><style>" + css + "</style></head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.cs = (id, p) => getComputedStyle(id === 'body' ? document.body : $(id)).getPropertyValue(p);</script>"
           "</body></html>";
}

} // namespace

/// The body's margin is the padding token (its reference default `8px 12px` here, with no tokens passed), not
/// litehtml's or the host's 8px.
WR_TEST(testTheBodyMarginIsThePaddingToken) {
    RenderEnv env(page("", "<p id=p>p</p>"));
    checkEval(env, "[cs('body', 'margin-top'), cs('body', 'margin-right'), cs('body', 'padding-top')].join()", "8px,12px,0px");
}

/// Every author rule beats the layer, whatever its specificity: a shorthand, a later longhand over the layer's var()
/// shorthand, the root's font, a button's padding.
WR_TEST(testAuthorRulesBeatTheLayer) {
    RenderEnv zero(page("body{margin:0}", "<p id=p>p</p>"));
    checkEval(zero, "[cs('body', 'margin-top'), cs('body', 'margin-left')].join()", "0px,0px");
    RenderEnv top(page("body{margin-top:3px}", "<p id=p>p</p>"));
    checkEval(top, "[cs('body', 'margin-top'), cs('body', 'margin-left')].join()", "3px,12px");
    RenderEnv font(page("html{font:12px serif}", "<p id=p>p</p>"));
    checkEval(font, "cs('p', 'font-size')", "12px");
    RenderEnv button(page("button{padding:0}", "<button id=b>b</button>"));
    checkEval(button, "[cs('b', 'padding-top'), cs('b', 'padding-left')].join()", "0px,0px");
}
