//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Slice.h"

namespace td {
namespace mtproto {

class DhCallback {
 public:
  DhCallback() = default;
  DhCallback(const DhCallback &) = delete;
  DhCallback &operator=(const DhCallback &) = delete;
  DhCallback(DhCallback &&) = delete;
  DhCallback &operator=(DhCallback &&) = delete;
  virtual ~DhCallback() = default;

  virtual int is_good_prime(Slice prime_str) const = 0;
  virtual void add_good_prime(Slice prime_str) const = 0;
  virtual void add_bad_prime(Slice prime_str) const = 0;
};

}  // namespace mtproto
}  // namespace td
