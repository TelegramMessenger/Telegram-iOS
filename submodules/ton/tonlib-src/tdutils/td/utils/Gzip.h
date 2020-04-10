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
  Gzip(Gzip &&other);
  Gzip &operator=(Gzip &&other);
  ~Gzip();

  enum Mode { Empty, Encode, Decode };
  Status init(Mode mode) TD_WARN_UNUSED_RESULT {
    if (mode == Encode) {
      return init_encode();
    } else if (mode == Decode) {
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

  enum State { Running, Done };
  Result<State> run() TD_WARN_UNUSED_RESULT;

 private:
  class Impl;
  unique_ptr<Impl> impl_;

  size_t input_size_ = 0;
  size_t output_size_ = 0;
  bool close_input_flag_ = false;
  Mode mode_ = Empty;

  void init_common();
  void clear();

  void swap(Gzip &other);
};

BufferSlice gzdecode(Slice s);

BufferSlice gzencode(Slice s, double k = 0.9);

}  // namespace td

#endif
