#ifndef VELAPSEDTIMER_H
#define VELAPSEDTIMER_H

#include <chrono>
#include "vglobal.h"

class VElapsedTimer {
public:
    VElapsedTimer() : m_valid(false) {}
    double      elapsed() const;
    bool        hasExpired(double millsec);
    void        start();
    double      restart();
    inline bool isValid() const { return m_valid; }

private:
    std::chrono::high_resolution_clock::time_point clock;
    bool                                           m_valid;
};
#endif  // VELAPSEDTIMER_H
