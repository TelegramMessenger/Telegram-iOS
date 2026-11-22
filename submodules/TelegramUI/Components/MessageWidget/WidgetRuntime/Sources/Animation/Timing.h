// An animation effect's timing (V5e plan, Task 2; Web Animations Level 1 §4.8–4.11): the active interval, the phases,
// fill, and the overall, simple, directed and transformed progress. Ported from twidget's `compute` (PROVENANCE.md).
#pragma once

#include <cstdint>
#include <memory>
#include <optional>

namespace wr::animation {

struct Easing;

enum class Fill : uint8_t { None, Forwards, Backwards, Both, Auto };
enum class Direction : uint8_t { Normal, Reverse, Alternate, AlternateReverse };

struct EffectTiming {
    double delay = 0;
    double endDelay = 0;
    double iterationStart = 0;
    double iterations = 1;
    /// nullopt: "auto", which is 0 for a keyframe effect.
    std::optional<double> duration;
    Fill fill = Fill::Auto;
    Direction direction = Direction::Normal;
    /// null: linear.
    std::shared_ptr<const Easing> easing;
};

struct ComputedTiming {
    enum class Phase : uint8_t { Before, Active, After, None };
    double activeDuration = 0;
    double endTime = 0;
    std::optional<double> localTime;
    std::optional<double> activeTime;
    /// The transformed progress (after the easing); nullopt when the effect is not in effect.
    std::optional<double> progress;
    std::optional<double> currentIteration;
    Phase phase = Phase::None;
    bool beforeFlag = false;
};

/// The iteration duration: `duration`, "auto" as 0.
double iterationDuration(const EffectTiming& timing);
/// Level 1 §4.8.2: iteration duration × iterations, 0 when either is 0.
double activeDuration(const EffectTiming& timing);
/// Level 1 §4.5.2: max(delay + active duration + end delay, 0).
double endTime(const EffectTiming& timing);
/// The effect at `localTime` (nullopt: no current time, phase None). `playingForwards`: the animation's playback rate is
/// not negative, which decides the phase at the active interval's edges.
ComputedTiming computeTiming(const EffectTiming& timing, std::optional<double> localTime, bool playingForwards);

} // namespace wr::animation
