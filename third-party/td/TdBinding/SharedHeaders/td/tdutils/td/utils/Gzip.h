//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#if TD_HAVE_ZLIB
#include "td/utils/buffer.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class Gzip {
 public:
  Gzip();
  Gzip(const Gzip &) = delete;
  Gzip &operator=(const Gzip &) = delete;
  Gzip(Gzip &&other) noexcept;
  Gzip &operator=(Gzip &&other) noexcept;
  ~Gzip();

  enum class Mode { Empty, Encode, Decode };
  Status init(Mode mode) TD_WARN_UNUSED_RESULT {
    if (mode == Mode::Encode) {
      return init_encode();
    } else if (mode == Mode::Decode) {
      return init_decode();
    }
    clear();
    return Status::OK();
  }

  Status init_encode() TD_WARN_UNUSED_RESULT;

  Status init_decode() TD_WARN_UNUSED_RESULT;

  void set_input(Slice input);

  void set_output(MutableSlice output);

  void close_input() {
    close_input_flag_ = true;
  }

  bool need_input() const {
    return left_input() == 0;
  }

  bool need_output() const {
    return left_output() == 0;
  }

  size_t left_input() const;

  size_t left_output() const;

  size_t used_input() const {
    return input_size_ - left_input();
  }

  size_t used_output() const {
    return output_size_ - left_output();
  }

  size_t flush_input() {
    auto res = used_input();
    input_size_ = left_input();
    return res;
  }

  size_t flush_output() {
    auto res = used_output();
    output_size_ = left_output();
    return res;
  }

  enum class State { Running, Done };
  Result<State> run() TD_WARN_UNUSED_RESULT;

 private:
  class Impl;
  unique_ptr<Impl> impl_;

  size_t input_size_ = 0;
  size_t output_size_ = 0;
  bool close_input_flag_ = false;
  Mode mode_ = Mode::Empty;

  void init_common();
  void clear();

  void swap(Gzip &other);
};

BufferSlice gzdecode(Slice s);

BufferSlice gzencode(Slice s, double max_compression_ratio);

}  // namespace td

#endif
