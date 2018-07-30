#include "velapsedtimer.h"

void VElapsedTimer::start()
{
    clock = std::chrono::high_resolution_clock::now();
    m_valid = true;
}

double VElapsedTimer::restart()
{
    double elapsedTime = elapsed();
    start();
    return elapsedTime;
}

double VElapsedTimer::elapsed() const
{
    if (!isValid()) return 0;
    return std::chrono::duration<double, std::milli>(
               std::chrono::high_resolution_clock::now() - clock)
        .count();
}

bool VElapsedTimer::hasExpired(double time)
{
    double elapsedTime = elapsed();
    if (elapsedTime > time) return true;
    return false;
}
