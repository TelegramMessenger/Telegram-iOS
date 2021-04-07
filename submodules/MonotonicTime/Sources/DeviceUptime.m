#import <MonotonicTime/DeviceUptime.h>

#include <sys/sysctl.h>

int32_t getDeviceUptimeSeconds(int32_t *bootTime) {
    struct timeval boottime;
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    time_t now;
    time_t uptime = -1;

    (void)time(&now);

    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0) {
        uptime = now - boottime.tv_sec;
        if (bootTime != NULL) {
            *bootTime = boottime.tv_sec;
        }
    }

    return uptime;
}
