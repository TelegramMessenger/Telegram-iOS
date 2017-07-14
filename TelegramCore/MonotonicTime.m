#import "MonotonicTime.h"

#include <sys/sysctl.h>

int64_t MonotonicGetBootTimestamp() {
    struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    int rc = sysctl(mib, 2, &boottime, &size, NULL, 0);
    if (rc != 0) {
        return 0;
    }
    return boottime.tv_sec * 1000000 + boottime.tv_usec;
}

int64_t MonotonicGetUptime() {
    int64_t before_now;
    int64_t after_now;
    struct timeval now;
    
    after_now = MonotonicGetBootTimestamp();
    do {
        before_now = after_now;
        gettimeofday(&now, NULL);
        after_now = MonotonicGetBootTimestamp();
    } while (after_now != before_now);
    
    return now.tv_sec * 1000000 + now.tv_usec - before_now;
}
