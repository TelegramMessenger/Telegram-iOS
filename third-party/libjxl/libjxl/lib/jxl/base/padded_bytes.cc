// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/padded_bytes.h"

namespace jxl {

void PaddedBytes::IncreaseCapacityTo(size_t capacity) {
  JXL_ASSERT(capacity > capacity_);

  size_t new_capacity = std::max(capacity, 3 * capacity_ / 2);
  new_capacity = std::max<size_t>(64, new_capacity);

  // BitWriter writes up to 7 bytes past the end.
  CacheAlignedUniquePtr new_data = AllocateArray(new_capacity + 8);
  if (new_data == nullptr) {
    // Allocation failed, discard all data to ensure this is noticed.
    size_ = capacity_ = 0;
    return;
  }

  if (data_ == nullptr) {
    // First allocation: ensure first byte is initialized (won't be copied).
    new_data[0] = 0;
  } else {
    // Subsequent resize: copy existing data to new location.
    memcpy(new_data.get(), data_.get(), size_);
    // Ensure that the first new byte is initialized, to allow write_bits to
    // safely append to the newly-resized PaddedBytes.
    new_data[size_] = 0;
  }

  capacity_ = new_capacity;
  std::swap(new_data, data_);
}

void PaddedBytes::assign(const uint8_t* new_begin, const uint8_t* new_end) {
  JXL_DASSERT(new_begin <= new_end);
  const size_t new_size = static_cast<size_t>(new_end - new_begin);

  // memcpy requires non-overlapping ranges, and resizing might invalidate the
  // new range. Neither happens if the new range is completely to the left or
  // right of the _allocated_ range (irrespective of size_).
  const uint8_t* allocated_end = begin() + capacity_;
  const bool outside = new_end <= begin() || new_begin >= allocated_end;
  if (outside) {
    resize(new_size);  // grow or shrink
    memcpy(data(), new_begin, new_size);
    return;
  }

  // There is overlap. The new size cannot be larger because we own the memory
  // and the new range cannot include anything outside the allocated range.
  JXL_ASSERT(new_size <= capacity_);

  // memmove allows overlap and capacity_ is sufficient.
  memmove(data(), new_begin, new_size);
  size_ = new_size;  // shrink
}

}  // namespace jxl
