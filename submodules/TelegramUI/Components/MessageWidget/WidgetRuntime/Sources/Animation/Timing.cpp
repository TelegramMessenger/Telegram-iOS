#include "Sources/Animation/Timing.h"

#include <algorithm>
#include <cmath>

#include "Sources/Animation/Easing.h"

namespace wr::animation {

double iterationDuration(const EffectTiming& timing) { return timing.duration.value_or(0); }

double activeDuration(const EffectTiming& timing) {
    const double duration = iterationDuration(timing);
    return (duration == 0 || timing.iterations == 0) ? 0 : duration * timing.iterations;
}

double endTime(const EffectTiming& timing) { return std::max(timing.delay + activeDuration(timing) + timing.endDelay, 0.0); }

ComputedTiming computeTiming(const EffectTiming& t, std::optional<double> localTime, bool forwards) {
    ComputedTiming r;
    r.activeDuration = activeDuration(t);
    r.endTime = endTime(t);
    if (!localTime || !std::isfinite(*localTime)) {
        return r;
    }
    const double local = *localTime;
    r.localTime = local;
    const double duration = iterationDuration(t);
    const double active = r.activeDuration;
    const double end = r.endTime;
    const double beforeActive = std::max(std::min(t.delay, end), 0.0);
    const double activeAfter = std::max(std::min(t.delay + active, end), 0.0);
    const bool fillsBackwards = t.fill == Fill::Backwards || t.fill == Fill::Both;
    const bool fillsForwards = t.fill == Fill::Forwards || t.fill == Fill::Both;
    if (local < beforeActive || (!forwards && local == beforeActive)) {
        r.phase = ComputedTiming::Phase::Before;
        if (fillsBackwards) {
            r.activeTime = std::max(local - t.delay, 0.0);
        }
    } else if (local > activeAfter || (forwards && local == activeAfter)) {
        r.phase = ComputedTiming::Phase::After;
        if (fillsForwards) {
            r.activeTime = std::max(std::min(local - t.delay, active), 0.0);
        }
    } else {
        r.phase = ComputedTiming::Phase::Active;
        r.activeTime = local - t.delay;
    }
    if (!r.activeTime) {
        return r;
    }
    const double activeTime = *r.activeTime;
    double overall = duration == 0 ? (r.phase == ComputedTiming::Phase::Before ? 0 : t.iterations) : activeTime / duration;
    overall += t.iterationStart;
    double simple = std::isinf(overall) ? std::fmod(t.iterationStart, 1.0) : std::fmod(overall, 1.0);
    if (simple == 0 && r.phase != ComputedTiming::Phase::Before && activeTime == active && t.iterations != 0) {
        simple = 1;
    }
    double iteration;
    if (r.phase == ComputedTiming::Phase::After && std::isinf(t.iterations)) {
        iteration = INFINITY;
    } else if (simple == 1) {
        iteration = std::floor(overall) - 1;
    } else {
        iteration = std::floor(overall);
    }
    r.currentIteration = iteration;
    bool forwardsDirection = true;
    if (t.direction == Direction::Reverse) {
        forwardsDirection = false;
    } else if ((t.direction == Direction::Alternate || t.direction == Direction::AlternateReverse) && std::isfinite(iteration)) {
        const double d = iteration + (t.direction == Direction::AlternateReverse ? 1 : 0);
        forwardsDirection = std::fmod(d, 2.0) == 0;
    }
    const double directed = forwardsDirection ? simple : 1 - simple;
    r.beforeFlag = (forwardsDirection && r.phase == ComputedTiming::Phase::Before) ||
                   (!forwardsDirection && r.phase == ComputedTiming::Phase::After);
    r.progress = t.easing ? t.easing->web(directed, r.beforeFlag) : directed;
    return r;
}

} // namespace wr::animation
