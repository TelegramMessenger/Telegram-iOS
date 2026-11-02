// widget-sandbox's CPU quota policy (its C++ copy, cpu_budget.cpp) against the fixture its four copies share
// (fixtures/cpu-budget.json): upstream's `cpu-budget: shared fixture` and `cpu-budget: edge cases`
// (packages/core/tests/unit/cpu-budget.test.ts at the vendored tag, v0.3.0). WidgetRuntime's event loop runs it for
// every step (the JS quota and the main-thread window).
#include "twidget/cpu_budget.h"
#include "twidget/json.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>

using namespace twidget;

namespace {

int g_failures = 0;

#define CHECK_MSG(cond, msg) do { if (!(cond)) { g_failures++; std::fprintf(stderr, "  FAIL %s:%d: %s — %s\n", __FILE__, __LINE__, #cond, std::string(msg).c_str()); } } while (0)

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

/// `{run: true, sliceMs}` or `{run: false, retryAt}`, as the fixture writes a decision.
bool sameDecision(const CpuDecision& got, const Json& want) {
    const bool run = want["run"].asBool();
    if (got.run != run) return false;
    return run ? got.sliceMs == want["sliceMs"].asNumber() : got.retryAt == want["retryAt"].asNumber();
}

std::string describe(const CpuDecision& d) {
    char buf[96];
    std::snprintf(buf, sizeof buf, d.run ? "{run: true, sliceMs: %g}" : "{run: false, retryAt: %g}", d.run ? d.sliceMs : d.retryAt);
    return buf;
}

void sharedFixture(const Json& fixture) {
    for (const Json& c : fixture["cases"].arr()) {
        const std::string name = c["name"].asString();
        const Json& cfg = c["config"];
        CpuBudget b(cfg["cpuLimitMs"].asNumber(), cfg["cpuQuotaMs"].asNumber(), cfg["cpuQuotaWindowMs"].asNumber(), cfg["cpuKillAfterMs"].asNumber());
        const auto& steps = c["steps"].arr();
        for (size_t i = 0; i < steps.size(); i++) {
            const Json& s = steps[i];
            const double at = s["at"].asNumber();
            const std::string where = name + ": step " + std::to_string(i);
            if (const Json* kind = s.find("decide")) {
                const CpuDecision d = b.decide(kind->asString(), at);
                CHECK_MSG(sameDecision(d, s["expect"]), where + ", got " + describe(d));
            } else if (const Json* kind = s.find("record")) {
                b.record(kind->asString(), s["cpuMs"].asNumber(), at);
            } else if (const Json* kill = s.find("kill")) {
                CHECK_MSG(b.shouldKill(at) == kill->asBool(), where);
            } else if (const Json* slice = s.find("queryBudget")) {
                CHECK_MSG(CpuBudget::queryBudgetMs(slice->asNumber()) == s["expect"].asNumber(), where);
            } else if (const Json* cost = s.find("opsCost")) {
                CHECK_MSG(std::fabs(CpuBudget::opsCostMs((*cost)[0].asNumber(), (*cost)[1].asNumber()) - s["expect"].asNumber()) < 1e-9, where);
            } else {
                CHECK_MSG(false, where + ": unknown step");
            }
        }
    }
}

void edgeCases() {
    const auto fresh = [] { return CpuBudget(500, 300, 1000, 0); };
    {
        CpuBudget b = fresh();
        CHECK_MSG(b.used(123456) == 0, "an empty window: nothing used");
        CHECK_MSG(sameDecision(b.decide("frame", 123456), *Json::parse(R"({"run": true, "sliceMs": 300})")), "an empty window: the full quota");
        CHECK_MSG(b.throttledFor(123456) == 0, "an empty window: not throttled");
    }
    {
        CpuBudget b = fresh();
        b.record("timer", 1000, 10);
        CHECK_MSG(b.used(10) == 1000, "time recorded counts");
        CHECK_MSG(b.used(10000) == 0, "time spent long ago is forgotten");
        CHECK_MSG(sameDecision(b.decide("timer", 10000), *Json::parse(R"({"run": true, "sliceMs": 300})")), "a later window starts afresh");
    }
    {
        CpuBudget b = fresh();
        b.record("timer", 50000, 0);
        CHECK_MSG(sameDecision(b.decide("event", 1), *Json::parse(R"({"run": true, "sliceMs": 50})")), "events get the floor");
        CHECK_MSG(sameDecision(b.decide("timer", 1), *Json::parse(R"({"run": false, "retryAt": 1000})")), "a timer waits for the window");
    }
    {
        CpuBudget b = fresh();
        b.record("timer", -5, 0);
        b.record("timer", std::numeric_limits<double>::quiet_NaN(), 0);
        CHECK_MSG(b.used(0) == 0, "negative or NaN durations are ignored");
    }
}

} // namespace

int main() {
    const char* path = std::getenv("WS_CPU_BUDGET");
    if (!path) {
        std::fprintf(stderr, "WS_CPU_BUDGET is not set\n");
        return 2;
    }
    const std::optional<Json> fixture = Json::parse(readFile(path));
    if (!fixture) {
        std::fprintf(stderr, "cannot parse %s\n", path);
        return 2;
    }
    sharedFixture(*fixture);
    edgeCases();
    std::printf("%s\n", g_failures ? "FAILED" : "all passed");
    return g_failures ? 1 : 0;
}
