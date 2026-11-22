#include "Tests/VirtualTime.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace wr_test {

namespace {

double tickTime(uint64_t tick) {
    return double(tick) * kFrameIntervalMs;
}

/// The first tick whose time is after `now`. The division only estimates it: 1050 / kFrameIntervalMs evaluates to
/// 62.999…, though tick 63's time is 1050 itself, so the tick is settled on the ticks' own times.
uint64_t firstTickAfter(double now) {
    uint64_t tick = now > 0 ? uint64_t(std::floor(now / kFrameIntervalMs)) : 0;
    while (tick > 0 && tickTime(tick - 1) > now) {
        tick--;
    }
    while (tickTime(tick) <= now) {
        tick++;
    }
    return tick;
}

} // namespace

DriveEnd driveVirtualTime(HostEnv& env, double untilMs, const std::function<bool()>& done, uint64_t maxSteps) {
    constexpr double kNever = std::numeric_limits<double>::infinity();
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    TestHost& host = env.host();
    // The tick the next frame runs at. It moves on past a tick that ran a frame, and past the ticks the clock passed
    // while no frame was wanted (a frame requested later runs at the first tick after its request); it is never
    // recomputed from the clock's time at a tick it has not passed, so a frame due at a timer's tick keeps that tick.
    uint64_t frameTick = firstTickAfter(host.now);
    // Every iteration counts, including the ones that only move the clock, so an inconsistent loop cannot spin here.
    for (uint64_t step = 0; step < maxSteps; step++) {
        if (done && done()) {
            return DriveEnd::Done;
        }
        if (env.runtime().stopReason() != wr::StopReason::None) {
            return DriveEnd::Stopped;
        }
        if (loop.hasRunnableTask(host.now)) {
            if (loop.runNextTask(host.now) == wr::StepResult::Stopped) {
                return DriveEnd::Stopped;
            }
            continue;
        }
        std::optional<double> deadline = loop.nextTimerDeadline();
        double timerAt = deadline ? std::max(*deadline, host.now) : kNever;
        if (tickTime(frameTick) < host.now) {
            frameTick = firstTickAfter(host.now);
        }
        double frameAt = loop.wantsAnimationFrame() ? tickTime(frameTick) : kNever;
        double next = std::min(timerAt, frameAt);
        if (next == kNever) {
            return DriveEnd::Idle;
        }
        if (next > untilMs) {
            host.now = std::max(host.now, untilMs);
            return DriveEnd::TimeLimit;
        }
        host.now = next;
        // A timer due at the frame's tick runs first: it is a task, and the rendering opportunity follows tasks. The
        // frame keeps its tick, so the next iteration runs the timer's task and the one after runs the frame, at the
        // same time.
        if (frameAt < timerAt) {
            frameTick++;
            if (loop.runAnimationFrame(host.now) == wr::StepResult::Stopped) {
                return DriveEnd::Stopped;
            }
        }
    }
    return DriveEnd::StepLimit;
}

const char* driveEndName(DriveEnd end) {
    switch (end) {
    case DriveEnd::Done: return "done";
    case DriveEnd::Idle: return "idle";
    case DriveEnd::TimeLimit: return "time limit";
    case DriveEnd::StepLimit: return "step limit";
    case DriveEnd::Stopped: return "stopped";
    }
    return "?";
}

} // namespace wr_test
