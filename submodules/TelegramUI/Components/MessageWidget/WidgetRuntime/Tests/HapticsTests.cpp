// Haptics (V2a plan, Task 6; widget-sandbox v0.2.2 docs/sdk-v1.md §2.6, the vendored SDK policy's HapticGate):
// TelegramWidget.HapticFeedback's three methods return it for chaining and throw TypeError for an unknown style or type.
// A call is posted as `haptic` only while the widget is visible, under the rate limit (5 in a burst, 10 per second), and
// with a touch (v0.2.2): while a finger is down on the widget and for 5 s after it is lifted; outside one, the first call
// opens a series whose first second plays, then nothing until the next touch, or 10 s after the series began. The press
// and its release are the primary pointer's (TapState's down, up and cancel); every time is the step's clock.
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

size_t diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    size_t n = 0;
    for (const auto& [k, detail] : host.diagnostics) {
        n += k == kind;
    }
    return n;
}

/// `#t` at (10, 10) 100 × 30, so a pointer at (50, 25) presses it.
const char* const kPad = "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:10px;top:10px;"
                         "width:100px;height:30px;display:block}</style></head><body><div id=t>t</div></body></html>";

void press(RenderEnv& env, PointerPhase phase) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), phase, 50, 25, 1, true);
    env.env().drain();
}

/// Moves the virtual clock to `ms` and plays `count` haptics in one script there.
void playAt(HostEnv& env, double ms, int count) {
    env.advance(ms - env.host().now);
    env.eval("for (let i = 0; i < " + std::to_string(count) + "; i++) TelegramWidget.HapticFeedback.selectionChanged(); 1");
}

} // namespace

WR_TEST(testTheMethodsChainAndPostTheirArguments) {
    HostEnv env;
    CHECK_EQ(env.eval("const H = TelegramWidget.HapticFeedback; [H === TelegramWidget.HapticFeedback,"
                      " H.impactOccurred('light') === H, H.notificationOccurred('success') === H, H.selectionChanged() === H].join()"),
             std::string("true,true,true,true"));
    const Calls expected = {{"haptic", "[\"impact\",\"light\"]"}, {"haptic", "[\"notification\",\"success\"]"}, {"haptic", "[\"selection\"]"}};
    CHECK(env.host().bridgeCalls == expected);
}

WR_TEST(testAnUnknownStyleOrTypeThrows) {
    HostEnv env;
    CHECK_EQ(env.eval("const H = TelegramWidget.HapticFeedback; const t = f => { try { f(); return 'no' } catch (e) { return e.constructor.name } };"
                      "[t(() => H.impactOccurred('huge')), t(() => H.impactOccurred()), t(() => H.impactOccurred({ toString: () => 'light' })),"
                      " t(() => H.notificationOccurred('oops')), t(() => H.notificationOccurred('error'))].join()"),
             std::string("TypeError,TypeError,TypeError,TypeError,no"));
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(1));
}

/// The Android bug's timer (widget-sandbox v0.2.2): without a touch the first call opens a series; its first second plays
/// under the bucket (5 of a burst), later calls are dropped, and the next series waits 10 s from the first's start.
WR_TEST(testWithoutATouchOneSecondThenNothing) {
    HostEnv env;
    playAt(env, 0, 20);
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(5));
    playAt(env, 1200, 3);
    playAt(env, 2500, 3);
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(5));
    CHECK(diagnosticsOf(env.host(), "haptic-limit") >= size_t(1));
    playAt(env, 10500, 1);
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(6));
}

/// The gate reads the step's clock (EventLoop::currentTime), never the host's live one: a burst inside one task sees no
/// refill however long it runs (conformance limit.haptic-rate failed once on a slow run of the live clock).
WR_TEST(testTheGateReadsTheStepsClock) {
    HostEnv env;
    playAt(env, 0, 20);
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(5));
    // The host's clock moved, the loop's has not (no step or script since): within the series' first second, nothing
    // is back yet.
    env.host().now += 200;
    CHECK(!wr::HostState::of(env.ctx()).admitHaptic(env.ctx()));
}

/// A finger down on the widget, and 5 s after its lift: haptics play under the rate limit alone.
WR_TEST(testDuringATouchTheBucketRules) {
    RenderEnv env(kPad);
    press(env, PointerPhase::Down);
    playAt(env.env(), 0, 20);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(5));
    playAt(env.env(), 2000, 3);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(8));
    press(env, PointerPhase::Up);
    // 2 s and 4.5 s after the lift: still the touch's window, not a 1 s series.
    playAt(env.env(), 4000, 1);
    playAt(env.env(), 6500, 1);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(10));
}

/// After a series, a tap lets the next one start before the 10 s: the press and its release reach the gate.
WR_TEST(testATouchAllowsTheNextSeries) {
    RenderEnv env(kPad);
    playAt(env.env(), 0, 1);
    playAt(env.env(), 1500, 1);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(1));
    press(env, PointerPhase::Down);
    press(env, PointerPhase::Up);
    // Past the touch's 5 s window and before the 10 s: a new series, allowed by the touch.
    playAt(env.env(), 7000, 1);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
}

/// A press whose release never comes counts as lifted 30 s after it began: its window ends at 35 s, and a call after
/// that opens a 1 s series.
WR_TEST(testAPressWithoutReleaseCountsAsLiftedAfter30s) {
    RenderEnv env(kPad);
    press(env, PointerPhase::Down);
    playAt(env.env(), 0, 1);
    playAt(env.env(), 36000, 1);
    playAt(env.env(), 37100, 1);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
}

/// A hidden widget's haptics are dropped (and reported), without an exception.
WR_TEST(testAHiddenWidgetPlaysNothing) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    env.drain();
    CHECK_EQ(env.eval("TelegramWidget.HapticFeedback.impactOccurred('soft') === TelegramWidget.HapticFeedback"), std::string("true"));
    CHECK(env.host().bridgeCalls.empty());
    CHECK_EQ(diagnosticsOf(env.host(), "haptic-limit"), size_t(1));
}
