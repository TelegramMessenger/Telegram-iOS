//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/TlStorerToString.h"

namespace td {

template <class T>
class TlDowncastHelper final : public T {
 public:
  explicit TlDowncastHelper(int32 constructor) : constructor_(constructor) {
  }
  int32 get_id() const final {
    return constructor_;
  }
  void store(TlStorerToString &s, const char *field_name) const final {
  }

 private:
  int32 constructor_{0};
};

}  // namespace td
