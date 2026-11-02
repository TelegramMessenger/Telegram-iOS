// widget-sandbox v0.4.0, the content safe area's SDK and host input (sdk-v1 §2.17, §3 `safeArea`, §5.12):
// TelegramWidget.contentSafeAreaInset, frozen and the same object until a change; a change lays out at the call (the
// renderer's variables) and then, in one never-deferred `safeArea` task, gives a fresh object and fires
// contentSafeAreaChanged once; an equal value is nothing; a change during the boot waits for its load.
#include <cstdio>
#include <string>

#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/CpuLimits.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::StepResult;
using wr_test::HostEnv;
using wr_test::RenderEnv;
using wr_test::ScopedCpuLimits;
using wr_test::ScopedFakeClock;

namespace {

void checkEval(HostEnv& env, const std::string& code, const std::string& want) {
    const std::string got = env.eval(code);
    if (got != want) {
        std::printf("    %s\n    got  %s\n    want %s\n", code.c_str(), got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

wr::ContentSafeArea band(double bottom, double cornerRight) {
    wr::ContentSafeArea area;
    area.bottom = bottom;
    area.cornerRight = cornerRight;
    return area;
}

/// An unstyled page (the UA layer pads the body by the band) that logs the event with what it then reads.
std::string page(const std::string& script = "") {
    return "<!doctype html><html><head></head><body><p>text</p><script>window.log = [];"
           "TelegramWidget.onEvent('contentSafeAreaChanged', function () { log.push('changed:' + this.contentSafeAreaInset.bottom + ':' +"
           " getComputedStyle(document.documentElement).getPropertyValue('--tg-content-safe-area-inset-bottom').trim()); });" +
           script + "</script></body></html>";
}

} // namespace

/// The host's value before the boot is the boot's: in the object from the first script on, with no event.
WR_TEST(testTheInitialSafeAreaIsTheBootsWithNoEvent) {
    RenderEnv env(page("log.push('boot:' + TelegramWidget.contentSafeAreaInset.bottom);"), {}, true, [](HostEnv& env) {
        wr::HostState::of(env.ctx()).setInitialContentSafeArea(env.ctx(), band(24, 64));
    });
    checkEval(env.env(), "log.join()", "boot:24");
    checkEval(env.env(), "JSON.stringify(TelegramWidget.contentSafeAreaInset)",
              "{\"top\":0,\"right\":0,\"bottom\":24,\"left\":0,\"cornerLeft\":0,\"cornerRight\":64}");
    checkEval(env.env(), "(a => Object.isFrozen(a) && a === TelegramWidget.contentSafeAreaInset)(TelegramWidget.contentSafeAreaInset)", "true");
}

/// A change: the renderer's variables at the call (the body's padding laid out), then one task with a fresh frozen
/// object and one event, the variables already set.
WR_TEST(testAChangeLaysOutAtTheCallThenFiresOnceInATask) {
    RenderEnv env(page("window.first = TelegramWidget.contentSafeAreaInset;"));
    const double before = env.render().documentHeight();
    wr::HostState::of(env.ctx()).setContentSafeArea(env.ctx(), band(24, 64));
    CHECK_EQ(env.render().documentHeight() - before, 24.0);
    checkEval(env.env(), "[TelegramWidget.contentSafeAreaInset.bottom, TelegramWidget.contentSafeAreaInset === first, log.length].join()", "0,true,0");
    env.env().drain();
    checkEval(env.env(), "log.join()", "changed:24:24px");
    checkEval(env.env(), "(a => [a.bottom, a.cornerRight, a === first, Object.isFrozen(a), a === TelegramWidget.contentSafeAreaInset].join())"
                         "(TelegramWidget.contentSafeAreaInset)",
              "24,64,false,true,true");
}

/// The same value again is nothing: no layout, no task, no event; nor is one equal once checked.
WR_TEST(testAnEqualChangeIsNothing) {
    RenderEnv env(page());
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.setContentSafeArea(env.ctx(), band(24, 64));
    env.env().drain();
    host.setContentSafeArea(env.ctx(), band(24.001, 64));
    CHECK(!wr::EventLoop::of(env.ctx()).hasRunnableTask(env.env().host().now));
    env.env().drain();
    checkEval(env.env(), "log.join()", "changed:24:24px");
}

/// The client's input, never the widget's: not deferred while the JS quota is spent (a timer is).
WR_TEST(testAChangeIsNotDeferredByTheQuota) {
    ScopedCpuLimits limits(wr::CpuLimits{});
    ScopedFakeClock clock(0.0);
    RenderEnv env(page("setTimeout(() => burn(300), 0); setTimeout(() => log.push('timer'), 0);"), {}, true,
                  [](HostEnv& env) { wr_test::installClockNatives(env); });
    checkEval(env.env(), "log.join()", "");
    wr::HostState::of(env.ctx()).setContentSafeArea(env.ctx(), band(24, 64));
    env.env().drain();
    checkEval(env.env(), "log.join()", "changed:24:24px");
}

/// A stopped widget takes nothing: no layout, no task.
WR_TEST(testAStoppedWidgetTakesNoChange) {
    RenderEnv env(page());
    const double before = env.render().documentHeight();
    env.env().runtime().stop(wr::StopReason::Internal);
    wr::HostState::of(env.ctx()).setContentSafeArea(env.ctx(), band(24, 64));
    CHECK_EQ(env.render().documentHeight(), before);
    CHECK(!wr::EventLoop::of(env.ctx()).hasRunnableTask(env.env().host().now));
}

/// Upstream's inputs wait for its boot: a change while the boot's tasks run lays out at once, but the object and the
/// event come after the load, in order with the state changes.
WR_TEST(testAChangeDuringTheBootWaitsForTheLoad) {
    RenderEnv env(page("TelegramWidget.onEvent('contentSafeAreaChanged', () => log.push(document.readyState));"), {}, false);
    wr::HostState& host = wr::HostState::of(env.ctx());
    CHECK(env.env().step() == StepResult::Ran);
    const double before = env.render().documentHeight();
    host.setContentSafeArea(env.ctx(), band(24, 64));
    CHECK_EQ(env.render().documentHeight() - before, 24.0);
    checkEval(env.env(), "[TelegramWidget.contentSafeAreaInset.bottom, document.readyState].join()", "0,loading");
    env.env().drain();
    checkEval(env.env(), "log.join()", "changed:24:24px,complete");
}
