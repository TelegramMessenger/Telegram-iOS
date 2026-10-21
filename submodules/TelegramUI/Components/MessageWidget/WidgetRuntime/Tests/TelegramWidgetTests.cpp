// TelegramWidget, SDK v1 (V2a plan, Task 3; widget-sandbox v0.1.0 docs/sdk-v1.md §2.1, §2.7, §2.11): profile,
// colorScheme and its alias theme, isActive, onEvent/offEvent for themeChanged, activated and deactivated (16 handlers
// per type), onTheme as onEvent('themeChanged') that also calls back at once; sendMessage and on are gone. onTheme's
// callbacks are a list of their own, as in the reference (packages/core/src/sandbox/globals.ts at the tag): 16 of them
// beside the 16 onEvent handlers, run after those, with the colour scheme.
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testTheV1Members) {
    HostEnv env;
    CHECK_EQ(env.eval("const W = TelegramWidget; [W.profile, W.isProfileAtLeast(1), W.isProfileAtLeast(999), W.isProfileAtLeast('1'),"
                      " W.colorScheme, W.theme, W.isActive, typeof W.sendMessage, typeof W.on, typeof W.ready].join()"),
             std::string("1,true,false,false,light,light,true,undefined,undefined,function"));
}

WR_TEST(testOnThemeCallsBackAtOnceAndOnEveryChange) {
    HostEnv env;
    CHECK_EQ(env.eval("window.seen = []; TelegramWidget.onTheme(t => seen.push(t)); seen.join()"), std::string("light"));
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("seen.join() + ':' + TelegramWidget.colorScheme + ':' + TelegramWidget.theme"), std::string("light,dark:dark:dark"));
}

WR_TEST(testOnEventHandlersRunWithTheWidgetAsThisAndNoArguments) {
    HostEnv env;
    env.eval("window.log = []; window.h = function () { log.push([this === TelegramWidget, arguments.length, TelegramWidget.colorScheme].join(':')); };"
             "TelegramWidget.onEvent('themeChanged', h); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("log.join()"), std::string("true:0:dark"));
    env.eval("TelegramWidget.offEvent('themeChanged', h); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Light);
    env.drain();
    CHECK_EQ(env.eval("log.length"), std::string("1"));
}

WR_TEST(testUnknownTypesAndNonFunctionsAreIgnored) {
    HostEnv env;
    CHECK_EQ(env.eval("const W = TelegramWidget; W.onEvent('noSuchEvent', () => {}); W.onEvent('themeChanged', 42);"
                      "W.offEvent('noSuchEvent', 1); W.onEvent(); W.offEvent(); 'ok'"),
             std::string("ok"));
}

WR_TEST(testSixteenHandlersPerType) {
    HostEnv env;
    env.eval("window.n = 0; for (let i = 0; i < 20; i++) TelegramWidget.onEvent('themeChanged', () => n++); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("n"), std::string("16"));
}

/// conformance 20-client-behaviour: 21 themeChanged handlers, then onTheme, whose callback must still run.
WR_TEST(testOnThemeHasItsOwnListRunAfterTheHandlers) {
    HostEnv env;
    env.eval("window.log = []; for (let i = 0; i < 20; i++) TelegramWidget.onEvent('themeChanged', () => log.push('e'));"
             "TelegramWidget.onTheme(t => log.push(t)); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("log.filter(x => x === 'e').length + ':' + log.filter(x => x !== 'e').join() + ':' + log[log.length - 1]"),
             std::string("16:light,dark:dark"));
}

WR_TEST(testOnThemeKeepsSixteenAndCallsOnlyThoseAtOnce) {
    HostEnv env;
    CHECK_EQ(env.eval("window.n = 0; for (let i = 0; i < 20; i++) TelegramWidget.onTheme(() => n++); n"), std::string("16"));
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("n"), std::string("32"));
}

WR_TEST(testTheSameHandlerIsAddedOnce) {
    HostEnv env;
    env.eval("window.n = 0; window.h = () => n++; TelegramWidget.onEvent('themeChanged', h); TelegramWidget.onEvent('themeChanged', h); 1");
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), wr::Theme::Dark);
    env.drain();
    CHECK_EQ(env.eval("n"), std::string("1"));
}

WR_TEST(testActivatedAndDeactivatedFollowVisibility) {
    HostEnv env;
    env.eval("window.log = []; document.addEventListener('visibilitychange', () => log.push('visibility:' + document.visibilityState));"
             "TelegramWidget.onEvent('deactivated', () => log.push('deactivated:' + TelegramWidget.isActive));"
             "TelegramWidget.onEvent('activated', () => log.push('activated:' + TelegramWidget.isActive)); 1");
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    env.drain();
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), true);
    env.drain();
    CHECK_EQ(env.eval("log.join()"), std::string("visibility:hidden,deactivated:false,visibility:visible,activated:true"));
}
