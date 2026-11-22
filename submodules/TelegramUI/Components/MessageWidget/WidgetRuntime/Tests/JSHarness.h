// A runtime per test, and checks written in JavaScript.
#pragma once

#include <algorithm>
#include <memory>
#include <string>
#include <string_view>

#include "Sources/Runtime/Runtime.h"
#include "Tests/wr_test.h"

namespace wr_test {

/// The counted caps (widget-sandbox v0.3.0) that every environment made while this lives gives its runtime (JSEnv,
/// DOMEnv, HostEnv, RenderEnv); strict otherwise. For a test of compat, or of a test past a strict cap it is not about.
class ScopedLimits {
public:
    explicit ScopedLimits(const wr::Limits& limits);
    ~ScopedLimits();
    ScopedLimits(const ScopedLimits&) = delete;
    ScopedLimits& operator=(const ScopedLimits&) = delete;

private:
    wr::Limits m_previous;
};

/// The limits a runtime made now gets (ScopedLimits).
const wr::Limits& testLimits();

/// The CPU limits every environment made while this lives gives its runtime. Otherwise the product's slice (500 ms) with
/// both windows lifted: the fake clock moves whole milliseconds per interrupt check, so the product's windows would
/// throttle tests that run many steps at one `now`. The quota tests set the product's.
class ScopedCpuLimits {
public:
    explicit ScopedCpuLimits(const wr::CpuLimits& limits);
    ~ScopedCpuLimits();
    ScopedCpuLimits(const ScopedCpuLimits&) = delete;
    ScopedCpuLimits& operator=(const ScopedCpuLimits&) = delete;

private:
    wr::CpuLimits m_previous;
};

/// The CPU limits a runtime made now gets (ScopedCpuLimits).
const wr::CpuLimits& testCpuLimits();

/// The clocks every runtime the harness makes reads (wr::CpuClock): fake and repeatable. They move by `stepMs` at every
/// interrupt-handler check in a slice (so a JS loop's time follows its bytecode), by `renderStepMs` at the end of every
/// render scope in a slice (a flush, a layout query's), and when a test advances them. Reset by ScopedFakeClock.
struct FakeCpuClock {
    double cpu = 0;
    double wall = 0;
    double stepMs = 1.0;
    double renderStepMs = 0;
    /// Both clocks, as time passing on the widget's thread does.
    void advance(double ms) {
        cpu += ms;
        wall += ms;
    }
    /// The wall clock alone (a thread that is starved or stuck outside JS).
    void advanceWall(double ms) { wall += ms; }
    wr::CpuClock clock();
};

/// The fake clock runtimes made now read.
FakeCpuClock& testClock();

/// Resets testClock() to zero with `stepMs` per interrupt-handler check while it lives.
class ScopedFakeClock {
public:
    explicit ScopedFakeClock(double stepMs = 1.0);
    ~ScopedFakeClock();
    ScopedFakeClock(const ScopedFakeClock&) = delete;
    ScopedFakeClock& operator=(const ScopedFakeClock&) = delete;
    FakeCpuClock& operator*() { return testClock(); }
    FakeCpuClock* operator->() { return &testClock(); }

private:
    FakeCpuClock m_previous;
};

/// The product's CPU limits on the fake clock, a millisecond an interrupt check, for a test whose runaway must stop at
/// its slice (500 ms: about 500 checks). Declared before the environment it governs.
struct ScopedProductSlices {
    ScopedCpuLimits limits{wr::CpuLimits{}};
    ScopedFakeClock clock{1.0};
};

/// Ends the runtime's slice `ms` fake milliseconds from now (a new "event" slice): at the default step a runaway stops
/// within about `ms` interrupt checks, with StopReason::Cpu. What a test's runaway outside a step is stopped by.
void stopAfter(wr::Runtime& runtime, double ms = 200);

/// The calling thread's CPU time in milliseconds (wr::CpuClock::thread(), never the fake clock): what a test comparing
/// the cost of two paths reads, a complexity check rather than a limit, so machine load moves it less than wall time.
double threadCpuMs();

/// The least thread CPU time of `runs` calls of `f`, in milliseconds.
template <typename F>
double leastCpuMs(F&& f, int runs = 3) {
    double least = 1e300;
    for (int run = 0; run < runs; run++) {
        const double start = threadCpuMs();
        f();
        least = std::min(least, threadCpuMs() - start);
    }
    return least;
}

/// A script a test evaluates outside any step runs in an "event" slice of the runtime's CPU limits (the product's slice
/// unless ScopedCpuLimits sets others), unless one is open already (a test's own beginSlice).
class EvalSlice {
public:
    explicit EvalSlice(wr::Runtime& runtime) : m_runtime(runtime), m_began(!runtime.inSlice()) {
        if (m_began) {
            m_runtime.beginSlice("event", m_runtime.cpuLimits().cpuLimitMs);
        }
    }
    ~EvalSlice() {
        if (m_began) {
            m_runtime.endSlice();
        }
    }
    EvalSlice(const EvalSlice&) = delete;
    EvalSlice& operator=(const EvalSlice&) = delete;

private:
    wr::Runtime& m_runtime;
    bool m_began;
};

class JSEnv {
public:
    /// A runtime over `table`, with `host` (not owned: it outlives the environment) or none.
    explicit JSEnv(const wr::InterfaceTable& table, wr::Host* host = nullptr);
    ~JSEnv();
    wr::Runtime& runtime() { return *m_runtime; }
    JSContext* ctx() { return m_runtime->context(); }
    /// The completion value as a string, "THROW <Name>: <message>", or "ABORTED" when the script stopped the widget. A
    /// script of its own, as a task is: it starts an operations batch (limit.batch).
    std::string eval(std::string_view code);

private:
    std::unique_ptr<wr::Runtime> m_runtime;
};

} // namespace wr_test

#define CHECK_JS(env, expr) \
    do { \
        std::string _r = (env).eval(std::string("String(!!(") + (expr) + "))"); \
        if (_r != "true") { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_JS(%s) -> %s\n", __FILE__, __LINE__, (expr), _r.c_str()); \
        } \
    } while (0)

#define CHECK_JS_EQ(env, expr, expected) \
    do { \
        std::string _r = (env).eval(std::string("String(") + (expr) + ")"); \
        if (_r != std::string(expected)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_JS_EQ(%s) -> %s, expected %s\n", __FILE__, __LINE__, (expr), _r.c_str(), std::string(expected).c_str()); \
        } \
    } while (0)

/// `code` throws an exception whose `name` is `name`.
#define CHECK_THROWS(env, code, name) \
    do { \
        std::string _r = (env).eval(std::string("(() => { try { ") + (code) + "; return 'no exception'; } catch (e) { return String(e.name); } })()"); \
        if (_r != std::string(name)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_THROWS(%s) -> %s, expected %s\n", __FILE__, __LINE__, (code), _r.c_str(), name); \
        } \
    } while (0)
