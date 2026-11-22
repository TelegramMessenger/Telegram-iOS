#include "Tests/JSHarness.h"

#include "Sources/Support/Errors.h"

namespace wr_test {

namespace {

wr::Limits g_limits = wr::Limits::strict();
FakeCpuClock g_clock;

/// The product's slice; both windows lifted (ScopedCpuLimits).
wr::CpuLimits harnessLimits() {
    wr::CpuLimits limits;
    limits.cpuQuotaMs = 1e12;
    limits.mainThreadQuotaMs = 1e12;
    return limits;
}

wr::CpuLimits g_cpuLimits = harnessLimits();

} // namespace

wr::CpuClock FakeCpuClock::clock() {
    return wr::CpuClock{[this] { return cpu; }, [this] { return wall; },
                        [this](wr::CpuClock::Pace pace) {
                            const double ms = pace == wr::CpuClock::Pace::Interrupt ? stepMs : renderStepMs;
                            cpu += ms;
                            wall += ms;
                        }};
}

FakeCpuClock& testClock() {
    return g_clock;
}

ScopedFakeClock::ScopedFakeClock(double stepMs) : m_previous(g_clock) {
    g_clock = FakeCpuClock{};
    g_clock.stepMs = stepMs;
}

ScopedFakeClock::~ScopedFakeClock() {
    g_clock = m_previous;
}

ScopedLimits::ScopedLimits(const wr::Limits& limits) : m_previous(g_limits) {
    g_limits = limits;
}

ScopedLimits::~ScopedLimits() {
    g_limits = m_previous;
}

const wr::Limits& testLimits() {
    return g_limits;
}

ScopedCpuLimits::ScopedCpuLimits(const wr::CpuLimits& limits) : m_previous(g_cpuLimits) {
    g_cpuLimits = limits;
}

ScopedCpuLimits::~ScopedCpuLimits() {
    g_cpuLimits = m_previous;
}

const wr::CpuLimits& testCpuLimits() {
    return g_cpuLimits;
}

double threadCpuMs() {
    static const wr::CpuClock clock = wr::CpuClock::thread();
    return clock.cpuMs();
}

void stopAfter(wr::Runtime& runtime, double ms) {
    runtime.beginSlice("event", ms);
}

JSEnv::JSEnv(const wr::InterfaceTable& table, wr::Host* host) {
    wr::Runtime::Options options;
    options.limits = g_limits;
    options.cpu = g_cpuLimits;
    options.clock = g_clock.clock();
    options.interfaces = &table;
    options.host = host;
    m_runtime = wr::Runtime::create(options);
}

JSEnv::~JSEnv() = default;

std::string JSEnv::eval(std::string_view code) {
    m_runtime->startBatch();
    EvalSlice slice(*m_runtime);
    bool threw = false;
    std::string result;
    try {
        result = m_runtime->evaluateToString(code, "<test>", &threw);
    } catch (const wr::Aborted&) {
        // A stop inside the script (HostEnv::eval's answer too).
        return "ABORTED";
    }
    return threw ? "THROW " + result : result;
}

} // namespace wr_test
