// Links (V2a plan, Task 5; widget-sandbox v0.1.0 docs/sdk-v1.md §2.5, packages/core/src/shared/sdk-policy.ts checkLink,
// packages/core/src/host/user-activation.ts): openLink and openTelegramLink check and normalise the URL and throw
// TypeError for an invalid one; a valid call reaches the host only from a trusted pointer press's dispatch, one call
// per press, and is otherwise dropped with `activation-blocked`; `<a href>` and window.open route by host and ignore
// what neither method takes with `navigation-blocked`.
#include <string>
#include <utility>
#include <vector>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

using Calls = std::vector<std::pair<std::string, std::string>>;

// `#t` at (10, 10) 100 × 30; the ids become globals.
std::string page(const std::string& body, const std::string& script = "") {
    return "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:10px;top:10px;"
           "width:100px;height:30px;display:block}</style></head><body>" +
           body + "<script>window.log = []; for (const e of document.querySelectorAll('[id]')) window[e.id] = e;" + script +
           "</script></body></html>";
}

void tapAt(RenderEnv& env, double x = 50, double y = 25) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, x, y, 1, true);
    env.env().drain();
}

size_t diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    size_t n = 0;
    for (const auto& [k, detail] : host.diagnostics) {
        n += k == kind;
    }
    return n;
}

const char* const kThrows = "window.throwsType = (f, u) => { try { f(u); return false } catch (e) { return e instanceof TypeError } };";

} // namespace

WR_TEST(testOpenLinkRejectsWhatTheRulesRefuse) {
    HostEnv env;
    env.eval(kThrows);
    CHECK_EQ(env.eval("const pad = n => 'https://example.org/' + 'a'.repeat(n - 20);"
                      "['http://example.org/', 'javascript:alert(1)', 'https://user:pw@example.org/', 'https://t.me/telegram',"
                      " 'https://sub.telegram.dog/x', 'example.org', 'tg://resolve?domain=telegram', pad(257), 'https://exa mple.org/',"
                      " 'https://example.org/a b', 'https://example.org/%zz', 'https://example.org/<', 'https://example.org:99999/',"
                      " 'https://example.org:/', 'https://-a.org/', 'https://a..org/', 'https:///x', 'https://ex\\u212Aample.org/',"
                      " 'https://example.org/\\ud800', 42, undefined, { toString() { return 'https://example.org/' } }]"
                      ".filter(u => !throwsType(u => TelegramWidget.openLink(u), u)).length"),
             std::string("0"));
    CHECK_EQ(env.eval("[pad(256), 'https://example.org', 'https://EXAMPLE.org:443/a?b#c', 'https://xn--e1afmkfd.xn--p1ai/']"
                      ".filter(u => throwsType(u => TelegramWidget.openLink(u), u)).length"),
             std::string("0"));
}

WR_TEST(testOpenTelegramLinkTakesOnlyTelegramHosts) {
    HostEnv env;
    env.eval(kThrows);
    CHECK_EQ(env.eval("['https://t.me/telegram', 'https://telegram.me/x?start=1', 'https://T.ME/Path', 'https://sub.t.me/',"
                      " 'https://telegram.dog/a']"
                      ".filter(u => throwsType(u => TelegramWidget.openTelegramLink(u), u)).length"),
             std::string("0"));
    CHECK_EQ(env.eval("['https://example.org/', 'tg://resolve?domain=telegram', 'http://t.me/x', 'https://t.me.example.org/',"
                      " 'https://nott.me/']"
                      ".filter(u => !throwsType(u => TelegramWidget.openTelegramLink(u), u)).length"),
             std::string("0"));
}

