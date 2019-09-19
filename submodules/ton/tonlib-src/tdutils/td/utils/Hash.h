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

#include "td/utils/common.h"

#if TD_HAVE_ABSL
#include <absl/hash/hash.h>
#endif

#include <utility>

namespace td {
// A simple wrapper for absl::flat_hash_map, std::unordered_map and probably some our implementaion of hash map in
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
#endif

// default hash implementations
template <class H, class T>
decltype(H::combine(std::declval<H>(), std::declval<T>())) AbslHashValue(H hasher, const T &value) {
  return H::combine(std::move(hasher), value);
}

#if TD_HAVE_ABSL
template <class T>
using Hash = AbslHash<T>;
#else
template <class T>
using Hash = TdHash<T>;
#endif

}  // namespace td
