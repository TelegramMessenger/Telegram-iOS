// The widget's state and where it is (widget-sandbox v0.2.2, docs/sdk-v1.md §2.13; v0.2 W1 plan, Task 3):
// TelegramWidget's chatData, publicData, isForward, chatType, viewer and isPreview, and the chatDataChanged /
// publicDataChanged events, as the host passes them (HostState::setContext, setInitialData, setData), checked by the
// vendored SDK policy and stripped as upstream's glue strips them (packages/ios SandboxEngine.widgetContext).
#include <optional>
#include <string>
#include <utility>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "twidget/sdk_policy.h"

using wr_test::HostEnv;

namespace {

twidget::WidgetViewer ann() {
    twidget::WidgetViewer viewer;
    viewer.id = 42;
    viewer.firstName = "Ann";
    viewer.lastName = "Lee";
    viewer.username = "ann_lee";
    viewer.isPremium = true;
    return viewer;
}

/// The original in the private chat with the bot (WIDGET_MESSAGE_KINDS.private), with Ann as the viewer.
twidget::WidgetContext privateContext() {
    twidget::WidgetContext context;
    context.canQuery = true;
    context.backgroundQuery = true;
    context.chatType = "private";
    context.viewer = ann();
    return context;
}

twidget::WidgetData state(std::optional<std::string> chatData, std::optional<std::string> publicData) {
    twidget::WidgetData data;
    data.chatData = std::move(chatData);
    data.publicData = std::move(publicData);
    return data;
}

void pass(HostEnv& env, const twidget::WidgetContext& context, const twidget::WidgetData& data) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.setContext(env.ctx(), context);
    host.setInitialData(env.ctx(), data);
}

std::vector<std::string> diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    std::vector<std::string> details;
    for (const auto& [k, detail] : host.diagnostics) {
        if (k == kind) {
            details.push_back(detail);
        }
    }
    return details;
}

constexpr const char* kSnapshot = "const W = TelegramWidget; [W.chatData, W.publicData, W.isForward, W.chatType, W.isPreview, JSON.stringify(W.viewer)].join('|')";

} // namespace

WR_TEST(testWithoutStateOrContext) {
    HostEnv env;
    CHECK_EQ(env.eval(kSnapshot), std::string("||false||false|null"));
    CHECK_EQ(env.eval("[TelegramWidget.chatData === null, TelegramWidget.publicData === null, TelegramWidget.chatType === null, TelegramWidget.viewer === null].join()"),
             std::string("true,true,true,true"));
}

WR_TEST(testTheStateAndContextAsPassed) {
    HostEnv env;
    pass(env, privateContext(), state("chat", "public"));
    CHECK_EQ(env.eval(kSnapshot),
             std::string("chat|public|false|private|false|{\"id\":42,\"first_name\":\"Ann\",\"last_name\":\"Lee\",\"username\":\"ann_lee\",\"is_premium\":true}"));
    CHECK_EQ(env.eval("[Object.isFrozen(TelegramWidget.viewer), TelegramWidget.viewer === TelegramWidget.viewer].join()"), std::string("true,true"));
    CHECK(diagnosticsOf(env.host(), "data-rejected").empty());
}

/// A forward is told nothing about the chat it is in and never has the chat state; it knows no viewer unless it may ask.
WR_TEST(testACopyNeverSeesChatData) {
    HostEnv env;
    twidget::WidgetContext context = privateContext();
    context.isCopy = true;
    context.canQuery = false;
    context.backgroundQuery = false;
    pass(env, context, state("secret", "p"));
    CHECK_EQ(env.eval(kSnapshot), std::string("|p|true||false|null"));
    CHECK_EQ(env.eval("TelegramWidget.chatData === null && TelegramWidget.chatType === null"), std::string("true"));
    // The server never copies the chat state: dropping it is silent.
    CHECK(diagnosticsOf(env.host(), "data-rejected").empty());
}

