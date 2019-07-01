#ifndef ASTC_MISC_H_
#define ASTC_MISC_H_

#include <math.h>

template <typename T>
T clamp(T a, T b, T x) {
  if (x < a) {
    return a;
  }

  if (x > b) {
    return b;
  }

  return x;
}

inline bool approx_equal(float x, float y, float epsilon) {
  return fabs(x - y) < epsilon;
}

#endif  // ASTC_MISC_H_
