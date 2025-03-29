//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/tl/tl_string_outputer.h"

namespace td {
namespace tl {

void tl_string_outputer::append(const std::string &str) {
  result += str;
}

std::string tl_string_outputer::get_result() const {
#if defined(_WIN32)
  std::string fixed_result;
  for (std::size_t i = 0; i < result.size(); i++) {
    if (result[i] == '\n') {
      fixed_result += '\r';
    }
    fixed_result += result[i];
  }
  return fixed_result;
#else
  return result;
#endif
}

}  // namespace tl
}  // namespace td