WR_TEST(testALiveCopyKnowsItsViewerButNotItsChat) {
    HostEnv env;
    twidget::WidgetContext context = privateContext();
    context.isCopy = true;
    context.backgroundQuery = false;
    context.chatType = "group";
    pass(env, context, state(std::nullopt, "p"));
    CHECK_EQ(env.eval("[TelegramWidget.isForward, TelegramWidget.chatType, TelegramWidget.viewer.id].join()"), std::string("true,,42"));
}

WR_TEST(testAWidgetThatMayNotAskHasNoViewer) {
    HostEnv env;
    twidget::WidgetContext context = privateContext();
    context.canQuery = false;
    context.backgroundQuery = false;
    context.chatType = "group";
    pass(env, context, state("c", std::nullopt));
    CHECK_EQ(env.eval("[TelegramWidget.viewer === null, TelegramWidget.chatType, TelegramWidget.chatData].join()"), std::string("true,group,c"));
}

/// An inline result before it is sent: its state, nothing about the user, and its flags ignored.
WR_TEST(testAPreviewKnowsNothingAboutTheUser) {
    HostEnv env;
    twidget::WidgetContext context = privateContext();
    context.isCopy = true;
    context.preview = true;
    pass(env, context, state("c", "p"));
    CHECK_EQ(env.eval(kSnapshot), std::string("c|p|false||true|null"));
    CHECK(wr::HostState::of(env.ctx()).isPreview());
}

WR_TEST(testMalformedStateIsNullAndReported) {
    {
        HostEnv env;
        pass(env, privateContext(), state(std::string("\xff\xfe"), std::string(1025, 'a')));
        CHECK_EQ(env.eval("[TelegramWidget.chatData === null, TelegramWidget.publicData === null].join()"), std::string("true,true"));
        const std::vector<std::string> details = diagnosticsOf(env.host(), "data-rejected");
        CHECK_EQ(details.size(), size_t(1));
        if (!details.empty()) {
            CHECK_EQ(details[0], std::string("chatData and publicData: not text of at most 1024 bytes (UTF-8, no NUL); the widget sees null"));
        }
    }
    {
        HostEnv env;
        pass(env, privateContext(), state(std::string("a\0b", 3), std::string("ok")));
        CHECK_EQ(env.eval("[TelegramWidget.chatData === null, TelegramWidget.publicData].join()"), std::string("true,ok"));
        CHECK_EQ(diagnosticsOf(env.host(), "data-rejected").size(), size_t(1));
    }
    {
        HostEnv env;
        twidget::WidgetContext context = privateContext();
        context.viewer->username = "ab";
        pass(env, context, state(std::nullopt, std::nullopt));
        CHECK_EQ(env.eval("JSON.stringify(TelegramWidget.viewer)"), std::string("{\"id\":42,\"first_name\":\"Ann\",\"last_name\":\"Lee\",\"is_premium\":true}"));
        const std::vector<std::string> details = diagnosticsOf(env.host(), "data-rejected");
        CHECK_EQ(details.size(), size_t(1));
        if (!details.empty()) {
            CHECK_EQ(details[0], std::string("viewer.username: not 5–32 characters of A–Z, a–z, 0–9 and _; the widget does not see it"));
        }
    }
}

/// The empty string is how the bot clears a field: the widget sees null, and nothing is reported.
WR_TEST(testTheEmptyStringClearsAField) {
    HostEnv env;
    pass(env, privateContext(), state(std::string(), std::string("p")));
    CHECK_EQ(env.eval("[TelegramWidget.chatData === null, TelegramWidget.publicData].join()"), std::string("true,p"));
    CHECK(diagnosticsOf(env.host(), "data-rejected").empty());
}

