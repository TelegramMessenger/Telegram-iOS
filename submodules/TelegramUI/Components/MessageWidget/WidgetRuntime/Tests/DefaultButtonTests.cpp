// The default <button> (SDK v1 §2.4; V2b plan, Task 2): a button the widget did not style is drawn from the client's
// button tokens (the root's --tg-button-* variables, the profile's UA stylesheet), and any author CSS overrides it.
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><html><head></head><body><button id=b>Go</button><button id=d disabled>No</button>"
    "<script>window.cs = (id, p) => getComputedStyle(document.getElementById(id))[p];</script></body></html>";

} // namespace

WR_TEST(testAnUnstyledButtonTakesTheTemplatesDefaults) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("cs('b', 'backgroundColor')"), std::string("rgba(51, 144, 236, 0.12)"));
}

WR_TEST(testAnUnstyledButtonTakesTheTokens) {
    RenderEnv env(kPage);
    wr::ThemeButtonTokens tokens;
    tokens.bg = "#112233";
    tokens.text = "#ffffff";
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {}, tokens);
    env.env().drain();
    CHECK_EQ(env.env().eval("[cs('b', 'backgroundColor'), cs('b', 'color')].join(' ')"), std::string("rgb(17, 34, 51) rgb(255, 255, 255)"));
}

WR_TEST(testAuthorCSSOverridesTheButton) {
    RenderEnv env("<!doctype html><html><head><style>button { background: #000 }</style></head><body><button id=b>Go</button>"
                  "<script>window.cs = (id, p) => getComputedStyle(document.getElementById(id))[p];</script></body></html>");
    wr::ThemeButtonTokens tokens;
    tokens.bg = "#112233";
    wr::HostState::of(env.ctx()).setThemeParams(env.ctx(), {}, tokens);
    env.env().drain();
    CHECK_EQ(env.env().eval("cs('b', 'backgroundColor')"), std::string("rgb(0, 0, 0)"));
}

WR_TEST(testADisabledButtonTakesTheDisabledOpacity) {
    RenderEnv env(kPage);
    CHECK_EQ(env.env().eval("[cs('d', 'opacity'), cs('b', 'opacity')].join()"), std::string("0.5,1"));
}
