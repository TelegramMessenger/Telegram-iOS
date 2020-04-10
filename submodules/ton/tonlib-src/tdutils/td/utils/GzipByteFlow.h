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

#include "td/utils/ByteFlow.h"
#include "td/utils/Gzip.h"

#include <limits>

namespace td {

#if TD_HAVE_ZLIB
class GzipByteFlow final : public ByteFlowBase {
 public:
  GzipByteFlow() = default;

  explicit GzipByteFlow(Gzip::Mode mode) {
    gzip_.init(mode).ensure();
  }

  void init_decode() {
    gzip_.init_decode().ensure();
  }

  void init_encode() {
    gzip_.init_encode().ensure();
  }

  void set_max_output_size(size_t max_output_size) {
    max_output_size_ = max_output_size;
  }

  void loop() override;

 private:
  Gzip gzip_;
  size_t uncommited_size_ = 0;
  size_t total_output_size_ = 0;
  size_t max_output_size_ = std::numeric_limits<size_t>::max();
  static constexpr size_t MIN_UPDATE_SIZE = 1 << 14;
};
#endif

}  // namespace td
