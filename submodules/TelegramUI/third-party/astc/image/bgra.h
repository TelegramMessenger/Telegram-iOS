#ifndef IMAGE_BGRA_H_
#define IMAGE_BGRA_H_

#include <cstddef>

#include "color.h"

class BgraImage {
 public:
  BgraImage(size_t width_, size_t height_, uint8_t *bytes)
      : width(width_),
        height(height_),
        pixel_count(width_ * height_),
        buffer_size(pixel_count * sizeof(bgra8_t)),
        buffer((bgra8_t *)bytes) {}

  BgraImage(BgraImage&& other)
      : width(other.width),
        height(other.height),
        buffer_size(other.buffer_size),
        buffer(other.buffer) {
    other.buffer = nullptr;
  }

  BgraImage(const BgraImage&) = delete;
  BgraImage& operator=(const BgraImage&) = delete;

  ~BgraImage() {
  }

  size_t width, height;

  size_t pixel_count;
  size_t buffer_size;
  bgra8_t* buffer;
};

#endif  // IMAGE_BGRA_H_
