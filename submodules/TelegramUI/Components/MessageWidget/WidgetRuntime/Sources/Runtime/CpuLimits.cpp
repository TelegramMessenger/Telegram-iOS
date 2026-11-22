#include "Sources/Runtime/CpuLimits.h"

#include <time.h>

namespace wr {

CpuClock CpuClock::thread() {
    return CpuClock{[] { return double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)) / 1e6; },
                    [] { return double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6; }};
}

} // namespace wr