/// The URL the host gets: scheme and host lowercase, non-ASCII after the host as UTF-8 escapes; the limit counts the
/// normalised URL.
WR_TEST(testTheHostGetsTheNormalisedUrl) {
    RenderEnv env(page("<button id=t>b</button>",
                       "t.onclick = () => TelegramWidget.openLink('HTTPS://Example.ORG:8443/\\u00c4?q=\\u00e9#\\u{1F600}');"));
    tapAt(env);
    const Calls expected = {{"openLink", "[\"https://example.org:8443/%C3%84?q=%C3%A9#%F0%9F%98%80\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
    CHECK_EQ(env.env().eval(std::string(kThrows) +
                            "throwsType(u => TelegramWidget.openLink(u), 'https://example.org/' + '\\u00e9'.repeat(79))"),
             std::string("true"));
}

/// One press unlocks one call, shared by both methods; outside a press a valid call is dropped with a diagnostic.
WR_TEST(testOnePressUnlocksOneCall) {
    RenderEnv env(page("<button id=t>b</button>",
                       "t.onclick = () => { TelegramWidget.openLink('https://example.org/1'); TelegramWidget.openTelegramLink('https://t.me/2');"
                       " TelegramWidget.openLink('https://example.org/3'); };"
                       "TelegramWidget.openLink('https://example.org/boot');"));
    CHECK(env.env().host().bridgeCalls.empty());
    CHECK_EQ(diagnosticsOf(env.env().host(), "activation-blocked"), size_t(1));
    tapAt(env);
    tapAt(env);
    const Calls expected = {{"openLink", "[\"https://example.org/1\"]"}, {"openLink", "[\"https://example.org/1\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
    CHECK_EQ(diagnosticsOf(env.env().host(), "activation-blocked"), size_t(5));
}

/// The press's own task only: its listeners and the promise jobs they leave (the final review's I1: the reference's
/// settle drains them inside the task, with the gesture), not a timer, a frame, a scripted click() outside it, or a
/// touch event's listener.
WR_TEST(testOnlyThePressesOwnTaskCarriesIt) {
    RenderEnv env(page("<button id=t>b</button><button id=u style=\"position:absolute;left:10px;top:100px;width:50px;height:20px\">u</button>",
                       "const open = s => () => TelegramWidget.openLink('https://example.org/' + s);"
                       "t.addEventListener('touchstart', open('touch'));"
                       "t.addEventListener('click', () => { Promise.resolve().then(open('promise')); setTimeout(open('timer'), 0);"
                       " requestAnimationFrame(open('frame')); });"
                       "u.addEventListener('click', open('u'));"
                       "setTimeout(() => u.click(), 0);"));
    tapAt(env);
    env.env().advance(20);
    const Calls promised = {{"openLink", "[\"https://example.org/promise\"]"}};
    CHECK(env.env().host().bridgeCalls == promised);
    // A finger's pointerdown is no gesture (widget-sandbox v0.3.0, the finger rule): its call is blocked. The click keeps
    // the press, and the first listener's promise job, run at the checkpoint after that listener, takes it before the
    // later listener's call.
    env.env().eval("t.addEventListener('pointerdown', open('down')); t.addEventListener('click', open('click')); 1");
    tapAt(env);
    const Calls expected = {{"openLink", "[\"https://example.org/promise\"]"}, {"openLink", "[\"https://example.org/promise\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
}

/// An async click handler opens its link after an await, as on the reference.
WR_TEST(testAnAsyncHandlerKeepsThePress) {
    RenderEnv env(page("<button id=t>b</button>",
                       "t.onclick = async () => { await Promise.resolve(); await null; TelegramWidget.openLink('https://example.org/a'); };"));
    tapAt(env);
    const Calls expected = {{"openLink", "[\"https://example.org/a\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
}

/// A press on a hidden widget unlocks nothing, and the diagnostic is reported at most 20 times.
WR_TEST(testAHiddenWidgetAndTheDiagnosticCap) {
    RenderEnv env(page("<button id=t>b</button>", "t.onclick = () => TelegramWidget.openLink('https://example.org/');"));
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    env.env().drain();
    tapAt(env);
    CHECK(env.env().host().bridgeCalls.empty());
    env.env().eval("for (let i = 0; i < 40; i++) TelegramWidget.openLink('https://example.org/'); 1");
    CHECK_EQ(diagnosticsOf(env.env().host(), "activation-blocked"), size_t(20));
}

/// A link tap routes by host; what neither method takes is ignored with navigation-blocked; a fragment is nothing.
WR_TEST(testLinksRouteByHost) {
    for (const auto& [href, call] : std::vector<std::pair<std::string, std::string>>{
             {"https://example.org/a", "openLink [\"https://example.org/a\"]"},
             {" https://T.me/x ", "openTelegramLink [\"https://t.me/x\"]"},
             {"http://example.org/", "navigation-blocked"},
             {"javascript:void 0", "navigation-blocked"},
             {"/relative", "navigation-blocked"},
             {"#top", ""},
         }) {
        RenderEnv env(page("<a id=t href=\"" + href + "\">a</a>"));
        tapAt(env);
        const wr_test::TestHost& host = env.env().host();
        std::string got = host.bridgeCalls.empty() ? std::string() : host.bridgeCalls[0].first + " " + host.bridgeCalls[0].second;
        if (got.empty() && diagnosticsOf(host, "navigation-blocked") == 1) {
            got = "navigation-blocked";
        }
        CHECK_EQ(got, call);
    }
}

/// window.open takes the same route (from a press) and returns null.
WR_TEST(testWindowOpenRoutesAndReturnsNull) {
    RenderEnv env(page("<button id=t>b</button>",
                       "t.onclick = () => log.push(window.open('https://t.me/s'), window.open('http://x/'), window.open());"));
    tapAt(env);
    const Calls expected = {{"openTelegramLink", "[\"https://t.me/s\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
    CHECK_EQ(env.env().eval("log.map(String).join()"), std::string("null,null,null"));
    CHECK_EQ(diagnosticsOf(env.env().host(), "navigation-blocked"), size_t(1));
}
