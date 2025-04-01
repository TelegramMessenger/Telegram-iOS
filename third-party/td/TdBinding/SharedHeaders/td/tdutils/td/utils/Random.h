//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <utility>

namespace td {

class Random {
 public:
#if TD_HAVE_OPENSSL
  static void secure_bytes(MutableSlice dest);
  static void secure_bytes(unsigned char *ptr, size_t size);
  static int32 secure_int32();
  static int64 secure_int64();
  static uint32 secure_uint32();
  static uint64 secure_uint64();

  // works only for current thread
  static void add_seed(Slice bytes, double entropy = 0);
  static void secure_cleanup();

  template <class T>
  static void shuffle(vector<T> &v) {
    for (size_t i = 1; i < v.size(); i++) {
      auto pos = static_cast<size_t>(secure_int32()) % (i + 1);
      using std::swap;
      swap(v[i], v[pos]);
    }
  }
#endif

  static uint32 fast_uint32();
  static uint64 fast_uint64();

  // distribution is not uniform, min_value and max_value are included
  static int fast(int min_value, int max_value);
  static double fast(double min_value, double max_value);
  static bool fast_bool();

  class Fast {
   public:
    uint64 operator()() {
      return fast_uint64();
    }
  };
  class Xorshift128plus {
   public:
    explicit Xorshift128plus(uint64 seed);
    Xorshift128plus(uint64 seed_a, uint64 seed_b);
    uint64 operator()();
    int fast(int min_value, int max_value);
    int64 fast64(int64 min_value, int64 max_value);
    void bytes(MutableSlice dest);

   private:
    uint64 seed_[2];
  };
};

}  // namespace td
