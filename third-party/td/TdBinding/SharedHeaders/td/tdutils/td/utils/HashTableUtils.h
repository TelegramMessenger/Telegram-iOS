//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <cstdint>
#include <functional>

namespace td {

template <class EqT, class KeyT>
bool is_hash_table_key_empty(const KeyT &key) {
  return EqT()(key, KeyT());
}

inline uint32 randomize_hash(uint32 h) {
  h ^= h >> 16;
  h *= 0x85ebca6b;
  h ^= h >> 13;
  h *= 0xc2b2ae35;
  h ^= h >> 16;
  return h;
}

template <class Type>
struct Hash {
  uint32 operator()(const Type &value) const;
};

template <class Type>
struct Hash<Type *> {
  uint32 operator()(Type *pointer) const {
    return Hash<uint64>()(reinterpret_cast<std::uintptr_t>(pointer));
  }
};

template <>
inline uint32 Hash<char>::operator()(const char &value) const {
  return randomize_hash(static_cast<uint32>(value));
}

template <>
inline uint32 Hash<int32>::operator()(const int32 &value) const {
  return randomize_hash(static_cast<uint32>(value));
}

template <>
inline uint32 Hash<uint32>::operator()(const uint32 &value) const {
  return randomize_hash(value);
}

template <>
inline uint32 Hash<int64>::operator()(const int64 &value) const {
  return randomize_hash(static_cast<uint32>(value + (value >> 32)));
}

template <>
inline uint32 Hash<uint64>::operator()(const uint64 &value) const {
  return randomize_hash(static_cast<uint32>(value + (value >> 32)));
}

template <>
inline uint32 Hash<string>::operator()(const string &value) const {
  return static_cast<uint32>(std::hash<string>()(value));
}

inline uint32 combine_hashes(uint32 first_hash, uint32 second_hash) {
  return first_hash * 2023654985u + second_hash;
}

}  // namespace td
