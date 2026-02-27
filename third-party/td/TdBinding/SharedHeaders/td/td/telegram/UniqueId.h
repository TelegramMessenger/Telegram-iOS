//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <atomic>

namespace td {

class UniqueId {
 public:
  enum Type : uint8 { Default, DcAuth, GetConfig, BindKey, TempFile };
  static uint64 next() {
    return next(Default, 0);
  }
  static uint64 next(Type type) {
    return next(type, 0);
  }
  static uint64 next(Type type, uint8 key) {
    // TODO: this is VERY ineffective
    static std::atomic<uint64> current_id{1};
    return ((current_id.fetch_add(1, std::memory_order_relaxed)) << 16) | (static_cast<uint64>(type) << 8) | key;
  }

  static uint8 extract_key(uint64 id) {
    return static_cast<uint8>(id);
  }
  static Type extract_type(uint64 id) {
    return static_cast<Type>(static_cast<uint8>(id >> 8));
  }
};

}  // namespace td
