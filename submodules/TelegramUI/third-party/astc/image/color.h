#ifndef IMAGE_COLOR_H_
#define IMAGE_COLOR_H_

#include <cstdint>

union rgba8_t {
  struct type {
    uint8_t r, g, b, a;
  } channels;
  uint32_t bits;
};
union bgra8_t {
  struct type {
    uint8_t b, g, r, a;
  } channels;
  uint32_t bits;
};

inline bgra8_t swap_red_blue(rgba8_t color) {
  bgra8_t output;
  output.channels.r = color.channels.r;
  output.channels.g = color.channels.g;
  output.channels.b = color.channels.b;
  output.channels.a = color.channels.a;
  return output;
}

inline rgba8_t swap_red_blue(bgra8_t color) {
  rgba8_t output;
  output.channels.r = color.channels.r;
  output.channels.g = color.channels.g;
  output.channels.b = color.channels.b;
  output.channels.a = color.channels.a;
  return output;
}

#endif  // IMAGE_COLOR_H_
