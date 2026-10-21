// Haptics (V2a plan, Task 6; widget-sandbox v0.1.0 docs/sdk-v1.md §2.6, packages/core/src/shared/sdk-policy.ts
// HapticGate): TelegramWidget.HapticFeedback's three methods return it for chaining and throw TypeError for an unknown
// style or type; a call is posted as `haptic` only while the widget is visible and the bucket (5, refilled at 10 per
// second on the runtime's clock) has room; dropped calls are reported as `haptic-limit` at most once per second.
#include <string>
#include <utility>
#include <vector>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

using Calls = std::vector<std::pair<std::string, std::string>>;

size_t diagnosticsOf(const wr_test::TestHost& host, const std::string& kind) {
    size_t n = 0;
    for (const auto& [k, detail] : host.diagnostics) {
        n += k == kind;
    }
    return n;
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

/// A burst of 20 in one task reaches the host as 5; the bucket refills at 10 per second; a drop is reported once per
/// second. The clock is the step's (EventLoop::currentTime), not the host's live one: a burst inside one task sees no
/// refill however long it runs (conformance limit.haptic-rate failed once on a slow run of the live clock).
WR_TEST(testTheBucket) {
    HostEnv env;
    env.eval("for (let i = 0; i < 20; i++) TelegramWidget.HapticFeedback.impactOccurred('rigid'); 1");
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(5));
    CHECK_EQ(diagnosticsOf(env.host(), "haptic-limit"), size_t(1));
    // The host's clock moved, the loop's has not (no step or script since): nothing is back.
    env.host().now += 200;
    CHECK(!wr::HostState::of(env.ctx()).admitHaptic(env.ctx()));
    // A step at the new time: two tokens are back; the report waits for its second.
    env.drain();
    env.eval("for (let i = 0; i < 5; i++) TelegramWidget.HapticFeedback.selectionChanged(); 1");
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(7));
    CHECK_EQ(diagnosticsOf(env.host(), "haptic-limit"), size_t(1));
    env.host().now += 1000;
    env.drain();
    env.eval("for (let i = 0; i < 6; i++) TelegramWidget.HapticFeedback.selectionChanged(); 1");
    CHECK_EQ(env.host().bridgeCalls.size(), size_t(12));
    CHECK_EQ(diagnosticsOf(env.host(), "haptic-limit"), size_t(2));
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
