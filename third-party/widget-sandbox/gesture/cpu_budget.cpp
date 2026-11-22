#include "twidget/cpu_budget.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace twidget {

static constexpr double kInf = std::numeric_limits<double>::infinity();

bool CpuBudget::deferrable(std::string_view kind) {
    return kind == "timer" || kind == "frame" || kind == "viewport" || kind == "resize" || kind == "theme" || kind == "bridge";
}

CpuBudget::CpuBudget(double cpuLimitMs, double cpuQuotaMs, double cpuQuotaWindowMs, double cpuKillAfterMs)
    : cpuLimitMs_(cpuLimitMs), cpuQuotaMs_(cpuQuotaMs), windowMs_(cpuQuotaWindowMs), cpuKillAfterMs_(cpuKillAfterMs),
      bucketMs_(std::max(1.0, cpuQuotaWindowMs / kBuckets)) {
    starts_.fill(-kInf);
    ms_.fill(0);
}

void CpuBudget::record(std::string_view /*kind*/, double cpuMs, double now) {
    double b = std::floor(now / bucketMs_);
    int slot = int(std::fmod(std::fmod(b, kBuckets) + kBuckets, kBuckets));
    double start = b * bucketMs_;
    if (starts_[slot] != start) { starts_[slot] = start; ms_[slot] = 0; }
    if (cpuMs > 0) ms_[slot] += cpuMs; // NaN and negatives are ignored
}

double CpuBudget::oldestStart(double now) const {
    return (std::floor(now / bucketMs_) - kBuckets + 1) * bucketMs_;
}

double CpuBudget::used(double now) const {
    double oldest = oldestStart(now);
    double sum = 0;
    for (int i = 0; i < kBuckets; i++) if (starts_[i] >= oldest) sum += ms_[i];
    return sum;
}

CpuDecision CpuBudget::decide(std::string_view kind, double now) {
    if (kind == "boot") return {true, cpuLimitMs_, 0};
    double remaining = cpuQuotaMs_ - used(now);
    if (deferrable(kind) && remaining <= 0) {
        // A throttling stretch continues while deferrals are at most one window apart.
        if (throttledSince_ < 0 || now - lastThrottleAt_ > windowMs_) throttledSince_ = now;
        lastThrottleAt_ = now;
        double oldestBusy = oldestStart(now);
        double oldest = kInf;
        for (int i = 0; i < kBuckets; i++) if (ms_[i] > 0 && starts_[i] >= oldestBusy && starts_[i] < oldest) oldest = starts_[i];
        double retryAt = oldest == kInf ? now + bucketMs_ : oldest + windowMs_;
        if (retryAt <= now) retryAt = now + bucketMs_;
        return {false, 0, retryAt};
    }
    return {true, std::min(cpuLimitMs_, std::max(remaining, kFloorMs)), 0};
}

double CpuBudget::throttledFor(double now) const {
    if (throttledSince_ < 0 || now - lastThrottleAt_ > windowMs_) return 0;
    return now - throttledSince_;
}

bool CpuBudget::shouldKill(double now) const {
    return cpuKillAfterMs_ > 0 && throttledFor(now) >= cpuKillAfterMs_;
}

} // namespace twidget
