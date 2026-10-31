// The TelegramWidget bridge (M1d plan, Task 4): calls posted to the host as (method, argsJson), the theme the chat
// reports, and the events the host sends in. The link rules and user activation are LinksTests'.
#include <string>
#include <utility>
#include <vector>

#include "Sources/Host/HostState.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

using Calls = std::vector<std::pair<std::string, std::string>>;

} // namespace

WR_TEST(testBridgeCallsReachTheHost) {
    HostEnv env;
    // SDK v1 §2.10: alert and the clipboard reach nothing (InertApisTests); outside a press a link is dropped (§2.5).
    CHECK_EQ(env.eval("TelegramWidget.openLink('https://x.org/'); TelegramWidget.ready();"
                      "window.open('https://y.org/'); alert(1); navigator.clipboard.writeText('c') instanceof Promise"),
             std::string("true"));
    const Calls expected = {{"ready", "[]"}};
    CHECK(env.host().bridgeCalls == expected);
    CHECK_EQ(env.eval("confirm('x')"), std::string("false"));
    CHECK(env.host().bridgeCalls == expected);
}

WR_TEST(testOnThemeRunsOnAThemeChange) {
    RenderEnv env("<!doctype html><html><head></head><body><script>window.seen = [];"
                  "TelegramWidget.onTheme(t => seen.push(t + ':' + TelegramWidget.theme));</script></body></html>");
    CHECK_EQ(env.env().eval("TelegramWidget.theme"), std::string("light"));
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    // onTheme calls back at once (SDK v1 §2.1), then on the change.
    CHECK_EQ(env.env().eval("seen.join()"), std::string("light:light,dark:dark"));
    CHECK_EQ(env.env().eval("TelegramWidget.theme"), std::string("dark"));
    // The task's flush patched the document into the dark scheme (twidget edit 80).
    CHECK(env.render().patchCount() > patches);
    CHECK_EQ(env.render().buildCount(), builds);
    // The same theme again changes nothing and runs no callback.
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.env().drain();
    CHECK_EQ(env.env().eval("seen.length"), std::string("2"));
}

WR_TEST(testTelegramWidgetIsUnforgeable) {
    HostEnv env;
    CHECK_EQ(env.eval("delete window.TelegramWidget"), std::string("false"));
    CHECK_EQ(env.eval("window.TelegramWidget = 1; typeof TelegramWidget"), std::string("object"));
    CHECK_EQ(env.eval("TelegramWidget === window.TelegramWidget"), std::string("true"));
    CHECK_EQ(env.eval("typeof window.TelegramWidgetConstructor"), std::string("undefined"));
}

WR_TEST(testCallbackListsAreBounded) {
    HostEnv env;
    // SDK v1 §2.11: 16 handlers per type, further ones ignored without an exception; onTheme keeps 16 of its own.
    CHECK_EQ(env.eval("window.n = 0; for (let i = 0; i < 20; i++) TelegramWidget.onTheme(() => n++); n"), std::string("16"));
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("n"), std::string("32"));
}
