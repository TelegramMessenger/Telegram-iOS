//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/ByteFlow.h"

namespace td {

class HttpContentLengthByteFlow final : public ByteFlowBase {
 public:
  HttpContentLengthByteFlow() = default;
  explicit HttpContentLengthByteFlow(size_t len) : len_(len) {
  }
  bool loop() final;

 private:
  static constexpr size_t MIN_UPDATE_SIZE = 1 << 14;
  size_t len_ = 0;
};

}  // namespace td
