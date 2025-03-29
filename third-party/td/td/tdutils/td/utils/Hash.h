//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#if TD_HAVE_ABSL
#include <absl/hash/hash.h>
#endif

#include <utility>

namespace td {
// A simple wrapper for absl::flat_hash_map, std::unordered_map and probably some our implementation of hash map in
// the future

// We will introduce out own Hashing utility like an absl one.
class Hasher {
 public:
  Hasher() = default;
  explicit Hasher(size_t init_value) : hash_(init_value) {
  }
  std::size_t finalize() const {
    return hash_;
  }

  static Hasher combine(Hasher hasher, size_t value) {
    hasher.hash_ ^= value;
    return hasher;
  }

  template <class A, class B>
  static Hasher combine(Hasher hasher, const std::pair<A, B> &value) {
    hasher = AbslHashValue(std::move(hasher), value.first);
    hasher = AbslHashValue(std::move(hasher), value.second);
    return hasher;
  }

 private:
  std::size_t hash_{0};
};

template <class IgnoreT>
class TdHash {
 public:
  template <class T>
  std::size_t operator()(const T &value) const noexcept {
    return AbslHashValue(Hasher(), value).finalize();
  }
};

#if TD_HAVE_ABSL
template <class T>
using AbslHash = absl::Hash<T>;
#else
template <class T>
using AbslHash = TdHash<T>;
#endif

// default hash implementations
template <class H, class T>
decltype(H::combine(std::declval<H>(), std::declval<T>())) AbslHashValue(H hasher, const T &value) {
  return H::combine(std::move(hasher), value);
}

}  // namespace td