/// sdk-v1 §2.13: a change fires chatDataChanged, then publicDataChanged, each only for a value that changed, both in one
/// task, with the new values already in place; nothing restarts.
WR_TEST(testAStateChangeFiresItsEventsInOrderWithoutRestarting) {
    HostEnv env;
    pass(env, privateContext(), state("c1", "p"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    env.eval("var log = []; window.mark = 7; const W = TelegramWidget;"
             "for (const t of ['chatDataChanged', 'publicDataChanged']) W.onEvent(t, () => log.push(t + ':' + W.chatData + '/' + W.publicData)); 1");
    host.setData(env.ctx(), state("c2", "p"));
    env.drain();
    CHECK_EQ(env.eval("log.join()"), std::string("chatDataChanged:c2/p"));
    host.setData(env.ctx(), state("c3", "p3"));
    env.step();
    CHECK_EQ(env.eval("log.join()"), std::string("chatDataChanged:c2/p,chatDataChanged:c3/p3,publicDataChanged:c3/p3"));
    host.setData(env.ctx(), state("c3", "p3"));
    env.drain();
    CHECK_EQ(env.eval("log.length"), std::string("3"));
    CHECK_EQ(env.eval("window.mark"), std::string("7"));
}

WR_TEST(testACopyNeverFiresChatDataChanged) {
    HostEnv env;
    twidget::WidgetContext context = privateContext();
    context.isCopy = true;
    pass(env, context, state(std::nullopt, "p1"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    env.eval("var log = []; for (const t of ['chatDataChanged', 'publicDataChanged']) TelegramWidget.onEvent(t, () => log.push(t)); 1");
    host.setData(env.ctx(), state("x", "p1"));
    env.drain();
    CHECK_EQ(env.eval("log.join()"), std::string(""));
    host.setData(env.ctx(), state("y", "p2"));
    env.drain();
    CHECK_EQ(env.eval("[log.join(), TelegramWidget.chatData === null, TelegramWidget.publicData].join('|')"), std::string("publicDataChanged|true|p2"));
}

WR_TEST(testTheStateMembersAreReadOnly) {
    HostEnv env;
    pass(env, privateContext(), state("c1", "p1"));
    CHECK_EQ(env.eval("TelegramWidget.chatData = 'x'; TelegramWidget.publicData = 'y'; TelegramWidget.chatType = 'channel'; [TelegramWidget.chatData, TelegramWidget.publicData, TelegramWidget.chatType].join()"),
             std::string("c1,p1,private"));
}

/// widget-sandbox v0.2.0's "Element members stay their element's" (docs/changes.md): an inline handler finds the
/// widget's own functions, not another element's members (a button outside a form has no `reset`, a div no `show`).
WR_TEST(testAnInlineHandlerFindsTheWidgetsOwnFunctions) {
    HostEnv env;
    CHECK_EQ(env.eval("function reset() { window.log1 = 'global'; } function show() { window.log2 = 'global'; }"
                      "document.body.innerHTML = '<button id=b onclick=\"reset()\"></button><div id=d onclick=\"show()\"></div>';"
                      "document.getElementById('b').click(); document.getElementById('d').click(); [window.log1, window.log2].join()"),
             std::string("global,global"));
}

/// Upstream's inputs wait for its boot (sandbox_engine.cpp: setData's bridge input is posted behind boot(), which runs
/// the scripts and the load): a change the host makes while the boot's tasks run is put in place after the load, the
/// scripts reading the state the boot started with.
WR_TEST(testAStateChangeDuringTheBootWaitsForTheLoad) {
    std::unique_ptr<HostEnv> env = HostEnv::booted(
        wr::BootOptions{"<!doctype html><html><body><script>var log = [];"
                        "TelegramWidget.onEvent('chatDataChanged', () => log.push('changed:' + TelegramWidget.chatData + ':' + document.readyState));"
                        "</script><script>log.push('script:' + TelegramWidget.chatData)</script></body></html>"},
        1, [](HostEnv& env) { pass(env, privateContext(), state("c1", "p")); });
    wr::HostState& host = wr::HostState::of(env->ctx());
    CHECK(env->step() == wr::StepResult::Ran);
    host.setData(env->ctx(), state("c2", "p"));
    host.setData(env->ctx(), state("c3", "p"));
    env->drain();
    CHECK_EQ(env->eval("log.join()"), std::string("script:c1,changed:c2:complete,changed:c3:complete"));
    // After the load a change is a task at once.
    host.setData(env->ctx(), state("c4", "p"));
    env->step();
    CHECK_EQ(env->eval("log.length"), std::string("4"));
}
