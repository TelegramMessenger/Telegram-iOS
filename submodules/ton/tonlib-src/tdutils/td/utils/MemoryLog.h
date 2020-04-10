/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <cstdio>
#include <cstring>

namespace td {

template <int buffer_size = 32 * (1 << 10)>
class MemoryLog : public LogInterface {
  static constexpr size_t MAX_OUTPUT_SIZE = buffer_size / 16 < (8 << 10) ? buffer_size / 16 : (8 << 10);

 public:
  MemoryLog() {
    std::memset(buffer_, ' ', sizeof(buffer_));
  }

  void append(CSlice new_slice, int log_level) override {
    Slice slice = new_slice;
    slice.truncate(MAX_OUTPUT_SIZE);
    while (!slice.empty() && slice.back() == '\n') {
      slice.remove_suffix(1);
    }
    size_t slice_size = slice.size();
    CHECK(slice_size * 3 < buffer_size);
    size_t pad_size = ((slice_size + 15) & ~15) - slice_size;
    constexpr size_t magic_size = 16;
    uint32 total_size = static_cast<uint32>(slice_size + pad_size + magic_size);
    uint32 real_pos = pos_.fetch_add(total_size, std::memory_order_relaxed);
    CHECK((total_size & 15) == 0);

    uint32 start_pos = real_pos & (buffer_size - 1);
    uint32 end_pos = start_pos + total_size;
    if (likely(end_pos <= buffer_size)) {
      std::memcpy(&buffer_[start_pos + magic_size], slice.data(), slice_size);
      std::memcpy(&buffer_[start_pos + magic_size + slice_size], "                     ", pad_size);
    } else {
      size_t first = buffer_size - start_pos - magic_size;
      size_t second = slice_size - first;
      std::memcpy(&buffer_[start_pos + magic_size], slice.data(), first);
      std::memcpy(&buffer_[0], slice.data() + first, second);
      std::memcpy(&buffer_[second], "                            ", pad_size);
    }

    CHECK((start_pos & 15) == 0);
    CHECK(start_pos <= buffer_size - magic_size);
    buffer_[start_pos] = '\n';
    size_t printed = std::snprintf(&buffer_[start_pos + 1], magic_size - 1, "LOG:%08x: ", real_pos);
    CHECK(printed == magic_size - 2);
    buffer_[start_pos + magic_size - 1] = ' ';

    if (log_level == VERBOSITY_NAME(FATAL)) {
      process_fatal_error(new_slice);
    }
  }

  void rotate() override {
  }

  Slice get_buffer() const {
    return Slice(buffer_, sizeof(buffer_));
  }

  size_t get_pos() const {
    return pos_ & (buffer_size - 1);
  }

 private:
  char buffer_[buffer_size];
  std::atomic<uint32> pos_{0};
};

}  // namespace td
