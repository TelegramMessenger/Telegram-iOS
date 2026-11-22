//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/ByteFlow.h"

#include <limits>

namespace td {

class HttpChunkedByteFlow final : public ByteFlowBase {
 public:
  bool loop() final;

 private:
  static constexpr size_t MAX_SIZE = std::numeric_limits<uint32>::max();  // some reasonable limit
  static constexpr size_t MIN_UPDATE_SIZE = 1 << 14;
  enum class State { ReadChunkLength, ReadChunkContent, OK };
  State state_ = State::ReadChunkLength;
  size_t len_ = 0;
  size_t save_len_ = 0;
  size_t total_size_ = 0;
};

}  // namespace td
