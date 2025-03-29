//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

class DhConfig {
 public:
  int32 version = 0;
  string prime;
  int32 g = 0;

  bool empty() const {
    return prime.empty();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_int(version);
    storer.store_string(prime);
    storer.store_int(g);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    version = parser.fetch_int();
    prime = parser.template fetch_string<std::string>();
    g = parser.fetch_int();
  }
};

}  // namespace td
