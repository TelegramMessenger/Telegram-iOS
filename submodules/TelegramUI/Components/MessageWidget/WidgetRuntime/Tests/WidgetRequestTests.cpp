// Requests to the bot, copyText, watchPublicData and previews (widget-sandbox v0.2.2, docs/sdk-v1.md §2.14–§2.16; v0.2 W1
// plan, Task 4), against upstream's engine tests (packages/desktop/tests/test_main.cpp sdk_request_*, sdk_copy_text_*,
// sdk_watch_public_data_*, sdk_preview_*): the vendored RequestGate on the step's clock, one tap per privileged call,
// every outcome settling the promise in a task of its own, and a preview that takes no input and no actions.
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"
#include "twidget/sdk_policy.h"

using wr::PointerPhase;
using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

using Calls = std::vector<std::pair<std::string, std::string>>;

/// `#t` absolutely placed at (10, 10) 100 × 30, so a tap at (50, 25) hits it; `T` is TelegramWidget, `log` a list.
std::string page(const std::string& script) {
    return "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:10px;top:10px;"
           "width:100px;height:30px;display:block}</style></head><body><div id=t>t</div>"
           "<script>window.log = []; const T = TelegramWidget; const t = document.getElementById('t');" +
           script + "</script></body></html>";
}

twidget::WidgetContext context(bool canQuery, bool backgroundQuery, bool preview = false) {
    twidget::WidgetContext context;
    context.canQuery = canQuery;
    context.backgroundQuery = backgroundQuery;
    context.preview = preview;
    context.chatType = "private";
    return context;
}

void pass(RenderEnv& env, const twidget::WidgetContext& context) {
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context);
}

void tap(RenderEnv& env) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 25, 1, true);
    env.env().drain();
}

twidget::WidgetRequestOutcome answer(std::optional<std::string> result) {
    twidget::WidgetRequestOutcome outcome;
    outcome.answer.result = std::move(result);
    return outcome;
}

twidget::WidgetRequestOutcome failure(twidget::WidgetRequestFailure failure) {
    twidget::WidgetRequestOutcome outcome;
    outcome.failure = failure;
    return outcome;
}

void complete(RenderEnv& env, int64_t id, const twidget::WidgetRequestOutcome& outcome) {
    wr::HostState::of(env.ctx()).completeRequest(env.ctx(), id, outcome);
    env.env().drain();
}

size_t diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    size_t n = 0;
    for (const auto& [k, detail] : host.diagnostics) {
        n += k == kind;
    }
    return n;
}

/// Logs each settled request: the answer as JSON and whether it is frozen, or the error's name and code.
constexpr const char* kLogRequest = "const ask = d => T.request(d).then(a => log.push(JSON.stringify(a) + Object.isFrozen(a)), e => log.push(e.name + ':' + e.code));";

} // namespace

WR_TEST(testATapRequestGoesOutAndResolvesWithTheResult) {
    RenderEnv env(page(std::string(kLogRequest) + "t.onclick = () => ask('vote:2');"));
    pass(env, context(true, false));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"vote:2\"]"}}));
    CHECK_EQ(env.env().eval("log.join()"), std::string(""));
    complete(env, 1, answer("ok"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("{\"result\":\"ok\"}true"));
    tap(env);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
    complete(env, 2, answer(std::nullopt));
    CHECK_EQ(env.env().eval("log.join()"), std::string("{\"result\":\"ok\"}true,{\"result\":null}true"));
}

WR_TEST(testBadDataThrowsTypeError) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setContext(env.ctx(), context(true, true));
    CHECK_EQ(env.eval("const r = []; for (const d of [undefined, '', 'x'.repeat(65), 5, '\\uD800']) {"
                      " try { TelegramWidget.request(d); r.push('no'); } catch (e) { r.push(e.constructor.name); } } r.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,TypeError"));
    CHECK(env.host().bridgeCalls.empty());
    CHECK_EQ(diagnosticsOf(env.host(), "request-blocked"), size_t(0));
}

