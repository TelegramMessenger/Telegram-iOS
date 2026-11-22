//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class Named {
 public:
  Slice get_name() const {
    return name_;
  }
  void set_name(Slice name) {
    name_ = name.str();
  }

 private:
  string name_;
};

}  // namespace td
