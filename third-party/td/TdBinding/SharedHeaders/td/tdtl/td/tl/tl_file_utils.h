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

std::string get_file_contents(const std::string &file_name);

bool put_file_contents(const std::string &file_name, const std::string &contents, bool compare_documentation);

std::string remove_documentation(const std::string &str);

}  // namespace tl
}  // namespace td
