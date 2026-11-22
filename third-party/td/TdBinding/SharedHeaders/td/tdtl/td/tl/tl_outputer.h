//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <string>

namespace td {
namespace tl {

class tl_outputer {
 public:
  virtual void append(const std::string &str) = 0;

  virtual ~tl_outputer() = 0;
};

}  // namespace tl
}  // namespace td
