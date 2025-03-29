//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/FlatHashTable.h"

#include "td/utils/bits.h"
#include "td/utils/Random.h"

namespace td {
namespace detail {

uint32 normalize_flat_hash_table_size(uint32 size) {
  return td::max(static_cast<uint32>(1) << (32 - count_leading_zeroes32(size)), static_cast<uint32>(8));
}

uint32 get_random_flat_hash_table_bucket(uint32 bucket_count_mask) {
  return Random::fast_uint32() & bucket_count_mask;
}

}  // namespace detail
}  // namespace td
