//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/tl/tl_core.h"

#include <cassert>

namespace td {
namespace tl {

void tl_type::add_constructor(tl_combinator *new_constructor) {
  constructors.push_back(new_constructor);

  assert(constructors.size() <= constructors_num);
}

}  // namespace tl
}  // namespace td