WR_TEST(testRefusalsRejectWithTheirCodes) {
    {
        // No can_query: NOT_ALLOWED, on a tap too.
        RenderEnv env(page(std::string(kLogRequest) + "t.onclick = () => ask('a');"));
        pass(env, context(false, false));
        tap(env);
        CHECK_EQ(env.env().eval("log.join()"), std::string("WidgetRequestError:NOT_ALLOWED"));
        CHECK(env.env().host().bridgeCalls.empty());
        CHECK_EQ(diagnosticsOf(env.env().host(), "request-blocked"), size_t(1));
    }
    {
        // A tap's request only, without background_query.
        RenderEnv env(page(kLogRequest));
        pass(env, context(true, false));
        env.env().eval("ask('a'); 1");
        env.env().drain();
        CHECK_EQ(env.env().eval("log.join()"), std::string("WidgetRequestError:NOT_ALLOWED"));
        CHECK(env.env().host().bridgeCalls.empty());
    }
    {
        // One in flight: the second rejects at once with BUSY, the first still settles.
        RenderEnv env(page(kLogRequest));
        pass(env, context(true, true));
        env.env().eval("ask('a'); ask('b'); 1");
        env.env().drain();
        CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"a\"]"}}));
        CHECK_EQ(env.env().eval("log.join()"), std::string("WidgetRequestError:BUSY"));
        complete(env, 1, answer("ok"));
        CHECK_EQ(env.env().eval("log.join()"), std::string("WidgetRequestError:BUSY,{\"result\":\"ok\"}true"));
    }
}

/// Background requests (background_query): one when the widget appears, then at most one per 5 s from the start of the
/// last one, only while visible; appearing on screen again lets the next out at once.
WR_TEST(testBackgroundRequestsFollowVisibility) {
    RenderEnv env(page(kLogRequest));
    pass(env, context(true, true));
    wr::HostState& host = wr::HostState::of(env.ctx());
    env.env().eval("ask('a'); 1");
    env.env().drain();
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"a\"]"}}));
    complete(env, 1, answer("ok"));
    env.env().eval("ask('b'); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log[1]"), std::string("WidgetRequestError:RATE_LIMITED"));
    env.env().advance(5000);
    env.env().eval("ask('c'); 1");
    env.env().drain();
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
    CHECK(env.env().host().bridgeCalls.back() == (std::pair<std::string, std::string>{"request", "[\"3\",\"c\"]"}));
    complete(env, 3, answer("ok"));
    // widget-sandbox v0.3.0: one made off screen is held, and is the request of the widget's next appearance.
    host.setVisible(env.ctx(), false);
    env.env().drain();
    env.env().eval("ask('d'); 1");
    env.env().drain();
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
    CHECK_EQ(env.env().eval("String(log.length)"), std::string("3"));
    host.setVisible(env.ctx(), true);
    env.env().drain();
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(3));
    CHECK(env.env().host().bridgeCalls.back() == (std::pair<std::string, std::string>{"request", "[\"4\",\"d\"]"}));
    complete(env, 4, answer("ok"));
    CHECK_EQ(env.env().eval("String(log.length)"), std::string("4"));
    // It was this appearance's: the next one waits the 5 s.
    env.env().eval("ask('e'); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log[4]"), std::string("WidgetRequestError:RATE_LIMITED"));
    env.env().advance(5000);
    env.env().eval("ask('f'); 1");
    env.env().drain();
    CHECK(env.env().host().bridgeCalls.back() == (std::pair<std::string, std::string>{"request", "[\"6\",\"f\"]"}));
}

/// widget-sandbox v0.3.0, sdk-v1 §2.14: a background request made while the widget is hidden (the clients make the host
/// off screen, so a widget's first lines run hidden) waits for it to appear, holding the one-in-flight slot: a second is
/// BUSY, a task later; a tap's request while it waits is BUSY too.
WR_TEST(testABackgroundRequestOffScreenWaitsForTheWidgetToAppear) {
    RenderEnv env(page(std::string(kLogRequest) + "t.onclick = () => ask('tap');"));
    pass(env, context(true, true));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.setVisible(env.ctx(), false);
    env.env().drain();
    env.env().eval("ask('boot'); ask('again'); 1");
    CHECK_EQ(env.env().eval("String(log.length)"), std::string("0"));
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("WidgetRequestError:BUSY"));
    CHECK(env.env().host().bridgeCalls.empty());
    host.setVisible(env.ctx(), true);
    env.env().drain();
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"boot\"]"}}));
    tap(env);
    CHECK_EQ(env.env().eval("log[1]"), std::string("WidgetRequestError:BUSY"));
    complete(env, 1, answer("fresh"));
    CHECK_EQ(env.env().eval("log[2]"), std::string("{\"result\":\"fresh\"}true"));
}

/// A widget that stops before it appears never sends its held request.
WR_TEST(testAHeldRequestIsNeverSentAfterAStop) {
    RenderEnv env(page(kLogRequest));
    pass(env, context(true, true));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.setVisible(env.ctx(), false);
    env.env().drain();
    env.env().eval("ask('boot'); 1");
    env.env().drain();
    env.env().runtime().stop(wr::StopReason::Internal);
    host.setVisible(env.ctx(), true);
    env.env().drain();
    CHECK(env.env().host().bridgeCalls.empty());
}

