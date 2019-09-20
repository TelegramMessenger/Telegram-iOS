/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "ton-types.h"
#include "td/utils/bits.h"
#include "crypto/common/bitstring.h"

namespace ton {

constexpr ShardId rootShardId = (1ULL << 63);

inline AccountIdPrefix extract_top64(td::UInt256 addr) {
  return td::ConstBitPtr{addr.raw}.get_uint(64);
}

inline AccountIdPrefix extract_top64(const Bits256& addr) {
  return addr.cbits().get_uint(64);
}

inline AccountIdPrefix extract_top64(td::ConstBitPtr addr) {
  return addr.get_uint(64);
}

inline AccountIdPrefixFull extract_addr_prefix(WorkchainId workchain, const StdSmcAddress& addr) {
  return AccountIdPrefixFull{workchain, extract_top64(addr)};
}

inline AccountIdPrefixFull extract_addr_prefix(WorkchainId workchain, td::ConstBitPtr addr) {
  return AccountIdPrefixFull{workchain, extract_top64(addr)};
}

inline int count_matching_bits(AccountIdPrefix x, AccountIdPrefix y) {
  return x == y ? 64 : td::count_leading_zeroes64(x ^ y);
}

inline int count_matching_bits(AccountIdPrefixFull x, AccountIdPrefixFull y) {
  if (x.workchain != y.workchain) {
    return td::count_leading_zeroes32(x.workchain ^ y.workchain);
  } else {
    return 32 + count_matching_bits(x.account_id_prefix, y.account_id_prefix);
  }
}

inline td::uint32 shard_prefix_length(ShardId shard) {
  return shard ? 63 - td::count_trailing_zeroes_non_zero64(shard) : 0;
}

inline td::uint32 shard_prefix_length(ShardIdFull shard) {
  return shard_prefix_length(shard.shard);
}

inline bool shard_is_ancestor(ShardId parent, ShardId child) {
  td::uint64 x = td::lower_bit64(parent), y = td::lower_bit64(child);
  return x >= y && !((parent ^ child) & (td::bits_negate64(x) << 1));
}

inline bool shard_is_proper_ancestor(ShardId parent, ShardId child) {
  td::uint64 x = td::lower_bit64(parent), y = td::lower_bit64(child);
  return x > y && !((parent ^ child) & (td::bits_negate64(x) << 1));
}

inline bool shard_is_ancestor(ShardIdFull parent, ShardIdFull child) {
  return parent.workchain == child.workchain && shard_is_ancestor(parent.shard, child.shard);
}

inline bool shard_is_proper_ancestor(ShardIdFull parent, ShardIdFull child) {
  return parent.workchain == child.workchain && shard_is_proper_ancestor(parent.shard, child.shard);
}

inline bool shard_contains(ShardId parent, AccountIdPrefix child) {
  td::uint64 x = td::lower_bit64(parent);
  return !((parent ^ child) & (td::bits_negate64(x) << 1));
}

inline bool shard_contains(ShardIdFull parent, ShardIdFull child) {
  return parent.workchain == child.workchain && shard_contains(parent.shard, child.shard);
}

inline bool shard_contains(ShardIdFull parent, const AccountIdPrefixFull& child) {
  return parent.workchain == child.workchain && shard_contains(parent.shard, child.account_id_prefix);
}

inline bool shard_contains(ShardId parent, const StdSmcAddress& addr) {
  return shard_contains(parent, extract_top64(addr));
}

inline bool shard_intersects(ShardId x, ShardId y) {
  td::uint64 z = std::max(td::lower_bit64(x), td::lower_bit64(y));
  return !((x ^ y) & (td::bits_negate64(z) << 1));
}

inline bool shard_intersects(ShardIdFull x, ShardIdFull y) {
  return x.workchain == y.workchain && shard_intersects(x.shard, y.shard);
}

inline ShardId shard_intersection(ShardId x, ShardId y) {
  return td::lower_bit64(x) < td::lower_bit64(y) ? x : y;
}

inline ShardIdFull shard_intersection(ShardIdFull x, ShardIdFull y) {
  return {x.workchain, shard_intersection(x.shard, y.shard)};
}

inline bool is_right_child(ShardId x) {
  return x & (td::lower_bit64(x) << 1);
}

inline bool is_left_child(ShardId x) {
  return !is_right_child(x);
}

inline bool is_right_child(ShardIdFull shard) {
  return is_right_child(shard.shard);
}

inline bool is_left_child(ShardIdFull shard) {
  return is_left_child(shard.shard);
}

template <typename T>
inline bool shard_is_ancestor(ShardId parent, T child) {
  return shard_contains(parent, extract_top64(child));
}

inline ShardId shard_prefix(ShardId id, td::uint32 len) {
  CHECK(len <= 63);
  td::uint64 x = td::lower_bit64(id), y = 1ULL << (63 - len);
  CHECK(y >= x);
  return (id & td::bits_negate64(y)) | y;
}

inline ShardIdFull shard_prefix(ShardIdFull id, td::uint32 len) {
  return ShardIdFull{id.workchain, shard_prefix(id.shard, len)};
}

inline ShardIdFull shard_prefix(AccountIdPrefixFull id, td::uint32 len) {
  ShardId y = 1ULL << (63 - len);
  return ShardIdFull{id.workchain, (id.account_id_prefix & td::bits_negate64(y)) | y};
}

template <typename T>
inline ShardId shard_prefix(T addr, td::uint32 len) {
  CHECK(len <= 63);
  td::uint64 y = 1ULL << (63 - len);
  return (extract_top64(addr) & td::bits_negate64(y)) | y;
}

inline ShardId shard_parent(ShardId shard) {
  td::uint64 x = td::lower_bit64(shard);
  CHECK(x);
  return (shard - x) | (x << 1);
}

inline ShardIdFull shard_parent(ShardIdFull shard) {
  return ShardIdFull{shard.workchain, shard_parent(shard.shard)};
}

inline bool shard_is_parent(ShardId parent, ShardId child) {
  td::uint64 y = td::lower_bit64(child);
  return y && shard_parent(child) == parent;
}

inline bool shard_is_parent(ShardIdFull parent, ShardIdFull child) {
  return parent.workchain == child.workchain && shard_is_parent(parent.shard, child.shard);
}

inline ShardId shard_child(ShardId shard, bool left) {
  td::uint64 x = td::lower_bit64(shard) >> 1;
  CHECK(x);
  return left ? shard - x : shard + x;
}

inline ShardIdFull shard_child(ShardIdFull shard, bool left) {
  return ShardIdFull{shard.workchain, shard_child(shard.shard, left)};
}

inline bool shard_is_sibling(ShardId x, ShardId y) {
  return (x ^ y) && ((x ^ y) == ((x & td::bits_negate64(x)) << 1));
}

inline bool shard_is_sibling(ShardIdFull x, ShardIdFull y) {
  return x.workchain == y.workchain && shard_is_sibling(x.shard, y.shard);
}

inline ShardId shard_sibling(ShardId x) {
  return x ^ ((x & td::bits_negate64(x)) << 1);
}

inline ShardIdFull shard_sibling(ShardIdFull shard) {
  return ShardIdFull{shard.workchain, shard_sibling(shard.shard)};
}

}  // namespace ton
