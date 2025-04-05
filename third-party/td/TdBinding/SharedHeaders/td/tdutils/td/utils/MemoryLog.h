//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <cstdio>
#include <cstring>

namespace td {

template <int buffer_size = 32 * (1 << 10)>
class MemoryLog final : public LogInterface {
  static constexpr size_t MAX_OUTPUT_SIZE = buffer_size / 16 < (8 << 10) ? buffer_size / 16 : (8 << 10);

  static_assert((buffer_size & (buffer_size - 1)) == 0, "Buffer size must be power of 2");
  static_assert(buffer_size >= (8 << 10), "Too small buffer size");

 public:
  MemoryLog() {
    std::memset(buffer_, ' ', sizeof(buffer_));
  }

  Slice get_buffer() const {
    return Slice(buffer_, sizeof(buffer_));
  }

  size_t get_pos() const {
    return pos_ & (buffer_size - 1);
  }

 private:
  void do_append(int log_level, CSlice new_slice) final {
    Slice slice = new_slice;
    slice.truncate(MAX_OUTPUT_SIZE);
    while (!slice.empty() && slice.back() == '\n') {
      slice.remove_suffix(1);
    }
    size_t slice_size = slice.size();
    CHECK(slice_size * 3 < buffer_size);
    size_t pad_size = ((slice_size + 15) & ~15) - slice_size;
    constexpr size_t MAGIC_SIZE = 16;
    auto total_size = static_cast<uint32>(slice_size + pad_size + MAGIC_SIZE);
    auto real_pos = pos_.fetch_add(total_size, std::memory_order_relaxed);
    CHECK((total_size & 15) == 0);

    uint32 start_pos = real_pos & (buffer_size - 1);
    uint32 end_pos = start_pos + total_size;
    if (likely(end_pos <= buffer_size)) {
      std::memcpy(&buffer_[start_pos + MAGIC_SIZE], slice.data(), slice_size);
      std::memcpy(&buffer_[start_pos + MAGIC_SIZE + slice_size], "               ", pad_size);
    } else {
      size_t first = buffer_size - start_pos - MAGIC_SIZE;
      size_t second = slice_size - first;
      std::memcpy(&buffer_[start_pos + MAGIC_SIZE], slice.data(), first);
      std::memcpy(&buffer_[0], slice.data() + first, second);
      std::memcpy(&buffer_[second], "               ", pad_size);
    }

    CHECK((start_pos & 15) == 0);
    CHECK(start_pos <= buffer_size - MAGIC_SIZE);
    buffer_[start_pos] = '\n';
    size_t printed = std::snprintf(&buffer_[start_pos + 1], MAGIC_SIZE - 1, "LOG:%08x: ", real_pos);
    CHECK(printed == MAGIC_SIZE - 2);
    buffer_[start_pos + MAGIC_SIZE - 1] = ' ';
  }

  char buffer_[buffer_size];
  std::atomic<uint32> pos_{0};
};

}  // namespace td
