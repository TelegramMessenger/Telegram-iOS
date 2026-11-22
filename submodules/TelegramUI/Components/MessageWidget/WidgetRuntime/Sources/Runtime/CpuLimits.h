// widget-sandbox's runtime limits (LIMIT_DEFAULTS in packages/core/src/shared/protocol.ts; docs/decisions.md "Runtime
// limits", "CPU time, not wall-clock time"), and the clocks they are measured with: the widget thread's CPU time, and
// the monotonic wall clock for the backstop. The CPU-clock limits plan, Task 2.
#pragma once

#include <cstdint>
#include <functional>

namespace wr {

/// The values, in every build and under both limit policies (they are the glue's, not the validator's).
struct CpuLimits {
    /// A task's slice: past it the widget stops ("CPU limit exceeded").
    double cpuLimitMs = 500;
    /// JS time per window: past it, deferrable tasks wait.
    double cpuQuotaMs = 300;
    double cpuQuotaWindowMs = 1000;
    /// Kill after this long of uninterrupted throttling; 0 never.
    double cpuKillAfterMs = 0;
    /// The host's own work for the widget per window: its layout queries' time and the modelled cost of its operations
    /// (upstream's opsCostMs).
    double mainThreadQuotaMs = 100;
};

/// Milliseconds on the widget thread's CPU clock and on the monotonic wall clock.
struct CpuClock {
    std::function<double()> cpuMs;
    std::function<double()> wallMs;
    /// Where a fake clock moves (tests only; empty in production): before the clocks are read at every interrupt-handler
    /// check outside our renderer (Interrupt), and before an outermost render scope reads its end (Render).
    enum class Pace : uint8_t { Interrupt, Render };
    std::function<void(Pace)> pace;
    /// CLOCK_THREAD_CPUTIME_ID of the calling thread, and CLOCK_UPTIME_RAW: what a step reads on the pool thread that
    /// runs it.
    static CpuClock thread();
};

} // namespace wr