WR_TEST(testFailuresRejectWithTheirCodes) {
    RenderEnv env(page(std::string(kLogRequest) + "t.onclick = () => ask('a');"));
    pass(env, context(true, false));
    tap(env);
    complete(env, 1, failure(twidget::WidgetRequestFailure::Timeout));
    tap(env);
    complete(env, 2, failure(twidget::WidgetRequestFailure::RateLimited));
    tap(env);
    complete(env, 3, failure(twidget::WidgetRequestFailure::Failed));
    tap(env);
    complete(env, 4, answer(std::string(1025, 'a')));
    CHECK_EQ(env.env().eval("log.join()"),
             std::string("WidgetRequestError:TIMEOUT,WidgetRequestError:RATE_LIMITED,WidgetRequestError:FAILED,WidgetRequestError:INVALID_ANSWER"));
    CHECK_EQ(diagnosticsOf(env.env().host(), "answer-rejected"), size_t(1));
    // Each outcome freed the gate: the next tap's request goes out.
    tap(env);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(5));
}

/// Upstream's shim words each rejection (globals.ts, requestError: `request: ` and the words for the refusal's reason or
/// the code), and makes it as `new Error(message)` does: the message the error's own and not enumerable.
WR_TEST(testErrorsCarryTheShimsWords) {
    constexpr const char* kLogMessage = "const say = p => p.then(a => log.push('ok'), e => log.push(e.message));";
    {
        RenderEnv env(page(std::string(kLogMessage) + "t.onclick = () => say(T.request('a'));"));
        pass(env, context(false, false));
        tap(env);
        CHECK_EQ(env.env().eval("log.join('|')"), std::string("request: requests are off for this message (the bot did not allow them here)"));
    }
    {
        RenderEnv env(page(kLogMessage));
        pass(env, context(true, true, true));
        env.env().eval("say(T.request('a')); 1");
        env.env().drain();
        CHECK_EQ(env.env().eval("log.join('|')"), std::string("request: a preview (an inline result not sent yet) cannot ask the bot"));
    }
    {
        RenderEnv env(page(kLogMessage));
        pass(env, context(true, false));
        env.env().eval("say(T.request('a')); say(T.request('b', { wallet: true })); 1");
        env.env().drain();
        CHECK_EQ(env.env().eval("log.join('|')"),
                 std::string("request: it needs a tap on the widget and runs in that tap's handler, one call per tap; background requests only "
                             "where the client allows them (the private chat with the bot)|"
                             "request: the client has no wallet for this user (TelegramWidget.wallet is null)"));
    }
    {
        RenderEnv env(page(kLogMessage));
        pass(env, context(true, true));
        env.env().eval("say(T.request('a')); say(T.request('b')); 1");
        env.env().drain();
        complete(env, 1, answer("ok"));
        env.env().eval("say(T.request('c')); 1");
        env.env().drain();
        CHECK_EQ(env.env().eval("log.join('|')"), std::string("request: a request is already in flight; wait for its answer|ok|"
                                                              "request: too many requests (background requests at most once per 5 s); try again later"));
    }
    {
        RenderEnv env(page(std::string(kLogMessage) + "t.onclick = () => say(T.request('a'));"));
        pass(env, context(true, false));
        tap(env);
        complete(env, 1, failure(twidget::WidgetRequestFailure::Timeout));
        tap(env);
        complete(env, 2, failure(twidget::WidgetRequestFailure::RateLimited));
        tap(env);
        complete(env, 3, failure(twidget::WidgetRequestFailure::Failed));
        tap(env);
        complete(env, 4, failure(twidget::WidgetRequestFailure::Rejected));
        tap(env);
        complete(env, 5, answer(std::string(1025, 'a')));
        CHECK_EQ(env.env().eval("log.join('|')"),
                 std::string("request: the bot did not answer in time|"
                             "request: too many requests (background requests at most once per 5 s); try again later|"
                             "request: the client could not deliver the request|request: the client could not deliver the request|"
                             "request: the bot's answer broke the limits (a result over 1024 bytes, or not text)"));
    }
    {
        RenderEnv env(page("t.onclick = () => T.request('a').catch(e => { window.e = e; });"));
        pass(env, context(false, false));
        tap(env);
        CHECK_EQ(env.env().eval("[e instanceof Error, Object.keys(e).join(), Object.getOwnPropertyDescriptor(e, 'message').enumerable, e.name, e.code,"
                                " String(e).startsWith('WidgetRequestError: request: ')].join()"),
                 std::string("true,name,code,false,WidgetRequestError,NOT_ALLOWED,true"));
    }
}

