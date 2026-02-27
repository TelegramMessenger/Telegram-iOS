//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/TlObject.h"

#include "td/utils/misc.h"

#include <cstdint>
#include <string>
#include <vector>

namespace td {

template <class Func, std::int32_t constructor_id>
class TlStoreBoxed {
 public:
  template <class T, class StorerT>
  static void store(const T &x, StorerT &storer) {
    storer.store_binary(constructor_id);
    Func::store(x, storer);
  }
};

template <class Func>
class TlStoreBoxedUnknown {
 public:
  template <class T, class StorerT>
  static void store(const T &x, StorerT &storer) {
    storer.store_binary(x->get_id());
    Func::store(x, storer);
  }
};

class TlStoreBool {
 public:
  template <class StorerT>
  static void store(const bool &x, StorerT &storer) {
    constexpr std::int32_t ID_BOOL_FALSE = 0xbc799737;
    constexpr std::int32_t ID_BOOL_TRUE = 0x997275b5;

    storer.store_binary(x ? ID_BOOL_TRUE : ID_BOOL_FALSE);
  }
};

class TlStoreBinary {
 public:
  template <class T, class StorerT>
  static void store(const T &x, StorerT &storer) {
    storer.store_binary(x);
  }
};

class TlStoreString {
 public:
  template <class T, class StorerT>
  static void store(const T &x, StorerT &storer) {
    storer.store_string(x);
  }
};

template <class Func>
class TlStoreVector {
 public:
  template <class T, class StorerT>
  static void store(const T &vec, StorerT &storer) {
    storer.store_binary(narrow_cast<int32>(vec.size()));
    for (auto &val : vec) {
      Func::store(val, storer);
    }
  }
};

class TlStoreObject {
 public:
  template <class T, class StorerT>
  static void store(const tl_object_ptr<T> &obj, StorerT &storer) {
    return obj->store(storer);
  }
};

}  // namespace td
