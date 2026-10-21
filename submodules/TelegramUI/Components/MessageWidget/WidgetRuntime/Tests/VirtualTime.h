// A virtual-time driver over a HostEnv's event loop (M1b plan, Task 17), for the WPT runner and the corpus boot.
// Tasks run while any is runnable at the current time; when none is, a wanted animation frame runs at its 60 Hz tick
// unless a timer is due first, and otherwise the clock jumps to the next timer deadline. The clock never passes
// `untilMs`. Tick n is at n * kFrameIntervalMs. A frame runs at the first tick after the time it was requested, a
// tick runs at most one frame, and the tasks due at a tick run before its frame.
#pragma once

#include <cstdint>
#include <functional>

#include "Tests/HostHarness.h"

namespace wr_test {

enum class DriveEnd : uint8_t {
    Done,       // done() held
    Idle,       // nothing runnable, no timer, no frame wanted
    TimeLimit,  // the next event is after untilMs; the clock is at untilMs
    StepLimit,  // maxSteps iterations ran
    Stopped,    // the runtime latched a stop
};

inline constexpr double kFrameIntervalMs = 1000.0 / 60.0;

/// An empty `done` never holds.
DriveEnd driveVirtualTime(HostEnv& env, double untilMs, const std::function<bool()>& done, uint64_t maxSteps);
const char* driveEndName(DriveEnd end);

} // namespace wr_test