WR_TEST(testAnAnswerForAnUnknownIdIsIgnored) {
    RenderEnv env(page(std::string(kLogRequest) + "t.onclick = () => ask('a');"));
    pass(env, context(true, false));
    tap(env);
    complete(env, 99, answer("stray"));
    CHECK_EQ(env.env().eval("log.join()"), std::string(""));
    complete(env, 1, answer("ok"));
    CHECK_EQ(env.env().eval("log.join()"), std::string("{\"result\":\"ok\"}true"));
    complete(env, 1, answer("again"));
    CHECK_EQ(env.env().eval("log.length"), std::string("1"));
}

WR_TEST(testCopyTextOnATap) {
    RenderEnv env(page("t.onclick = () => T.copyText('PROMO-42');"));
    pass(env, context(false, false));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{{"copyText", "[\"PROMO-42\"]"}}));
    env.env().eval("T.copyText('x'); 1");
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(1));
    CHECK_EQ(diagnosticsOf(env.env().host(), "activation-blocked"), size_t(1));
    CHECK_EQ(env.env().eval("const r = []; for (const s of ['', 'a'.repeat(257), 5, undefined]) {"
                            " try { T.copyText(s); r.push('no'); } catch (e) { r.push(e.constructor.name); } } r.join()"),
             std::string("TypeError,TypeError,TypeError,TypeError"));
}

/// One tap, one privileged call (sdk-v1 §2.14): a handler that asks and then copies copies nothing.
WR_TEST(testOneTapUnlocksOneCall) {
    RenderEnv env(page("t.onclick = () => { T.request('a').catch(() => {}); T.copyText('b'); };"));
    pass(env, context(true, false));
    tap(env);
    CHECK(env.env().host().bridgeCalls == (Calls{{"request", "[\"1\",\"a\"]"}}));
    CHECK_EQ(diagnosticsOf(env.env().host(), "activation-blocked"), size_t(1));
}

WR_TEST(testWatchPublicDataPostsOnlyChanges) {
    HostEnv env;
    CHECK_EQ(env.eval("const W = TelegramWidget; [W.watchPublicData(), W.watchPublicData(), W.unwatchPublicData(), W.unwatchPublicData()].length"), std::string("4"));
    CHECK(env.host().bridgeCalls == (Calls{{"watchPublicData", "[\"true\"]"}, {"watchPublicData", "[\"false\"]"}}));
    CHECK(!wr::HostState::of(env.ctx()).watchesPublicData());
}

/// sdk-v1 §2.16: a preview takes no input and no actions (only ready and setResizeAnchor), and its storage is never
/// preloaded or committed.
WR_TEST(testAPreviewRefusesEverythingButReadyAndTheAnchor) {
    RenderEnv env(page("t.onclick = () => log.push('click');"));
    env.env().host().storedAreas["local"] = {{"a", "1"}};
    pass(env, context(true, true, true));
    env.env().eval("T.request('a').catch(e => log.push(e.code)); T.copyText('x'); T.openLink('https://example.org');"
                   "T.HapticFeedback.selectionChanged(); T.watchPublicData(); T.setResizeAnchor('bottom'); T.ready(); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("NOT_ALLOWED"));
    CHECK(env.env().host().bridgeCalls == (Calls{{"ready", "[]"}}));
    CHECK_EQ(diagnosticsOf(env.env().host(), "preview-blocked"), size_t(5));
    CHECK(wr::HostState::of(env.ctx()).resizeAnchor() == wr::ResizeAnchor::Bottom);
    tap(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("NOT_ALLOWED"));
    CHECK_EQ(env.env().eval("localStorage.setItem('k', 'v'); [localStorage.getItem('k'), localStorage.getItem('a')].join()"), std::string("v,"));
    env.env().drain();
    CHECK(env.env().host().storageCommits.empty());
}

WR_TEST(testRefusalDiagnosticsAreCapped) {
    RenderEnv env(page(""));
    pass(env, context(false, false));
    env.env().eval("for (let i = 0; i < 25; i++) T.request('a').catch(() => {}); 1");
    env.env().drain();
    CHECK_EQ(diagnosticsOf(env.env().host(), "request-blocked"), size_t(20));
}
