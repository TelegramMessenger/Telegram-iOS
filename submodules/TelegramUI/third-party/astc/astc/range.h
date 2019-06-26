#ifndef ASTC_RANGE_H_
#define ASTC_RANGE_H_

#include <cstdint>

/**
 * Define normalized (starting at zero) numeric ranges that can be represented
 * with 8 bits or less.
 */
enum range_t {
  RANGE_2,
  RANGE_3,
  RANGE_4,
  RANGE_5,
  RANGE_6,
  RANGE_8,
  RANGE_10,
  RANGE_12,
  RANGE_16,
  RANGE_20,
  RANGE_24,
  RANGE_32,
  RANGE_40,
  RANGE_48,
  RANGE_64,
  RANGE_80,
  RANGE_96,
  RANGE_128,
  RANGE_160,
  RANGE_192,
  RANGE_256,
  RANGE_MAX
};

/**
 * Table of maximum value for each range, minimum is always zero.
 */
const uint8_t range_max_table[RANGE_MAX] = {1,  2,  3,  4,   5,   7,   9,
                                            11, 15, 19, 23,  31,  39,  47,
                                            63, 79, 95, 127, 159, 191, 255};

#endif  // ASTC_RANGE_H_
