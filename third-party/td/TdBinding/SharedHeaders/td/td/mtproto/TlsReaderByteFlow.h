//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/ByteFlow.h"

namespace td {
namespace mtproto {

class TlsReaderByteFlow final : public ByteFlowBase {
 public:
  bool loop() final;
};

}  // namespace mtproto
}  // namespace td
