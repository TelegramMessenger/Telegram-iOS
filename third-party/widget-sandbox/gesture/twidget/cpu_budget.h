// CPU quota policy: a line-for-line mirror of src/host/cpu-budget.ts (see the
// comments there), the fourth copy next to CpuBudget.swift and CpuBudget.kt.
// A sliding window of `cpuQuotaWindowMs` in ten buckets; a widget may spend
// `cpuQuotaMs` of JS time per window, beyond that deferrable tasks are
// postponed until the oldest busy bucket leaves the window — never dropped or
// killed. Events always run with a floor of 50 ms.
//
// The engine keeps two of them (docs/decisions.md, "Strict limits from the start"):
// the JS quota (`cpuQuotaMs`, JS time only) and the main-thread window
// (`mainThreadQuotaMs`): the host's own work for the widget, its layout queries
// and the modelled cost of the ops it forwards (`opsCostMs`). A deferrable task
// waits while either window is spent.
//
// Pure and side-effect free; checked against tests/fixtures/cpu-budget.json
// (copied to desktop/tests/fixtures by `pnpm build:desktop`).
#pragma once

#include <array>
#include <algorithm>
#include <string_view>

namespace twidget {

struct CpuDecision {
    bool run;
    double sliceMs; // when run
    double retryAt; // when deferred
    bool operator==(const CpuDecision& o) const { return run == o.run && (run ? sliceMs == o.sliceMs : retryAt == o.retryAt); }
};

class CpuBudget {
public:
    static constexpr int kBuckets = 10;
    /// Minimum slice any task gets, so user input is handled even with the quota spent.
    static constexpr double kFloorMs = 50;
    /// Kinds that may be postponed. `boot`, `event` and `visibility` always run.
    static bool deferrable(std::string_view kind);
    /// A task's layout queries may block the host for at most this much, whatever its slice (boot included).
    static constexpr double kQueryBudgetMs = 100;
    /// Layout-query budget of one task (cpu-budget.ts `queryBudgetMs`): past it the task is interrupted and killed.
    static double queryBudgetMs(double /*sliceMs*/) { return kQueryBudgetMs; }
    /// Modelled main-thread cost of one op the glue forwards to the validator, and of one canvas command in it.
    static constexpr double kOpCostMs = 0.025;
    static constexpr double kCanvasCommandCostMs = 0.002;
    /// What a batch of `ops` ops with `canvasCommands` canvas commands costs the host's main thread (cpu-budget.ts
    /// `opsCostMs`): deterministic, from what the widget sent.
    static double opsCostMs(double ops, double canvasCommands) { return ops * kOpCostMs + canvasCommands * kCanvasCommandCostMs; }

    CpuBudget(double cpuLimitMs, double cpuQuotaMs, double cpuQuotaWindowMs, double cpuKillAfterMs);

    /// Account `cpuMs` of widget JS time for a task that ended at `now`.
    void record(std::string_view kind, double cpuMs, double now);
    /// JS time used in the window ending now.
    double used(double now) const;
    /// Before a task: run it with this slice for the interrupt handler, or retry at `retryAt`.
    CpuDecision decide(std::string_view kind, double now);
    /// Length of the current uninterrupted throttling stretch (0 when not throttled).
    double throttledFor(double now) const;
    /// `cpuKillAfterMs` (0 = never): kill the runtime once throttling has lasted this long.
    bool shouldKill(double now) const;

private:
    double oldestStart(double now) const;

    double cpuLimitMs_, cpuQuotaMs_, windowMs_, cpuKillAfterMs_, bucketMs_;
    std::array<double, kBuckets> starts_{};
    std::array<double, kBuckets> ms_{};
    double throttledSince_ = -1;
    double lastThrottleAt_ = -1;
};

} // namespace twidget
