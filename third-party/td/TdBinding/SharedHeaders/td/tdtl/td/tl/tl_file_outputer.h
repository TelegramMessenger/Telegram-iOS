//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_outputer.h"

#include <cstdio>
#include <string>

namespace td {
namespace tl {

class tl_file_outputer : public tl_outputer {
  FILE *f;

  void close();

 public:
  tl_file_outputer();

  bool open(const std::string &file_name);

  virtual void append(const std::string &str);

  virtual ~tl_file_outputer();
};

}  // namespace tl
}  // namespace td
